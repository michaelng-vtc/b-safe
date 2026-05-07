#ifndef BLE_APP_H
#define BLE_APP_H

#include "ble_nus.h"

#include <stdint.h>

typedef struct
{
	uint8_t Connected;
	uint8_t Send_rdy;
	uint8_t Recv_Fin;
	uint8_t Ble_rx_buffer[BLE_NUS_MAX_DATA_LEN];
	uint16_t Ble_rx_len;
	uint8_t Send_Fin;
	uint8_t Ble_tx_buffer[BLE_NUS_MAX_DATA_LEN];
	uint16_t Ble_tx_len;	
}Ble_commu_app_t;

void Ble_app_init(void);
void Ble_uart_send_data(uint8_t* send_buff, uint16_t send_len);
void Ble_uart_tx_Handler(void);
void Ble_stack_init(void);
extern Ble_commu_app_t* const Ble_commu_helper_ptr;

#endif
