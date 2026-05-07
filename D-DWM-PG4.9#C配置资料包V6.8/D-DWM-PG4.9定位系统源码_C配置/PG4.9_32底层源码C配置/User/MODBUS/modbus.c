#include "modbus.h"
#include "common_config.h"
#include "bsp_uart.h"
#include "bsp_flash.h"
#include "ble_app.h"
#include "App_cir.h"
#include "App_remote_cfg.h"

#define MODBUS_LENGTH 135

/* 需要更改了 */
#define MODBUS_CONFIG_START_ADDR  0x0000
#define MODBUS_CONFIG_END_ADDR    MODBUS_CONFIG_START_ADDR + MODBUS_LENGTH

#define MODBUS_DATA_START_ADDR    0x0100
#define MODBUS_DATA_REGNUM        (21)
#define MODBUS_DATA_END_ADDR      MODBUS_DATA_START_ADDR + MODBUS_DATA_REGNUM * 100
uint16_t modbus_data_reg[MODBUS_DATA_REGNUM] = {0};  

uint8_t Modbus_inst_addr = 0x01;
uint8_t Recv_method = RX_DATA_UART;
uint16_t modbus_reg[MODBUS_LENGTH] = {0};


void Modbus_03_Handler(uint16_t start_addr, uint16_t reg_num);
void Modbus_10_Handler(uint8_t start_addr, uint16_t reg_num);
unsigned int CRC_Calculate(unsigned char *pdata,uint16_t num);
void MODBUS_datain(void); 
void MODBUS_dataout(void);




const unsigned char auchCRCHi[] = /* CRC锟斤拷位锟街节憋拷*/
{ 	 
	0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40,
	0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 
	0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41,
	0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 
	0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 
	0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 
	0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 
	0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 
	0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 
	0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 
	0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 
	0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 
	0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 
	0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 
	0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 
	0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40 
} ; 

const unsigned char auchCRCLo[] = /* CRC锟斤拷位锟街节憋拷*/ 
{ 
	0x00, 0xC0, 0xC1, 0x01, 0xC3, 0x03, 0x02, 0xC2, 0xC6, 0x06, 0x07, 0xC7, 0x05, 0xC5, 0xC4, 0x04, 0xCC,
	0x0C, 0x0D, 0xCD, 0x0F, 0xCF, 0xCE, 0x0E, 0x0A, 0xCA, 0xCB, 0x0B, 0xC9, 0x09, 0x08, 0xC8, 0xD8, 
	0x18, 0x19, 0xD9, 0x1B, 0xDB, 0xDA, 0x1A, 0x1E, 0xDE, 0xDF, 0x1F, 0xDD, 0x1D, 0x1C, 0xDC, 0x14, 
	0xD4, 0xD5, 0x15, 0xD7, 0x17, 0x16, 0xD6, 0xD2, 0x12, 0x13, 0xD3, 0x11, 0xD1, 0xD0, 0x10, 0xF0, 
	0x30, 0x31, 0xF1, 0x33, 0xF3, 0xF2, 0x32, 0x36, 0xF6, 0xF7, 0x37, 0xF5, 0x35, 0x34, 0xF4, 0x3C, 
	0xFC, 0xFD, 0x3D, 0xFF, 0x3F, 0x3E, 0xFE, 0xFA, 0x3A, 0x3B, 0xFB, 0x39, 0xF9, 0xF8, 0x38, 0x28, 
	0xE8, 0xE9, 0x29, 0xEB, 0x2B, 0x2A, 0xEA, 0xEE, 0x2E, 0x2F, 0xEF, 0x2D, 0xED, 0xEC, 0x2C, 0xE4, 
	0x24, 0x25, 0xE5, 0x27, 0xE7, 0xE6, 0x26, 0x22, 0xE2, 0xE3, 0x23, 0xE1, 0x21, 0x20, 0xE0, 0xA0, 
	0x60, 0x61, 0xA1, 0x63, 0xA3, 0xA2, 0x62, 0x66, 0xA6, 0xA7, 0x67, 0xA5, 0x65, 0x64, 0xA4, 0x6C, 
	0xAC, 0xAD, 0x6D, 0xAF, 0x6F, 0x6E, 0xAE, 0xAA, 0x6A, 0x6B, 0xAB, 0x69, 0xA9, 0xA8, 0x68, 0x78, 
	0xB8, 0xB9, 0x79, 0xBB, 0x7B, 0x7A, 0xBA, 0xBE, 0x7E, 0x7F, 0xBF, 0x7D, 0xBD, 0xBC, 0x7C, 0xB4, 
	0x74, 0x75, 0xB5, 0x77, 0xB7, 0xB6, 0x76, 0x72, 0xB2, 0xB3, 0x73, 0xB1, 0x71, 0x70, 0xB0, 0x50, 
	0x90, 0x91, 0x51, 0x93, 0x53, 0x52, 0x92, 0x96, 0x56, 0x57, 0x97, 0x55, 0x95, 0x94, 0x54, 0x9C, 
	0x5C, 0x5D, 0x9D, 0x5F, 0x9F, 0x9E, 0x5E, 0x5A, 0x9A, 0x9B, 0x5B, 0x99, 0x59, 0x58, 0x98, 0x88, 
	0x48, 0x49, 0x89, 0x4B, 0x8B, 0x8A, 0x4A, 0x4E, 0x8E, 0x8F, 0x4F, 0x8D, 0x4D, 0x4C, 0x8C, 0x44, 
	0x84, 0x85, 0x45, 0x87, 0x47, 0x46, 0x86, 0x82, 0x42, 0x43, 0x83, 0x41, 0x81, 0x80, 0x40
} ;	 

