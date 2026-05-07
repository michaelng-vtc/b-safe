#include "App_remote_cfg.h"
#include "deca_device_api.h"
#include "deca_regs.h"
#include "modbus.h"
#include "Twr.h"
#include "string.h"
#include "port.h"

uint8_t App_remote_cfg_flag = 0;
#define REMOTE_CFG_RECV_MAXLEN (31)
#define REMOTE_CFG_SEND_MAXLEN (42)
uint8_t Remote_cfg_recvbuff[REMOTE_CFG_RECV_MAXLEN+2] = {0};
uint8_t Remote_cfg_sendbuff[REMOTE_CFG_SEND_MAXLEN+2] = {0};

#define REMOTE_CFG_UPLOAD_DATALEN (30)

#define REMOTE_CFG_SEND_NUM (10)
Remote_tag_cfg_t Recv_cfg = {0};
Remote_tag_cfg_t Send_cfg = {0};
uint8_t Now_recv_frame = 0;
uint8_t Send_frame = 0;
uint8_t Cfg_state = REMOTE_CFG_RECV;

void App_remote_cfg_change_state(uint8_t state)
{
	Cfg_state = state;
}

Remote_tag_cfg_t* App_remote_get_cfg(void)
{
	return &Send_cfg;
}

void App_remote_upload_recvdata(void)
{
	uint8_t data_len = 0;
	uint8_t i = 0;
	uint8_t data[REMOTE_CFG_UPLOAD_DATALEN] = {0};
	
	for(i=0;i<6;i++)
		data[data_len++] = Recv_cfg.id[i];
	data[data_len++] =  Recv_cfg.static_freq >> 8;    //9
	data[data_len++] =  Recv_cfg.static_freq & 0x00FF;

	data[data_len++] =  Recv_cfg.alarm_freq >> 8;
	data[data_len++] =  Recv_cfg.alarm_freq & 0x00FF;

	data[data_len++] =  Recv_cfg.moving_freq >> 8;
	data[data_len++] =  Recv_cfg.moving_freq & 0x00FF; 

	data[data_len++] =  Recv_cfg.imu_en;
	data[data_len++] =  Recv_cfg.imu_sensitive;  
	data[data_len++] =  Recv_cfg.send_packets_move;
	data[data_len++] =  Recv_cfg.send_packets_static; 
	data[data_len++] =  Recv_cfg.rx_ant_delay >> 8;
	data[data_len++] =  Recv_cfg.rx_ant_delay & 0x00FF; 
	data[data_len++] =  Recv_cfg.kind;
	data[data_len++] =  Now_recv_frame;    
	data[data_len++] =  Recv_cfg.version >> 8;
	data[data_len++] =  Recv_cfg.version & 0x00FF; 
	data[data_len++] =  Recv_cfg.smartpwr_en;
	data[data_len++] =  Recv_cfg.power_db; 
	data[data_len++] =  Recv_cfg.nosleep_freq >> 8;
	data[data_len++] =  Recv_cfg.nosleep_freq & 0x00FF;
	data[data_len++] =  Recv_cfg.poweroff_time;
	data[data_len++] =  Recv_cfg.pg_id;
	data[data_len++] =  Recv_cfg.poweroff_en;
	data[data_len++] =  Recv_cfg.heart_Rate_Min;
	Modbus_writeRemoteCfgData(data,data_len);
}

void App_remote_cfg_tx_handler(void)
{
	uint8_t i = 0;
	dwt_forcetrxoff();
	Send_frame = 0;
	memset(Remote_cfg_sendbuff,0,sizeof(Remote_cfg_sendbuff));
	if(Cfg_state == REMOTE_CFG_SINGLE_CFG)
	{
		Remote_cfg_sendbuff[0] = 0xAA;
	}
	else if(Cfg_state == REMOTE_CFG_ALL_CFG)
	{
		Remote_cfg_sendbuff[0] = 0xCC;
	}
	else
	{
		return;
	}
	
	
	for(i=0;i<6;i++)
	{
		Remote_cfg_sendbuff[i+2] = Send_cfg.id[i];
	}
	
	Remote_cfg_sendbuff[8] = (Send_cfg.static_freq >> 8) & 0x00FF;
	Remote_cfg_sendbuff[9] = (Send_cfg.static_freq & 0x00FF);

	Remote_cfg_sendbuff[10] = (Send_cfg.alarm_freq >> 8) & 0x00FF;		
	Remote_cfg_sendbuff[11] = (Send_cfg.alarm_freq  & 0x00FF);	

	Remote_cfg_sendbuff[12] = (Send_cfg.moving_freq >> 8) & 0x00FF;		
	Remote_cfg_sendbuff[13] = (Send_cfg.moving_freq  & 0x00FF);	

	Remote_cfg_sendbuff[14] = Send_cfg.imu_en;		
	Remote_cfg_sendbuff[15] = Send_cfg.send_packets_move;
	Remote_cfg_sendbuff[16] = Send_cfg.send_packets_static;
	Remote_cfg_sendbuff[17]	= Send_cfg.imu_sensitive; 

	Remote_cfg_sendbuff[18] = (Send_cfg.rx_ant_delay >> 8) & 0x00FF;		
	Remote_cfg_sendbuff[19] = (Send_cfg.rx_ant_delay  & 0x00FF);

	Remote_cfg_sendbuff[20] = Send_cfg.smartpwr_en;
	Remote_cfg_sendbuff[21] = Send_cfg.power_db;

	Remote_cfg_sendbuff[22] = (Send_cfg.nosleep_freq >> 8) & 0x00FF;		
	Remote_cfg_sendbuff[23] = (Send_cfg.nosleep_freq & 0x00FF);

	Remote_cfg_sendbuff[24] = Send_cfg.poweroff_time;
	Remote_cfg_sendbuff[25] = Send_cfg.poweroff_en;					 
	Remote_cfg_sendbuff[26] = Send_cfg.pg_id;
	Remote_cfg_sendbuff[27] = Send_cfg.heart_Rate_Min;
	memcpy(&Remote_cfg_sendbuff[28],Send_cfg.SYNC_Time_Buff,sizeof(Send_cfg.SYNC_Time_Buff));

	for(i = 0; i < REMOTE_CFG_SEND_NUM; i++)
	{
		Remote_cfg_sendbuff[1] = Send_frame++;
		dwt_writetxdata(sizeof(Remote_cfg_sendbuff), Remote_cfg_sendbuff, 0);//将Poll包数据传给DW1000，将在开启发送时传出去
		dwt_writetxfctrl(sizeof(Remote_cfg_sendbuff), 0, 0);//设置超宽带发送数据长度
		dwt_starttx(DWT_START_TX_IMMEDIATE);//开启发送	
		while (!(dwt_read32bitreg(SYS_STATUS_ID)) & (SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR))//不断查询芯片状态直到发送完成  
		{ };
		dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_TXFRS_BIT_MASK);               //清除标志位
		deca_sleep(10);
	}
	
}


