#include "DS-TWR.h"
#include "loc.h"
#include "modbus.h"
#include "oled.h"
#include "Filter.h"
#include "bsp_uart.h"
#include "bsp_timer.h"
#include "port.h"

uint8_t SYS_MAJOR_BS_FLAG=0;    						  //系统循环标志位-主基站
uint8_t SYS_BS_MESSAGE_FLAG=0;      				  //主基站联系次基站标志位
uint16_t SYS_BS_MESSAGE_Timer_FLAG=0;        //主基站等待次基站回复允许错误数据次数缓存区
uint16_t TAG_ID=0;   												//测距标签ID
uint16_t Calculate_TAG_FLAG=0;    				  //定位模式中，循环标签ID的标志位
uint8_t  Oled_Display_flag = 0;              //OLED显示计数
#define ANC_RETRYTIME_MAX 2             //主基站测距重试最大值
uint8_t  Anc_Retry_time = 0;                 //主基站测距重试指示

extern uint16_t Timer1_error_flag;

/******************************************************************************
					主基站通讯次基站进行测距并等待接收数据
*******************************************************************************/
int8_t DW1000send_dist_msg(uint8_t A_ID,uint8_t B_ID,uint8_t C_ID,uint32_t *dist) //通讯次基站测距
{

	if(SYS_BS_MESSAGE_FLAG==0)
	{								
		memset(DS_send_msg,0,sizeof(DS_send_msg));
		DS_send_msg[0] = A_ID;	
		DS_send_msg[1] = B_ID;
		DS_send_msg[2] = frame_seq_nb;
		DS_send_msg[3] = 0XEF; 
		DS_send_msg[4] = C_ID;
		dwt_setrxtimeout(8500);//设定接收超时时间，0位没有超时时间	
		dwt_writetxdata(sizeof(DS_send_msg), DS_send_msg, 0);//将Poll包数据传给DW1000，将在开启发送时传出去
		dwt_writetxfctrl(sizeof(DS_send_msg), 0, 1);//设置超宽带发送数据长度
		dwt_setrxaftertxdelay(0);
		dwt_starttx(DWT_START_TX_IMMEDIATE | DWT_RESPONSE_EXPECTED);//开启发送			
	//						deca_sleep(1);//休眠固定时间	
		SYS_BS_MESSAGE_FLAG=2;					
	}
//		 if(SYS_BS_MESSAGE_FLAG==1)
//		 {
//				dwt_setrxtimeout(8500);//设定接收超时时间，0位没有超时时间	
//				dwt_rxenable(0);//打开接收
//				SYS_BS_MESSAGE_FLAG=2;
//		 }
	if(SYS_BS_MESSAGE_FLAG==2)
	{								
		 if((status_reg = dwt_read32bitreg(SYS_STATUS_ID)) & (SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR))//不断查询芯片状态直到成功接收或者发生错误
		 {						
			SYS_BS_MESSAGE_FLAG=3;							
		 }	
		 else 
			return 0;
	}
	if(SYS_BS_MESSAGE_FLAG==3)
	{
		if(frame_seq_nb<0xFF)
			frame_seq_nb++;
		else 
			frame_seq_nb=0;
		if (status_reg & SYS_STATUS_RXFCG_BIT_MASK)//如果成功接收
		{
			SYS_BS_MESSAGE_FLAG=4;
		}
		else 
		{
			dwt_write32bitreg(SYS_STATUS_ID,SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR);	
			
			if(status_reg & SYS_STATUS_ALL_RX_TO)
			{
				//接收超时情况：代表次基站可能没有正确接收到主基站命令 重新指令次基站测距
				if(SYS_BS_MESSAGE_Timer_FLAG>3)  //错误数据少于4次重新接收，大于4次重新通讯测距
				{
					SYS_BS_MESSAGE_FLAG=0;
					SYS_BS_MESSAGE_Timer_FLAG = 0;
					return -1;  //代表本次出错											
				}
				else
				{
					SYS_BS_MESSAGE_FLAG=0;	//重新发出指令
					SYS_BS_MESSAGE_Timer_FLAG++;
				}	
			}									
			else
			{
				//接收其它情况出错：重启接收
				//dwt_rxreset();
				dwt_setrxtimeout(8500);
				dwt_rxenable(0); //重新接收
				SYS_BS_MESSAGE_FLAG=2;			
			}
				
			//SYS_BS_MESSAGE_FLAG=0;//不初始化 因为等待回信过程，有测距程序会收到无效数据包
			return 0;
		}
	}
	if(SYS_BS_MESSAGE_FLAG==4)
	{	
		dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_TXFRS_BIT_MASK);//清楚寄存器标志位
		frame_len = dwt_read32bitreg(RX_FINFO_ID) & FRAME_LEN_MAX;	//获得接收到的数据长度
		dwt_readrxdata(DS_rx_buffer, frame_len, 0);   //读取接收数据
		if (DS_rx_buffer[3]==0xFF&&((DS_rx_buffer[0]==B_ID)&&(DS_rx_buffer[1]==A_ID)))//判断接收到的数据是否是response数据
		{     					
			SYS_BS_MESSAGE_FLAG=5;									
		}
		else 
		{
			Timer1_error_flag=0;        //错误标志归0 	
			if(DS_rx_buffer[0]==B_ID && DS_rx_buffer[1]==C_ID)  //次基站正与标签测距 重新监听测距回传信息
			{
				dwt_rxenable(0); //重新接收
				SYS_BS_MESSAGE_FLAG=2;	
				SYS_BS_MESSAGE_Timer_FLAG = 0;
			}	
			else  //接收到了其它信息 不处理 立刻重新监听
			{
				dwt_rxenable(0); //重新接收
				SYS_BS_MESSAGE_FLAG=2;
			}																				
			return 0;
		}
	}
	if(SYS_BS_MESSAGE_FLAG==5)
	{
		if(DS_rx_buffer[4] == 0x01)  //代表次基站测距成功
		{
			*dist = DS_rx_buffer[5] << 8 | DS_rx_buffer[6];
			SYS_BS_MESSAGE_FLAG=0;
			SYS_BS_MESSAGE_Timer_FLAG=0;//标志位清零
			return 1;
		}
		else  //测距失败 不记录这一次的距离信息
		{
			
			SYS_BS_MESSAGE_FLAG=0;
			SYS_BS_MESSAGE_Timer_FLAG=0;//标志位清零
			return -1;
		}
		
	}
	return 0;		
}



