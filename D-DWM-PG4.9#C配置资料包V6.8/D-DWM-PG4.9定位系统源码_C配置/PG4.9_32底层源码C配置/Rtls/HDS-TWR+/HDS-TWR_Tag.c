#include "HDS-TWR.h"
#include "oled.h"
#include "modbus.h"
#include "bsp_uart.h"
#include "bsp_timer.h"
#include "port.h"

extern uint16_t Timer1_error_flag;
extern uint16_t Timer1_tag_waitresp_flag;

uint8_t SYS_TAG_INFORM_FLAG = 0;             //标签接收Inform包标志位
uint8_t SYS_TAG_RESP_FLAG = 0;               //标签接收Resp包标志位
uint8_t SYS_TAG_FINAL_FLAG = 0;              //标签发送Final包标志位
uint8_t SYS_TAG_FLAG = 0;                    //标签主流程标志位

Cal_data_t Last_cal_data_hds;
//int16 Last_x = 0;                       //上一次定位坐标x
//int16 Last_y = 0;                       //上一次定位坐标y
//int16 Last_z = 0;                       //上一次定位坐标z
//uint16 Last_Dist[ANCHOR_LIST_COUNT] = {0};               //上一次测距8个基站的距离

uint8_t Timer_Tag_Tick = 8;                  //监听基站发送Resp包计时器计时到时值
uint8_t Time_Up_Tag = 0;                     //监听Resp包计时器到时指示 1：到时
uint32 Resp_TimeList[ANCHOR_LIST_COUNT];                //接收Resp包缓存

uint32 Poll_Send_Time;                  //发送Poll包时间
uint8_t Cal_anc_num;                         //计算基站数量  可用于再次加快流程 目前没有用到

#define Tag_delay_base_ms 0x3CE00;      //标签延时发送Final包的延时基底，该数乘上x后与系统时间相加 代表大约延时xms发送 0x3CE00
uint8_t Tag_delay_SendFinal_time = 1;        //标签延时发送Final包时间 单位为毫秒

uint8_t Calculate_Tag_Mode = 0;              //标签接收到主基站的定位模式
uint8_t tag_device_id = 0;

void Tag_Output_Handler_HDS(void);


/*! ------------------------------------------------------------------------------------------------------------------
 * @fn HDS_TWR_Tag_RecvInform(uint8_t TAG_ID)
 *
 * @brief  标签监听Recv包
 *
 * input parameters:
 * @param TAG_ID - 标签ID
 *
 * output parameters
 * 
 * returns 0：无事发生 1：接收到Inform包并成功回送Poll包 2：发送Poll包失败
 */
