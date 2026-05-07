#include "HDS-TWR.h"
#include "bsp_timer.h"
#include "string.h"
#include "common_config.h"
#include "port.h"
#include "App_Range.h"

uint8_t SYS_SUB_ANC_WORK_FLAG = 0;               //次基站监听工作标志位
uint8_t SYS_SUB_ANC_REPLY_FLAG = 0;              //次基站发送Reply包标志位
uint8_t SYS_SUB_ANC_FLAG = 0;                    //次基站主流程标志位
uint8_t Get_TagID = 0;                           //获取到的本次定位标签
uint8_t Sub_Anc_En = 0;                          //本次次基站是否使能
uint8_t Sub_Anc_Cal_Success = 0;                 //本次次基站TWR测距计算是否成功
uint8_t Sub_AncID = 0;
uint8_t Sub_AncRecvFinal_Timeout = 0;

extern uint16_t Timer1_error_flag ;

uint8_t Range_Sub_AncID_HDS = 0;
uint8_t Range_Send_ID_HDS = 0;

/*! ------------------------------------------------------------------------------------------------------------------
 * @fn HDS_TWR_SubAnc_Listen(uint8_t Sub_ID)
 *
 * @brief  次基站监听主基站信息来不同动作
 *
 * input parameters:
 * @param Sub_ID - 次基站ID
 *
 * output parameters
 * 
 * returns 0：无事发生 1：接收到Poll包 2：接收到Req包
 */
uint8_t HDS_TWR_SubAnc_Listen(uint8_t Sub_ID)
{
	if(SYS_SUB_ANC_WORK_FLAG == 0)
	{
		dwt_setrxtimeout(0);						                                          //设置接收超时时间
		dwt_rxenable(0);                                                          //打开接收
		SYS_SUB_ANC_WORK_FLAG = 1;
	}
	
	if(SYS_SUB_ANC_WORK_FLAG == 1)
	{
		if((status_reg = dwt_read32bitreg(SYS_STATUS_ID)) & (SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_ALL_RX_ERR))//不断查询芯片状态直到接收成功或者出现错误
		{
			SYS_SUB_ANC_WORK_FLAG = 2;
		}
		else return 0;
	}
	
	if(SYS_SUB_ANC_WORK_FLAG == 2)
	{
		if (status_reg & SYS_STATUS_RXFCG_BIT_MASK)                                        //成功接收
		{
			SYS_SUB_ANC_WORK_FLAG = 3;
		}
		else                                                                      //接收超时
		{
				/* Clear RX error events in the DW1000 status register. */
			dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_ALL_RX_ERR);
//			dwt_rxreset();		
			SYS_SUB_ANC_WORK_FLAG=0;							
			return 0;
		}
	}
	
	if(SYS_SUB_ANC_WORK_FLAG == 3)
	{
		uint8_t ret = 0;
		dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_RXFCG_BIT_MASK);                       //清除标志位
		frame_len = dwt_read32bitreg(RX_FINFO_ID) & FRAME_LEN_MAX;      //获得接收数据长度
		dwt_readrxdata(HDS_rx_buffer, frame_len, 0);                                    //读取接收数据
		if(HDS_rx_buffer[0] == 0xFF && HDS_rx_buffer[3] == 0xAA)                              //接收到主基站的Inform包
		{
			uint16_t Cal_en = HDS_rx_buffer[4] << 8 | HDS_rx_buffer[5];
			Get_TagID = HDS_rx_buffer[1];                                                 //根据主基站的命令来记录标签ID
			frame_seq_nb = HDS_rx_buffer[2];                                              //记录通讯帧号
			if((Cal_en >> (Sub_ID - SUB_ANC_STARTID + 1)) & 0x01)                               //根据ID来读取使能情况
				Sub_Anc_En = 1;
			else
				Sub_Anc_En = 0;
			Sub_Anc_Cal_Success = 0;                                                //清空计算成功标志 防止本次帧号测距数据使用上一次的结果
			ret = 0;
			Timer1_error_flag = 0;
		}
		else if(HDS_rx_buffer[3] == 0xAB && HDS_rx_buffer[2] == frame_seq_nb && HDS_rx_buffer[0] == Get_TagID)    //接收到标签的Poll包
		{
//			Get_TagID = HDS_rx_buffer[0];                                                 //记录标签ID
			memset(Time_ts,0,sizeof(Time_ts));                                      //清空时间存放数组
			Time_ts[1] = (uint32)get_rx_timestamp_u64();                            //记录接收Poll包时间戳T1
			Timer1_error_flag = 0;
			ret = 1;
		}
		else if(HDS_rx_buffer[0] == 0xFF && HDS_rx_buffer[3] == 0xDE && HDS_rx_buffer[1] == Sub_ID) //接收到主基站发送的Request包
		{
			if(frame_seq_nb != HDS_rx_buffer[2])
				Sub_Anc_Cal_Success = 0;  //帧号不对 仍然返回 但显示测距出错
			ret = 2;
			Timer1_error_flag = 0;
		}
		else if(HDS_rx_buffer[1] == Sub_AncID && HDS_rx_buffer[3] == 0xA1)//接收到自动标定Poll包
		{
			Range_Send_ID_HDS = HDS_rx_buffer[0];	//读取发送者ID号
			frame_seq_nb = HDS_rx_buffer[2];	//读取帧号
			memset(Time_ts,0,sizeof(Time_ts));                                      //清空时间存放数组
			Time_ts[1] = (uint32)get_rx_timestamp_u64();	//记录接收Poll包时间戳
			Timer1_error_flag = 0;
			ret = 3;
		}
		else if(HDS_rx_buffer[1] == Sub_AncID && HDS_rx_buffer[3] == 0xC3)//接收到自动标定Final包
		{
			Range_Send_ID_HDS = HDS_rx_buffer[0];	//读取发送者ID号
			frame_seq_nb = HDS_rx_buffer[2]; 	//读取帧号
			Time_ts[2] = (uint32)get_tx_timestamp_u64();	//记录发送Resp包时间戳
			Time_ts[5] = (uint32)get_rx_timestamp_u64();	//记录接收Final包时间戳
			Timer1_error_flag = 0;
			ret = 4;
		}
		else if(HDS_rx_buffer[0] == 0xFF && HDS_rx_buffer[1] == Sub_AncID && HDS_rx_buffer[3] == 0xE5)//接收到主基站呼叫次基站测距包
		{
			Range_Sub_AncID_HDS = HDS_rx_buffer[4];	//读取要测距基站ID号
			Device_cfg_ptr->Anc_range_cfg.range_max_num = HDS_rx_buffer[5];	//读取测距次数
			frame_seq_nb = HDS_rx_buffer[2];	//读取帧号
			memset(Time_ts,0,sizeof(Time_ts));                                      //清空时间存放数组
			Timer1_error_flag = 0;
			ret = 5;
		}