/******************************************************************************
												    CRC校验
*******************************************************************************/
unsigned int CRC_Calculate(unsigned char *pdata,uint16_t num)
{
  unsigned char uchCRCHi = 0xFF ;               
	unsigned char  uchCRCLo = 0xFF ;               
	unsigned char uIndex ;                
	while(num --)                    
	{
		uIndex = uchCRCHi^*pdata++ ;           
		uchCRCHi = uchCRCLo^auchCRCHi[uIndex];
		uchCRCLo = auchCRCLo[uIndex];
	}
	return (uchCRCHi << 8 | uchCRCLo) ;
}
/******************************************************************************
												    数据应答发送函数
*******************************************************************************/
void Modbus_Reply(unsigned char *buf,unsigned int length)
{
	if(Recv_method == RX_DATA_UART)
	{
		Uart_Sendstring(buf, length);
	}
	else if(Recv_method == RX_DATA_BLE)
	{
		Ble_uart_send_data(buf, length);
	}
}


void Modbus_Init(uint8_t addr)
{
	Modbus_inst_addr = addr;
	MODBUS_datain();
}



void Tag_LastData_Prepare(unsigned int addr)
{
	//根据addr地址找到是哪个标签
	uint8_t i;
	uint8_t tag_id_temp = (addr - MODBUS_DATA_START_ADDR) / 21;
	modbus_data_reg[0] = Cal_data[tag_id_temp].Cal_Flag >> 16;
	modbus_data_reg[1] = Cal_data[tag_id_temp].Cal_Flag & 0x0000FFFF;
	modbus_data_reg[2] = Cal_data[tag_id_temp].x;
	modbus_data_reg[3] = Cal_data[tag_id_temp].y;
	modbus_data_reg[4] = Cal_data[tag_id_temp].z;	
	for(i=0;i<16;i++)
	  modbus_data_reg[5 + i] = Cal_data[tag_id_temp].Dist[i];	
}


void Modbus_03_Handler(uint16_t start_addr, uint16_t reg_num)
{
	unsigned char send_length;
	unsigned char send_buf[300];
	unsigned char i;
	unsigned int crc;

	send_length = 0;
	send_buf[send_length++] = Modbus_inst_addr;
	send_buf[send_length++] = 0x03;
	send_buf[send_length++] = reg_num*2;
	if(start_addr < MODBUS_DATA_START_ADDR)
	{
		for (i = 0;i < reg_num;i++)
		{
			send_buf[send_length++] = modbus_reg[start_addr+i] >> 8;
			send_buf[send_length++] = modbus_reg[start_addr+i] & 0x00FF;
		}
	}
	else
	{
		if(reg_num > MODBUS_DATA_REGNUM)  //最多只能读取21个寄存器内容 如果需要更多 请自行修改
			reg_num = MODBUS_DATA_REGNUM;
		send_buf[2] = reg_num * 2;
		for (i = 0;i < reg_num;i++)
		{
			send_buf[send_length++] = modbus_data_reg[i] >> 8;
			send_buf[send_length++] = modbus_data_reg[i] & 0x00FF;
		}
	}
	crc = CRC_Calculate(send_buf,send_length);
	send_buf[send_length++] = crc >> 8;
	send_buf[send_length++] = crc & 0x00FF;
	Modbus_Reply(send_buf, send_length);
}


void Modbus_10_Handler(uint8_t start_addr, uint16_t reg_num)
{
	uint8_t send_buf[8];
	unsigned int crc;
	send_buf[0] = Modbus_inst_addr;
	send_buf[1] = 16;
	send_buf[2] = (start_addr / 256);
	send_buf[3] = (start_addr % 256);
	send_buf[4] = (reg_num / 256);
	send_buf[5] = (reg_num % 256);
	crc = CRC_Calculate(send_buf,6);
	send_buf[6] = crc >> 8;
	send_buf[7] = crc & 0x00FF;
	Modbus_Reply(send_buf,8);
}

