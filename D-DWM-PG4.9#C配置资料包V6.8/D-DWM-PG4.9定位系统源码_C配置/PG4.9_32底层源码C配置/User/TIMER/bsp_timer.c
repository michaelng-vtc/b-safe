#include "bsp_timer.h"
#include "port.h"

const nrf_drv_timer_t TIMER1_INSTANCE = NRF_DRV_TIMER_INSTANCE(1);

uint16_t Timer1_uart_tick_flag = 0;
uint16_t Timer1_led_tick_flag = 0;
uint16_t Timer1_led2_tick_flag = 0;
uint16_t Timer1_error_flag = 0;
uint16_t Timer1_tag_waitresp_flag = 0;
uint16_t Timer1_config_mode_flag = 0;
/**
 * @brief Handler for timer events.
 */
void Timer0_event_handler(nrf_timer_event_t event_type, void* p_context)
{
	static uint32_t i;
	switch (event_type)
	{
		case NRF_TIMER_EVENT_COMPARE0:  //1ms到时触发一次
		{
			if(Timer1_uart_tick_flag < 6)
			{
				Timer1_uart_tick_flag++;
			}
			if(Timer1_led_tick_flag < 5000)
			{
				Timer1_led_tick_flag++;
			}
			if(Timer1_led2_tick_flag < 5000)
			{
				Timer1_led2_tick_flag++;
			}
			if(Timer1_error_flag < 1200)
			{
				Timer1_error_flag++;
			}
			if(Timer1_tag_waitresp_flag < 10)
			{
				Timer1_tag_waitresp_flag++;
			}
			if(Timer1_config_mode_flag < 10000)
			{
				Timer1_config_mode_flag++;
			}
			Key_event();
			break;
		}          
		default:
			break;
	}
}


void Timer1_Init(void)
{
	uint32_t err_code = NRF_SUCCESS;

	uint32_t time_ticks;
	nrf_drv_timer_config_t timer_cfg = NRF_DRV_TIMER_DEFAULT_CONFIG;
	timer_cfg.bit_width = NRF_TIMER_BIT_WIDTH_32;
	timer_cfg.frequency = NRF_TIMER_FREQ_1MHz;
	timer_cfg.mode = NRF_TIMER_MODE_TIMER;

	err_code = nrf_drv_timer_init(&TIMER1_INSTANCE, &timer_cfg, Timer0_event_handler);
	APP_ERROR_CHECK(err_code);	
	time_ticks = nrf_drv_timer_ms_to_ticks(&TIMER1_INSTANCE, 1);
	nrf_drv_timer_extended_compare(&TIMER1_INSTANCE, NRF_TIMER_CC_CHANNEL0, time_ticks, NRF_TIMER_SHORT_COMPARE0_CLEAR_MASK, true);
	
	nrf_drv_timer_enable(&TIMER1_INSTANCE);
}
