#include "HDS-TWR.h"
#include "modbus.h"
#include "loc.h"
#include "oled.h"
#include "Filter.h"
#include "bsp_timer.h"
#include "common_config.h"
#include "port.h"
#include "App_remote_cfg.h"

#include "nrf_log.h"
#include "nrf_log_ctrl.h"
#include "nrf_log_default_backends.h"


uint8_t SYS_MAINANCHOR_FLAG = 0;       //主基站主流程标志位
uint8_t SYS_ANC_INFORM_FLAG = 0;       //基站发送INFORM包标志位
uint8_t SYS_ANC_REQ_FLAG = 0;          //基站发送REQ包标志位   
uint8_t SYS_ANC_REQ_REPLY_FLAG = 0;    //基站接收REPLY包标志位   

uint8_t Tag_ID = 0;                    //本次需要定位的标签ID
uint8_t Calculate_TAG_index = 0;       //扫描定位标签列表当前顺序

uint8_t ReqRetry_times = 0;            //主基站访问次基站测距值的重试次数

extern uint16_t Timer1_error_flag;

/*! ------------------------------------------------------------------------------------------------------------------
 * @fn HDS_TWR_Inform_Handle(uint8_t B_ID)
 *
 * @brief  主基站对要定位的标签发送Inform包并等待接收其Poll包
 *
 * input parameters:
 * @param B_ID - 标签ID
 *
 * output parameters
 * 
 * returns 0：动作未完成 1：发送成功 2：发送失败 3：接收超时 4：接收到其它次基站的Resp包
 */