uint8_t HDS_TWR_Tag_RecvInform(uint8_t TAG_ID)
{
  if(SYS_TAG_INFORM_FLAG == 0)
	{ 
		dwt_setrxtimeout(0);               //设定接收超时时间，0位没有超时时间
		dwt_rxenable(0);
		SYS_TAG_INFORM_FLAG = 1;
	}		
	
	if(SYS_TAG_INFORM_FLAG == 1)
	{
		if((status_reg = dwt_read32bitreg(SYS_STATUS_ID)) & (SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR))//不断查询芯片状态直到接收成功或者出现错误
		{
//			NRF_LOG_INFO("status reg:%x",status_reg);
			SYS_TAG_INFORM_FLAG = 2;
		}		
		else 
		{			
			return 0;
		}
			
	}		
	
	if(SYS_TAG_INFORM_FLAG == 2)
	{
		if (status_reg & SYS_STATUS_RXFCG_BIT_MASK)    //成功接收
		{
//			NRF_LOG_INFO("status reg:%x",status_reg);
			SYS_TAG_INFORM_FLAG = 3;
		}
		else                                  //接收超时
		{
			/* Clear RX error events in the DW1000 status register. */
			dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR);
//				dwt_rxreset();
			SYS_TAG_INFORM_FLAG=0;							
			return 0;
		}
	}		
	
	if(SYS_TAG_INFORM_FLAG == 3)
	{
		dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_RXFCG_BIT_MASK);                           //清除标志位
		frame_len = dwt_read32bitreg(RX_FINFO_ID) & FRAME_LEN_MAX;          //获得接收数据长度
		dwt_readrxdata(HDS_rx_buffer, frame_len, 0);                                        //读取接收数据
		if(HDS_rx_buffer[0] == 0xFF && HDS_rx_buffer[1] == TAG_ID && HDS_rx_buffer[3] == 0xAA)          //接收到该标签的Inform包
		{
			SYS_TAG_INFORM_FLAG = 4;
		}			
		else
		{
			dwt_setrxtimeout(0);               //设定接收超时时间，0位没有超时时间
			dwt_rxenable(0);
			SYS_TAG_INFORM_FLAG = 1;
		}		
	}		
	
	if(SYS_TAG_INFORM_FLAG == 4)                                                    
	{
		uint8_t i;
		frame_now = HDS_rx_buffer[2];
//    Calculate_Anc = HDS_rx_buffer[4];
		Calculate_Tag_Mode = HDS_rx_buffer[6];
//		printf("Recv frame:%d\r\n",frame_now);
		//获取上一次计算坐标和测距信息
		Last_cal_data_hds.Cal_Flag = HDS_rx_buffer[7] << 16 | HDS_rx_buffer[14] << 8 | HDS_rx_buffer[15];
		Last_cal_data_hds.x = HDS_rx_buffer[8] << 8 | HDS_rx_buffer[9];
		Last_cal_data_hds.y = HDS_rx_buffer[10] << 8 | HDS_rx_buffer[11];
		Last_cal_data_hds.z = HDS_rx_buffer[12] << 8 | HDS_rx_buffer[13];
		
		for(i=0;i<ANCHOR_LIST_COUNT;i++)		
			Last_cal_data_hds.Dist[i] = HDS_rx_buffer[16 + i*2] << 8 | HDS_rx_buffer[17 + i*2];
		memset(Resp_TimeList,0,sizeof(Resp_TimeList));                                 //清空缓存Resp时间戳数组
//		deca_sleep(1);                                                                 //多加1ms 使后面次基站的接收更容易接收成功
		SYS_TAG_INFORM_FLAG = 5;
	}

	if(SYS_TAG_INFORM_FLAG == 5)                                                     //发送Poll包
	{
		uint8_t ret;
		uint8_t send_len = TX_TAG_POLL_FIX_LEN;
//		dwt_forcetrxoff();
		memset(TX_TAG_POLL_BUFF,0,sizeof(TX_TAG_POLL_BUFF));
		TX_TAG_POLL_BUFF[0] = TAG_ID;
		TX_TAG_POLL_BUFF[1] = 0x00;
		TX_TAG_POLL_BUFF[2] = frame_now;
		TX_TAG_POLL_BUFF[3] = 0xAB;
		
		//数据透传需要发送
		if(Uwb_commu_helper_ptr->Sender.Data_commu_En)
		{
			TX_TAG_POLL_BUFF[4] = 1;
			TX_TAG_POLL_BUFF[5] = Uwb_commu_helper_ptr->Sender.Data_commu_len;
			memcpy(&TX_TAG_POLL_BUFF[6],Uwb_commu_helper_ptr->Sender.DataBuff,Uwb_commu_helper_ptr->Sender.Data_commu_len);
			Uwb_commu_helper_ptr->Sender.Data_commu_En = 0;
			send_len += Uwb_commu_helper_ptr->Sender.Data_commu_len; 
		}
		
		dwt_writetxdata(send_len, TX_TAG_POLL_BUFF, 0);                //将发送数据传到DW1000
		dwt_writetxfctrl(send_len, 0, 1);                                 //设定发送长度
		dwt_setrxaftertxdelay(0);				                                               //设定发送后打开接收时间
		ret = dwt_starttx(DWT_START_TX_IMMEDIATE);                                     //立即发送
		if(ret == DWT_SUCCESS)
			SYS_TAG_INFORM_FLAG = 6;
		else
			return 2;
	}
	
	if(SYS_TAG_INFORM_FLAG == 6)
	{
		if(((status_reg = dwt_read32bitreg(SYS_STATUS_ID)) & SYS_STATUS_TXFRS_BIT_MASK))
		{
			dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_TXFRS_BIT_MASK);                          //清除标志位   
			SYS_TAG_INFORM_FLAG = 0;
			return 1;
		}	
	}
	
	return 0;
}



/*! ------------------------------------------------------------------------------------------------------------------
 * @fn HDS_TWR_Tag_RecvResp(uint8_t TAG_ID)
 *
 * @brief  标签定时接收Recv包
 *
 * input parameters:
 * @param TAG_ID - 标签ID
 *
 * output parameters
 * 
 * returns 0：动作未完成 1：计时器到时接收结束
 */

