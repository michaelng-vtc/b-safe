#include "DS-TWR.h"
#include "bsp_timer.h"
#include "port.h"
#include "App_range.h"

uint8_t SYS_BS_FLAG=0;    				//系统循环标志位-次基站
uint8_t SYS_BS_TAG_FLAG=0;       //次基站收到需要测距标签的ID
#define RETRYTIME_MAX  5
uint8_t Sub_TagRetry_times = 0;  //次基站对失败重传的次数
uint32_t dis_buf=0;
uint8_t Sub_anc_Id = 0;
extern uint16_t Timer1_error_flag;

uint8_t Range_Sub_AncID_DS = 0;
uint8_t Range_Send_ID_DS = 0;

/******************************************************************************
					次基站应答主基站进行测距并返回数据
*******************************************************************************/
int32_t DW1000send_dist_msg_last(uint8_t A_ID,uint8_t B_ID,uint32_t dist,uint8_t success_flag) //次基站回应主基站
{		   
//	uint32 i;

	memset(DS_send_msg,0,sizeof(DS_send_msg));
	DS_send_msg[0] =  A_ID;	//发送方ID：次基站ID
	DS_send_msg[1] =  B_ID;//接收者ID：主基站ID
	DS_send_msg[2] = frame_seq_nb;
	DS_send_msg[3] = 0XFF; 
	DS_send_msg[4] = success_flag; 
	DS_send_msg[5] = dist >> 8; 
	DS_send_msg[6] = dist & 0x00FF; 	
	dwt_writetxdata(DS_REPLY_LEN, DS_send_msg, 0);//将Poll包数据传给DW3000，将在开启发送时传出去
	dwt_writetxfctrl(DS_REPLY_LEN, 0, 1);//设置超宽带发送数据长度
//				dwt_setrxaftertxdelay(0);
//				dwt_setrxtimeout(7500);						//设置接收超时时间
	dwt_starttx(DWT_START_TX_IMMEDIATE);//开启发送 
	while(!((status_reg = dwt_read32bitreg(SYS_STATUS_ID)) & SYS_STATUS_TXFRS_BIT_MASK))//不断查询芯片状态直到接收成功或者出现错误
	{ }
	dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_TXFRS_BIT_MASK);               //清除标志位		
	return 0;		
}


/******************************************************************************
	次基站等待主基站下达测距命令信号，如果是测距命令，也进行被动测距，用于基站标定功能
*******************************************************************************/
uint8_t DW1000rec_dist_msg(uint8_t B_ID) //次基站等待信号 
{
//		uint32 i;
	if(SYS_BS_FLAG==0)
	{
		dwt_setrxtimeout(0);//设定接收超时时间，0位没有超时时间  65535
		dwt_rxenable(0);//打开接收
		Timer1_error_flag = 0;
		SYS_BS_FLAG=1;
	}
	if(SYS_BS_FLAG==1)
	{			
		if((status_reg = dwt_read32bitreg(SYS_STATUS_ID)) & (SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR))//不断查询芯片状态直到接收成功或者出现错误
		{ 
			SYS_BS_FLAG=2;
		}
		else return 0;			
	}		
	if(SYS_BS_FLAG==2)
	{
		if (status_reg & SYS_STATUS_RXFCG_BIT_MASK)//成功接收
		{
			SYS_BS_FLAG=3;	 
		}
		else
		{
			/* Clear RX error events in the DW1000 status register. */
				dwt_write32bitreg(SYS_STATUS_ID,SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR);	
			//          dwt_rxreset();			
			SYS_BS_FLAG=0;
			return 0;
		}
	}
	if(SYS_BS_FLAG==3)
	{
		dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_RXFCG_BIT_MASK);//清楚标志位
		frame_len = dwt_read32bitreg(RX_FINFO_ID) & FRAME_LEN_MAX;//获得接收数据长度
		dwt_readrxdata(DS_rx_buffer, frame_len, 0);//读取接收数据			 
		if (DS_rx_buffer[3]==0xEF&&B_ID==DS_rx_buffer[1])//判断
		{
			Timer1_error_flag = 0;
			SYS_BS_FLAG = 4;
			dis_buf = 0;              //清零上一次的测距值
			Sub_TagRetry_times = 0;   //重置重试次数
			return DS_rx_buffer[4];      //返回要测距的标签id
		}
		else if (DS_rx_buffer[3]==0xE5&&DS_rx_buffer[1]==B_ID&&DS_rx_buffer[0]==0xFF)//判断
		{
			Timer1_error_flag = 0;
			SYS_BS_FLAG=5;

			Range_Sub_AncID_DS = DS_rx_buffer[4];	//读取发送者ID号
			Device_cfg_ptr->Anc_range_cfg.range_max_num = DS_rx_buffer[5];		//读取测距次数
			frame_seq_nb = DS_rx_buffer[2];	//读取帧号
			memset(Time_ts,0,sizeof(Time_ts));
		}
		else if(DS_rx_buffer[1] == B_ID && DS_rx_buffer[3] == 0xA1)//接收到自动标定Poll包
		{
			Range_Send_ID_DS = DS_rx_buffer[0];//读取发送者ID号
			frame_seq_nb = DS_rx_buffer[2];//读取帧号
			memset(Time_ts,0,sizeof(Time_ts));                                      //清空时间存放数组
			Time_ts[1] = (uint32)get_rx_timestamp_u64();	//记录接收Poll包时间戳
			Timer1_error_flag = 0;
			SYS_BS_FLAG = 6;
		}
		else if(DS_rx_buffer[1] == B_ID && DS_rx_buffer[3] == 0xC3)//接收到自动标定Final包
		{
			Range_Send_ID_DS = DS_rx_buffer[0];//读取发送者ID号
			frame_seq_nb = DS_rx_buffer[2];  	//读取帧号                      
			Time_ts[2] = (uint32)get_tx_timestamp_u64();          //记录发送Resp包时间戳
			Time_ts[5] = (uint32)get_rx_timestamp_u64();			//记录接收Final包时间戳
			Timer1_error_flag = 0;
			SYS_BS_FLAG = 7;
		}
		else 
		{
			dwt_rxenable(0);//立即重新打开接收
			SYS_BS_FLAG=1;
			return 0;
		}	
	}					
	return 0;		
}