uint8_t HDS_TWR_Inform_Handle(uint8_t B_ID)
{
	if(SYS_ANC_INFORM_FLAG == 0)
	{
		uint8_t i;
		uint8_t ret = 0;
		Device_config_t *cfg_ptr = Get_Device_config();
		memset(TX_ANC_INFORM_BUFF,0,sizeof(TX_ANC_INFORM_BUFF));
		
		if(frame_seq_nb < 0xFF)
			frame_seq_nb++;
		else
			frame_seq_nb = 0;
		
		TX_ANC_INFORM_BUFF[0] = 0xFF;
		TX_ANC_INFORM_BUFF[1] = B_ID;
		TX_ANC_INFORM_BUFF[2] = frame_seq_nb;
		TX_ANC_INFORM_BUFF[3] = 0xAA;
		TX_ANC_INFORM_BUFF[4] = cfg_ptr->Calculate_Anc_en >> 8 & 0x00FF;                               //写入基站使能信息
		TX_ANC_INFORM_BUFF[5] = cfg_ptr->Calculate_Anc_en & 0x00FF;
		TX_ANC_INFORM_BUFF[6] = cfg_ptr->Flash_structure_Mode;                         //写入定位模式 0测距 1二维定位 2三维定位
		
		//上次定位是否成功
		TX_ANC_INFORM_BUFF[7] = Cal_data[B_ID].Cal_Flag >> 16 & 0x01;
		//发送上次x坐标
		TX_ANC_INFORM_BUFF[8] = Cal_data[B_ID].x >> 8 & 0x00FF;  
		TX_ANC_INFORM_BUFF[9] = Cal_data[B_ID].x & 0x00FF;          
		//发送上次y坐标
		TX_ANC_INFORM_BUFF[10] = Cal_data[B_ID].y >> 8 & 0x00FF;
		TX_ANC_INFORM_BUFF[11] = Cal_data[B_ID].y & 0x00FF;
		//发送上次z坐标
		TX_ANC_INFORM_BUFF[12] = Cal_data[B_ID].z >> 8 & 0x00FF;
		TX_ANC_INFORM_BUFF[13] = Cal_data[B_ID].z & 0x00FF;
		
		//上次测距是否成功
		TX_ANC_INFORM_BUFF[14] = Cal_data[B_ID].Cal_Flag >> 8 & 0x00FF;
		TX_ANC_INFORM_BUFF[15] = Cal_data[B_ID].Cal_Flag & 0x00FF;
		//发送上次各个基站的测距值
		for(i=0;i<ANCHOR_LIST_COUNT;i++)
		{
			TX_ANC_INFORM_BUFF[16 + i * 2] = Cal_data[B_ID].Dist[i] >> 8 & 0x00FF;
			TX_ANC_INFORM_BUFF[17 + i * 2] = Cal_data[B_ID].Dist[i] & 0x00FF;
		}
		
		dwt_writetxdata(sizeof(TX_ANC_INFORM_BUFF), TX_ANC_INFORM_BUFF, 0);   //写入发送数据
		dwt_writetxfctrl(sizeof(TX_ANC_INFORM_BUFF), 0, 0);                   //设定发送长度
		dwt_setrxaftertxdelay(0);                                             //设置发送后开启接收，并设定延迟时间	
		dwt_setrxtimeout(5000);						                                    //设置接收超时时间
		
		ret = dwt_starttx(DWT_START_TX_IMMEDIATE | DWT_RESPONSE_EXPECTED);    //立即发送，等待接收
				
		if(ret == DWT_SUCCESS)									
			SYS_ANC_INFORM_FLAG = 1;								
		else      //发送错误 失败
		{
//			NRF_LOG_INFO("hds:poll send error. frame:%d",frame_seq_nb);
			return 2;
		}
			
	}
	
	if(SYS_ANC_INFORM_FLAG == 1)
	{
		if ((dwt_read32bitreg(SYS_STATUS_ID) & SYS_STATUS_TXFRS_BIT_MASK))             //不断查询芯片状态直到发送完成
		{ 
			dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_TXFRS_BIT_MASK);                 //清除标志位	
			SYS_ANC_INFORM_FLAG = 2;	
//			NRF_LOG_INFO("tx ok");
//			NRF_LOG_PROCESS();
		}	
		else 
			return 0;
	}
	
	if(SYS_ANC_INFORM_FLAG == 2)
	{
//		dwt_setrxtimeout(4500);						//设置接收超时时间
//		dwt_rxenable(0);
		SYS_ANC_INFORM_FLAG = 3;
	}
	
	if(SYS_ANC_INFORM_FLAG == 3)
	{
		if((status_reg = dwt_read32bitreg(SYS_STATUS_ID)) & (SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR))  //不断查询芯片状态直到接收成功或者出现错误
		{
			SYS_ANC_INFORM_FLAG = 4;
		}
		else 
			return 0;
	}
	
	if(SYS_ANC_INFORM_FLAG == 4)
	{
		if(status_reg & SYS_STATUS_RXFCG_BIT_MASK)
			SYS_ANC_INFORM_FLAG = 5;
		else     //接收超时 标签没有回应
		{
			/* Clear RX error events in the DW1000 status register. */
			dwt_write32bitreg(SYS_STATUS_ID,SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR);
//			dwt_rxreset();
			SYS_ANC_INFORM_FLAG = 0;		
			if(status_reg & SYS_STATUS_ALL_RX_TO)
				return 3;  //接收超时
			else
			{
				dwt_rxenable(0);       //接收出错 重新接收
				SYS_ANC_INFORM_FLAG = 3;
				return 0;
			}
		}
	}
	
	if(SYS_ANC_INFORM_FLAG == 5)
	{
		dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_RXFCG_BIT_MASK);                        //清除标志位
		frame_len = dwt_read32bitreg(RX_FINFO_ID) & FRAME_LEN_MAX;       //获得接收数据长度
		dwt_readrxdata(HDS_rx_buffer, frame_len, 0);                                     //读取接收数据
		if(HDS_rx_buffer[0] == B_ID && HDS_rx_buffer[3] == 0xAB)
		{
			SYS_ANC_INFORM_FLAG = 0;
			memset(Time_ts,0,sizeof(Time_ts));
			Time_ts[1] = (uint32)get_rx_timestamp_u64();                             //记录接收Poll包时间戳T1
			
			//获取透传数据
			if(HDS_rx_buffer[4] == 1)
			{			
				Uwb_commu_helper_ptr->Recver.Data_commu_len = HDS_rx_buffer[5];
				memcpy(Uwb_commu_helper_ptr->Recver.DataBuff,&HDS_rx_buffer[6] ,Uwb_commu_helper_ptr->Recver.Data_commu_len);
				Uwb_commu_helper_ptr->Recver.Data_Has_recv = 1;
			}
			
			return 1;
		}							
		else if(HDS_rx_buffer[1] == B_ID && HDS_rx_buffer[3] == 0xBC)		
		{
			//接收到了其它次基站的Resp包
			SYS_ANC_INFORM_FLAG = 0;
			return 4;
		}
		else
		{
			//接收到了无关信息 立刻重新打开接收
			dwt_rxenable(0);
			SYS_ANC_INFORM_FLAG = 3;
		}		
	}	
	return 0;

}