uint8_t HDS_TWR_Tag_RecvResp(uint8_t TAG_ID)
{
	if(Time_Up_Tag == 1)
	{
		if(SYS_TAG_RESP_FLAG < 3)
			SYS_TAG_RESP_FLAG = 6;
	}
	
	if(SYS_TAG_RESP_FLAG == 0)
	{
		dwt_forcetrxoff();
		Timer1_tag_waitresp_flag = 0;
		Timer1_error_flag = 0;
		SYS_TAG_RESP_FLAG = 1;
	}
	
	if(SYS_TAG_RESP_FLAG == 1)
	{
		dwt_setrxtimeout(0);                                                        //设定接收超时时间，0位没有超时时间
		dwt_rxenable(0);
		SYS_TAG_RESP_FLAG = 2;
	}
	
	if(SYS_TAG_RESP_FLAG == 2)
	{
		if((status_reg = dwt_read32bitreg(SYS_STATUS_ID)) & (SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR))   //不断查询芯片状态直到接收成功或者出现错误
		{
			SYS_TAG_RESP_FLAG = 3;
		}
		else return 0;
	}

	if(SYS_TAG_RESP_FLAG == 3)
	{
		if (status_reg & SYS_STATUS_RXFCG_BIT_MASK)//成功接收
		{
			SYS_TAG_RESP_FLAG = 4;
		}
		else  //接收超时
		{
				/* Clear RX error events in the DW1000 status register. */
			dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR);
	
//			dwt_rxreset();
			if(Time_Up_Tag == 1)
				SYS_TAG_RESP_FLAG = 6;
			else
			{
				dwt_rxenable(0);
			  SYS_TAG_RESP_FLAG = 2;			//立刻重新打开接收
				return 0;
			}
			
		}
	}
	
	if(SYS_TAG_RESP_FLAG == 4)
	{
		dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_RXFCG_BIT_MASK);                           //清除标志位
		frame_len = dwt_read32bitreg(RX_FINFO_ID) & FRAME_LEN_MAX;          //获得接收数据长度
		dwt_readrxdata(HDS_rx_buffer, frame_len, 0);                                        //读取接收数据
		if(HDS_rx_buffer[1] == TAG_ID && HDS_rx_buffer[3] == 0xBC)
			SYS_TAG_RESP_FLAG = 5;
		else
		{
			dwt_rxenable(0);
			SYS_TAG_RESP_FLAG = 2;			//立刻重新打开接收
		}
	}

	if(SYS_TAG_RESP_FLAG == 5)
	{
		uint8_t anc_id = HDS_rx_buffer[0];
		//获取接收时间
		if(anc_id == 0xFF)    
			Resp_TimeList[0] = (uint32)get_rx_timestamp_u64();			                    //按照不同基站放到不同的接收缓存中	
		else
			Resp_TimeList[ANCHOR_LIST_COUNT - (0xFF - anc_id)] = (uint32)get_rx_timestamp_u64();
		
		//获取透传数据
		if(HDS_rx_buffer[4] == 1)
		{			
			Uwb_commu_helper_ptr->Recver.Data_commu_len = HDS_rx_buffer[5];
			memcpy(Uwb_commu_helper_ptr->Recver.DataBuff,&HDS_rx_buffer[6],Uwb_commu_helper_ptr->Recver.Data_commu_len);
			Uwb_commu_helper_ptr->Recver.Data_Has_recv = 1;
		}
		
		if(Time_Up_Tag == 1)
			SYS_TAG_RESP_FLAG = 6;
		else
		{
			dwt_rxenable(0);
			SYS_TAG_RESP_FLAG = 2;			//立刻重新打开接收
		}
	}	
	
	if(SYS_TAG_RESP_FLAG == 6)                                                       //计时器超时
	{
		Time_Up_Tag = 0;
		SYS_TAG_RESP_FLAG = 0;	
		dwt_forcetrxoff();
		Timer1_error_flag = 0;
		return 1;
	}	
	return 0;
}

/*! ------------------------------------------------------------------------------------------------------------------
 * @fn HDS_TWR_Tag_SendFinal(uint8_t TAG_ID)
 *
 * @brief  标签发送Final包 需写入估计的发送时间并以此时间延时发送
 *
 * input parameters:
 * @param TAG_ID - 标签ID
 *
 * output parameters
 * 
 * returns 0：动作未完成 1：发送成功 2：发送失败
 */
