#include "App_Range.h"
#include "Filter.h"
#include "string.h"
#include "bsp_timer.h"
#include "common_config.h"
#include "port.h"

extern uint16_t Timer1_error_flag;

uint8_t SYS_RANGE_FLAG=0;    						//自动标定循环标志位
uint8_t SYS_RAN_BACK_RESP_FLAG=0;    						//回传RESP包标志位-被测距基站
uint8_t SYS_RAN_RECV_RESP_FLAG=0;    						//通知回传RESP包-测距基站
uint8_t SYS_RAN_RECV_ACK_FLAG=0;    						//通知回传ACK包-测距基站
uint8_t SYS_RAN_BACK_DIST_FLAG=0;    						//通知回传距离
uint8_t SYS_RAN_BACK_ACK_FLAG=0;    						//ACK包标志位-次基站
uint8_t SYS_RAN_SUB_DIST_FLAG=0;    						//次基站回传距离给主基站
uint8_t SYS_RAN_CALL_SUB_FLAG=0;    						//呼叫次基站测距标志位

uint8_t Range_get_dis_msg[RANGE_TX_BUF_LEN];
uint8_t Range_Rx_Buff[RANGE_RX_BUF_LEN];

#define RANGE_BUFF_SIZE		256
uint16_t  Range_DIST_BUFF[RANGE_BUFF_SIZE];       		   	//测距距离

Anc_range_cfg_t *Range_cfg = NULL;

void RANGE_Init(void)
{
	Range_cfg = &Device_cfg_ptr->Anc_range_cfg;
}


/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 次基站相关基站测距部分标志位初始化
 *
 * input parameters 无
 * output parameters 无
 * 
 */
void RANGE_SUB_ANC_Reset(void)
{
	SYS_RAN_CALL_SUB_FLAG = 0;
	SYS_RAN_BACK_ACK_FLAG = 0;
	SYS_RAN_BACK_RESP_FLAG = 0;
	SYS_RAN_RECV_RESP_FLAG = 0;
	SYS_RAN_RECV_ACK_FLAG = 0;
	SYS_RAN_SUB_DIST_FLAG = 0;
	
}


/*! ------------------------------------------------------------------------------------------------------------------
 * @fn uint8_t RANGE_Main_Call_SubDist(uint8_t A_ID,uint8_t B_ID) 
 *
 * @brief  主基站呼叫被测距基站测距 通知被测距基站回传距离
 *
 * input parameters:
 * @param A_ID - 发送者ID
 * @param B_ID - 接收者ID
 * output parameters
 * 
 * returns 0：动作未完成 1：接收成功 2：发送失败 3：接收超时
 */