void Modbus_41_write_response(uint8_t recv_flag)
{
	uint8_t send_buf[6];
	unsigned int crc;
	send_buf[0] = Modbus_inst_addr;
	send_buf[1] = 0x41;
	send_buf[2] = recv_flag;
	if(recv_flag == 0)
	{
		send_buf[3] = 0;
	}
	else
	{
		send_buf[3] = Cir_inst_ptr->upload_count;
	}
	crc = CRC_Calculate(send_buf,4);
	send_buf[4] = (crc >> 8);
	send_buf[5] = (crc & 0x00FF);
	Modbus_Reply(send_buf,6);
}

void Modbus_41_recv_handler(uint8_t *recv_data)
{
	uint8_t recv_flag = 0;
	do
	{
		uint16_t start_idx = recv_data[2] << 8 | recv_data[3];
		uint16_t read_len = recv_data[4] << 8 | recv_data[5];
		if(start_idx > CIR_READ_MAXLEN || read_len > CIR_READ_MAXLEN)
		{
			break;
		}
		if(start_idx + read_len > CIR_READ_MAXLEN)
		{
			break;
		}
		Cir_inst_ptr->cir_start_idx = start_idx;
		Cir_inst_ptr->cir_read_idx_len = read_len;
		
		recv_flag = App_cir_read_cir();
	}
	while(0);
	Modbus_41_write_response(recv_flag);
}

void Modbus_42_write_upload_response(uint8_t now_idx)
{
	uint8_t send_buf[CIR_UPLOAD_DATA_MAXLEN + 8];
	unsigned int crc;
	send_buf[0] = Modbus_inst_addr;
	send_buf[1] = 0x42;
	send_buf[2] = 0xA0;
	send_buf[3] = now_idx;
	send_buf[4] = Cir_inst_ptr->cache.data_len >> 8;
	send_buf[5] = Cir_inst_ptr->cache.data_len & 0x00FF;
	memcpy(&send_buf[6], Cir_inst_ptr->cache.data_ptr, Cir_inst_ptr->cache.data_len);

	crc = CRC_Calculate(send_buf,Cir_inst_ptr->cache.data_len + 6);
	send_buf[Cir_inst_ptr->cache.data_len + 6] = (crc >> 8);
	send_buf[Cir_inst_ptr->cache.data_len + 7] = (crc & 0x00FF);
	Modbus_Reply(send_buf,Cir_inst_ptr->cache.data_len + 8);
}

void Modbus_42_upload_handler(uint8_t upload_idx)
{
	if(App_cir_get_cache(upload_idx))
	{
		Modbus_42_write_upload_response(upload_idx);
	}
}

void Modbus_43_write_response(uint8_t recv_flag)
{
	uint8_t send_buf[6];
	unsigned int crc;
	send_buf[0] = Modbus_inst_addr;
	send_buf[1] = 0x43;
	send_buf[2] = recv_flag;
	if(recv_flag == 0)
	{
		send_buf[3] = 0;
	}
	else
	{
		send_buf[3] = 1;
	}
	crc = CRC_Calculate(send_buf,4);
	send_buf[4] = (crc >> 8);
	send_buf[5] = (crc & 0x00FF);
	Modbus_Reply(send_buf,6);
}

void Modbus_43_recv_handler(uint8_t *recv_data)
{
	uint8_t recv_flag = 0;
	uint8_t i = 0;
	Remote_tag_cfg_t* cfg = App_remote_get_cfg();
	App_remote_cfg_change_state(recv_data[3]);
	for(i=0;i<6;i++)			
	{
		cfg->id[i] = recv_data[4 + i];
	}	
	cfg->static_freq = recv_data[10] << 8 | recv_data[11];
	cfg->alarm_freq = recv_data[12] << 8 | recv_data[13];
	cfg->moving_freq = recv_data[14] << 8 | recv_data[15];
	cfg->imu_en = recv_data[16];
	cfg->imu_sensitive = recv_data[17];		 
	cfg->send_packets_move = recv_data[18];
	cfg->send_packets_static = recv_data[19];
	cfg->rx_ant_delay = recv_data[20] << 8 | recv_data[21]; 
	cfg->smartpwr_en = recv_data[22];
	cfg->power_db = recv_data[23];
	cfg->nosleep_freq = recv_data[24] << 8 | recv_data[25];
	cfg->poweroff_time = recv_data[26];
	cfg->pg_id = recv_data[27]; 
	cfg->poweroff_en = recv_data[28];
	cfg->heart_Rate_Min = recv_data[29];
	memcpy(cfg->SYNC_Time_Buff,&recv_data[30],sizeof(cfg->SYNC_Time_Buff));
 	Modbus_43_write_response(1);
}