uint8_t HDS_TWR_Tag_SendFinal(uint8_t TAG_ID)
{
	if(SYS_TAG_FINAL_FLAG == 0)
	{
		uint8_t i;
		uint8_t ret;
		uint32 Last_rx_time_Hi32;
		uint64_t Final_Send_Time;
		uint32_t delay_time;

		memset(TX_TAG_FINAL_BUFF,0,sizeof(TX_TAG_FINAL_BUFF));
		TX_TAG_FINAL_BUFF[0] = TAG_ID;
		TX_TAG_FINAL_BUFF[1] = 0;
		TX_TAG_FINAL_BUFF[2] = frame_now;
		TX_TAG_FINAL_BUFF[3] = 0xCD;
		for(i=0;i<ANCHOR_LIST_COUNT;i++)
			final_msg_set_ts(&TX_TAG_FINAL_BUFF[4 + 4 * i],Resp_TimeList[i]);                //写入接收到各基站的Resp时间
		Poll_Send_Time = (uint32)get_tx_timestamp_u64();                                   //获取Poll包发送时间
		final_msg_set_ts(&TX_TAG_FINAL_BUFF[68],Poll_Send_Time);													 //写入Poll包发送时间
		
		
		//延时发送并估计发送时间
		Last_rx_time_Hi32 = dwt_readsystimestamphi32();
		delay_time = Last_rx_time_Hi32 + Tag_delay_SendFinal_time * Tag_delay_base_ms;
		dwt_setdelayedtrxtime(delay_time);                                                 //设置延时发送时间 DW1000会在delay_time的时间发送数据  
		
		Final_Send_Time = (((uint64_t)(delay_time & 0xFFFFFFFEUL)) << 8) + Device_cfg_ptr->Uwb_config.UWB_ANT_TX_DLY;       //估计发送时间 需要先左移八位
		final_msg_set_ts(&TX_TAG_FINAL_BUFF[72],Final_Send_Time);		                       //写入估计的发送时间
		dwt_writetxdata(sizeof(TX_TAG_FINAL_BUFF), TX_TAG_FINAL_BUFF, 0);                  //将Poll包数据传给DW1000，将在开启发送时传出去
		dwt_writetxfctrl(sizeof(TX_TAG_FINAL_BUFF), 0, 1);                                    //设置超宽带发送数据长度
		dwt_setrxaftertxdelay(0);				
		ret = dwt_starttx(DWT_START_TX_DELAYED);                                           //设置延时发送
		if(ret == DWT_SUCCESS)
			SYS_TAG_FINAL_FLAG=1;
		else  //发送失败
			return 2;
	}
	
	if(SYS_TAG_FINAL_FLAG == 1)
	{
		if((dwt_read32bitreg(SYS_STATUS_ID) & SYS_STATUS_TXFRS_BIT_MASK))
		{
			dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_TXFRS_BIT_MASK);//清除标志
			SYS_TAG_FINAL_FLAG = 0;
			return 1;
		}	
	}
	return 0;
}




/*! ------------------------------------------------------------------------------------------------------------------
 * @fn Mode_Tag_HDS()
 *
 * @brief  标签主流程
 *
 */
