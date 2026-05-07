#include "port.h"
#include "sdk_common.h"
#include "bsp_uart.h"
#include "bsp_spi.h"
#include "oled.h"
#include "bsp_timer.h"
#include "modbus.h"
#include "common_config.h"
#include "bsp_flash.h"
#include "app_timer.h"
#include "nrf_delay.h"
//#include "dw3000.h"

Key_helper_t Key_inst_list[KEY_TOTAL_NUM] = {0};

#define KEY_GOTO_CONFIGMODE_TIME_MS   1500
#define KEY_GETOUT_CONFIGMODE_TIME_MS 7000
#define KEY_UART 0
#define KEY_SET   1
#define KEY_MODE  2


LED_Mode_t LED2_mode;
uint16_t LED2_tick_max = 0;
#define LED2_MODE_BLE_ERROR_TICK_MS   0
#define LED2_MODE_ADV_TICK_MS         250
#define LED2_MODE_CONNECT_TICK_MS     1000

extern uint16_t Timer1_config_mode_flag;
extern uint16_t Timer1_led2_tick_flag;

//uint8_t flag = 0;

void LED_Init(void)
{
	//配置两个LED为输出模式
	nrf_gpio_cfg_output(LED1_PIN);
	nrf_gpio_cfg_output(LED2_PIN);
	LED1_ON();
	LED2_OFF();
}

void LED2_Event(void)
{
	if(Timer1_led2_tick_flag > LED2_tick_max)
	{
		LED2_TOGGLE();
		Timer1_led2_tick_flag = 0;
//		DW3000_GPIO7_control(flag);
//		flag = !flag;
	}
}

void LED2_Change_mode(LED_Mode_t new_mode)
{
	LED2_mode = new_mode;
	switch(LED2_mode)
	{
		case LED_MODE_BLE_ERROR:
		{
			LED2_tick_max = LED2_MODE_BLE_ERROR_TICK_MS;
			LED2_OFF();			
			break;
		}
		case LED_MODE_ADV:
		{
			LED2_tick_max = LED2_MODE_ADV_TICK_MS;
			break;
		}
		case LED_MODE_CONNECTED:
		{
			LED2_tick_max = LED2_MODE_CONNECT_TICK_MS;
			break;
		}
		default:break;
	}
	Timer1_led2_tick_flag = 0;
}


//GPIOTE event触发 按键按下后操作
static void gpiote_event_handler(nrf_drv_gpiote_pin_t pin, nrf_gpiote_polarity_t action)
{
	uint8_t i;
	if(action == GPIOTE_CONFIG_POLARITY_Toggle)
	{
		bool is_set = !nrf_drv_gpiote_in_is_set(pin);
		for(i=0;i<KEY_TOTAL_NUM;i++)
		{
			if(pin == Key_inst_list[i].Key_pin)
			{
				Key_helper_t *key_now = &Key_inst_list[i];				
				if(is_set)  //从没按下到按下
				{
					key_now->Press_count = 0;
					key_now->Status = Key_preview_press;
//					NRF_LOG_INFO("press! pin %d", key_now->Key_pin);
//					NRF_LOG_PROCESS();
				}
				else  //从按下到松开
				{
					if(key_now->Press_count < KEY_REALPRESS_THRESH)
					{
//						NRF_LOG_INFO("Not good press! pin %d count:%d state:%d",key_now->Key_pin, key_now->Press_count, key_now->Status);
						key_now->Status = Key_release;
						
					}
					else if(key_now->Press_count < KEY_LONGPRESS_THRESH)
					{
//						NRF_LOG_INFO("click! pin %d count:%d state:%d",key_now->Key_pin, key_now->Press_count, key_now->Status);
						key_now->Status = Key_Click;
						
					}
					else
					{
//						NRF_LOG_INFO("long press release! pin %d count:%d state:%d",key_now->Key_pin, key_now->Press_count, key_now->Status);
						key_now->Status = Key_release;
						
					}
					key_now->Press_count = 0;				
				}	
				break;				
			}			
		}
	}
}

void Key_event(void)
{
	uint8_t i;
	for(i=0;i<KEY_TOTAL_NUM;i++)
	{
		if(Key_inst_list[i].Status == Key_preview_press)
		{
			if(Key_inst_list[i].Press_count < KEY_LONGPRESS_THRESH)
			{
				Key_inst_list[i].Press_count++;				
			}		
			else
			{
				Key_inst_list[i].Status = Key_long_press;
//				NRF_LOG_INFO(" pin %d long press!", Key_inst_list[i].Key_pin);
//				NRF_LOG_PROCESS();
			}						
		}
	}
}
	
