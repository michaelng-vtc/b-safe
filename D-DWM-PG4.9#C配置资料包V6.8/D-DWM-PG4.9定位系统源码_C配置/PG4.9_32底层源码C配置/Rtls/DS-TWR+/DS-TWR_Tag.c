#include "DS-TWR.h"
#include "oled.h"
#include "modbus.h"
#include "bsp_uart.h"
#include "bsp_timer.h"
#include "port.h"

uint8_t SYS_Calculate_PASSIVE_FLAG=0;   				//系统循环标志位被动测距函数

uint16_t   Calculate_Receive_FLAG=0;      //标签接收到的信息标志位
uint16_t   Calculate_Receive_MODE=0;      //标签接收到的定位模式数据
Cal_data_t Last_cal_Data;
extern uint16_t Timer1_error_flag;

void Tag_Output_Handler_DS(void);


/******************************************************************************
						标签应答基站并进行测距
*******************************************************************************/
int32_t DW1000receive(uint8_t B_ID) //被动
{
	uint8_t i;
	if(SYS_Calculate_PASSIVE_FLAG==0)  //打开接收
	{
//				ERROR_FLAG=0;        //错误标志归0
		dwt_setrxaftertxdelay(0);			
		dwt_setrxtimeout(11000);//设定接收超时时间，0位没有超时时间
		dwt_rxenable(0);//打开接收
		SYS_Calculate_PASSIVE_FLAG=1;
	}
	if(SYS_Calculate_PASSIVE_FLAG==1)  //等待接收
	{
		if((status_reg = dwt_read32bitreg(SYS_STATUS_ID)) & (SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR))//不断查询芯片状态直到接收成功或者出现错误
		{
			SYS_Calculate_PASSIVE_FLAG=2;
		}
		else return 0;
	}					
			
	if(SYS_Calculate_PASSIVE_FLAG==2)  //验证是否成功接收
	{
		if (status_reg & SYS_STATUS_RXFCG_BIT_MASK)//成功接收
		{
			SYS_Calculate_PASSIVE_FLAG=3;
		}
		else
		{
			/* Clear RX error events in the DW1000 status register. */
			dwt_write32bitreg(SYS_STATUS_ID,SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR);	
			//            dwt_rxreset();			
			SYS_Calculate_PASSIVE_FLAG=0;							
			return 0;
		}
	}
	if(SYS_Calculate_PASSIVE_FLAG==3)   //判断是否为有效数据包
	{
		dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_RXFCG_BIT_MASK);//清楚标志位
		frame_len = dwt_read32bitreg(RX_FINFO_ID) & FRAME_LEN_MAX;//获得接收数据长度
		dwt_readrxdata(DS_rx_buffer, frame_len, 0);//读取接收数据
		if (DS_rx_buffer[3]==0xAB&&B_ID==DS_rx_buffer[1])//判断数据
		{       
			SYS_Calculate_PASSIVE_FLAG=4;							
		}
		else 
		{	
			SYS_Calculate_PASSIVE_FLAG=0;
			return 0;
		}
	}
	if(SYS_Calculate_PASSIVE_FLAG==4)  //发送数据后打开接收
	{
		memcpy(DS_send_msg,DS_rx_buffer,DS_TX_BUF_LEN);							
		if(DS_rx_buffer[0]==0xFF) //判断是否为主基站的消息
		{
			Calculate_Receive_MODE=DS_rx_buffer[4];
			Last_cal_Data.Cal_Flag = DS_rx_buffer[5] << 16 | DS_rx_buffer[12] << 16 | DS_rx_buffer[13];
			Last_cal_Data.x = DS_rx_buffer[6] << 8 | DS_rx_buffer[7];
			Last_cal_Data.y = DS_rx_buffer[8] << 8 | DS_rx_buffer[9];
			Last_cal_Data.z = DS_rx_buffer[10] << 8 | DS_rx_buffer[11];

			for(i=0;i<ANCHOR_LIST_COUNT;i++)
			{
				Last_cal_Data.Dist[i] = DS_rx_buffer[14 + i*2] << 8 | DS_rx_buffer[15 + i*2];
			}												
		}
		Time_ts[1] = get_rx_timestamp_u64();//获得Poll包接收时间T2
		final_msg_set_ts(&DS_send_msg[8],Time_ts[1]);//将T2写入发送数据
		DS_send_msg[0]=B_ID;
		DS_send_msg[1]=DS_rx_buffer[0];
		DS_send_msg[2] = frame_seq_nb;
		DS_send_msg[3]=0XBC; 
		dwt_writetxdata(DS_RESP_LEN, DS_send_msg, 0);//写入发送数据
		dwt_writetxfctrl(DS_RESP_LEN, 0, 1);//设定发送长度
		dwt_setrxaftertxdelay(0);//设置发送后开启接收，并设定延迟时间
		dwt_setrxtimeout(9500);						//设置接收超时时间
		dwt_starttx(DWT_START_TX_IMMEDIATE | DWT_RESPONSE_EXPECTED);//立即发送，等待接收      
		SYS_Calculate_PASSIVE_FLAG=5;						
	}							
	if(SYS_Calculate_PASSIVE_FLAG==5)  //等待接收
	{
		if ((status_reg = dwt_read32bitreg(SYS_STATUS_ID)) & (SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR))///不断查询芯片状态直到接收成功或者出现错误
		{ 
			SYS_Calculate_PASSIVE_FLAG=6;
		}
		else return 0;
	}
	if(SYS_Calculate_PASSIVE_FLAG==6)  //验证是否成功接收
	{							
		if(frame_seq_nb<0xFF)
			frame_seq_nb++;
		else 
			frame_seq_nb=0;
		if (status_reg & SYS_STATUS_RXFCG_BIT_MASK)//接收成功
		{
			SYS_Calculate_PASSIVE_FLAG=7;
		}
		else
		{
			/* Clear RX error events in the DW1000 status register. */
			dwt_write32bitreg(SYS_STATUS_ID,SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR);	
			//              dwt_rxreset();						
			SYS_Calculate_PASSIVE_FLAG=0;
			return 0;
		}
	}
	if(SYS_Calculate_PASSIVE_FLAG==7)  //判断是否为有效数据
	{															
		dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_TXFRS_BIT_MASK);//清楚标志位
		frame_len = dwt_read32bitreg(RX_FINFO_ID) & FRAME_LEN_MAX;//数据长度
		dwt_readrxdata(DS_rx_buffer, frame_len, 0);//读取接收数据
		if ((DS_rx_buffer[3]==0xCD)&&(B_ID==DS_rx_buffer[1]))//判断是否为Fianl包
		{
			SYS_Calculate_PASSIVE_FLAG=8;
		}
		else 
		{
			SYS_Calculate_PASSIVE_FLAG=0;
			return 0;
		}
	}						
	if(SYS_Calculate_PASSIVE_FLAG==8)  //返回数据
	{						
		uint8_t send_len = DS_FIX_BUF_LEN;		
		//接收到数据透传的数据
		if(DS_rx_buffer[28] == 1)
		{
			Uwb_commu_helper_ptr->Recver.Data_Has_recv = 1;
			Uwb_commu_helper_ptr->Recver.Data_commu_len = DS_rx_buffer[29];
			memcpy(Uwb_commu_helper_ptr->Recver.DataBuff,&DS_rx_buffer[30],Uwb_commu_helper_ptr->Recver.Data_commu_len);
		}

		memcpy(DS_send_msg,DS_rx_buffer,DS_TX_BUF_LEN);


		/* Retrieve response transmission and final reception timestamps. */
		DS_send_msg[0]=B_ID;
		DS_send_msg[1]=DS_rx_buffer[0];
		DS_send_msg[3]=0XDE; 
		Time_ts[2] = get_tx_timestamp_u64();//获得response发送时间T3
		Time_ts[5] = get_rx_timestamp_u64();//获得final接收时间T6
		final_msg_set_ts(&DS_send_msg[12],Time_ts[2]);//将T3写入发送数据
		final_msg_set_ts(&DS_send_msg[24],Time_ts[5]);//将T6写入发送数据

		//如果需要数据透传
		DS_send_msg[28] = Uwb_commu_helper_ptr->Sender.Data_commu_En;
		if(Uwb_commu_helper_ptr->Sender.Data_commu_En && DS_rx_buffer[0] == Uwb_commu_helper_ptr->Sender.Data_commu_RevID)
		{							
			DS_send_msg[29] = Uwb_commu_helper_ptr->Sender.Data_commu_len;
			memcpy(&DS_send_msg[30],Uwb_commu_helper_ptr->Sender.DataBuff,Uwb_commu_helper_ptr->Sender.Data_commu_len);			
			Uwb_commu_helper_ptr->Sender.Data_commu_En = 0;
			send_len += Uwb_commu_helper_ptr->Sender.Data_commu_len;
		}
		else
		{
			DS_send_msg[29] = 0;
		}

		dwt_writetxdata(send_len, DS_send_msg, 0);//写入发送数据
		dwt_writetxfctrl(send_len, 0, 1);//设定发送长度
		dwt_starttx(DWT_START_TX_IMMEDIATE );//设定为立刻发送
		SYS_Calculate_PASSIVE_FLAG=9;
	}						
	if(SYS_Calculate_PASSIVE_FLAG==9)  //验证是否发送完成
	{						
		if (dwt_read32bitreg(SYS_STATUS_ID) & SYS_STATUS_TXFRS_BIT_MASK)//不断查询芯片状态直到发送完成
		{ 
			dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_TXFRS_BIT_MASK);//清楚标志位										
			SYS_Calculate_PASSIVE_FLAG=0;
			if(DS_rx_buffer[0]==0xFF) 
			{
				Calculate_Receive_FLAG++; //如果是与主基站通讯，进行OLED显示
				return 2;  //主基站测距完成
			}

			return 1;     //次基站测距完成
		}
		else return 0;
	}									
	return 0;	
}

