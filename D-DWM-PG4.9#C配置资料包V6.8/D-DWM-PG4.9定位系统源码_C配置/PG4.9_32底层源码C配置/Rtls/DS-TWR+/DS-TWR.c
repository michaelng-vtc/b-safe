#include "DS-TWR.h"
#include "Filter.h"
#include "string.h"
#include "common_config.h"

uint8_t SYS_Calculate_ACTIVE_FLAG=0;   				//系统循环标志位主动测距函数
uint8_t DS_send_msg[DS_TX_BUF_LEN];  // DWM1000通讯数据包
uint8_t DS_rx_buffer[DS_RX_BUF_LEN]; //DWM1000接收数据包缓存区



/**
 * @brief 基站呼叫标签并进行测距
 * @param A_ID 发送方ID 
 * @param B_ID 接收方ID
 * @param MODE 工作模式 
 * @param ret  状态指示 0无变化 1测距完成 -1测距失败 -2测距中途超时 
 */
int32_t DW1000send(uint8_t A_ID,uint8_t B_ID,uint8_t MODE, int8_t *ret) //主动模式
{
	uint16_t result_dist;   
	uint32_t i;
	if(SYS_Calculate_ACTIVE_FLAG==0)
	{
		memset(DS_send_msg,0,sizeof(DS_send_msg));

		DS_send_msg[0] =  A_ID;	//UWB POLL 包数据
		DS_send_msg[1] =  B_ID;//UWB Fianl 包数据
		DS_send_msg[2] = frame_seq_nb;
		DS_send_msg[3] = 0XAB; 
		DS_send_msg[4] = MODE;    //初始化			  

		//上次定位是否成功
		DS_send_msg[5] = Cal_data[B_ID].Cal_Flag >> 16 & 0x01;
		DS_send_msg[6]=Cal_data[B_ID].x>>8;		//赋予上一次的坐标信息
		DS_send_msg[7]=Cal_data[B_ID].x&0x00FF;		//赋予上一次的坐标信息				
		DS_send_msg[8]=Cal_data[B_ID].y>>8;		//赋予上一次的坐标信息
		DS_send_msg[9]=Cal_data[B_ID].y&0x00FF;		//赋予上一次的坐标信息
		DS_send_msg[10]=Cal_data[B_ID].z>>8;		//赋予上一次的坐标信息
		DS_send_msg[11]=Cal_data[B_ID].z&0x00FF;		//赋予上一次的坐标信息	
		
		//上次测距是否成功
		DS_send_msg[12] = Cal_data[B_ID].Cal_Flag >> 8 & 0x00FF;
		DS_send_msg[13] = Cal_data[B_ID].Cal_Flag & 0x00FF;		
		for(i=0;i<ANCHOR_LIST_COUNT;i++)
		{
			DS_send_msg[14 + i * 2]=Cal_data[B_ID].Dist[i]>>8;		//赋予上一次的距离信息
			DS_send_msg[15 + i * 2]=Cal_data[B_ID].Dist[i]&0x00FF;		//赋予上一次的距离信息
		}								
							
		dwt_writetxdata(DS_POLL_LEN, DS_send_msg, 0);//将Poll包数据传给DW1000，将在开启发送时传出去
		dwt_writetxfctrl(DS_POLL_LEN, 0, 1);//设置超宽带发送数据长度
		dwt_setrxaftertxdelay(0);
		dwt_setrxtimeout(9500);						//设置接收超时时间

		dwt_starttx(DWT_START_TX_IMMEDIATE| DWT_RESPONSE_EXPECTED);//开启发送，发送完成后等待一段时间开启接收，等待时间在dwt_setrxaftertxdelay中设置;	
		SYS_Calculate_ACTIVE_FLAG=1;
	}			
	if(SYS_Calculate_ACTIVE_FLAG==1)
	{			
//		printf("%d\n",SYS_Calculate_ACTIVE_FLAG); 
		if((status_reg = dwt_read32bitreg(SYS_STATUS_ID)) & (SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR))//不断查询芯片状态直到成功接收或者发生错误
		{
			SYS_Calculate_ACTIVE_FLAG=2;
		}
		else return 0;
	}
	if(SYS_Calculate_ACTIVE_FLAG==2)
	{
//				printf("%d\n",SYS_Calculate_ACTIVE_FLAG); 
		if(frame_seq_nb<0xFF)
			frame_seq_nb++;
		else 
			frame_seq_nb=0;
		if (status_reg & SYS_STATUS_RXFCG_BIT_MASK)//如果成功接收
		{									
			SYS_Calculate_ACTIVE_FLAG=3;
		}
		else 
		{
			/* Clear RX error events in the DW1000 status register. */
			dwt_write32bitreg(SYS_STATUS_ID,SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR);	
	//          	dwt_rxreset();
			if(status_reg & SYS_STATUS_ALL_RX_TO)
				*ret = -2;  //代表本次测距过程中途失败						
			SYS_Calculate_ACTIVE_FLAG=0;
			return	0;	
		}
	}
						
	if(SYS_Calculate_ACTIVE_FLAG==3)
	{
//		printf("%d\n",SYS_Calculate_ACTIVE_FLAG); 
		dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_TXFRS_BIT_MASK);//清楚寄存器标志位
		frame_len = dwt_read32bitreg(RX_FINFO_ID) & FRAME_LEN_MAX;	//获得接收到的数据长度
		dwt_readrxdata(DS_rx_buffer, frame_len, 0);   //读取接收数据
		
		if ((DS_rx_buffer[3]==0xBC)&&((DS_rx_buffer[0]==B_ID)&&(DS_rx_buffer[1]==A_ID)))//判断接收到的数据是否是response数据
		{  
			SYS_Calculate_ACTIVE_FLAG=4;
		}
		else 
		{	
			SYS_Calculate_ACTIVE_FLAG=0;
			return 0;							
		}		
	}
	if(SYS_Calculate_ACTIVE_FLAG==4)
	{ 
		uint8_t send_len = DS_FIX_BUF_LEN;
		memcpy(DS_send_msg,DS_rx_buffer,DS_TX_BUF_LEN);
		
		Time_ts[0] = get_tx_timestamp_u64();										//获得POLL发送时间T1
		Time_ts[3] = get_rx_timestamp_u64();										//获得RESPONSE接收时间T4
		final_msg_set_ts(&DS_send_msg[4],Time_ts[0]);     //将T1写入发送数据
		final_msg_set_ts(&DS_send_msg[16],Time_ts[3]);    //将T4写入发送数据
		DS_send_msg[0] =  A_ID;	//发送者ID
		DS_send_msg[1] =  B_ID; //接收者ID
		DS_send_msg[3] =  0XCD; 
		DS_send_msg[2] = frame_seq_nb;
		
		DS_send_msg[28] = Uwb_commu_helper_ptr->Sender.Data_commu_En;
		if(Uwb_commu_helper_ptr->Sender.Data_commu_En && B_ID == Uwb_commu_helper_ptr->Sender.Data_commu_RevID)
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
		
		dwt_writetxdata(send_len, DS_send_msg, 0);//将发送数据写入DW1000
		dwt_writetxfctrl(send_len, 0, 1);//设定发送数据长度
		dwt_setrxaftertxdelay(0);
		dwt_setrxtimeout(9500);						//设置接收超时时间
		dwt_starttx(DWT_START_TX_IMMEDIATE| DWT_RESPONSE_EXPECTED);//设定为发送后立刻打开接收
		SYS_Calculate_ACTIVE_FLAG=5;						
	}
	
	if(SYS_Calculate_ACTIVE_FLAG==5)						
	{
		if ((status_reg = dwt_read32bitreg(SYS_STATUS_ID)) & (SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR))//不断查询芯片状态直到成功接收或者发生错误
		{ 
			SYS_Calculate_ACTIVE_FLAG=6;
		}
		else return 0;
	}
	
	if(SYS_Calculate_ACTIVE_FLAG==6)
	{	
		if(frame_seq_nb<0xFF)
			frame_seq_nb++;
		else 
			frame_seq_nb=0;
		
		if (status_reg & SYS_STATUS_RXFCG_BIT_MASK)//如果成功接收
		{	
			SYS_Calculate_ACTIVE_FLAG=7;	
		}
		else 
		{
			dwt_write32bitreg(SYS_STATUS_ID,SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR);	
//			dwt_rxreset();
			if(status_reg & SYS_STATUS_ALL_RX_TO)
			 *ret = -2;  //代表本次测距过程中途失败							
			SYS_Calculate_ACTIVE_FLAG=0;								
			return	0;								
		}
	}
	if(SYS_Calculate_ACTIVE_FLAG==7)
	{
		dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_TXFRS_BIT_MASK);//清楚寄存器标志位
		frame_len = dwt_read32bitreg(RX_FINFO_ID) & FRAME_LEN_MAX;	//获得接收到的数据长度
		dwt_readrxdata(DS_rx_buffer, frame_len, 0);   //读取接收数据						
		if ((DS_rx_buffer[3]==0xDE)&&((DS_rx_buffer[0]==B_ID)&&(DS_rx_buffer[1]==A_ID)))//判断接收到的数据是否是response数据
		{
			dwt_readdiagnostics(&rx_diag);                            //读取本次接收信号强度信息
			SYS_Calculate_ACTIVE_FLAG=8;
		}
		else 
		{
			dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_ALL_RX_ERR);	
			SYS_Calculate_ACTIVE_FLAG=0;
			return 0;
		}
	}
	if(SYS_Calculate_ACTIVE_FLAG==8)
	{
		uint32_t Time_ts_F[6];				
		
		//收到数据透传的数据
		if(DS_rx_buffer[28] == 1)
		{
			Uwb_commu_helper_ptr->Recver.Data_Has_recv = 1;
			Uwb_commu_helper_ptr->Recver.Data_commu_len = DS_rx_buffer[29];
			memcpy(Uwb_commu_helper_ptr->Recver.DataBuff,&DS_rx_buffer[30],Uwb_commu_helper_ptr->Recver.Data_commu_len);
		}
		
		final_msg_get_ts(&DS_rx_buffer[4], &Time_ts_F[0]);
		final_msg_get_ts(&DS_rx_buffer[8], &Time_ts_F[1]);
		final_msg_get_ts(&DS_rx_buffer[12], &Time_ts_F[2]);
		final_msg_get_ts(&DS_rx_buffer[16], &Time_ts_F[3]);
		final_msg_get_ts(&DS_rx_buffer[24], &Time_ts_F[5]);									
		Time_ts[0]= (uint32)Time_ts_F[0];
		Time_ts[1]= (uint32)Time_ts_F[1];
		Time_ts[2]= (uint32)Time_ts_F[2];
		Time_ts[3]= (uint32)Time_ts_F[3];
		Time_ts[4]= (uint32)get_tx_timestamp_u64();	
		Time_ts[5]= (uint32)Time_ts_F[5];

		if(Twr_CalDist(B_ID,&result_dist) == 0)
		{
			//计算失败
			SYS_Calculate_ACTIVE_FLAG=0;
			*ret = -1;
			return result_dist;
		}
		else
		{
			SYS_Calculate_ACTIVE_FLAG=0;
			*ret = 1;
			return result_dist;
		}										    								
	}				
	return 0;   
}