/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 判断数据是否符合Modbus协议解析
 *
 * input parameters
 * @param
 * @param
 * output parameters
 * 
 */
Modbus_err_t Modbus_Handler(uint8_t* buf, uint16_t length, uint8_t rx_method)
{
	unsigned int crc;
	uint8_t need_write2flash = 0;
	if(length <= 2)
	{
		return Err_modbus_read_mem_overflow;
	}
	crc = CRC_Calculate(buf,length-2);
	Recv_method = rx_method;
	//判断mobusID和crc校验是否正确
	if(buf[0] != Modbus_inst_addr)
	{
		 return Err_modbus_id;
	}
	if(buf[length-2] != (crc >> 8) || buf[length-1] != (crc & 0x00FF))  
	{
	   return Err_modbus_crc;
	}
	
	MODBUS_datain();  //将实际数据导入到寄存器表中			
	switch(buf[1])
	{
		case 0x03:
		{
			uint16_t startaddr, reg_num;		
			startaddr = buf[2] << 8 | buf[3];
			reg_num = buf[4] << 8 | buf[5];
			if(!(startaddr >= MODBUS_CONFIG_START_ADDR && startaddr < MODBUS_CONFIG_END_ADDR) &&
				 !(startaddr >= MODBUS_DATA_START_ADDR && startaddr < MODBUS_DATA_END_ADDR))
			{
				return Err_modbus_addr;
			}			
			
			if(startaddr >= MODBUS_CONFIG_START_ADDR && startaddr < MODBUS_CONFIG_END_ADDR)
			{
				if (startaddr + reg_num > MODBUS_LENGTH)
				{
					return Err_modbus_read_mem_overflow;
				}
			
			}
			else
			{
				//读取了0x0100到0x05B0地址 认为是读取标签上一次的定位数据
				Tag_LastData_Prepare(startaddr);
			}
			Modbus_03_Handler(startaddr, reg_num); 	
			break;
		}
		case 0x06:  //写一个数据
		{
			uint16_t startaddr, reg_value;
			
			startaddr = buf[2] << 8 | buf[3];
			reg_value = buf[4] << 8 | buf[5];
			if(startaddr < MODBUS_CONFIG_START_ADDR || startaddr >= MODBUS_CONFIG_END_ADDR)
			{
				return Err_modbus_addr;
			}
			modbus_reg[startaddr] = reg_value;
			//返回指令 返回相同即可
			Modbus_Reply(buf, length);
			need_write2flash = 1;  //需要对应flash更改
			break;
		}
		case 0x10:  //写入多个数据
		{
			uint16_t startaddr, reg_num, i;		
			startaddr = buf[2] << 8 | buf[3];
			reg_num = buf[4] << 8 | buf[5];
			if(startaddr < MODBUS_CONFIG_START_ADDR || startaddr >= MODBUS_CONFIG_END_ADDR)
			{
				return Err_modbus_addr;
			}		
			//赋值到寄存器表
			for(i=0;i<reg_num;i++)
			{
				modbus_reg[startaddr + i] = buf[7 + i*2] << 8 | buf[8 + i*2];
			}
			//返回指令
			Modbus_10_Handler(startaddr,reg_num);
			need_write2flash = 1;  //需要对应flash更改
			break;
		}
		case 0x41:  //自定义功能码：指令进行cir读取
		{
			Modbus_41_recv_handler(buf);
			break;
		}
		case 0x42:  //自定义功能码：指令上传cir数据
		{
			//再根据func区分
			if(buf[2] == 0xA0)  //指令上传对应数据包数据
			{
				Modbus_42_upload_handler(buf[3]);
			}
			else if(buf[2] == 0xA1)  //指令结束本次cir上传记录
			{
				App_cir_clear();
				Modbus_Reply(buf,5);  //直接回传数据
			}
			break;
		}
		case 0x43:  //自定义功能码：远程配置标签
		{
			Modbus_43_recv_handler(buf);
			break;
		}
		default:break;
	}
	MODBUS_dataout();
	if(need_write2flash == 1) 
	{
//		FLASH_write();
		Flash_write_config();
	}
	return Err_modbus_ok;
}