/******************************************************************************
												         标签模式函数
*******************************************************************************/
void MODE_TAG_DS(void)
{
	int32_t dis_buf=0;							
	dis_buf = DW1000receive(Device_cfg_ptr->Flash_Device_ID &0x00FF);	
	
	if(Calculate_Receive_FLAG>2)
	{
		#if (MODULE_USE != MODULE_PG17)
		if(OLED_display_time > 5)
		{
			OLED_display_data(Last_cal_Data.Dist[0],Last_cal_Data.x,Last_cal_Data.y,Last_cal_Data.z,Calculate_Receive_MODE + 1); //屏幕显示会卡住主流程通讯		启动屏幕显示会降低测距速率
			OLED_display_time = 0;
		}
		else
			OLED_display_time++;	
		#endif
		Calculate_Receive_FLAG=0;
	}	
		
	if(dis_buf==2)  //串口输出
	{				
		Tag_Output_Handler_DS();  //定位测距数据输出  如果想要更高速率 可以考虑标签不输出数据
	
			//数据透传
		if(Uwb_commu_helper_ptr->Recver.Data_Has_recv == 1)  //获取到数据透传信息 串口输出
		{
			Modbus_writeRecvData(0xFF,Uwb_commu_helper_ptr->Recver.DataBuff, Uwb_commu_helper_ptr->Recver.Data_commu_len);
			memset(Uwb_commu_helper_ptr->Recver.DataBuff,0,sizeof(Uwb_commu_helper_ptr->Recver.DataBuff));
			Uwb_commu_helper_ptr->Recver.Data_Has_recv = 0;
		}			
	}
	
	if(dis_buf!=0)//测距成功
	{   		
		Timer1_error_flag=0;        //错误标志归0				
		if(LED_FLAG > 5)
		{
			LED1_TOGGLE();
			LED_FLAG=0;						  
		} 
		else 
			LED_FLAG++;
		SYS_Calculate_PASSIVE_FLAG=0;
	}
	
	if(Timer1_error_flag > Device_cfg_ptr->Uwb_config.Twr_Error_max)   //测距发生错误
	{				
		SYS_Calculate_PASSIVE_FLAG=0;
		Timer1_error_flag=0;        //错误标志归0
		dwt_forcetrxoff();
	}					
}

void Tag_Output_Handler_DS(void)
{
	if(Device_cfg_ptr->Tag_output_cfg.output_en == 0)
		return;
	//	memset(Tag_Usart_Str,0,sizeof(Tag_Usart_Str));
	if(Device_cfg_ptr->Tag_output_cfg.ouput_protocal == 0)    //自由输出
	{
		Prepare_tag_result_output(&Last_cal_Data,Device_cfg_ptr->Tag_output_cfg.output_format,Calculate_Receive_MODE);
//		Usart1_SendString((unsigned char*)Tag_Usart_Str,strlen((const char*)Tag_Usart_Str));
		Uart_Sendstring((unsigned char*)Tag_Usart_Str,strlen((const char*)Tag_Usart_Str));
	}
	else if(Device_cfg_ptr->Tag_output_cfg.ouput_protocal == 1)  //modbus输出
	{
		int16_t last_xyz[3] = {Last_cal_Data.x,Last_cal_Data.y,Last_cal_Data.z};
		Modbus_writeTagoutput_Data(Last_cal_Data.Cal_Flag, Last_cal_Data.Dist,last_xyz);
	}
}			