/*! ------------------------------------------------------------------------------------------------------------------
 * @fn HDS_TWR_Send_RequestSubDist(uint8_t Sub_ID)
 *
 * @brief  主基站发送Request包 通知次基站回传距离Reply包
 *
 * output parameters
 * @param Sub_ID  要通知的次基站ID

 * returns 0：动作未完成 1：发送成功 2：发送失败
 */
uint8_t HDS_TWR_Send_RequestSubDist(uint8_t Sub_ID)
{
	if(SYS_ANC_REQ_REPLY_FLAG == 0)
	{
		uint8_t ret = 0;
		memset(TX_ANC_REQ_BUFF,0,sizeof(TX_ANC_REQ_BUFF));
			
		TX_ANC_REQ_BUFF[0] = 0xFF;
		TX_ANC_REQ_BUFF[1] = Sub_ID;
		TX_ANC_REQ_BUFF[2] = frame_seq_nb;
		TX_ANC_REQ_BUFF[3] = 0xDE;
			
		dwt_writetxdata(sizeof(TX_ANC_REQ_BUFF), TX_ANC_REQ_BUFF, 0);       //写入发送数据
		dwt_writetxfctrl(sizeof(TX_ANC_REQ_BUFF), 0, 1);                       //设定发送长度
		dwt_setrxaftertxdelay(0);                                           //设置发送后开启接收，并设定延迟时间
		dwt_setrxtimeout(2000);                                             //设定超时时间		
		ret = dwt_starttx(DWT_START_TX_IMMEDIATE | DWT_RESPONSE_EXPECTED);  //立即发送			
		if(ret == DWT_SUCCESS)									
			SYS_ANC_REQ_REPLY_FLAG = 1;								
		else  //发送失败
			return 2;
	}
	
	if(SYS_ANC_REQ_REPLY_FLAG == 1)
	{
		if ((dwt_read32bitreg(SYS_STATUS_ID) & SYS_STATUS_TXFRS_BIT_MASK))           //不断查询芯片状态直到发送完成
		{  
			dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_TXFRS_BIT_MASK);               //清除标志位	
			SYS_ANC_REQ_REPLY_FLAG = 2;	
		}	
		else 
			return 0;
	}
	
//	if(SYS_ANC_REQ_REPLY_FLAG == 2)                                       
//	{
////		dwt_setrxtimeout(2100);                                             //设定超时时间
////		dwt_rxenable(0);                                                    //打开接收
//		SYS_ANC_REQ_REPLY_FLAG = 3;
//	}
	
	if(SYS_ANC_REQ_REPLY_FLAG == 2)
	{
		if((status_reg = dwt_read32bitreg(SYS_STATUS_ID)) & (SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR)) //不断查询芯片状态直到接收成功或者出现错误
		{
			SYS_ANC_REQ_REPLY_FLAG = 3;
		}
		else 
			return 0;
	}
	
	
	if(SYS_ANC_REQ_REPLY_FLAG == 3)
	{
		if(status_reg & SYS_STATUS_RXFCG_BIT_MASK)
			SYS_ANC_REQ_REPLY_FLAG = 4;
		else       //接收超时
		{
			/* Clear RX error events in the DW1000 status register. */
			dwt_write32bitreg(SYS_STATUS_ID,SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR);
//			dwt_rxreset();
			SYS_ANC_REQ_REPLY_FLAG = 0;  
			if(status_reg & SYS_STATUS_ALL_RX_TO)
				return 2;
			else
			return 0;				
		}
	}		
	
	if(SYS_ANC_REQ_REPLY_FLAG == 4)
	{
		dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_RXFCG_BIT_MASK);                         //清除标志位
		frame_len = dwt_read32bitreg(RX_FINFO_ID) & FRAME_LEN_MAX;        //获得接收数据长度
		dwt_readrxdata(HDS_rx_buffer, frame_len, 0);                                      //读取接收数据
		if(HDS_rx_buffer[1] == 0xFF && HDS_rx_buffer[3] == 0xEF && HDS_rx_buffer[0] == Sub_ID)
		{
			uint8_t anc_order = ANCHOR_LIST_COUNT - (255 - Sub_ID);                                        //根据次基站ID来对应位置存放数据
			uint8_t cal_success = HDS_rx_buffer[4];                                              //测距成功标志 
			if(cal_success == 1)
			{
				Calculate_FLAG |= 0x01 << anc_order;                                    //更新测距成功标志
				Dist_Cal_All[anc_order] = HDS_rx_buffer[5] << 8 | HDS_rx_buffer[6];		              //更新测距值
			}				
			SYS_ANC_REQ_REPLY_FLAG = 0;
			return 1;
		}									
		else   //接收到不是要读取的信息 重新打开接收 
		{
//			dwt_setrxtimeout(1200);  
			dwt_rxenable(0);
			SYS_ANC_REQ_REPLY_FLAG = 2;
		}			
			
	}
  return 0;	
}