uint8_t RANGE_Main_Call_SubDist(uint8_t A_ID,uint8_t B_ID) 
{
	if(SYS_RAN_BACK_DIST_FLAG == 0)
	{
		uint8_t ret;
		memset(Range_get_dis_msg,0,sizeof(Range_get_dis_msg));
		
		if(frame_seq_nb < 0xFF)
			frame_seq_nb++;
		else
			frame_seq_nb = 0;
		
		Range_get_dis_msg[0] = 0xFF;
		Range_get_dis_msg[1] = A_ID;
		Range_get_dis_msg[2] = frame_seq_nb;
		Range_get_dis_msg[3] = 0xE5;
		Range_get_dis_msg[4] = B_ID;
		Range_get_dis_msg[5] = Range_cfg->range_max_num;
		
		dwt_writetxdata(sizeof(Range_get_dis_msg), Range_get_dis_msg, 0);         //将数据传给DW1000，将在开启发送时传出去
		dwt_writetxfctrl(sizeof(Range_get_dis_msg), 0, 1);//设置超宽带发送数据长度			
		dwt_setrxaftertxdelay(0);        //设定超时时间		
		dwt_setrxtimeout(20000);	//设定接收超时时间 20ms
		
		ret = dwt_starttx(DWT_START_TX_IMMEDIATE | DWT_RESPONSE_EXPECTED);  //立即发送			
		if(ret == DWT_SUCCESS)
			SYS_RAN_BACK_DIST_FLAG = 2;
		else  //发送失败
			return 2;
	}
	if(SYS_RAN_BACK_DIST_FLAG == 2)
	{
		if((status_reg = dwt_read32bitreg(SYS_STATUS_ID)) & (SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR))//不断查询芯片状态直到成功接收或者发生错误
		{
			SYS_RAN_BACK_DIST_FLAG = 3;
		}
		else return 0;
	}
	if(SYS_RAN_BACK_DIST_FLAG == 3)
	{
		if (status_reg & SYS_STATUS_RXFCG_BIT_MASK)//如果成功接收
			SYS_RAN_BACK_DIST_FLAG = 4;
		else
		{
			dwt_write32bitreg(SYS_STATUS_ID,SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR);	
//			dwt_rxreset();
			SYS_RAN_BACK_DIST_FLAG = 0;
			
			if(status_reg & SYS_STATUS_ALL_RX_TO)
				return 3;
			return 0;
		}
		return 0;
	}
	if(SYS_RAN_BACK_DIST_FLAG == 4)
	{
		dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_TXFRS_BIT_MASK);//清楚寄存器标志位
		
		frame_len = dwt_read32bitreg(RX_FINFO_ID) & FRAME_LEN_MAX;       //获得接收数据长度
		if(frame_len > RANGE_RX_BUF_LEN)  //接收超过数据长度 立即重新打开接收
		{
			dwt_rxenable(DWT_START_RX_IMMEDIATE);
			SYS_RAN_BACK_DIST_FLAG = 2;
			return 0;
		}
		dwt_readrxdata(Range_Rx_Buff, frame_len, 0);                                     //读取接收数据
		if(Range_Rx_Buff[1] == 0xFF && Range_Rx_Buff[3] == 0xF6)
		{
			SYS_RAN_BACK_DIST_FLAG = 0;
			Range_cfg->range_flag = Range_Rx_Buff[5] << 8 | Range_Rx_Buff[6];
			Range_cfg->range_dist = Range_Rx_Buff[7] << 8 | Range_Rx_Buff[8];
			return 1;
		}
		else
		{
			dwt_rxenable(0);
			SYS_RAN_BACK_DIST_FLAG = 2;
		}
	}
	return 0;
}

/*! ------------------------------------------------------------------------------------------------------------------
 * @fn RANGE_Anc_Recv_Resp(uint8_t A_ID,uint8_t B_ID) 
 *
 * @brief  测距基站发送Poll包 通知被测基站回传Resp包
 *
 * input parameters:
 * @param A_ID - 发送者ID
 * @param B_ID - 接收者ID
 * output parameters
 * 
 * returns 0：动作未完成 1：接收成功 2：发送失败 3：接收超时
 */
uint8_t RANGE_Anc_Recv_Resp(uint8_t A_ID,uint8_t B_ID) 
{
	if(SYS_RAN_RECV_RESP_FLAG == 0)
	{
		uint8_t ret;
		memset(Range_get_dis_msg,0,sizeof(Range_get_dis_msg));
		
		if(frame_seq_nb < 0xFF)
			frame_seq_nb++;
		else
			frame_seq_nb = 0;
		
		Range_get_dis_msg[0] = A_ID;
		Range_get_dis_msg[1] = B_ID;
		Range_get_dis_msg[2] = frame_seq_nb;
		Range_get_dis_msg[3] = 0xA1;
		
		dwt_writetxdata(sizeof(Range_get_dis_msg), Range_get_dis_msg, 0);         //将数据传给DW1000，将在开启发送时传出去
		dwt_writetxfctrl(sizeof(Range_get_dis_msg), 0, 1);                        //设置超宽带发送数据长度
		dwt_setrxaftertxdelay(0);        //设定超时时间		
		dwt_setrxtimeout(8500);	//设定接收超时时间 8.5ms
		ret = dwt_starttx(DWT_START_TX_IMMEDIATE | DWT_RESPONSE_EXPECTED);  //立即发送			
		if(ret == DWT_SUCCESS)
			SYS_RAN_RECV_RESP_FLAG=2;
		else  //发送失败
			return 2;
	}
	
	if(SYS_RAN_RECV_RESP_FLAG == 2)
	{
		if((status_reg = dwt_read32bitreg(SYS_STATUS_ID)) & (SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR))//不断查询芯片状态直到成功接收或者发生错误
		{
			SYS_RAN_RECV_RESP_FLAG = 3;
		}
		else return 0;
	}
	if(SYS_RAN_RECV_RESP_FLAG == 3)
	{
		if (status_reg & SYS_STATUS_RXFCG_BIT_MASK)//如果成功接收
			SYS_RAN_RECV_RESP_FLAG=4;
		else
		{
			dwt_write32bitreg(SYS_STATUS_ID,SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR);	
//			dwt_rxreset();
			SYS_RAN_RECV_RESP_FLAG = 0;
			
			if(status_reg & SYS_STATUS_ALL_RX_TO) //接收超时
				return 3;
			return 0;
		}
		return 0;
	}
	if(SYS_RAN_RECV_RESP_FLAG == 4)
	{
		dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_TXFRS_BIT_MASK);//清楚寄存器标志位
		
		frame_len = dwt_read32bitreg(RX_FINFO_ID) & FRAME_LEN_MAX;       //获得接收数据长度
		if(frame_len > RANGE_RX_BUF_LEN)	//如果接收到的数据大于接收缓存区
		{
			dwt_rxenable(DWT_START_RX_IMMEDIATE);	//重新打开接收
			SYS_RAN_RECV_RESP_FLAG = 2;
			return 0;
		}
		dwt_readrxdata(Range_Rx_Buff, frame_len, 0);                                     //读取接收数据
		if(Range_Rx_Buff[1] == A_ID && Range_Rx_Buff[3] == 0xB2)	//接收到被测距基站回传的Resp包
		{
			SYS_RAN_RECV_RESP_FLAG = 0;
			frame_seq_nb = Range_Rx_Buff[2];
			memset(Time_ts,0,sizeof(Time_ts));
			Time_ts[0] = (uint32)get_tx_timestamp_u64();	//记录发送Poll包时间戳T1
			Time_ts[3] = (uint32)get_rx_timestamp_u64(); 	//记录接收Resp包时间戳T4
			Timer1_error_flag = 0;
			return 1;
		}
		dwt_rxenable(0);
		SYS_RAN_RECV_RESP_FLAG = 2;
	}
	return 0;
}