/******************************************************************************
												         次基站函数
*******************************************************************************/
void MODE_SUB_ANCHOR_DS(void)
{
	int8_t ret = 0;
	if(SYS_BS_FLAG!=4) 
	{	
		Sub_anc_Id = ((Device_cfg_ptr->Flash_Device_ID>>8)&0xFF)+SUB_ANC_STARTID;
		//			ERROR_FLAG=0;        //错误标志归0
		SYS_BS_TAG_FLAG=DW1000rec_dist_msg(Sub_anc_Id);									
	}
	if(SYS_BS_FLAG==4)
	{			
		dis_buf = DW1000send(Sub_anc_Id,SYS_BS_TAG_FLAG,0,&ret);																		
		if(ret == 1)
		{
			Sub_TagRetry_times = 0;
			DW1000send_dist_msg_last(Sub_anc_Id,255,dis_buf,1);	//发送距离

			if(LED_FLAG > 5)
			{
				LED1_TOGGLE();
				LED_FLAG=0;
			}
			else 
				LED_FLAG++;

			SYS_BS_FLAG=0;	
		}
		else if(ret == -2 || ret == -1)
		{
			Sub_TagRetry_times++;
			if(Sub_TagRetry_times > RETRYTIME_MAX)
			{
				//重传次数超过界限
				Sub_TagRetry_times = 0;
				DW1000send_dist_msg_last(Sub_anc_Id,255,0,0);  //回传失败信息
				SYS_BS_FLAG = 0;
			}
			else
			{
				//重传次数没超过设定界限
				Timer1_error_flag = 0;  
				return;
			}
		}				
	}
	if(SYS_BS_FLAG==5)
	{
		ret = RANGE_Call_Sub_Anc_Dist(Sub_anc_Id,Range_Sub_AncID_DS);		//自动标定
		if(ret == 1)
		{
			SYS_BS_FLAG = 0;
			Timer1_error_flag = 0;
		}
		return;
	}
	if(SYS_BS_FLAG == 6)
	{
		ret = RANGE_Anc_Back_Resp(Sub_anc_Id,Range_Send_ID_DS);			//回传Resp包
		if(ret == 1)
		{
			SYS_BS_FLAG = 0;
			Timer1_error_flag = 0;
			return ;
		}
	}
	if(SYS_BS_FLAG == 7)
	{
		ret = RANGE_Anc_Back_ACK(Sub_anc_Id,Range_Send_ID_DS);				//回传Ack包
		if(ret == 1)
		{
			SYS_BS_FLAG = 0;
			Timer1_error_flag = 0;
			if(LED_FLAG > 5)
			{
				LED1_TOGGLE();
				LED_FLAG=0;
			}
			else 
				LED_FLAG++;
			return ;
		}
	}
	if(Timer1_error_flag>Device_cfg_ptr->Uwb_config.Twr_Error_max)   //测距发生错误
	{				
		if(SYS_BS_FLAG==4) 
			DW1000send_dist_msg_last(Sub_anc_Id,255,0,0);	//如果是定位模式，虽然测距失败，也返回信息
		dwt_forcetrxoff();
		RANGE_SUB_ANC_Reset();				
		SYS_BS_FLAG=0;	
		SYS_Calculate_ACTIVE_FLAG=0;
		Timer1_error_flag=0;        //错误标志归0
	}						
}
