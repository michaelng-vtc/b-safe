#ifndef APP_REMOTE_CFG_H
#define APP_REMOTE_CFG_H

#include "stdint.h"

#define REMOTE_CFG_RECV (0)
#define REMOTE_CFG_SINGLE_CFG (1)
#define REMOTE_CFG_ALL_CFG  (2)
#define REMOTE_CFG_SYNC_LENGTH	(14)

typedef struct
{
	uint8_t id[6];
	uint8_t  pg_id;
	uint16_t static_freq;  //静止时发送频率  27000-65535
	uint16_t alarm_freq;   //报警发送频率    50-65535
	uint16_t moving_freq;  //运动时发送频率  100-65535
	uint8_t  imu_en;       //三轴使能 0关闭 1开启
	uint8_t  imu_sensitive;    //三轴灵敏度 0：高 1:中 3:低	
	uint8_t  send_packets_move;  //运动发包次数
	uint8_t  send_packets_static; //静止发包次数
	uint16_t rx_ant_delay;     //标签接收延时 
	uint8_t  kind;     //标签种类 0-3
	uint32_t version;  //标签版本号 高16位a 高8位b 低8位c 最终结果a.b.c
	uint8_t  smartpwr_en;     //使能SmartPower
	uint8_t  power_db;     //配置的功率
	uint16_t nosleep_freq; //没有三轴时候间隔一定时间发包 50-65535
	uint8_t  poweroff_time;  //关机按键时间 1-20
	uint8_t  poweroff_en;   //关机模式使能
	uint8_t	 heart_Rate_Min;	//心率间隔时间
	uint8_t  SYNC_Time_Buff[REMOTE_CFG_SYNC_LENGTH];	//YYYYMMDDHHmmss
}Remote_tag_cfg_t;

void App_remote_cfg_change_state(uint8_t state);
void App_remote_cfg_Handler(void);
Remote_tag_cfg_t* App_remote_get_cfg(void);
void App_remote_cfg_reset(void);
#endif


