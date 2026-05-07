#ifndef __HDS_TWR_H
#define __HDS_TWR_H

#include "TWR.h"

#define ANCHOR_WAITFINAL_MAX 120                         //基站等待resp包最大时间 0.1ms为单位

#define TX_ANC_INFORM_LEN 50
extern uint8_t TX_ANC_INFORM_BUFF[TX_ANC_INFORM_LEN];         //基站发送Inform包数组

#define TX_TAG_POLL_FIX_LEN 8
#define TX_TAG_POLL_LEN TX_TAG_POLL_FIX_LEN + UWB_COMMU_DATA_MAXLEN
extern uint8_t TX_TAG_POLL_BUFF[TX_TAG_POLL_LEN];             //标签发送Poll包数组

#define TX_ANC_RESP_FIX_LEN 8
#define TX_ANC_RESP_LEN TX_ANC_RESP_FIX_LEN + UWB_COMMU_DATA_MAXLEN
extern uint8_t TX_ANC_RESP_BUFF[TX_ANC_RESP_LEN];             //基站发送Resp包数组

#define TX_TAG_FINAL_LEN 78
extern uint8_t TX_TAG_FINAL_BUFF[TX_TAG_FINAL_LEN];           //标签发送Final包数组

#define TX_ANC_REQ_LEN 6
extern uint8_t TX_ANC_REQ_BUFF[TX_ANC_REQ_LEN];               //基站发送Request包数组  主基站

#define TX_ANC_REPLY_LEN 9
extern uint8_t TX_ANC_REPLY_BUFF[TX_ANC_REPLY_LEN];           //基站发送Reply包数组  次基站

#define RX_MAX_LEN 127
extern uint8_t HDS_rx_buffer[RX_MAX_LEN];                           //接收缓存

extern uint16_t Dis_cal;
extern uint8_t frame_now;
extern uint16_t Anc_recvFinal_timeflag;

extern uint8_t SYS_ANC_RESP_FLAG;
extern uint8_t SYS_ANC_FINAL_FLAG;
extern uint8_t SYS_ANC_DELAY_SEND_FLAG;


uint8_t HDS_TWR_Send_Resp(uint8_t A_ID, uint8_t B_ID, uint8_t En);
uint8_t HDS_TWR_Recv_FinalAndCal(uint8_t A_ID ,uint8_t B_ID, uint16_t recv_timeout);

void Mode_MainAnchor_HDS(void);
void Mode_Tag_HDS(void);
void Mode_Sub_Anchor_HDS(void);

#endif