void App_remote_cfg_rx_handler(void)
{
	if(App_remote_cfg_flag == 0)
	{
		dwt_setrxtimeout(5000);
		dwt_rxenable(DWT_START_RX_IMMEDIATE);
		App_remote_cfg_flag = 1;
	}
	
	if(App_remote_cfg_flag == 1)   //轮询接收状态
	{
		if((status_reg = dwt_read32bitreg(SYS_STATUS_ID)) & (SYS_STATUS_RXFCG_BIT_MASK | SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR)) //不断查询芯片状态直到接收成功或者出现错误		
		{
			App_remote_cfg_flag=2;
		}
		else
			return;
	}
	
	if(App_remote_cfg_flag == 2)   //判断接收成功还是接收失败
	{
		if(status_reg & SYS_STATUS_RXFCG_BIT_MASK)//成功接收
		{					
			App_remote_cfg_flag=3;
		}
		else
		{
			/* Clear RX error events in the DW1000 status register. */
			dwt_write32bitreg(SYS_STATUS_ID,SYS_STATUS_ALL_RX_TO | SYS_STATUS_ALL_RX_ERR);
			App_remote_cfg_flag=0;							
			return;
		}
	}
	
	if(App_remote_cfg_flag == 3)   //判断是否为有效数据包
	{
		dwt_write32bitreg(SYS_STATUS_ID, SYS_STATUS_RXFCG_BIT_MASK);                         //清除标志位
		frame_len = dwt_read32bitreg(RX_FINFO_ID) & FRAME_LEN_MAX;//获得接收数据长度
		dwt_readrxdata(Remote_cfg_recvbuff, frame_len, 0);//读取接收数据
		if (Remote_cfg_recvbuff[0] == 0xBB)//判断数据
		{       
			App_remote_cfg_flag = 4;			
		}							
		else
		{	
			App_remote_cfg_flag = 0;
			return;
		}			
	}
	
	if(App_remote_cfg_flag == 4)   //处理接收到的数据并串口回传
	{
		uint8_t i = 0;
		Now_recv_frame = Remote_cfg_recvbuff[1];
		for(i=0;i<6;i++)
			Recv_cfg.id[i] = Remote_cfg_recvbuff[i+2];
		Recv_cfg.static_freq = (Remote_cfg_recvbuff[8]<<8) | Remote_cfg_recvbuff[9];
		Recv_cfg.alarm_freq = (Remote_cfg_recvbuff[10]<<8) | Remote_cfg_recvbuff[11];
		Recv_cfg.moving_freq = (Remote_cfg_recvbuff[12]<<8) | Remote_cfg_recvbuff[13];
		Recv_cfg.imu_en =  Remote_cfg_recvbuff[14];
		Recv_cfg.send_packets_move = Remote_cfg_recvbuff[15];
		Recv_cfg.send_packets_static = Remote_cfg_recvbuff[16];
		Recv_cfg.imu_sensitive = Remote_cfg_recvbuff[17];
		Recv_cfg.rx_ant_delay = (Remote_cfg_recvbuff[18]<<8) | Remote_cfg_recvbuff[19];
		Recv_cfg.kind = Remote_cfg_recvbuff[20];
		Recv_cfg.version = (Remote_cfg_recvbuff[21]<<8) | Remote_cfg_recvbuff[22];
		Recv_cfg.smartpwr_en = Remote_cfg_recvbuff[23];
		Recv_cfg.power_db = Remote_cfg_recvbuff[24];
		Recv_cfg.nosleep_freq = (Remote_cfg_recvbuff[25]<<8) | Remote_cfg_recvbuff[26];
		Recv_cfg.poweroff_time = Remote_cfg_recvbuff[27];
		Recv_cfg.poweroff_en = Remote_cfg_recvbuff[28];
		Recv_cfg.pg_id = Remote_cfg_recvbuff[29];	
		Recv_cfg.heart_Rate_Min = Remote_cfg_recvbuff[30];
		
		App_remote_upload_recvdata();
		LED1_TOGGLE();
		App_remote_cfg_flag = 0;
	}
	
}


void App_remote_cfg_Handler(void)
{
	if(Cfg_state != REMOTE_CFG_RECV)
	{
		App_remote_cfg_tx_handler();
		App_remote_cfg_reset();
		Cfg_state = REMOTE_CFG_RECV;
	}
	else
	{
		App_remote_cfg_rx_handler();
	}
}


void App_remote_cfg_reset(void)
{
	dwt_forcetrxoff();
	App_remote_cfg_flag = 0;
}

