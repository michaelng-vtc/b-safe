#include "HDS-TWR.h"
#include "Filter.h"
#include <string.h>

uint8_t SYS_ANC_RESP_FLAG = 0;                                //基站延时发送Resp包标志位
uint8_t SYS_ANC_FINAL_FLAG = 0;                               //基站接收Final包标志位

uint16_t Dis_cal = 0;                                       //计算测得的距离
uint8_t frame_now;                                            //当前通讯流程帧
uint16_t Anc_recvFinal_timeflag = 0;

#define Anchor_delay_base  0x1E700                       //基站延时发送基底 0x3CE00 延时为1ms 0x1E700 延时为500us  



uint8_t TX_ANC_INFORM_BUFF[TX_ANC_INFORM_LEN];                //基站发送Inform包数组
uint8_t TX_TAG_POLL_BUFF[TX_TAG_POLL_LEN];                    //标签发送Poll包数组
uint8_t TX_ANC_RESP_BUFF[TX_ANC_RESP_LEN];                    //基站发送Resp包数组
uint8_t TX_TAG_FINAL_BUFF[TX_TAG_FINAL_LEN];                  //标签发送Final包数组
uint8_t TX_ANC_REQ_BUFF[TX_ANC_REQ_LEN];                      //基站发送Request包数组  主基站
uint8_t TX_ANC_REPLY_BUFF[TX_ANC_REPLY_LEN];                  //基站发送Reply包数组  次基站
uint8_t HDS_rx_buffer[RX_MAX_LEN];                                  //接收缓存


/*! ------------------------------------------------------------------------------------------------------------------
 * @fn HDS_TWR_Send_Resp(uint8_t A_ID, uint8_t B_ID, uint8_t En)
 *
 * @brief  基站延时发送Resp包
 *
 * output parameters
   @param A_ID  发送方基站ID
   @param B_ID  接收标签的ID
   @param En    是否使能数据透传
	
 * returns 0：动作未完成 1：发送成功 2：发送失败
 */
uint8_t HDS_TWR_Send_Resp(uint8_t A_ID, uint8_t B_ID, uint8_t En)
{
	uint32_t delay_time;
	if(SYS_ANC_RESP_FLAG == 0)
	{
		int ret;
		uint8_t anc_order = 0;		
		uint8_t send_len = TX_ANC_RESP_FIX_LEN;
		
		memset(TX_ANC_RESP_BUFF,0,sizeof(TX_ANC_RESP_BUFF));
		TX_ANC_RESP_BUFF[0] = A_ID;
		TX_ANC_RESP_BUFF[1] = B_ID;
		TX_ANC_RESP_BUFF[2] = frame_seq_nb;
		TX_ANC_RESP_BUFF[3] = 0xBC;
		TX_ANC_RESP_BUFF[4] = En;                          
		
		if(A_ID == 0xFF)
			anc_order = 1;
		else		
			anc_order = 17 - (0xFF - A_ID);                  //根据ID来获取延时发送顺序
		
		if(En == 1)
		{
			TX_ANC_RESP_BUFF[5] = Uwb_commu_helper_ptr->Sender.Data_commu_len;
			memcpy(&TX_ANC_RESP_BUFF[6],Uwb_commu_helper_ptr->Sender.DataBuff,Uwb_commu_helper_ptr->Sender.Data_commu_len);
			send_len += Uwb_commu_helper_ptr->Sender.Data_commu_len;
		}
		
		delay_time = dwt_readsystimestamphi32();           //读取上次接收时间
		delay_time += Anchor_delay_base * anc_order;		       //延时发送
		dwt_setdelayedtrxtime(delay_time);
		dwt_writetxdata(send_len, TX_ANC_RESP_BUFF, 0);     //将数据传给DW1000，将在开启发送时传出去
		dwt_writetxfctrl(send_len, 0, 1);                      //设置超宽带发送数据长度
		dwt_setrxaftertxdelay(0);				
		ret = dwt_starttx(DWT_START_TX_DELAYED);                            //开启延时发送
		if(ret == DWT_SUCCESS)
			SYS_ANC_RESP_FLAG=1;
		else  //发送失败
			return 2;
	}
	
	if(SYS_ANC_RESP_FLAG == 1)
	{
		if((dwt_read32bitreg(SYS_STATUS_ID) & SYS_STATUS_TXFRS_BIT_MASK))
		{
			dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_TXFRS_BIT_MASK);               //清除标志
			SYS_ANC_RESP_FLAG = 0;
			return 1;
		}	
	}
	
	return 0;
}

