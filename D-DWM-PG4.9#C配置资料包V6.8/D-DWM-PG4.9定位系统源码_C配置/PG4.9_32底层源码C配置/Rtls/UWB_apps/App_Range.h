#ifndef __APP_RANGE_H
#define __APP_RANGE_H

#include "TWR.h"

#define RANGE_TX_BUF_LEN 20
#define RANGE_RX_BUF_LEN 45               //DWM1000接收数据包长度

void RANGE_Init(void);
void RANGE_SUB_ANC_Reset(void);
uint8_t Mode_MainAnchor_RANGE(uint8_t A_ID,uint8_t B_ID);
uint8_t Mode_SubAnchor_RANGE(uint8_t A_ID,uint8_t B_ID);

uint8_t RANGE_Anc_Back_Resp(uint8_t A_ID,uint8_t B_ID);
uint8_t RANGE_Anc_Back_ACK(uint8_t A_ID,uint8_t B_ID);
uint8_t RANGE_Anc_Recv_Resp(uint8_t A_ID,uint8_t B_ID);
uint8_t RANGE_Anc_Recv_ACK(uint8_t A_ID,uint8_t B_ID);

uint8_t RANGE_Main_Call_SubDist(uint8_t A_ID,uint8_t B_ID);
uint8_t RANGE_Sub_Back_Dist(uint8_t A_ID,uint8_t B_ID);
uint8_t RANGE_Call_Sub_Anc_Dist(uint8_t A_ID,uint8_t B_ID);




#endif