/******************************************************************************
												    数据导入MODBUS寄存器表
*******************************************************************************/
void MODBUS_datain(void) 
{
	uint16_t o,q;

	modbus_reg[0]=Device_cfg_ptr->Flash_Usart_BaudRate;
	modbus_reg[1]=Device_cfg_ptr->Flash_Modbus_ADDR;
	modbus_reg[2]=(Device_cfg_ptr->Flash_Ranging_Mode<<8&0xFF00)|Device_cfg_ptr->Flash_structure_Mode;
	modbus_reg[3]=Device_cfg_ptr->Flash_Device_Mode;
	modbus_reg[4]=Device_cfg_ptr->Flash_Device_ID;
	modbus_reg[5]=(Device_cfg_ptr->Uwb_config.UWB_Channel<<8&0xFF00)|Device_cfg_ptr->Uwb_config.UWB_Data_rat;//空中信道  空中传输速率
	modbus_reg[6]=Device_cfg_ptr->FLASH_KALMAN_Q;       	    //卡尔曼滤波-Q
	modbus_reg[7]=Device_cfg_ptr->FLASH_KALMAN_R;       	    //卡尔曼滤波-R
	modbus_reg[8]=Device_cfg_ptr->Uwb_config.UWB_ANT_DLY;    //接收延时
	modbus_reg[9] = 0;
	
	for(q = 0;q < ANCHOR_LIST_COUNT; q++)  //输入基站位置坐标
	{
		Anchor_t *a = &(Device_cfg_ptr->Anchor_List[q]);
		if(q == 0)
		{
			Device_cfg_ptr->Calculate_Anc_en = 1;
		}
		else
		{
			if(a->en == 1)
			{
				Device_cfg_ptr->Calculate_Anc_en |= 0x01 << q;
			}			
				
		}
		modbus_reg[11 + q * 3] = a -> x;
		modbus_reg[12 + q * 3] = a -> y;
		modbus_reg[13 + q * 3] = a -> z;
	}
	modbus_reg[10] = Device_cfg_ptr->Calculate_Anc_en;
	
	modbus_reg[59]= Device_cfg_ptr->Device_range_work_mode ;
	modbus_reg[60] = (Device_cfg_ptr->FLASH_CAL_xyz_En<<8&0xFF00)|Device_cfg_ptr->Flash_TAG_NUM ;

	for(o=0;o<50;o++)
	{
		modbus_reg[61+o]=((Device_cfg_ptr->Flash_TAG_BUF[2*o+1]<<8)&0xFF00)|Device_cfg_ptr->Flash_TAG_BUF[2*o];
	}
	
	modbus_reg[111]=((firmware_version << 8) & 0xFF00) | Device_cfg_ptr->Uwb_config.UWB_chip_id << 6 | firmware_structure << 4 | (MODULE_USE & 0x0F); 					
	modbus_reg[112] = Device_cfg_ptr->Tag_output_cfg.output_en << 8 | Device_cfg_ptr->Tag_output_cfg.output_format;
	modbus_reg[113] = Device_cfg_ptr->Tag_output_cfg.ouput_protocal;
	modbus_reg[114] = Device_cfg_ptr->Anchor_OutputProtocal;
	modbus_reg[115] = (Device_cfg_ptr->Anc_range_cfg.range_en<<8&0xFF00)|Device_cfg_ptr->Anc_range_cfg.range_max_num;
	modbus_reg[116] = Device_cfg_ptr->Anc_range_cfg.range_id;
	modbus_reg[117] = ((Device_cfg_ptr->Uwb_config.UWB_Is_Use_Trim << 8) & 0xFF00) | Device_cfg_ptr->Uwb_config.UWB_Trim_Value;
	
}
/******************************************************************************
												   从MODBUS寄存器表导出到输出
*******************************************************************************/
void MODBUS_dataout(void) 
{
	uint16_t q;
	//读写的数据才需要！只读的不用赋予！
	if(modbus_reg[0]<=9) 			
		Device_cfg_ptr->Flash_Usart_BaudRate=modbus_reg[0];
	if(modbus_reg[1]<=255) 
		Device_cfg_ptr->Flash_Modbus_ADDR=modbus_reg[1];
	if(((modbus_reg[2]>>8)&0xFF)<=1) 
		Device_cfg_ptr->Flash_Ranging_Mode=(modbus_reg[2]>>8)&0xFF; //测距方式
	if((modbus_reg[2]&0xFF)<=2) 
		Device_cfg_ptr->Flash_structure_Mode=modbus_reg[2]&0xFF;
	if(modbus_reg[3]<=3) 
		Device_cfg_ptr->Flash_Device_Mode=modbus_reg[3];
	if((((modbus_reg[4]>>8)&0xFF)<=14)&&((modbus_reg[4]&0xFF)<=100)) 
		Device_cfg_ptr->Flash_Device_ID=modbus_reg[4];
	if(((modbus_reg[5]>>8)&0xFF)<=5) 
		Device_cfg_ptr->Uwb_config.UWB_Channel=(modbus_reg[5]>>8)&0xFF;          //空中信道 
	if((modbus_reg[5]&0xFF)<=5) 
		Device_cfg_ptr->Uwb_config.UWB_Data_rat = modbus_reg[5]&0xFF;                   //空中传输速率

	Device_cfg_ptr->FLASH_KALMAN_Q=modbus_reg[6];       	    //卡尔曼滤波-Q
	Device_cfg_ptr->FLASH_KALMAN_R=modbus_reg[7];       	    //卡尔曼滤波-R
	Device_cfg_ptr->Uwb_config.UWB_ANT_DLY=modbus_reg[8];           //接收延时
		
	Device_cfg_ptr->Calculate_Anc_en=modbus_reg[10];
	
	for(q = 0; q < ANCHOR_LIST_COUNT; q++)
	{
		Anchor_t *a = &(Device_cfg_ptr->Anchor_List[q]);
		if(q == 0)
		{
			a -> en = 1;   //主基站默认使能
		}
		else
		{
			if(((Device_cfg_ptr->Calculate_Anc_en >> q) & 0x01))						
			  a -> en = 1;
			else
				a -> en = 0;									
		}		

		a -> x = modbus_reg[q * 3 + 11];			 
		a -> y = modbus_reg[q * 3 + 12];
		a -> z = modbus_reg[q * 3 + 13];				
			
	}
		
	if( modbus_reg[59] <= 10) 
	{
		if(modbus_reg[59] >= 5 && modbus_reg[59] <= 9 && Device_cfg_ptr->Device_range_work_mode <= 4)  //先记录之前的 用作还原
			Device_cfg_ptr->Device_last_range_work_mode = Device_cfg_ptr->Device_range_work_mode;
		Device_cfg_ptr->Device_range_work_mode = modbus_reg[59];
		if(Device_cfg_ptr->Device_range_work_mode == Workmode_idle)
		{
			App_remote_cfg_reset();
		}
	}
	
	if(((modbus_reg[60]>>8)&0xFF) <= 1)
		Device_cfg_ptr->FLASH_CAL_xyz_En = (modbus_reg[60]>>8) & 0xFF;
	

	if((modbus_reg[60] & 0xFF) > 0 && (modbus_reg[60] & 0xFF) <= 100)
		Device_cfg_ptr->Flash_TAG_NUM = modbus_reg[60] & 0x00FF;
	
	for(q=0;q<50;q++)
	{
		if(((modbus_reg[61+q]>>8)&0xFF)<=99) 
		{
			Device_cfg_ptr->Flash_TAG_BUF[2*q+1]=(modbus_reg[61+q]>>8)&0xFF;
		
		}
		if((modbus_reg[61+q]&0xFF)<=99) 
		{
			Device_cfg_ptr->Flash_TAG_BUF[2*q]=modbus_reg[61+q]&0xFF;
		}
	}
	Device_cfg_ptr->Tag_output_cfg.output_en = modbus_reg[112] >> 8;
	Device_cfg_ptr->Tag_output_cfg.output_format = modbus_reg[112] & 0x00FF;
	Device_cfg_ptr->Tag_output_cfg.ouput_protocal = modbus_reg[113];
	Device_cfg_ptr->Anchor_OutputProtocal = modbus_reg[114];
	
	if(((modbus_reg[115]>>8) & 0xFF) <= 1) 
		Device_cfg_ptr->Anc_range_cfg.range_en = (modbus_reg[115]>>8) & 0xFF;	//测距使能	
	if((modbus_reg[115] & 0xFF) <= 255)	
		Device_cfg_ptr->Anc_range_cfg.range_max_num = modbus_reg[115] & 0xFF;	//测距次数
	Device_cfg_ptr->Anc_range_cfg.range_id = modbus_reg[116];		//需要测距的ID 高八位：发起测距者ID 低八位：测距对象ID					
	Device_cfg_ptr->Uwb_config.UWB_Is_Use_Trim = modbus_reg[117] >> 8;
	Device_cfg_ptr->Uwb_config.UWB_Trim_Value = modbus_reg[117] & 0x00FF;
	Device_cfg_ptr->RF_test_En = modbus_reg[118] >> 8;
	Device_cfg_ptr->RF_test_mode = modbus_reg[118] & 0x00FF;
}


