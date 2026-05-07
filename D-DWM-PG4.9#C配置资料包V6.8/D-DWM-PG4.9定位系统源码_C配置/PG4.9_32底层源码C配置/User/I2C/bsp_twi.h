#ifndef BSP_TWI_H
#define BSP_TWI_H

#include "nrf_drv_twi.h"

#define TWI_SCL_PIN 26
#define TWI_SDA_PIN 25


void TWI_Init(void);
ret_code_t TWI_Send_bytes(uint8_t address, uint8_t const *send_data,uint8_t length);

#endif