/*! ------------------------------------------------------------------------------------------------------------------
 * @fn Anchorsend_dist_msg(uint8_t A_ID,uint8_t B_ID,uint32 *dist)
 *
 * @brief  测距基站发送Final包 通知被测距基站回传ACK包
 *
 * input parameters:
 * @param A_ID - 发送者ID
 * @param B_ID - 接收者ID
 * output parameters
 * 
 * returns 0：动作未完成 1：接收成功 2：发送失败 3：接收超时
 */
uint8_t RANGE_Anc_Recv_ACK(uint8_t A_ID,uint8_t B_ID) 
{
	if(SYS_RAN_RECV_ACK_FLAG == 0)
	{
		uint8_t ret;
		memset(Range_get_dis_msg,0,sizeof(Range_get_dis_msg));
		
		Range_get_dis_msg[0] = A_ID;
		Range_get_dis_msg[1] = B_ID;
		Range_get_dis_msg[2] = frame_seq_nb;
		Range_get_dis_msg[3] = 0xC3;
		
		dwt_writetxdata(sizeof(Range_get_dis_msg), Range_get_dis_msg, 0);         //将数据传给DW1000，将在开启发送时传出去
		dwt_writetxfctrl(sizeof(Range_get_dis_msg), 0, 1);                        //设置超宽带发送数据长度
		dwt_setrxaftertxdelay(0);  
		dwt_setrxtimeout(8500);					//设定超时时间 8.5ms		
		ret = dwt_starttx(DWT_START_TX_IMMEDIATE | DWT_RESPONSE_EXPECTED);  //立即发送			
		if(ret == DWT_SUCCESS)
		 SYS_RAN_RECV_ACK_FLAG=2;
		else  //发送失败
			return 2;
	}
	
	if(SYS_RAN_RECV_ACK_FLAG == 2)
	{
		if((status_reg = dwt_read32bitreg(SYS_STATUS_ID)) & (SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR))//不断查询芯片状态直到成功接收或者发生错误
		{
			SYS_RAN_RECV_ACK_FLAG = 3;
		}
		else return 0;
	}
	if(SYS_RAN_RECV_ACK_FLAG == 3)
	{
		if (status_reg & SYS_STATUS_RXFCG_BIT_MASK)//如果成功接收
			SYS_RAN_RECV_ACK_FLAG=4;
		else
		{
			dwt_write32bitreg(SYS_STATUS_ID,SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR);	
//			dwt_rxreset();
			SYS_RAN_RECV_ACK_FLAG = 0;
			
			if(status_reg & SYS_STATUS_ALL_RX_TO)//如果接收超时
				return 3;
			return 0;
		}
		return 0;
	}
	if(SYS_RAN_RECV_ACK_FLAG == 4)
	{
		dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_TXFRS_BIT_MASK);//清楚寄存器标志位
		
		frame_len = dwt_read32bitreg(RX_FINFO_ID) & FRAME_LEN_MAX;       //获得接收数据长度
		if(frame_len > RANGE_RX_BUF_LEN)	//如果接收到的数据大于接收缓存区
		{
			dwt_rxenable(DWT_START_RX_IMMEDIATE);	//重新打开接收
			SYS_RAN_RECV_ACK_FLAG = 2;
			return 0;
		}
		dwt_readrxdata(Range_Rx_Buff, frame_len, 0);                                     //读取接收数据
		if(Range_Rx_Buff[1] == A_ID && Range_Rx_Buff[3] == 0xD4)	//接收到被测距基站回传的Ack包
		{
			SYS_RAN_RECV_ACK_FLAG = 0;
			Time_ts[4] = (uint32)get_tx_timestamp_u64();		//记录发送Fianl包时间戳T5
			final_msg_get_ts(&Range_Rx_Buff[4],&Time_ts[1]);	//记录被测距基站接收Poll包时间戳T2
			final_msg_get_ts(&Range_Rx_Buff[8],&Time_ts[2]);	//记录被测距基站发送Resp包时间戳T3
			final_msg_get_ts(&Range_Rx_Buff[12],&Time_ts[5]);	//记录被测距基站接收Final包时间戳T6
			Timer1_error_flag = 0;
			return 1;
		}
		dwt_rxenable(0);
		SYS_RAN_RECV_ACK_FLAG = 2;
	}
	return 0;
}