/**
 * @brief 主基站输出测距及定位信息
 * @param ID 标签ID 
 * @param cal_data 存放定位数据
 * @param _rx_diag 接收强度信息
 */
void MODBUS_writeRtlsData(uint16_t ID,Cal_data_t *cal_data,dwt_rxdiag_t *_rx_diag,uint32_t * ts)
{
    //01 03 number 00 00 01 01 02 02 CRCH CRCL
	unsigned char send_length;
	unsigned char send_buf[86 + 5];
	unsigned int crc;
	unsigned int i;
	uint8_t anc_output_protocal = Get_Device_config()->Anchor_OutputProtocal;
	send_length = 0;
	send_buf[send_length++] = Modbus_inst_addr;
	send_buf[send_length++] = 0x03;
	send_buf[send_length++] = 0;     //长度最后再写入

	send_buf[send_length++] = 0xCA;
	send_buf[send_length++] = 0xDA;  //代表定位数据包

	send_buf[send_length++] = 0;
	send_buf[send_length++] = anc_output_protocal;

	send_buf[send_length++] = ID >> 8;
	send_buf[send_length++] = ID & 0x00FF;

	send_buf[send_length++] = cal_data->Cal_Flag >> 24;
	send_buf[send_length++] = cal_data->Cal_Flag >> 16;
	send_buf[send_length++] = cal_data->Cal_Flag >>  8;
	send_buf[send_length++] = cal_data->Cal_Flag & 0x000000FF;

	if(anc_output_protocal & ANC_OUTPUT_RTLS)
	{
		send_buf[send_length++] = cal_data->x >> 8;
		send_buf[send_length++] = cal_data->x & 0x00FF;
	 
		send_buf[send_length++] = cal_data->y >> 8;
		send_buf[send_length++] = cal_data->y & 0x00FF;
		
		send_buf[send_length++] = cal_data->z >> 8;
		send_buf[send_length++] = cal_data->z & 0x00FF;
	}

	if(anc_output_protocal & ANC_OUTPUT_DIST)
	{
		for(i=0;i<ANCHOR_LIST_COUNT;i++)
		{
			send_buf[send_length++] = cal_data->Dist[i] >> 8;
			send_buf[send_length++] = cal_data->Dist[i] & 0x00FF;
		}
	}
	
	if(anc_output_protocal & ANC_OUTPUT_RXDIAG)
	{
	     /* DW3000部分接收信息不提供 这里不提供的信息恒为0 
		   目前没有启用STS 读取的信息都是基于ipatov部分的*/
		 send_buf[send_length++] = 0;  //maxNoise
		 send_buf[send_length++] = _rx_diag->dgcdecision;  //maxNoise
		 send_buf[send_length++] = 0;	//stdNoise
		 send_buf[send_length++] = 0;	//stdNoise
		 send_buf[send_length++] = _rx_diag->ipatovF1 >> 8;
		 send_buf[send_length++] = _rx_diag->ipatovF1 & 0x00FF; 
		 send_buf[send_length++] = _rx_diag->ipatovF2 >> 8;
		 send_buf[send_length++] = _rx_diag->ipatovF2 & 0x00FF; 
		 send_buf[send_length++] = _rx_diag->ipatovF3 >> 8;
		 send_buf[send_length++] = _rx_diag->ipatovF3 & 0x00FF;
		 send_buf[send_length++] = _rx_diag->ipatovPower >> 8;      //maxGrowthCIR
		 send_buf[send_length++] = _rx_diag->ipatovPower & 0x00FF;  //maxGrowthCIR
		 send_buf[send_length++] = _rx_diag->ipatovAccumCount >> 8;      //rxPreamCount
		 send_buf[send_length++] = _rx_diag->ipatovAccumCount & 0x00FF;	 //rxPreamCount
		 send_buf[send_length++] = _rx_diag->ipatovFpIndex >> 8;
		 send_buf[send_length++] = _rx_diag->ipatovFpIndex & 0x00FF;	
	}
	
	if(anc_output_protocal & ANC_OUTPUT_TS)
	{
		uint32_t now_time = 0;
		for(i=0;i<6;i++)
		{
			now_time = ts[i];
			send_buf[send_length++] = now_time >> 24;
			send_buf[send_length++] = now_time >> 16;
			send_buf[send_length++] = now_time >> 8;
			send_buf[send_length++] = now_time & 0x000000FF;			
		}
	}

	send_buf[2] = send_length - 3;  //写入长度
	
	crc = CRC_Calculate(send_buf,send_length);
	send_buf[send_length++] = crc >> 8;
	send_buf[send_length++] = crc & 0x00FF;

	Modbus_Reply(send_buf,send_length);
}