/******************************************************************************
							 主基站函数
*******************************************************************************/

void MODE_MAJOR_ANCHOR_DS(void)
{

//	int8_t o=0;
	int i = 0;
	if((SYS_MAJOR_BS_FLAG!=0)&&(Device_cfg_ptr->Flash_TAG_BUF[Calculate_TAG_FLAG] != TAG_ID))//检测过程中标签ID被修改就取消检测重新开始  防止检测过程被修改
	{
		SYS_MAJOR_BS_FLAG=0;
		Anc_Retry_time = 0;		
	}
	
	if(SYS_MAJOR_BS_FLAG==0)
	{
//			Calculate_FLAG=0;                                    //状态标志为清空
		if(Device_cfg_ptr->Device_range_work_mode > 0 && Device_cfg_ptr->Device_range_work_mode <= 8)		
		{					
			Calculate_FLAG=0;                                    //状态标志为清空
			TAG_ID=Device_cfg_ptr->Flash_TAG_BUF[Calculate_TAG_FLAG];												
			SYS_MAJOR_BS_FLAG=1;								
			Timer1_error_flag=0;                     //错误标志为归0												
		}										
	}
	
	/*****************************************
			开始定位，主基站与标签测距
	*****************************************/
	if(SYS_MAJOR_BS_FLAG==1) //主基站与标签测距
	{
		int8_t ret = 0;
		Dist_Cal_All[0]=DW1000send(255,TAG_ID,Device_cfg_ptr->Flash_structure_Mode,&ret);																				
		if(ret == 1)
		{
			Calculate_FLAG|=0x01<<0;		//成功测距赋予标志
			if(LED_FLAG > 5)
			{
				LED1_TOGGLE();  //测距成功led反转
				LED_FLAG=0;
			}
			else
			{
				LED_FLAG++;
			}

			SYS_MAJOR_BS_FLAG = 2;												
			Timer1_error_flag=0;                                      //错误标志为归0
		}
		else if(ret != 0)
		{		
			//测距出错
			if(Anc_Retry_time < ANC_RETRYTIME_MAX)
			{
				Anc_Retry_time++;
				Timer1_error_flag = 0;
			}
			else
			{
				Calculate_FLAG|=0x00<<0;		//成功测距赋予标志		
				SYS_MAJOR_BS_FLAG = 2;												
				Timer1_error_flag=0;                                      //错误标志为归0
				Anc_Retry_time = 0;
			}
		}					 
	}
		
	/*****************************************
					 次基站与标签测距依次进行 二维/三维定位模式有效
	*****************************************/

	for(i=0;i<ANCHOR_LIST_COUNT - 1;i++) //次基站与标签测距 
	{
		if(SYS_MAJOR_BS_FLAG==2+i) //次基站与标签测距
		{													                          										
			if(Device_cfg_ptr->Anchor_List[i+1].en == 1)
			{
				int8_t ret;								
				ret = DW1000send_dist_msg(255,SUB_ANC_STARTID+i,TAG_ID,&Dist_Cal_All[1+i]);
				if(ret != 0)		
				{
					if(ret == 1)
					{
						Calculate_FLAG|=0x01<<(1+i);		//成功测距赋予标志	
						SYS_MAJOR_BS_FLAG++;															
						Timer1_error_flag=0;            //错误标志为归0
					}
					else if(ret == -1)  
					{
						Calculate_FLAG|=0x00<<(1+i);		//失败测距赋予标志	
						SYS_MAJOR_BS_FLAG++;															
						Timer1_error_flag=0;            //错误标志为归0
					}																																			
				}														
			}
			else
			{
				SYS_MAJOR_BS_FLAG++;
				Timer1_error_flag=0;
			}									
	  }
	}					
		/*****************************************
							 测距结束，处理数据并输出
		*****************************************/
		if(SYS_MAJOR_BS_FLAG==ANCHOR_LIST_COUNT + 1)
		{							
			uint8_t i;
			uint8_t cla_flag=0;
			
			//****  距离保存  ****//
			for(i=0;i<ANCHOR_LIST_COUNT;i++)                                        //将测距值赋予到寄存器
			{
				if((Calculate_FLAG>>i)&0x01)                          //测距成功才保存数值					
					Device_cfg_ptr->Anchor_List[i].dist = Dist_Cal_All[i];                   															
				else							
					Device_cfg_ptr->Anchor_List[i].dist = 0;                          //测距失败输出0					
			}	

			//****  定位解算  ****//
			if(Device_cfg_ptr->Flash_structure_Mode >= 1 && Device_cfg_ptr->FLASH_CAL_xyz_En == 1)
			{
				float clua_x_y_z[3] = {0};
				if(Device_cfg_ptr->Flash_structure_Mode == 1)
					cla_flag = Rtls_Cal_2D(Device_cfg_ptr->Anchor_List,Calculate_FLAG,clua_x_y_z);  //解算坐标
				else
					cla_flag = Rtls_Cal_3D(Device_cfg_ptr->Anchor_List,Calculate_FLAG,clua_x_y_z);  //解算坐标
				
				if(cla_flag == 0) //状态显示计算错误
				{
					Calculate_FLAG&=~(0x01<<16);		//计算失败赋予标志	   
					Cal_data[TAG_ID].x=0;//回传标签坐标值
					Cal_data[TAG_ID].y=0;//回传标签坐标值
					Cal_data[TAG_ID].z=0;//回传标签坐标值
				}
				else  //状态显示正确
				{
					Calculate_FLAG|=0x01<<16;		//计算成功赋予标志	                  
					clua_x_y_z[0] = KalmanFilter(clua_x_y_z[0],Device_cfg_ptr->FLASH_KALMAN_Q,Device_cfg_ptr->FLASH_KALMAN_R,TAG_ID,0);    //卡尔曼滤波
					clua_x_y_z[1] = KalmanFilter(clua_x_y_z[1],Device_cfg_ptr->FLASH_KALMAN_Q,Device_cfg_ptr->FLASH_KALMAN_R,TAG_ID,1);		//卡尔曼滤波
					clua_x_y_z[2] = KalmanFilter(clua_x_y_z[2],Device_cfg_ptr->FLASH_KALMAN_Q,Device_cfg_ptr->FLASH_KALMAN_R,TAG_ID,2);		//卡尔曼滤波														 
					Cal_data[TAG_ID].x=(int)(clua_x_y_z[0]);//回传标签坐标值
					Cal_data[TAG_ID].y=(int)(clua_x_y_z[1]);//回传标签坐标值
					Cal_data[TAG_ID].z=(int)(clua_x_y_z[2]);//回传标签坐标值								
				}
			}			
			
			//****  赋值到寄存器  ****//
			for(i=0;i<ANCHOR_LIST_COUNT;i++)   
			{
				if(Device_cfg_ptr->Anchor_List[i].en==1) 
					Cal_data[TAG_ID].Dist[i]=Device_cfg_ptr->Anchor_List[i].dist;								
				else 
					Cal_data[TAG_ID].Dist[i]=0;							
			}							
			Cal_data[TAG_ID].Cal_Flag = Calculate_FLAG;
			
			if(Device_cfg_ptr->Flash_structure_Mode == 0) //测距模式可OLED显示
			{
				#if (MODULE_USE != MODULE_PG17)
				if(OLED_display_time > 100)     //一段时间后重新刷新OLED                         
				{
					OLED_Clear();
					OLED_display();			
					OLED_display_data(Cal_data[TAG_ID].Dist[0],0,0,0,1);                   //OLED显示距离
					OLED_display_time = 0;
				}
				else if(OLED_display_time % 5 == 0)  //短时间不重刷画面显示距离 如果有数据位数改变会残留
				{
					OLED_display_data(Cal_data[TAG_ID].Dist[0],0,0,0,1);                   //OLED显示距离
					OLED_display_time++;
				}
				else
					OLED_display_time++;
				#endif
			}				
				
			//****  数据输出  ****//
			if(Device_cfg_ptr->Device_range_work_mode==Workmode_once_auto_output||Device_cfg_ptr->Device_range_work_mode==Workmode_continous_auto_output
				||Device_cfg_ptr->Device_range_work_mode==Workmode_onstart_once_auto_output||Device_cfg_ptr->Device_range_work_mode==Workmode_onstart_continous_auto_output)//自动输出	
				MODBUS_writeRtlsData(TAG_ID,&Cal_data[TAG_ID],&rx_diag,Time_ts);	
										 			
			if(Device_cfg_ptr->Device_range_work_mode==Workmode_once_no_output||Device_cfg_ptr->Device_range_work_mode==Workmode_once_auto_output
				||Device_cfg_ptr->Device_range_work_mode==Workmode_onstart_once_no_output||Device_cfg_ptr->Device_range_work_mode==Workmode_onstart_once_auto_output)   //单次检测后清零使能
			{	
				/* 5.0版本后不存入寄存表 采用虚拟寄存器表方式来输出数据  
				MODBUS_datain();  				//存入寄存器以读取														
				modbus_reg[42]=Tag_ID;
				modbus_reg[43]=Cal_data[Tag_ID].Cal_Flag;
				modbus_reg[44]=Cal_data[Tag_ID].x;
				modbus_reg[45]=Cal_data[Tag_ID].y;
				modbus_reg[46]=Cal_data[Tag_ID].z; 
						
			  	for(i=0;i<8;i++)
				{
					modbus_reg[47+i]=Cal_data[Tag_ID].Dist[i];
				}
				*/
				Device_cfg_ptr->Device_range_work_mode=Workmode_idle;   																		//清零使能
			}	
				
			//****  数据透传  ****//			
			if(Uwb_commu_helper_ptr->Recver.Data_Has_recv)
			{
				Modbus_writeRecvData(TAG_ID,Uwb_commu_helper_ptr->Recver.DataBuff,Uwb_commu_helper_ptr->Recver.Data_commu_len);
				memset(Uwb_commu_helper_ptr->Recver.DataBuff,0,sizeof(Uwb_commu_helper_ptr->Recver.DataBuff));
				Uwb_commu_helper_ptr->Recver.Data_Has_recv = 0;
			}
			
//			if(LED_FLAG > 5)
//			{
//				GPIO_Toggle(LED_GPIO,LED);
//				LED_FLAG=0;
//			}
//			else 
//				LED_FLAG++;
				
			SYS_MAJOR_BS_FLAG=0;
				
			if(Calculate_TAG_FLAG<(Device_cfg_ptr->Flash_TAG_NUM-1))//ID列表扫描 ，ID变更				
				Calculate_TAG_FLAG++;					
			else					
				Calculate_TAG_FLAG=0;																							  									
		}
											
		if(Timer1_error_flag > Device_cfg_ptr->Uwb_config.Twr_Error_max)   //测距发生错误,并且已启动，错误计数不能调太小，否则干扰次基站测距
		{																
			SYS_Calculate_ACTIVE_FLAG=0;   				//系统循环标志位主动测距函数
			SYS_BS_MESSAGE_FLAG=0;       //主基站联系次基站标志位
			SYS_BS_MESSAGE_Timer_FLAG=0;       //主基站等待次基站回复允许错误数据次数缓存区
			if(SYS_MAJOR_BS_FLAG > 2)	
				SYS_MAJOR_BS_FLAG++;
			else
			  SYS_MAJOR_BS_FLAG = 0;
			SYS_Calculate_ACTIVE_FLAG=0;//系统循环标志位主动测距标志位
			SYS_BS_MESSAGE_FLAG=0; //主基站联系次基站的标志位	
			dwt_forcetrxoff();			
			Timer1_error_flag=0;        //错误标志归0
			
		}   			
}
			