void Mode_Tag_HDS(void)
{
	uint8_t ret;

	
	//**** 监听Inform包 如接收到正确Inform包即发出Poll包 ****//
	if(SYS_TAG_FLAG == 0)  
	{
		tag_device_id = Device_cfg_ptr->Flash_Device_ID;  //单次测距过程中id不可修改
		ret = HDS_TWR_Tag_RecvInform(tag_device_id);
		if(ret == 1)
		{
			Timer1_error_flag = 0;
			SYS_TAG_FLAG = 1;
			Timer1_tag_waitresp_flag = 0;			
		}
	}
	
	//**** 监听Resp包 ****//
	if(SYS_TAG_FLAG == 1)    
	{
		if(Timer1_tag_waitresp_flag > Timer_Tag_Tick)                //判断计时器有无到时
			Time_Up_Tag = 1;
		ret = HDS_TWR_Tag_RecvResp(tag_device_id);
		if(ret == 1)                           
			SYS_TAG_FLAG = 2;
	}
	
	//**** 发送Final包 ****//
	if(SYS_TAG_FLAG == 2)  
	{
		ret = HDS_TWR_Tag_SendFinal(tag_device_id);  
		if(ret == 1)
			SYS_TAG_FLAG = 3;					
		else if(ret == 2)                             //发送失败
			SYS_TAG_FLAG = 0;
	}
	
	//**** 完成一次测距流程的动作 OLED显示和串口输出 ****//
	if(SYS_TAG_FLAG == 3)  
	{
		#if (MODULE_USE != MODULE_PG17)
		if(OLED_display_time > 50)
		{
			OLED_display_data(Last_cal_data_hds.Dist[0],Last_cal_data_hds.x,Last_cal_data_hds.y,Last_cal_data_hds.z,Calculate_Tag_Mode + 1);
			OLED_display_time = 0;
		}
		else
			OLED_display_time++;
		#endif
		NRF_LOG_INFO("hds ok frame:%d",frame_now);
//		printf("Twr Ok frame:%d\r\n",frame_now);
		
		/* 特殊处理 */
//		dwt_setrxtimeout(0);               //设定接收超时时间，0位没有超时时间
//		dwt_rxenable(0);                   //先马上打开接收 以准备下一次的测距
//	  SYS_TAG_INFORM_FLAG = 1;
			
		Tag_Output_Handler_HDS();	         //输出接收到的上一次的定位信息
		
		if(Uwb_commu_helper_ptr->Recver.Data_Has_recv == 1)          //获取到数据透传信息 串口输出
		{
//			uint8_t i;
//			printf("Main Anc:");
//			for(i=0;i<UWB_COMMU_DATA_MAXLEN;i++)
//			   printf("%c",Data_SendRecv[i]);
//			printf("\r\n");
//			Data_SendRecv_En = 0;
			Modbus_writeRecvData(0xFF,Uwb_commu_helper_ptr->Recver.DataBuff, Uwb_commu_helper_ptr->Recver.Data_commu_len);
			memset(Uwb_commu_helper_ptr->Recver.DataBuff,0,sizeof(Uwb_commu_helper_ptr->Recver.DataBuff));
			Uwb_commu_helper_ptr->Recver.Data_Has_recv = 0;
		}
		
		if(LED_FLAG > 5)
		{
			LED1_TOGGLE();
			LED_FLAG=0;
		}
		else 
			LED_FLAG++;
		
		Timer1_error_flag = 0;
		SYS_TAG_FLAG = 0;
	}
	
	if(Timer1_error_flag >Device_cfg_ptr->Uwb_config.Twr_Error_max)  //看门狗错误 复位  cfg_ptr->Uwb_config.Twr_Error_max
	{
		SYS_TAG_INFORM_FLAG = 0;
		SYS_TAG_RESP_FLAG = 0;
		SYS_TAG_FINAL_FLAG = 0;
		SYS_TAG_FLAG = 0;
		Timer1_tag_waitresp_flag = 0;
		dwt_forcetrxoff();
//		if((dwt_read32bitreg(SYS_STATUS_ID) & SYS_STATUS_HPDWARN))  //延时响应出错
//      dwt_write32bitreg(SYS_CTRL_ID, SYS_CTRL_TRXOFF);
		Timer1_error_flag = 0;
	}
	
}

void Tag_Write_dist_data(void)
{
	uint8_t i = 0;
	
}


void Tag_Output_Handler_HDS(void)
{
	
//	Device_config_t *cfg_ptr = Get_Device_config();
	if(Device_cfg_ptr->Tag_output_cfg.output_en == 0)
		return;
	
//	memset(Tag_Usart_Str,0,sizeof(Tag_Usart_Str));
	if(Device_cfg_ptr->Tag_output_cfg.ouput_protocal == 0)    //自由输出
	{
		Prepare_tag_result_output(&Last_cal_data_hds,Device_cfg_ptr->Tag_output_cfg.output_format,Calculate_Tag_Mode);
//		Usart1_SendString((unsigned char*)Tag_Usart_Str,strlen((const char*)Tag_Usart_Str));
		Uart_Sendstring((unsigned char*)Tag_Usart_Str,strlen((const char*)Tag_Usart_Str));
	}
	else if(Device_cfg_ptr->Tag_output_cfg.ouput_protocal == 1)  //modbus输出
	{
		int16_t last_xyz[3] = {Last_cal_data_hds.x,Last_cal_data_hds.y,Last_cal_data_hds.z};
		Modbus_writeTagoutput_Data(Last_cal_data_hds.Cal_Flag, Last_cal_data_hds.Dist,last_xyz);
	}
								 
}			