/*! ------------------------------------------------------------------------------------------------------------------
 * @fn Mode_MainAnchor_RANGE(uint8_t A_ID,uint8_t B_ID)
 *
 * @brief  主基站跟次基站测距_主流程
 *
 * input parameters:
 * @param A_ID - 发送者ID
 * @param B_ID - 接收者ID
 * returns 0：动作未完成 1：动作完成
 */
uint8_t Mode_MainAnchor_RANGE(uint8_t A_ID,uint8_t B_ID)
{
	uint8_t ret = 0;
	static uint8_t buff_num = 0;
	static uint8_t num_range = 0;
	/**** Poll包状态 ****/
	if(SYS_RANGE_FLAG == 0)
	{
		ret = RANGE_Anc_Recv_Resp(A_ID,B_ID);
		if(ret == 1)									//发送Poll包并接收到了Resp包
		{
			SYS_RANGE_FLAG = 1;
			Timer1_error_flag = 0;
		}
		if(ret == 3)									//接收超时
		{
			Timer1_error_flag = 0;
			if(++num_range >= Range_cfg->range_max_num)
				SYS_RANGE_FLAG = 3;
			else
				SYS_RANGE_FLAG = 0;						//重新打开接收
		}
	}
	/**** Final包状态 ****/
	if(SYS_RANGE_FLAG == 1)
	{
		ret = RANGE_Anc_Recv_ACK(A_ID,B_ID);
		if(ret == 1)									//发送Final包并接收到了Ack包
		{
			SYS_RANGE_FLAG = 2;
			Timer1_error_flag = 0;
		}
		if(ret == 3)									//接收超时
		{
			Timer1_error_flag = 0;
			if(++num_range >= Range_cfg->range_max_num)
				SYS_RANGE_FLAG = 3;
			else
				SYS_RANGE_FLAG = 0;						//重新打开接收
		}
	}
	if(SYS_RANGE_FLAG == 2)
	{
		uint16_t dist = 0;
		if(Range_CalDist(&dist) != -1)
		{
			Range_DIST_BUFF[buff_num++] = dist;	//测距到的距离存入测距缓存区
			Range_cfg->range_flag = 1;		//只要有一次测距成功 标志位就置为1 
		}
		Timer1_error_flag = 0;
		if(++num_range >= Range_cfg->range_max_num)
			SYS_RANGE_FLAG = 3;
		else
			SYS_RANGE_FLAG = 0;
		
		if(LED_FLAG > 5)
		{
			LED1_TOGGLE();
			LED_FLAG = 0;
		}
		else
			LED_FLAG++;
		
	}
	if(SYS_RANGE_FLAG == 3)
	{
		uint8_t j;
		uint32 dis = 0;
		
		for(j = 0; j < buff_num; j++)
		{	
			dis += Range_DIST_BUFF[j];
		}
		Range_cfg->range_dist = dis / buff_num;		//得到的距离取平均
		buff_num = 0;
		SYS_RANGE_FLAG = 0;
		Timer1_error_flag = 0;
		num_range = 0;
		return 1;
	}
	if(Timer1_error_flag > Device_cfg_ptr->Uwb_config.Twr_Error_max)                                //看门狗出错 复位标志位
	{
		SYS_RANGE_FLAG = 0;
		SYS_RAN_RECV_RESP_FLAG = 0;
		SYS_RAN_RECV_ACK_FLAG = 0;
		dwt_forcetrxoff();                                      //强制关闭所有发送和接收		
		Timer1_error_flag = 0;
	}
	return 0;
}

