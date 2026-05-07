#ifndef PORT_H
#define PORT_H

#include "nrf_gpio.h"
#include "nrf_drv_gpiote.h"
#include "nordic_common.h"
#include "nrf_log.h"
#include "nrf_log_ctrl.h"
#include "nrf_log_default_backends.h"


/* 端口定义 */
#define LED1_PIN 12
#define LED2_PIN 13
#define KEY1_PIN 11
#define KEY2_PIN 14
#define KEY3_PIN 15

#define KEY_TOTAL_NUM 3
#define KEY_REALPRESS_THRESH 50
#define KEY_LONGPRESS_THRESH 500

#define PIN_ON(x) nrf_gpio_pin_write(x, 1);
#define PIN_OFF(x) nrf_gpio_pin_write(x, 0);
#define PIN_TOGGLE(x) nrf_gpio_pin_toggle(x);

#define LED1_ON() PIN_ON(LED1_PIN);
#define LED1_OFF() PIN_OFF(LED1_PIN);
#define LED1_TOGGLE() PIN_TOGGLE(LED1_PIN);

#define LED2_ON() PIN_ON(LED2_PIN);
#define LED2_OFF() PIN_OFF(LED2_PIN);
#define LED2_TOGGLE() PIN_TOGGLE(LED2_PIN);



typedef enum
{
	Key_not_press = 0,
	Key_preview_press,
	Key_Click,
	Key_long_press,
	Key_release
}Key_status_t;

typedef struct 
{
	uint8_t Key_pin;
	uint16_t Press_count;
	Key_status_t Status;
}Key_helper_t;
	
typedef enum
{
	LED_MODE_BLE_ERROR,
	LED_MODE_ADV,
	LED_MODE_CONNECTED
}LED_Mode_t;

typedef enum {RESET = 0, SET = !RESET} FlagStatus, ITStatus;

/* 方法 */

void LED_Init(void);
void LED2_Event(void);
void LED2_Change_mode(LED_Mode_t new_mode);
uint32_t KEY_Init(void);
void Key_Check_Handler(void);
void peripherals_init (void);
void Key_event(void);
#endif
