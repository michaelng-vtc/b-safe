#ifndef __DS_TWR_H
#define __DS_TWR_H

#include "TWR.h"

#define DS_FIX_BUF_LEN (32)
#define DS_TX_BUF_LEN (127)
#define DS_RX_BUF_LEN (127)             //DWM1000接收数据包最大长度

#define DS_POLL_LEN (48)
#define DS_RESP_LEN (14)
#define DS_FINAL_LEN DS_TX_BUF_LEN
#define DS_ACK_LEN DS_TX_BUF_LEN
#define DS_ASK_LEN (7)
#define DS_REPLY_LEN (9)

extern uint8 DS_send_msg[DS_TX_BUF_LEN];  // DWM1000通讯数据包
extern uint8 DS_rx_buffer[DS_RX_BUF_LEN]; //DWM1000接收数据包缓存区

extern uint8_t SYS_Calculate_ACTIVE_FLAG;

int32_t DW1000send(uint8_t A_ID,uint8_t B_ID,uint8_t MODE, int8_t *ret);
void MODE_TAG_DS(void);
void MODE_SUB_ANCHOR_DS(void);
void MODE_MAJOR_ANCHOR_DS(void);


#endif
