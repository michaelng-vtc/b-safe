#ifndef __modbus_H
#define __modbus_H

#include "TWR.h"

typedef enum
{
	Err_modbus_ok = 0,
	Err_modbus_id,
	Err_modbus_crc,
	Err_modbus_func,
	Err_modbus_addr,
	Err_modbus_read_mem_overflow
}Modbus_err_t;



void Modbus_Init(uint8_t addr);
Modbus_err_t Modbus_Handler(uint8_t* buf, uint16_t length, uint8_t rx_method);

void Modbus_writeRecvData(uint8_t id, uint8_t* temp, uint8_t data_len);
void MODBUS_writeRtlsData(uint16_t ID,Cal_data_t *cal_data,dwt_rxdiag_t *_rx_diag,uint32_t * ts);
void Modbus_writeTagoutput_Data(uint32_t success_flag, uint16_t *Dist, int16_t *Rtls);
void Modbus_writeRangeData(uint16_t flag, uint16_t ID,uint16_t Dist);
void Modbus_writeRemoteCfgData(uint8_t *data, uint8_t data_len);

#endif	