/*! ------------------------------------------------------------------------------------------------------------------
 * @fn Mode_SubAnchor_RANGE(uint8_t A_ID,uint8_t B_ID)
 *
 * @brief  从基站跟从基站测距_主流程
 *
 * input parameters:
 * @param A_ID - 发送者ID
 * @param B_ID - 接收者ID
 * returns 0：动作未完成 1：动作完成
 */
uint8_t Mode_SubAnchor_RANGE(uint8_t A_ID,uint8_t B_ID)
{
	uint8_t ret = 0;
	static uint16_t num_range = 0;
	
	if(SYS_RANGE_FLAG == 0)
	{
		ret = RANGE_Main_Call_SubDist(A_ID,B_ID);		//主基站呼叫被测距基站测距
		if(ret == 1)
		{
			Timer1_error_flag = 0;
			if(LED_FLAG > 5)
			{
				LED1_TOGGLE();
				LED_FLAG = 0;
			}
			else
				LED_FLAG++;
			return 1;
		}
		else if(ret == 3)								//接收超时
		{
			Timer1_error_flag = 0;
			if(++num_range >= Range_cfg->range_max_num)
			{
				num_range = 0;
				return 1;
			}
			else										//重新发送
				return 0;
		}
	}
	if(Timer1_error_flag > Device_cfg_ptr->Uwb_config.Twr_Error_max) 
	{
		dwt_forcetrxoff();
		SYS_RANGE_FLAG = 0;
		SYS_RAN_BACK_DIST_FLAG = 0;
		Timer1_error_flag=0;        //错误标志归0
	}
	return 0;
}
/*! ------------------------------------------------------------------------------------------------------------------
 * @fn RANGE_Anc_Back_Resp(uint8_t A_ID,uint8_t B_ID) 
 *
 * @brief  被测距基站回传Resp包
 *
 * input parameters:
 * @param A_ID - 发送者ID
 * @param B_ID - 接收者ID
 * output parameters
 * 
 * returns 0：动作未完成 1：发送成功 2：发送失败
 */
uint8_t RANGE_Anc_Back_Resp(uint8_t A_ID,uint8_t B_ID) 
{
	if(SYS_RAN_BACK_RESP_FLAG == 0)
	{
		uint8_t ret;
		memset(Range_get_dis_msg,0,sizeof(Range_get_dis_msg));
		Range_get_dis_msg[0] = A_ID;
		Range_get_dis_msg[1] = B_ID;
		Range_get_dis_msg[2] = frame_seq_nb;
		Range_get_dis_msg[3] = 0xB2;
		
		dwt_writetxdata(sizeof(Range_get_dis_msg), Range_get_dis_msg, 0);         //将数据传给DW1000，将在开启发送时传出去
		dwt_writetxfctrl(sizeof(Range_get_dis_msg), 0, 1);                        //设置超宽带发送数据长度
		dwt_setrxaftertxdelay(0);				
		ret = dwt_starttx(DWT_START_TX_IMMEDIATE);                                //开启发送
		if(ret == DWT_SUCCESS)
			SYS_RAN_BACK_RESP_FLAG=1;
		else  //发送失败
			return 2;
	}
	
	if(SYS_RAN_BACK_RESP_FLAG == 1)
	{
		if((dwt_read32bitreg(SYS_STATUS_ID) & SYS_STATUS_TXFRS_BIT_MASK))                  //读取是否发送完成
		{
			dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_TXFRS_BIT_MASK);                     //清除发送标志位
			SYS_RAN_BACK_RESP_FLAG = 0;
			
			return 1;
		}	
	}
	return 0;
}