/**
 * @brief 输出接收到数据透传的信息 协议是仿Modbus
 * @param id 发送方的id 
 * @param temp 数据透传信息数组
 */
void Modbus_writeRecvData(uint8_t id, uint8_t* temp, uint8_t data_len)
{
	unsigned char send_length;
	unsigned char send_buf[UWB_COMMU_DATA_MAXLEN + 4 + 5];
	unsigned int crc;
	unsigned int i;
	send_length = 0;
	send_buf[send_length++] = 0x01;
	send_buf[send_length++] = 0x03;
	send_buf[send_length++] = data_len + 4;

	send_buf[send_length++] = 0xED;
	send_buf[send_length++] = 0xDA;  //代表数据透传包

	send_buf[send_length++] = 0x00;
	send_buf[send_length++] = id;

	for(i=0;i<data_len;i++)
		send_buf[send_length++] = temp[i];

	crc = CRC_Calculate(send_buf,send_length);
	send_buf[send_length++] = crc >> 8;
	send_buf[send_length++] = crc & 0x00FF;
	Modbus_Reply(send_buf,send_length);
}

/**
 * @brief 标签输出从主基站接收到的上一次定位和测距信息 协议是仿Modbus
 * @param Dist 测距值数组 
 * @param Rtls 定位xyz数组
 */
