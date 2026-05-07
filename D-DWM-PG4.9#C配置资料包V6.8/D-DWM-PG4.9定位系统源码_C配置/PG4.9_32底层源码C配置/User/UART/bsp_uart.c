#include "bsp_uart.h"
#include "app_uart.h"
#include "app_error.h"
#include "nrf_uart.h"
#include "port.h"
#include "bsp_timer.h"

#include "nrf_log.h"
#include "nrf_log_ctrl.h"
#include "nrf_log_default_backends.h"

#define UART1_RX_PIN 7  //7  22
#define UART1_TX_PIN 6  //6  23
#define UART3_RX_PIN 22  //7  22
#define UART3_TX_PIN 23  //6  23

Uart_Rx_Helper_t Uart_rx_helper;
extern uint16_t Timer1_uart_tick_flag;

uint8_t Tx_send_rdy = 1;

//与上位机配合使用需要限制
nrf_uart_baudrate_t Baudrate_list[10] = {NRF_UART_BAUDRATE_4800,NRF_UART_BAUDRATE_9600,NRF_UART_BAUDRATE_14400,NRF_UART_BAUDRATE_19200,NRF_UART_BAUDRATE_38400,
                                         NRF_UART_BAUDRATE_56000,NRF_UART_BAUDRATE_57600,NRF_UART_BAUDRATE_115200,NRF_UART_BAUDRATE_230400,NRF_UART_BAUDRATE_250000 };


void usart_interupt_handle(app_uart_evt_t * p_event)
{
    if (p_event->evt_type == APP_UART_COMMUNICATION_ERROR)
    {
//        APP_ERROR_HANDLER(p_event->data.error_communication);  //这里如果是引出引脚作为输入时，会在这里报错 先注释掉
    }
    else if (p_event->evt_type == APP_UART_FIFO_ERROR)
    {
        APP_ERROR_HANDLER(p_event->data.error_code);
    }
	else if(p_event->evt_type == APP_UART_DATA_READY)  //代表数据移入到fifo了
	{
		uint8_t cr;
		app_uart_get(&cr);
		Uart_rx_helper.Recv_temp_buffer[Uart_rx_helper.Recv_temp_len] = cr;
		if(Uart_rx_helper.Recv_temp_len < UART_RX_BUF_SIZE)
		{
			Uart_rx_helper.Recv_temp_len++;
		}
		Timer1_uart_tick_flag = 0;
	}
	else if(p_event->evt_type == APP_UART_TX_EMPTY)  //发送完成
	{
		Tx_send_rdy = 1;
	}
}

void Uart_check_recv(void)
{
	if(Timer1_uart_tick_flag > 2 && Uart_rx_helper.Recv_temp_len > 0)  //接收到数据且接收空闲超时了
	{
		Uart_rx_helper.Recv_fin = 1;
		Uart_rx_helper.Recv_len = Uart_rx_helper.Recv_temp_len;  //将缓存内容长度赋值到实际接收长度
		Uart_rx_helper.Recv_temp_len = 0;                        //记得缓存要清零
		memcpy(Uart_rx_helper.Recv_buffer,Uart_rx_helper.Recv_temp_buffer,Uart_rx_helper.Recv_len);  //复制缓存数组到实际接收数组中
	}
}

void Uart_Sendstring(const uint8_t* send_buff, uint16_t send_len)
{
	uint16_t i;
	while(!Tx_send_rdy){}
	for(i = 0;i < send_len; i++)
	{
		Tx_send_rdy = 0;
		app_uart_put(send_buff[i]);
	}
}

void Uart_Deinit(void)
{
	app_uart_close();
}

uint32_t Uart_Init(uint8_t baud_rate_idx, uint8_t mode)
{
	 uint32_t err_code;
	 uint32_t uart_rx_pin = 0, uart_tx_pin = 0;
	 if(baud_rate_idx > 10)
	 {
		 return NRF_ERROR_INTERNAL;
	 }
	 nrf_uart_baudrate_t baudrate = Baudrate_list[baud_rate_idx];
	 if(mode == 1)
	 {
		 uart_rx_pin = UART1_RX_PIN;
		 uart_tx_pin = UART1_TX_PIN;
	 }
	 else if(mode == 3)
	 {
		 uart_rx_pin = UART3_RX_PIN;
		 uart_tx_pin = UART3_TX_PIN;
	 }
	app_uart_comm_params_t comm_params = 
	{
		 uart_rx_pin,
		 uart_tx_pin,
		 UART_PIN_DISCONNECTED,
		 UART_PIN_DISCONNECTED,
		 APP_UART_FLOW_CONTROL_DISABLED,
		 false,
		 baudrate
	 };
	 APP_UART_FIFO_INIT(&comm_params,UART_RX_BUF_SIZE,UART_TX_BUF_SIZE,usart_interupt_handle,APP_IRQ_PRIORITY_LOWEST,err_code);  //设置的数组大小必须为2的n次方
	 
	 APP_ERROR_CHECK(err_code);
	 return NRF_SUCCESS;
}