//    else  //监听到其它包
//		{
//			dwt_rxenable(0);
//			SYS_SUB_ANC_WORK_FLAG = 1;
//			return 0;
//		}		
		SYS_SUB_ANC_WORK_FLAG = 0;
		return ret;
	}
	return 0;
}

/*! ------------------------------------------------------------------------------------------------------------------
 * @fn HDS_TWR_Sub_Anc_Send_Reply()
 *
 * @brief  次基站发送Reply包
 *
 * input parameters:
 * @param Sub_ID - 次基站ID
 *
 * output parameters
 * 
 * returns 0：动作未完成 1：发送成功 2：发送失败
 */
uint8_t HDS_TWR_Sub_Anc_Send_Reply(uint8_t Sub_ID)
{
	if(SYS_SUB_ANC_REPLY_FLAG == 0)
	{
		uint8_t ret;
		memset(TX_ANC_REPLY_BUFF,0,sizeof(TX_ANC_REPLY_BUFF));
		TX_ANC_REPLY_BUFF[0] = Sub_ID;
		TX_ANC_REPLY_BUFF[1] = 0xFF;
		TX_ANC_REPLY_BUFF[2] = frame_seq_nb;
		TX_ANC_REPLY_BUFF[3] = 0xEF;
		TX_ANC_REPLY_BUFF[4] = Sub_Anc_Cal_Success;
		TX_ANC_REPLY_BUFF[5] = (Dis_cal >> 8) & 0x00FF;
		TX_ANC_REPLY_BUFF[6] = Dis_cal & 0x00FF;
		
		dwt_writetxdata(sizeof(TX_ANC_REPLY_BUFF), TX_ANC_REPLY_BUFF, 0);         //将数据传给DW1000，将在开启发送时传出去
		dwt_writetxfctrl(sizeof(TX_ANC_REPLY_BUFF), 0, 1);                        //设置超宽带发送数据长度
		dwt_setrxaftertxdelay(0);				
		ret = dwt_starttx(DWT_START_TX_IMMEDIATE);                                //开启发送
		if(ret == DWT_SUCCESS)
		 SYS_SUB_ANC_REPLY_FLAG=1;
		else  //发送失败
			return 2;
	}
	
	if(SYS_SUB_ANC_REPLY_FLAG == 1)
	{
		if((dwt_read32bitreg(SYS_STATUS_ID) & SYS_STATUS_TXFRS_BIT_MASK))                  //读取是否发送完成
		{
			dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_TXFRS_BIT_MASK);                     //清除发送标志位
			SYS_SUB_ANC_REPLY_FLAG = 0;
			return 1;
		}	
	}
	return 0;
}

/*! ------------------------------------------------------------------------------------------------------------------
 * @fn Mode_Sub_Anchor_HDS(void)
 *
 * @brief  次基站主流程
 *
 */