/*! ------------------------------------------------------------------------------------------------------------------
 * @fn RANGE_Anc_Back_ACK(uint8_t A_ID,uint8_t B_ID) 
 *
 * @brief  被测距基站回传ACK包
 *
 * input parameters:
 * @param A_ID - 发送者ID
 * @param B_ID - 接收者ID
 * output parameters
 * 
 * returns 0：动作未完成 1：发送成功 2：发送失败
 */
uint8_t RANGE_Anc_Back_ACK(uint8_t A_ID,uint8_t B_ID) 
{
	if(SYS_RAN_BACK_ACK_FLAG == 0)
	{
		uint8_t ret;
		memset(Range_get_dis_msg,0,sizeof(Range_get_dis_msg));
		Range_get_dis_msg[0] = A_ID;
		Range_get_dis_msg[1] = B_ID;
		Range_get_dis_msg[2] = frame_seq_nb;
		Range_get_dis_msg[3] = 0xD4;
		
		final_msg_set_ts(&Range_get_dis_msg[4],Time_ts[1]);//将T2写入发送数据
		final_msg_set_ts(&Range_get_dis_msg[8],Time_ts[2]);//将T3写入发送数据
		final_msg_set_ts(&Range_get_dis_msg[12],Time_ts[5]);//将T6写入发送数据
		
		dwt_writetxdata(sizeof(Range_get_dis_msg), Range_get_dis_msg, 0);         //将数据传给DW1000，将在开启发送时传出去
		dwt_writetxfctrl(sizeof(Range_get_dis_msg), 0, 1);                        //设置超宽带发送数据长度
		dwt_setrxaftertxdelay(0);				
		ret = dwt_starttx(DWT_START_TX_IMMEDIATE);                                //开启发送
		if(ret == DWT_SUCCESS)
			SYS_RAN_BACK_ACK_FLAG=1;
		else  //发送失败
			return 2;
	}
	
	if(SYS_RAN_BACK_ACK_FLAG == 1)
	{
		if((dwt_read32bitreg(SYS_STATUS_ID) & SYS_STATUS_TXFRS_BIT_MASK))                  //读取是否发送完成
		{
			dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_TXFRS_BIT_MASK);                     //清除发送标志位
			SYS_RAN_BACK_ACK_FLAG = 0;
			return 1;
		}
	}
	return 0;
}
/*! ------------------------------------------------------------------------------------------------------------------
 * @fn RANGE_Sub_Back_Dist(uint8_t A_ID,uint8_t B_ID) 
 *
 * @brief  被测距基站回传距离给主基站
 *
 * input parameters:
 * @param A_ID - 发送者ID
 * @param B_ID - 接收者ID
 * output parameters
 * 
 * returns 0：动作未完成 1：发送成功 2：发送失败
 */
uint8_t RANGE_Sub_Back_Dist(uint8_t A_ID,uint8_t B_ID) 
{
	if(SYS_RAN_SUB_DIST_FLAG == 0)
	{
		uint8_t ret;
		
		memset(Range_get_dis_msg,0,sizeof(Range_get_dis_msg));
		
		dwt_forcetrxoff(); 
		
		Range_get_dis_msg[0] = A_ID;
		Range_get_dis_msg[1] = 0xFF;
		Range_get_dis_msg[2] = frame_seq_nb;
		Range_get_dis_msg[3] = 0xF6;
		Range_get_dis_msg[4] = B_ID;
		Range_get_dis_msg[5] = (Range_cfg->range_flag >> 8) & 0x00FF;
		Range_get_dis_msg[6] = Range_cfg->range_flag & 0x00FF;
		Range_get_dis_msg[7] = (Range_cfg->range_dist >> 8) & 0x00FF;
		Range_get_dis_msg[8] = Range_cfg->range_dist & 0x00FF;
		
		dwt_writetxdata(sizeof(Range_get_dis_msg), Range_get_dis_msg, 0);         //将数据传给DW1000，将在开启发送时传出去
		dwt_writetxfctrl(sizeof(Range_get_dis_msg), 0, 1);                        //设置超宽带发送数据长度
		dwt_setrxaftertxdelay(0);				
		ret = dwt_starttx(DWT_START_TX_IMMEDIATE);                                //开启发送
		if(ret == DWT_SUCCESS)
			SYS_RAN_SUB_DIST_FLAG=1;
		else  //发送失败
			return 2;
	}
	
	if(SYS_RAN_SUB_DIST_FLAG == 1)
	{
		if((dwt_read32bitreg(SYS_STATUS_ID) & SYS_STATUS_TXFRS_BIT_MASK))                  //读取是否发送完成
		{
			dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_TXFRS_BIT_MASK);                     //清除发送标志位
			SYS_RAN_SUB_DIST_FLAG = 0;
			return 1;
		}
		else
			return 0;
	}
	return 0;
}

