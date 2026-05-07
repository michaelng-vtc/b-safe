#ifndef BSP_UART_h
#define BSP_UART_h

#include <stdint.h>

//52832目前只有一个串口


#define UART_TX_BUF_SIZE 512
#define UART_RX_BUF_SIZE 512


uint32_t Uart_Init(uint8_t baud_rate_idx, uint8_t mode);
void Uart_Deinit(void);
void Uart_check_recv(void);
void Uart_Sendstring(const uint8_t* send_buff, uint16_t send_len);

typedef struct 
{
	uint8_t Recv_fin;
	uint16_t Recv_len;
	uint16_t Recv_temp_len;
	uint8_t Recv_temp_buffer[UART_RX_BUF_SIZE];
	uint8_t Recv_buffer[UART_RX_BUF_SIZE];
}Uart_Rx_Helper_t;

#endif