void Mode_Sub_Anchor_HDS()
{
	uint8_t ret = 0;
	
	//**** 次基站监听响应状态 ****//
	if(SYS_SUB_ANC_FLAG == 0)
	{
		Sub_AncID = ((Device_cfg_ptr->Flash_Device_ID>>8)&0xFF)+SUB_ANC_STARTID;
		Sub_AncRecvFinal_Timeout = ANCHOR_WAITFINAL_MAX - 5*((Device_cfg_ptr->Flash_Device_ID>>8)&0xFF + 1);
		ret = HDS_TWR_SubAnc_Listen(Sub_AncID);
		if(ret == 1)
			SYS_SUB_ANC_FLAG = 10;
		else if(ret == 2)
			SYS_SUB_ANC_FLAG = 20;	
		else if(ret == 3)
			SYS_SUB_ANC_FLAG = 30;
		else if(ret == 4)
			SYS_SUB_ANC_FLAG = 40;
		else if(ret == 5)
			SYS_SUB_ANC_FLAG = 50;						
	}
	
	//**** 接收到Poll包 回送Resp包 ****//
	if(SYS_SUB_ANC_FLAG == 10)  
	{
		Sub_Anc_Cal_Success = 0;
		if(Sub_Anc_En == 1)
		{			
			ret = HDS_TWR_Send_Resp(Sub_AncID,Get_TagID,0);
			if(ret == 1)		
				SYS_SUB_ANC_FLAG = 11;
			else if(ret == 2)  //发送失败
			{
				dwt_forcetrxoff();
//				deca_sleep(10);
				SYS_SUB_ANC_FLAG = 0;
			}
		}
		else
			SYS_SUB_ANC_FLAG = 0;
	}
	
	/**** 发送完Resp包 接收Final包并计算距离 ****/
	if(SYS_SUB_ANC_FLAG == 11)  
	{
		ret = HDS_TWR_Recv_FinalAndCal(Sub_AncID,Get_TagID,Sub_AncRecvFinal_Timeout);
		if(ret == 1)
		{			
			Sub_Anc_Cal_Success = 1;
			SYS_SUB_ANC_FLAG = 0;
			Timer1_error_flag = 0;
			return ;
		}
		else if(ret == 2)
		{
			Sub_Anc_Cal_Success = 0;
			SYS_SUB_ANC_FLAG = 0;
			Timer1_error_flag = 0;
			return ;
		}				
	}
	
	/**** 接收到Req包 发送自己的测距Reply包 ****/
	if(SYS_SUB_ANC_FLAG == 20)  
	{
		ret = HDS_TWR_Sub_Anc_Send_Reply(Sub_AncID);
		if(ret == 1)
		{
			if(LED_FLAG>5)
			{
				LED1_TOGGLE();
				LED_FLAG=0;
			}
			else LED_FLAG++;
			
			SYS_SUB_ANC_FLAG = 0;
		}
		else if(ret == 2)
			SYS_SUB_ANC_FLAG = 0;
	}
	
	/**** 接收到自动标定Poll包 发送自己的测距Reply包 ****/
	if(SYS_SUB_ANC_FLAG == 30)  
	{
		ret = RANGE_Anc_Back_Resp(Sub_AncID,Range_Send_ID_HDS);
		if(ret == 1)
		{
			SYS_SUB_ANC_FLAG = 0;
			Timer1_error_flag = 0;
			return ;
		}
	}
	/**** 接收到自动标定FINAL包 发送ACK包 ****/
	if(SYS_SUB_ANC_FLAG == 40)  
	{
		ret = RANGE_Anc_Back_ACK(Sub_AncID,Range_Send_ID_HDS);
		if(ret == 1)
		{
			SYS_SUB_ANC_FLAG = 0;
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
	/**** 接收到 A基站呼叫次基站包 ****/
	if(SYS_SUB_ANC_FLAG == 50)
	{
		ret = RANGE_Call_Sub_Anc_Dist(Sub_AncID,Range_Sub_AncID_HDS);
		if(ret == 1)
		{
			SYS_SUB_ANC_FLAG = 0;
			Timer1_error_flag = 0;
		}
		return ;
	}
	
	
	/**** 看门狗到时 复位状态 ****/
	if(Timer1_error_flag > Device_cfg_ptr->Uwb_config.Twr_Error_max) 
	{
		SYS_SUB_ANC_WORK_FLAG = 0;
		SYS_SUB_ANC_REPLY_FLAG = 0;
		SYS_ANC_RESP_FLAG = 0;
		SYS_ANC_FINAL_FLAG = 0;
		SYS_SUB_ANC_FLAG = 0;
//		Sub_Anc_Cal_Success = 0;
		RANGE_SUB_ANC_Reset();
		dwt_forcetrxoff();                                          //强制关闭发送和接收
//		if((dwt_read32bitreg(SYS_STATUS_ID) & SYS_STATUS_HPDWARN))  //延时响应出错
//      dwt_write32bitreg(SYS_CTRL_ID, SYS_CTRL_TRXOFF);
		Timer1_error_flag = 0;
	}
}