/*! ------------------------------------------------------------------------------------------------------------------
 * @fn RANGE_Call_Sub_Anc_Dist(uint8_t A_ID,uint8_t B_ID) 
 *
 * @brief  主基站呼叫次基站进行测距
 *
 * input parameters:
 * @param A_ID - 发送者ID
 * @param B_ID - 接收者ID
 * output parameters
 * 
 * returns 0：动作未完成 1：测距结束
 */
uint8_t RANGE_Call_Sub_Anc_Dist(uint8_t A_ID,uint8_t B_ID) 
{
	uint8_t ret = 0;
	static uint8_t num_range = 0;
	static uint16_t num_sub = 0;
	/**** 发送Poll包状态 ****/
	if(SYS_RAN_CALL_SUB_FLAG == 0)
	{
		ret = RANGE_Anc_Recv_Resp(A_ID,B_ID);
		if(ret == 1)							//发送Poll包并接收到了Resp包
		{
			SYS_RAN_CALL_SUB_FLAG = 1;
			Timer1_error_flag = 0;
		}
		if(ret == 3)							//接收超时
		{
			Timer1_error_flag = 0;
			if(++num_range >= Range_cfg->range_max_num)
				SYS_RAN_CALL_SUB_FLAG = 3;		//计算测距结果
			else
				SYS_RAN_CALL_SUB_FLAG = 0;		 //重新发送Poll包
		}
		return 0;
	}
	if(SYS_RAN_CALL_SUB_FLAG == 1)
	{
		ret = RANGE_Anc_Recv_ACK(A_ID,B_ID);
		if(ret == 1)							//发送Final包并接收到了Ack包
		{
			SYS_RAN_CALL_SUB_FLAG = 2;
			Timer1_error_flag = 0;
		}
		if(ret == 3)							//接收超时
		{
			Timer1_error_flag = 0;
			if(++num_range >= Range_cfg->range_max_num)
				SYS_RAN_CALL_SUB_FLAG = 3;		//计算测距结果
			else
				SYS_RAN_CALL_SUB_FLAG = 0;		//重新发送Poll包
		}
		return 0;
	}
	if(SYS_RAN_CALL_SUB_FLAG == 2)
	{
		uint16_t dist = 0;
		if(Range_CalDist(&dist) != -1)
		{
			Range_DIST_BUFF[num_sub++] = dist;		//得到的距离存入缓存区
			Range_cfg->range_flag = 1;								//赋予测距使能
		}
		Timer1_error_flag = 0;
		if(++num_range >= Range_cfg->range_max_num)
			SYS_RAN_CALL_SUB_FLAG = 3;					//计算测距结果
		else
			SYS_RAN_CALL_SUB_FLAG = 0;					//重新发送Poll包
		if(LED_FLAG > 5)
		{
			LED1_TOGGLE();
			LED_FLAG = 0;
		}
		else
			LED_FLAG++;
		return 0;
	}
	if(SYS_RAN_CALL_SUB_FLAG == 3)
	{
		uint8_t j;
		uint32 dis = 0;

		for(j = 0; j < num_sub; j++)
		{	
			dis += Range_DIST_BUFF[j];
		}
		Range_cfg->range_dist = dis / num_sub;						//取平均
		num_sub = 0;
		num_range = 0;									//清空测距次数
		SYS_RAN_CALL_SUB_FLAG = 4;
		Timer1_error_flag = 0;
		return 0;
	}
	if(SYS_RAN_CALL_SUB_FLAG == 4)
	{
		ret = RANGE_Sub_Back_Dist(A_ID,B_ID);			//回传距离给主基站
		if(ret == 1)
		{
			SYS_RAN_CALL_SUB_FLAG = 0;
			Timer1_error_flag = 0;
			Range_cfg->range_flag = 0;								//清零使能
			Range_cfg->range_dist = 0;
			memset(Range_DIST_BUFF,0,sizeof(Range_DIST_BUFF));
			return 1;
		}
	}
	return 0;
}