/*! ------------------------------------------------------------------------------------------------------------------
 * @fn HDS_TWR_Recv_FinalAndCal(uint8_t A_ID ,uint8_t B_ID)
 *
 * @brief  接收标签Final包并计算距离
 *
 * output parameters
   @param A_ID  发送方基站ID
   @param B_ID  接收标签的ID
	 @param recv_timeout 基站接收超时时间0.1ms为单位 
 * returns 0：动作未完成 1：计算成功 2：计算距离失败
 */
uint8_t HDS_TWR_Recv_FinalAndCal(uint8_t A_ID ,uint8_t B_ID, uint16_t recv_timeout)
{
	
	if(SYS_ANC_FINAL_FLAG == 0)
	{
		Anc_recvFinal_timeflag = 0;
		dwt_forcetrxoff();		
		dwt_setrxtimeout(0);    //设定接收超时时间，0位没有超时时间
		dwt_rxenable(0);
		SYS_ANC_FINAL_FLAG = 1;
	}
	
	if(Anc_recvFinal_timeflag > recv_timeout)
	{
		Anc_recvFinal_timeflag = 0;
		SYS_ANC_FINAL_FLAG = 0;
//		dwt_rxreset();
		dwt_forcetrxoff();
		return 2;
	}
	
	if(SYS_ANC_FINAL_FLAG == 1)
	{
		if((status_reg = dwt_read32bitreg(SYS_STATUS_ID)) & (SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_ALL_RX_ERR))//不断查询芯片状态直到接收成功或者出现错误
		{
			SYS_ANC_FINAL_FLAG = 2;
		}
		else return 0;
	}
	
	if(SYS_ANC_FINAL_FLAG == 2)  //成功接收或接收超时
	{
		if (status_reg & SYS_STATUS_RXFCG_BIT_MASK)//成功接收
		{
			SYS_ANC_FINAL_FLAG = 3;
		}
		else
		{
			/* Clear RX error events in the DW1000 status register. */
			dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_ALL_RX_ERR);
			SYS_ANC_FINAL_FLAG=0;							
//				if(status_reg & SYS_STATUS_ALL_RX_TO)
//				  return 2;
//			  else
//          return 0;	
		}
	}
		
	if(SYS_ANC_FINAL_FLAG == 3)
	{
		dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_RXFCG_BIT_MASK);            //清除标志位
		frame_len = dwt_read32bitreg(RX_FINFO_ID) & FRAME_LEN_MAX;    			//获得接收数据长度
		dwt_readrxdata(HDS_rx_buffer, frame_len, 0);                                  //读取接收数据
		if(HDS_rx_buffer[0] == B_ID && HDS_rx_buffer[3] == 0xCD)
		{
			SYS_ANC_FINAL_FLAG = 4;
		}		
		else if(HDS_rx_buffer[3] == 0xDE && HDS_rx_buffer[0] == 0xFF)
		{
			SYS_ANC_FINAL_FLAG = 0;
			Anc_recvFinal_timeflag = 0;
			return 2;
		}
		else
		{
			SYS_ANC_FINAL_FLAG = 0;		
		}			  
	}
		
	if(SYS_ANC_FINAL_FLAG == 4)
	{
		uint8_t Anc_order = 0;
		uint8_t i;
		//根据情况接收对应的时间戳
		if(A_ID != 0xFF)
			Anc_order = ANCHOR_LIST_COUNT - (0xFF - A_ID);
		
		Time_ts[2] = (uint32)get_tx_timestamp_u64();              //获取T2 基站发送Resp时间戳
		final_msg_get_ts(&HDS_rx_buffer[4 + Anc_order*4],&Time_ts[3]);  //获取T3 标签接收Resp时间戳
		final_msg_get_ts(&HDS_rx_buffer[68],&Time_ts[0]);               //获取T0 标签发送Poll时间戳
		final_msg_get_ts(&HDS_rx_buffer[72],&Time_ts[4]);               //获取T4 标签发送Final时间戳 此为估计时间
		Time_ts[5] = (uint32)get_rx_timestamp_u64();              //获取T5 基站接收Final时间戳
		dwt_readdiagnostics(&rx_diag);                        //读取本次接收信号强度信息		
		SYS_ANC_FINAL_FLAG = 5;
	}
		
	if(SYS_ANC_FINAL_FLAG == 5)                                 //计算距离
	{
		if(Twr_CalDist(B_ID,&Dis_cal) != 1)
		{
			//计算失败
			SYS_ANC_FINAL_FLAG = 0;
			return 2;				
		}
		else
		{
			SYS_ANC_FINAL_FLAG = 0;
			return 1;
		}
								
	}
	return 0;			
}



