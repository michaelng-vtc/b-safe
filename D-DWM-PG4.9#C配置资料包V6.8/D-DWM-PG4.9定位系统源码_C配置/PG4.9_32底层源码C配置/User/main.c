 /*! ----------------------------------------------------------------------------
 * @app PG定位系统
 * @author 广州联网科技有限公司
 * @web www.gzlwkj.com
 */
 
 /*
   2023/5/26 v5.8
   新推出 适用于pg4.9模块
   可以通过蓝牙收发通信 可配置和输出定位数据 目前app只是实现了获取定位数据并显示 配置端暂未实现
   匹配5.8版本pg功能
*/

/*
   2024/5/28 v6.2
   新增CIR检测功能
   修改数据透传实现方式和最大传输内容限制
   修复已知bug
*/

 /*
   2024/6/18 v6.6
   新增CIR检测功能
   修改数据透传实现方式和最大传输内容限制
   整合远程配置功能 可配置手环工牌标签
   修改默认以串口3输出
   修复已知bug
*/

/*
   2025/6/9 v6.6
   修复接收强度计算错误问题
*/

/*
   2025/8/29 v6.8
   新增频偏设置功能
   新增硬件测试模式 连续帧连续波模式
   支持C款跟D款手环测距 在远程配置功能下进行对手环的时间对时
   新增C款跟D款手环心率血氧上报显示
*/

#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>

#include "main.h"
#include "nordic_common.h"
#include "nrf.h"
#include "app_error.h"
#include "app_timer.h"

#include "nrf_log.h"
#include "nrf_log_ctrl.h"
#include "nrf_log_default_backends.h"
#include "nrf_delay.h"


#include "port.h"
#include "dw3000.h"
#include "ble_app.h"
#include "bsp_timer.h"
#include "bsp_uart.h"
#include "oled.h"
#include "modbus.h"
#include "common_config.h"
#include "DS-TWR.h"
#include "HDS-TWR.h"
#include "AT.h"
#include "App_Range.h"

extern uint16_t Timer1_led_tick_flag;
extern Uart_Rx_Helper_t Uart_rx_helper;

uint16_t Sys_cfg_savebuff[8]={0};  //检测系统配置参数是否被改变缓存数组
bool HasInit = false;
Anc_range_cfg_t *Anc_range = NULL;

/**@brief Function for the Timer initialization.
 *
 * @details Initializes the timer module. This creates and starts application timers.
 */
static void timers_init(void)
{
    // Initialize timer module.
    ret_code_t err_code = app_timer_init();
    APP_ERROR_CHECK(err_code);
// ret_code_t err_code;
//       err_code = app_timer_create(&m_app_timer_id, APP_TIMER_MODE_REPEATED, timer_timeout_handler);
    // Create timers.

    /* YOUR_JOB: Create any timers to be used by the application.
                 Below is an example of how to create a timer.
                 For every new timer needed, increase the value of the macro APP_TIMER_MAX_TIMERS by
                 one.
       ret_code_t err_code;
       err_code = app_timer_create(&m_app_timer_id, APP_TIMER_MODE_REPEATED, timer_timeout_handler);
       APP_ERROR_CHECK(err_code); */
}



/**@brief Function for initializing the nrf log module.
 */
static void log_init(void)
{
    ret_code_t err_code = NRF_LOG_INIT(NULL);
    APP_ERROR_CHECK(err_code);

    NRF_LOG_DEFAULT_BACKENDS_INIT();
}

/******************************************************************************
												         检测DWM1000配置参数是否被改变
*******************************************************************************/
void Sys_cfg_check(void)
{
	uint8_t sys_cfg_change_en=0;
	if(Sys_cfg_savebuff[0] != Device_cfg_ptr->Uwb_config.UWB_Channel)//检查空中信道是否被改变
	{
		Sys_cfg_savebuff[0]=Device_cfg_ptr->Uwb_config.UWB_Channel;
		sys_cfg_change_en=1;
	}
	if(Sys_cfg_savebuff[1]!=Device_cfg_ptr->Uwb_config.UWB_Data_rat)//检查空中速率是否被改变
	{
		Sys_cfg_savebuff[1]=Device_cfg_ptr->Uwb_config.UWB_Data_rat;
		sys_cfg_change_en=1;
	}
	if(Sys_cfg_savebuff[2]!=Device_cfg_ptr->Uwb_config.UWB_ANT_DLY)//检查天线延时是否被改变
	{
		Sys_cfg_savebuff[2]=Device_cfg_ptr->Uwb_config.UWB_ANT_DLY;
		sys_cfg_change_en=1;
	}
	if(Sys_cfg_savebuff[3]!=Device_cfg_ptr->Flash_Device_Mode)//检查模块角色是否被改变
	{
		Sys_cfg_savebuff[3]=Device_cfg_ptr->Flash_Device_Mode;
		sys_cfg_change_en=1;
	}
	if(Sys_cfg_savebuff[4]!=Device_cfg_ptr->Flash_structure_Mode)//检查模块定位模式是否被改变
	{
		Sys_cfg_savebuff[4]=Device_cfg_ptr->Flash_structure_Mode;
		sys_cfg_change_en=1;
	}
	if(Sys_cfg_savebuff[5]!=Device_cfg_ptr->Flash_Device_ID)//检查模块ID是否被改变
	{
		Sys_cfg_savebuff[5]=Device_cfg_ptr->Flash_Device_ID;
		sys_cfg_change_en=1;
	}
	if(Sys_cfg_savebuff[6]!= (Device_cfg_ptr->Uwb_config.UWB_Is_Use_Trim << 8 | Device_cfg_ptr->Uwb_config.UWB_Trim_Value))
	{
		Sys_cfg_savebuff[6]=Device_cfg_ptr->Uwb_config.UWB_Is_Use_Trim << 8 | Device_cfg_ptr->Uwb_config.UWB_Trim_Value;
		sys_cfg_change_en=1;
	}
	if(Sys_cfg_savebuff[7]!=Device_cfg_ptr->RF_test_En)
	{
		Sys_cfg_savebuff[7]=Device_cfg_ptr->RF_test_En;
		sys_cfg_change_en=1;
	}
	if(!HasInit && sys_cfg_change_en)
	{
		HasInit = true;
		sys_cfg_change_en = 0;
		return;
	}
	
	if(sys_cfg_change_en && HasInit) 
	{
		dwt_forcetrxoff();
		NRF_LOG_INFO("cfg change!");
		DW3000_Init(); //如果被改变，执行初始化
		if(Device_cfg_ptr->RF_test_En)
			Dw3000_Rf_Handle(Device_cfg_ptr->RF_test_mode, Device_cfg_ptr->Uwb_config.UWB_Channel);
		#if !(MODULE_USE & MODULE_PG17)
		OLED_Clear(); 
		OLED_display();
		#endif
	}
	
}