//按键目前 硬件连接pcb有误 由上到下是123
void Key_Check_Handler(void)
{

	if(System_config_mode == 0)  //未进入配置模式
	{
		//需要两个按键长按7-8秒后才认为进入配置模式
		if(Key_inst_list[KEY_SET].Status == Key_long_press && Key_inst_list[KEY_MODE].Status == Key_long_press)
		{
//			NRF_LOG_INFO("check key mode");
			if(Timer1_config_mode_flag > KEY_GOTO_CONFIGMODE_TIME_MS)
			{
				NRF_LOG_INFO("go to config mode");
				System_config_mode = 1;	
				Timer1_config_mode_flag = 0;				
			}
		}
		else
		{
			Timer1_config_mode_flag = 0;
		}
	}
	else //进入配置模式
	{
		bool Has_action = false;
		
		if(Key_inst_list[KEY_SET].Status == Key_long_press && Key_inst_list[KEY_MODE].Status == Key_long_press)
		{
			//无意义
			Timer1_config_mode_flag = 0;
			return;
		}
			
		if(Key_inst_list[KEY_SET].Status == Key_Click)  //按下set键
		{
			switch(Device_cfg_ptr->Flash_Device_Mode)
			{
				case DEVICE_MODE_TAG:
				{
					uint8_t id = Device_cfg_ptr->Flash_Device_ID & 0x00FF;
					id+=1;
					if(id > 99)
					{
						id = 0;
					}
					Device_cfg_ptr->Flash_Device_ID &= 0xFF00;
					Device_cfg_ptr->Flash_Device_ID |= id;
					break;
				}
				case DEVICE_MODE_SUBANC:
				{
					uint8_t id = (Device_cfg_ptr->Flash_Device_ID >> 8)& 0x00FF;
					id+=1;
					if(id > ANCHOR_LIST_COUNT - 2)
					{
						id = 0;
					}
					Device_cfg_ptr->Flash_Device_ID &= 0x00FF;
					Device_cfg_ptr->Flash_Device_ID |= (id << 8);
					break;
				}
				default:break;
			}
			Key_inst_list[KEY_SET].Status = Key_release;
			Has_action = true;			
		}
		else if(Key_inst_list[KEY_SET].Status == Key_long_press)  //长按Set键
		{
			switch(Device_cfg_ptr->Flash_Device_Mode)
			{
				case DEVICE_MODE_TAG:
				{					
					Device_cfg_ptr->Flash_Device_ID &= 0xFF00;
					break;
				}
				case DEVICE_MODE_SUBANC:
				{
					Device_cfg_ptr->Flash_Device_ID &= 0x00FF;
					break;
				}
				default:break;
			}		
			Has_action = true;
		}		
		
		
		if(Key_inst_list[KEY_MODE].Status == Key_Click)  //按下mode键
		{
			Device_cfg_ptr->Flash_Device_Mode++;
			if(Device_cfg_ptr->Flash_Device_Mode > DEVICE_MODE_MAINANC)
			{
			 Device_cfg_ptr->Flash_Device_Mode = DEVICE_MODE_TAG;
			}			
			Key_inst_list[KEY_MODE].Status = Key_release;			 
			Has_action = true;
		}
		else if(Key_inst_list[KEY_MODE].Status == Key_long_press)  //长按mode键
		{
			//无意义
			Has_action = true;
		}
		
		if(Key_inst_list[KEY_UART].Status == Key_Click)  //按下uart键
		{
			Has_action = true;
			Device_cfg_ptr->Nrf_uart_mode = Device_cfg_ptr->Nrf_uart_mode == 1 ? 3 : 1;
			Key_inst_list[KEY_UART].Status = Key_release;
		}
		else if(Key_inst_list[KEY_UART].Status == Key_long_press)  //长按mode键
		{
			//无意义
			Has_action = true;
		}
		
		if(Has_action)
		{
			Timer1_config_mode_flag = 0;
			OLED_Clear(); 
			OLED_display();
		}
		
		//如果8s没有按下任何按键 退出配置模式
		if(Timer1_config_mode_flag > KEY_GETOUT_CONFIGMODE_TIME_MS)
		{
			System_config_mode = 0;
			//保存到flash
			Flash_write_config();
			nrf_delay_ms(50);     //立刻重启会保存失败
			//重启
			NVIC_SystemReset(); 
		}
	}
	
	
}


/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 不用app_button的初始化
 *
 * input parameters
 * @param
 * @param
 * output parameters
 * 
 */
uint32_t KEY_Init(void)
{
	uint32_t err_code;
	
	Key_inst_list[0].Key_pin = KEY1_PIN;
	Key_inst_list[1].Key_pin = KEY2_PIN;
	Key_inst_list[2].Key_pin = KEY3_PIN;
	
	if (!nrf_drv_gpiote_is_init())
	{
		err_code = nrf_drv_gpiote_init();  //初始化内部gpiote处理器
		VERIFY_SUCCESS(err_code);
	}
	
	
	nrf_drv_gpiote_in_config_t config = NRFX_GPIOTE_CONFIG_IN_SENSE_TOGGLE(true);  //设置输入触发为高转低电平
	config.pull = NRF_GPIO_PIN_PULLUP; //设置内部上拉
	err_code = nrf_drv_gpiote_in_init(KEY1_PIN, &config, gpiote_event_handler); //传入事件触发回调函数
	VERIFY_SUCCESS(err_code);
	err_code = nrf_drv_gpiote_in_init(KEY2_PIN, &config, gpiote_event_handler);  //传入事件触发回调函数
	VERIFY_SUCCESS(err_code);
	err_code = nrf_drv_gpiote_in_init(KEY3_PIN, &config, gpiote_event_handler);  //传入事件触发回调函数
	VERIFY_SUCCESS(err_code);
	nrf_drv_gpiote_in_event_enable(KEY1_PIN, true);  //使能事件
	nrf_drv_gpiote_in_event_enable(KEY2_PIN, true);
	nrf_drv_gpiote_in_event_enable(KEY3_PIN, true);
	return NRF_SUCCESS;
}

void peripherals_init (void)
{
	Device_config_t* cfg_ptr;
	LED_Init();
	KEY_Init();
	SPI_Init();
	//flash读取后再初始化modbus
	Flash_fds_Init();
	cfg_ptr = Get_Device_config();
	Modbus_Init(cfg_ptr->Flash_Modbus_ADDR);
	Uart_Init(cfg_ptr->Flash_Usart_BaudRate, cfg_ptr->Nrf_uart_mode);
	Timer1_Init();
	OLED_Init();
	OLED_ColorTurn(0);//0正常显示，1 反色显示
	OLED_DisplayTurn(0);//0正常显示 1 屏幕翻转显示
	OLED_Clear();
	OLED_display();
	
}	
