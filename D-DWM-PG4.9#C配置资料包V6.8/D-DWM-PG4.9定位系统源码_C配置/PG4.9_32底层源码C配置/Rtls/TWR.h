#ifndef __TWR_H
#define __TWR_H

#include "common_config.h"
#include "stdint.h"

#include "deca_device_api.h"
#include "deca_regs.h"


/* Hold copy of status register state here for reference, so reader can examine it at a breakpoint. 
在这里保存状态寄存器状态的副本以供参考，以便读者可以在断点上检查它。*/
static uint32_t status_reg = 0;
static uint32_t frame_len;        		//DWM1000收发数据包长度缓存	
static uint16_t LED_FLAG=0;     		//系统指示灯记录标志位

/* UWB microsecond (uus) to device time unit (dtu, around 15.65 ps) conversion factor.
UWB微秒（UUS）到设备时间单位（DTU，约15.65 ps）的转换系数。
 * 1 uus = 512 / 499.2 祍 and 1 祍 = 499.2 * 128 dtu. 
  1 UUS＝512／499.2，1＝499.2×128 DTU。*/
#define UUS_TO_DWT_TIME 65536

#define SPEED_OF_LIGHT 299702547

#define FLIGHT_OF_UWBTIME  SPEED_OF_LIGHT * DWT_TIME_UNITS

#define FINAL_MSG_TS_LEN 4  //时间数据长度

#define FRAME_LEN_MAX      (127)

#define FRAME_LEN_MAX_EX   (1023)

typedef struct 
{
	uint32_t Cal_Flag;  //测距成功标志位 第17位 1：定位成功 第0-15：1分别代表A-P基站测距成功
	int16_t x;         //计算出的x坐标 单位cm
	int16_t y;         //计算出的y坐标 单位cm
	int16_t z;         //计算出的z坐标 单位cm
	uint16_t Dist[ANCHOR_LIST_COUNT];     //测得标签与A-H基站的距离
}Cal_data_t;


extern uint32_t frame_seq_nb;                                            //帧序列号，每次传输后递增。

extern uint32_t Time_ts[6];  					                                   //飞行时间缓存记录
//extern u16   Cal_Last_XYZ[100][3];                               //回传坐标使用的缓存，用于次基站和主基站模式测得的标签距离下一次回传给标签
//extern uint32_t Cal_Last_Dist[100][8];        //存放100个标签的8个基站测距值
extern uint32_t Dist_Cal_All[ANCHOR_LIST_COUNT];        //存放本次测距的数组
extern Cal_data_t Cal_data[100];

#define TAG_USART_BUF_DIST_LEN 350
#define TAG_USART_BUF_RTLS_LEN 60
#define TAG_USART_BUF_MAXLEN TAG_USART_BUF_DIST_LEN + TAG_USART_BUF_RTLS_LEN
extern char Tag_Usart_Str[TAG_USART_BUF_MAXLEN];
void Prepare_tag_result_output(Cal_data_t* now_data, uint8_t format, uint8_t mode);

extern dwt_rxdiag_t rx_diag;                                           //接收信息
extern uint32_t Calculate_FLAG;


void final_msg_get_ts(const uint8_t *ts_field, uint32_t *ts);
void final_msg_get_dist(const uint8_t *ts_field, uint32_t *dist);
uint64_t get_tx_timestamp_u64(void);
uint64_t get_rx_timestamp_u64(void);
void final_msg_set_ts(uint8_t *ts_field, uint32_t ts);
void final_msg_set_dist(uint8_t *ts_field, uint32_t dist);
int16_t Twr_CalDist(uint8_t tag_id,uint16_t *cal_dist);
int16_t Range_CalDist(uint16_t *cal_dist);

#endif