/**@brief Function for application main entry.
 */
int main(void)
{
    // Initialize.
    log_init();	
    timers_init();  
	Ble_stack_init();	
	peripherals_init();
	Ble_app_init();	
	DW3000_Init();		
    RANGE_Init();  //基站相互测距初始化
	Anc_range = &(Device_cfg_ptr->Anc_range_cfg);    
    NRF_LOG_INFO("Pg init ok, system started.");
    
    // Enter main loop.
	nrf_delay_ms(5);

    while(1)
    {
		Key_Check_Handler();
		
		if(System_config_mode) //配置模式中 不做后续处理
		{
			if(Timer1_led_tick_flag > 50)
			{
				LED1_TOGGLE();
				Timer1_led_tick_flag = 0;
			}
			continue;
		}
		
		Uart_check_recv();
		if(Uart_rx_helper.Recv_fin)
		{
			Uart_rx_helper.Recv_fin = 0;
			//接收完成处理 根据协议判断
			if(Modbus_Handler(Uart_rx_helper.Recv_buffer,Uart_rx_helper.Recv_len,RX_DATA_UART) != Err_modbus_ok)
			{
				AT_event(Uart_rx_helper.Recv_buffer,Uart_rx_helper.Recv_len,RX_DATA_UART);
			}
			Uart_rx_helper.Recv_len = 0;
		}
		if(Ble_commu_helper_ptr->Connected && Ble_commu_helper_ptr->Recv_Fin)
		{
			//蓝牙接收数据成功
			Ble_commu_helper_ptr->Recv_Fin = 0;
			//接收完成处理 根据协议判断
			if(Modbus_Handler(Ble_commu_helper_ptr->Ble_rx_buffer,Ble_commu_helper_ptr->Ble_rx_len,RX_DATA_BLE) != Err_modbus_ok)
			{
				AT_event(Ble_commu_helper_ptr->Ble_rx_buffer,Ble_commu_helper_ptr->Ble_rx_len,RX_DATA_BLE);
			}				
			Ble_commu_helper_ptr->Ble_rx_len = 0;
		}
		Ble_uart_tx_Handler();
		Sys_cfg_check();
		
		if(Device_cfg_ptr->RF_test_En)
			continue;
		
		switch(Device_cfg_ptr->Flash_Device_Mode)
		{
			case DEVICE_MODE_TAG:
			{
				if(Device_cfg_ptr->Flash_Ranging_Mode == DEVICE_RANGEMODE_HDS)
				{
					Mode_Tag_HDS();
				}
				else
				{
					MODE_TAG_DS();
				}
				break;
			}
			case DEVICE_MODE_SUBANC:
			{
				if(Device_cfg_ptr->Flash_Ranging_Mode == DEVICE_RANGEMODE_HDS)
				{
					Mode_Sub_Anchor_HDS();
				}
				else
				{
					MODE_SUB_ANCHOR_DS();
				}
				break;
			}
			case DEVICE_MODE_MAINANC:
			{
				if(Anc_range->range_id != 0 && Anc_range->range_en != 0)
				{
					uint8_t ret = 0;
					
					if(Anc_range->range_id >> 8 == 0xFF)
					{
						ret = Mode_MainAnchor_RANGE(Anc_range->range_id >> 8,Anc_range->range_id & 0x00FF);
						if(ret == 1)
						{
							Modbus_writeRangeData(Anc_range->range_flag,Anc_range->range_id,Anc_range->range_dist);
							Anc_range->range_id = 0;
							Anc_range->range_flag = 0;
							Anc_range->range_dist = 0;
						}
					}
					else
					{
						ret = Mode_SubAnchor_RANGE(Anc_range->range_id >> 8,Anc_range->range_id & 0x00FF);
						if(ret == 1)
						{
							Modbus_writeRangeData(Anc_range->range_flag,Anc_range->range_id,Anc_range->range_dist);
							Anc_range->range_id = 0;
							Anc_range->range_flag = 0;
							Anc_range->range_dist = 0;
						}
					}
				}
				else if(Anc_range->range_en == 0)
				{
					if(Device_cfg_ptr->Flash_Ranging_Mode == DEVICE_RANGEMODE_HDS)
					{
						Mode_MainAnchor_HDS();
					}
					else
					{
						MODE_MAJOR_ANCHOR_DS();
					}
				}
				break;
			}
			default:break;
		}
		
		LED2_Event();
		
		#if DEBUG
		NRF_LOG_PROCESS();
		#endif
    }
}


/**
 * @}
 */