void Modbus_writeTagoutput_Data(uint32_t success_flag, uint16_t *Dist, int16_t *Rtls)
{
	unsigned char send_length;
	unsigned char send_buf[51];
	unsigned int crc;
	unsigned int i;
	uint8_t tag_output_format = Get_Device_config()->Tag_output_cfg.output_format;
	send_length = 0;
	send_buf[send_length++] = 0x01;
	send_buf[send_length++] = 0x03;
	send_buf[send_length++] = 0;   //先不写长度 等最后再写入
	
	send_buf[send_length++] = 0xAC;
	send_buf[send_length++] = 0xDA;  //代表标签数据包

	send_buf[send_length++] = 0x00;
	send_buf[send_length++] = tag_output_format;
	
	if(tag_output_format & TAG_OUTPUT_DIST)  //输出测距值
	{
		send_buf[send_length++] = success_flag >> 8;
		send_buf[send_length++] = success_flag & 0x00FF;
		for(i=0;i<ANCHOR_LIST_COUNT;i++)
		{
			send_buf[send_length++] = Dist[i] >> 8;
			send_buf[send_length++] = Dist[i] & 0x00FF;
		}
	}
	
	if(tag_output_format & TAG_OUTPUT_RTLS)  //输出定位值
	{
		send_buf[send_length++] = 0;
		send_buf[send_length++] = success_flag >> 16 & 0x01;
		for(i=0;i<3;i++)
		{
			send_buf[send_length++] = Rtls[i] >> 8;
			send_buf[send_length++] = Rtls[i] & 0x00FF;
		}	
	}
	
	send_buf[2] = send_length - 3;

	crc = CRC_Calculate(send_buf,send_length);
	send_buf[send_length++] = crc >> 8;
	send_buf[send_length++] = crc & 0x00FF;
//	Modbus_Reply(send_buf,send_length);
	Uart_Sendstring(send_buf, send_length);
	Ble_uart_send_data(send_buf, send_length);
}

/**
 * @brief 自动标定距离输出
 * @param id 发送方的id 
 * @param temp 数据透传信息数组
 */
void Modbus_writeRangeData(uint16_t flag, uint16_t ID,uint16_t Dist)
{
	unsigned char send_length;
	unsigned char send_buf[13];
	unsigned int crc;
	
	send_length = 0;
	send_buf[send_length++] = 0x01;
	send_buf[send_length++] = 0x03;
	send_buf[send_length++] = 0;   //先不写长度 等最后再写入
	send_buf[send_length++] = 0xDA;
	send_buf[send_length++] = 0xDA;  //代表标签数据包
	send_buf[send_length++] = flag >> 8;
	send_buf[send_length++] = flag & 0x00FF;  //测距标志位
	send_buf[send_length++] = ID >> 8;
	send_buf[send_length++] = ID & 0x00FF;  //测距ID
	send_buf[send_length++] = Dist >> 8;
	send_buf[send_length++] = Dist & 0x00FF;  //测距距离
	
	send_buf[2] = send_length - 3;
	crc = CRC_Calculate(send_buf,send_length);
	send_buf[send_length++] = crc/256;
	send_buf[send_length++] = crc%256;
	Modbus_Reply(send_buf,send_length);
}

/**
 * @brief 远程配置上报
 * @param data 上报的数据内容
 * @param data_len 上报的数据长度
 */
void Modbus_writeRemoteCfgData(uint8_t *data, uint8_t data_len)
{
	unsigned char send_length;
	unsigned char send_buf[37];
	unsigned int crc;
	uint8_t i = 0;
	
	send_length = 0;
	send_buf[send_length++] = 0x01;
	send_buf[send_length++] = 0x03;
	send_buf[send_length++] = 0;   //先不写长度 等最后再写入
	send_buf[send_length++] = 0x6D;
	send_buf[send_length++] = 0xDA;  //代表远程配置数据包
	
	for(i=0;i<data_len;i++)
		send_buf[send_length++] = data[i];
	
	send_buf[2] = send_length - 3;
	crc = CRC_Calculate(send_buf,send_length);
	send_buf[send_length++] = crc >> 8;
	send_buf[send_length++] = crc & 0x00FF;
	Modbus_Reply(send_buf,send_length);
}