/*! ------------------------------------------------------------------------------------------------------------------
 * @fn Mode_MainAnchor_HDS()
 *
 * @brief  主基站主流程
 *
 */
void Mode_MainAnchor_HDS(void)
{
	uint8_t ret = 0;
	uint8_t i;
	
	/**** 等待命令状态 ****/
	if(SYS_MAINANCHOR_FLAG == 0)                             
	{
		//等待指令
		if(Device_cfg_ptr->Device_range_work_mode > 0 && Device_cfg_ptr->Device_range_work_mode <= 8)
		{			
//			dwt_forcetrxoff();
			Calculate_FLAG = 0;
			Timer1_error_flag = 0;
			Tag_ID = Device_cfg_ptr->Flash_TAG_BUF[Calculate_TAG_index];
			SYS_MAINANCHOR_FLAG = 1;		
		}
		else if(Device_cfg_ptr->Device_range_work_mode == Workmode_remote_cfg)
		{
			App_remote_cfg_Handler();
			Timer1_error_flag = 0;
		}
	}
	
	/**** Inform包状态 ****/
	if(SYS_MAINANCHOR_FLAG == 1)                             
	{
		ret = HDS_TWR_Inform_Handle(Tag_ID);  
		if(ret == 1)                                           //发送Inform包并接收到了Poll包
		{			
			SYS_MAINANCHOR_FLAG = 2;
		}
		else if(ret == 2 || ret == 3)                          //发送Inform包失败 或 发送后3ms没有接收到Poll包
		{
			dwt_forcetrxoff();
			if(Calculate_TAG_index < (Device_cfg_ptr->Flash_TAG_NUM-1))          //变更下一个标签	
				Calculate_TAG_index++; 		
			else	
			  Calculate_TAG_index=0;
			SYS_MAINANCHOR_FLAG = 0;
			
		}
		else if(ret == 4)  //发送后3ms后还没有接收到Poll包且接收到了其它基站的Resp包 尝试接收Final包
		{
			SYS_MAINANCHOR_FLAG = 3;
		}
	}
	
	/**** 发送Resp包状态 ****/
	if(SYS_MAINANCHOR_FLAG == 2)                             
	{		
		if(Uwb_commu_helper_ptr->Sender.Data_commu_En && Tag_ID == Uwb_commu_helper_ptr->Sender.Data_commu_RevID)	
			ret = HDS_TWR_Send_Resp(0xFF,Tag_ID,1);		
		else
			ret = HDS_TWR_Send_Resp(0xFF,Tag_ID,0);
		if(ret == 1)
		{
			Uwb_commu_helper_ptr->Sender.Data_commu_En = 0;                                    //复位数据透传使能
			SYS_MAINANCHOR_FLAG = 3;			
		}							
		else if(ret == 2)  //发送失败 延时后问其它基站要数据
		{
			dwt_forcetrxoff();
			deca_sleep(12);
			SYS_MAINANCHOR_FLAG = 4;
		}
	}
	
	/**** 接收Final包并计算测距值 ****/
	if(SYS_MAINANCHOR_FLAG == 3)                             
	{
		ret = HDS_TWR_Recv_FinalAndCal(0xFF,Tag_ID,ANCHOR_WAITFINAL_MAX);
		if(ret == 1)
		{
			Calculate_FLAG|=0x01<<0;		                         //成功测距赋予标志
			Dist_Cal_All[0] = Dis_cal;			
			SYS_MAINANCHOR_FLAG = 4;
			ReqRetry_times = 0;
			deca_sleep(1);  //确保其它基站也计算完了
		}		
		else if(ret == 2)
		{
			SYS_MAINANCHOR_FLAG = 4;
//			deca_sleep(1);  //确保其它基站也计算完了
		}
								
	}
	
	/**** Request访问次基站并要其返回测距值 ****/
	if(SYS_MAINANCHOR_FLAG > 3 && SYS_MAINANCHOR_FLAG < (3 + ANCHOR_LIST_COUNT))
	{
		for(i=SYS_MAINANCHOR_FLAG - 4; i < ANCHOR_LIST_COUNT - 1;i++)
		{
			if(SYS_MAINANCHOR_FLAG == 4 + i)
			{
				if(Device_cfg_ptr->Anchor_List[i+1].en == 1)                        //次基站使能才发送
				{
					ret = HDS_TWR_Send_RequestSubDist(SUB_ANC_STARTID + i);
					if(ret == 1)
					{
						SYS_MAINANCHOR_FLAG++;
						ReqRetry_times = 0;
						Timer1_error_flag = 0;
					}
					else if(ret == 2)                                 //接收3ms超时跳过
					{
						if(ReqRetry_times < 3)
							ReqRetry_times++;												
						else
						{
							SYS_MAINANCHOR_FLAG++;
							ReqRetry_times = 0;
							Timer1_error_flag = 0;
						}					
					}
				}
				else
					SYS_MAINANCHOR_FLAG++;
			}
		}
	}
		
	/**** 获取所有数据了 解算输出 ****/
	if(SYS_MAINANCHOR_FLAG == 3 + ANCHOR_LIST_COUNT)  	
	{		
		uint8_t i;
														
		//****  距离保存  ****//
		for(i=0;i<ANCHOR_LIST_COUNT;i++)
		{					
			if((Calculate_FLAG>>i)&0x01)                          //测距成功才保存数值					
				Device_cfg_ptr->Anchor_List[i].dist = Dist_Cal_All[i];                   															
			else							
				Device_cfg_ptr->Anchor_List[i].dist = 0;                          //测距失败输出0		
		}		
		
    /****  定位解算  ****/		
		if(Device_cfg_ptr->Flash_structure_Mode != 0 && Device_cfg_ptr->FLASH_CAL_xyz_En)  			//不是测距模式
		{
			float clua_x_y[3] = {0};
			uint8_t cla_flag = 0;
			if(Device_cfg_ptr->Flash_structure_Mode == 1) 											//二维模式
				cla_flag = Rtls_Cal_2D(Device_cfg_ptr->Anchor_List,Calculate_FLAG,clua_x_y);
			if(Device_cfg_ptr->Flash_structure_Mode == 2) 											//三维模式
				cla_flag = Rtls_Cal_3D(Device_cfg_ptr->Anchor_List,Calculate_FLAG,clua_x_y);
	
			if(cla_flag == 0) 																	//状态显示计算错误
			{
				Calculate_FLAG&=~(0x01<<16);											//计算失败赋予标志	   
				Cal_data[Tag_ID].x = 0;                         //回传标签坐标值x
				Cal_data[Tag_ID].y = 0;                         //回传标签坐标值y
				Cal_data[Tag_ID].z = 0;                         //回传标签坐标值z
			}
			else  																								//状态显示正确  解算坐标滤波
			{
				Calculate_FLAG|=0x01<<16;													//计算成功赋予标志
				
				clua_x_y[0] = KalmanFilter(clua_x_y[0],Device_cfg_ptr->FLASH_KALMAN_Q,Device_cfg_ptr->FLASH_KALMAN_R,Tag_ID,0);    //卡尔曼滤波
				clua_x_y[1] = KalmanFilter(clua_x_y[1],Device_cfg_ptr->FLASH_KALMAN_Q,Device_cfg_ptr->FLASH_KALMAN_R,Tag_ID,1);		//卡尔曼滤波
				clua_x_y[2] = KalmanFilter(clua_x_y[2],Device_cfg_ptr->FLASH_KALMAN_Q,Device_cfg_ptr->FLASH_KALMAN_R,Tag_ID,2);		//卡尔曼滤波	
				Cal_data[Tag_ID].x = (int)(clua_x_y[0]);            //回传标签坐标值x
				Cal_data[Tag_ID].y = (int)(clua_x_y[1]);            //回传标签坐标值y
				Cal_data[Tag_ID].z = (int)(clua_x_y[2]);            //回传标签坐标值z																																	
			}	
		}
		

		/****  结果输出  ****/
		for(i=0;i<ANCHOR_LIST_COUNT;i++)                                        //将测距值赋予到寄存器
		{
			if(Device_cfg_ptr->Anchor_List[i].en==1) 
				Cal_data[Tag_ID].Dist[i]=Device_cfg_ptr->Anchor_List[i].dist; 					
			else 
				Cal_data[Tag_ID].Dist[i]=0;
		}	
		
		Cal_data[Tag_ID].Cal_Flag = Calculate_FLAG;             //赋予使能位
		 
		
		/* 根据不同模式输出 */
		if(Device_cfg_ptr->Device_range_work_mode==Workmode_once_auto_output||Device_cfg_ptr->Device_range_work_mode==Workmode_continous_auto_output
				||Device_cfg_ptr->Device_range_work_mode==Workmode_onstart_once_auto_output||Device_cfg_ptr->Device_range_work_mode==Workmode_onstart_continous_auto_output)//自动输出	
			MODBUS_writeRtlsData(Tag_ID,&Cal_data[Tag_ID],&rx_diag,Time_ts);	
										 			
		if(Device_cfg_ptr->Device_range_work_mode==Workmode_once_no_output||Device_cfg_ptr->Device_range_work_mode==Workmode_once_auto_output
			||Device_cfg_ptr->Device_range_work_mode==Workmode_onstart_once_no_output||Device_cfg_ptr->Device_range_work_mode==Workmode_onstart_once_auto_output)   //单次检测后清零使能
		{	

			Device_cfg_ptr->Device_range_work_mode=Workmode_idle;   						//清零使能
		}	
			
		if(Uwb_commu_helper_ptr->Recver.Data_Has_recv)                                       //数据透传接收信息
		{
			Modbus_writeRecvData(Tag_ID,Uwb_commu_helper_ptr->Recver.DataBuff, Uwb_commu_helper_ptr->Recver.Data_commu_len);
			Uwb_commu_helper_ptr->Recver.Data_Has_recv = 0;
		}
		
		if(LED_FLAG > 5)                                        //LED指示灯闪烁
		{
			LED1_TOGGLE();
			LED_FLAG=0;
		}
		else 
			LED_FLAG++;
		
		if(Device_cfg_ptr->Flash_structure_Mode == 0) //测距模式可OLED显示
		{
			#if (MODULE_USE != MODULE_PG17)
			if(OLED_display_time > 500)     //一段时间后重新刷新OLED                         
			{
				OLED_Clear();
				OLED_display();			
				OLED_display_data(Cal_data[Tag_ID].Dist[0],0,0,0,1);                   //OLED显示距离
				OLED_display_time = 0;
			}
			else if(OLED_display_time % 10 == 0)  //短时间不重刷画面显示距离 如果有数据位数改变会残留
			{
				OLED_display_data(Cal_data[Tag_ID].Dist[0],0,0,0,1);                   //OLED显示距离
				OLED_display_time++;
			}
			else
				OLED_display_time++;
			#endif
		}				
				
//		deca_sleep(3);
		
		if(Calculate_TAG_index < (Device_cfg_ptr->Flash_TAG_NUM-1))             //ID列表扫描 ，ID变更		
			Calculate_TAG_index++; 		
		else	
			Calculate_TAG_index=0;
		
		SYS_MAINANCHOR_FLAG = 0;
	}
	
	if(Timer1_error_flag > Device_cfg_ptr->Uwb_config.Twr_Error_max)                                //看门狗出错 复位标志位
	{
		SYS_MAINANCHOR_FLAG = 0;
		SYS_ANC_INFORM_FLAG = 0;
		SYS_ANC_REQ_FLAG = 0;
		SYS_ANC_RESP_FLAG = 0;
		SYS_ANC_FINAL_FLAG = 0;
		SYS_ANC_REQ_REPLY_FLAG = 0;
		dwt_forcetrxoff();                                      //强制关闭所有发送和接收		
//		if((dwt_read32bitreg(SYS_STATUS_ID) & SYS_STATUS_HPDWARN))  //延时发送响应出错
//      dwt_write32bitreg(SYS_CTRL_ID, SYS_CTRL_TRXOFF);
		Timer1_error_flag = 0;
	}
}


