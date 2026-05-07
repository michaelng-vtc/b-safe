#ifndef __OLED_H
#define __OLED_H 

#include "stdlib.h"
#include "stdint.h"
#include "main.h"

#define MCU_STM32 (0)  
#define MCU_NRF   (1)
#define MCU_USE MCU_NRF  //如果使用32还需要再手动添加对应32的头文件 此处省略

extern uint16_t OLED_display_time;

#if MCU_USE == MCU_STM32
#include "stm32f10x.h"
//-----------------OLED端口定义---------------- 
#define OLED_SCL_Clr() GPIO_ResetBits(GPIOB,GPIO_Pin_12)//SCL
#define OLED_SCL_Set() GPIO_SetBits(GPIOB,GPIO_Pin_12)

#define OLED_SDA_Clr() GPIO_ResetBits(GPIOB,GPIO_Pin_13)//DIN
#define OLED_SDA_Set() GPIO_SetBits(GPIOB,GPIO_Pin_13)

//#define OLED_RES_Clr() GPIO_ResetBits(GPIOA,GPIO_Pin_2)//RES
//#define OLED_RES_Set() GPIO_SetBits(GPIOA,GPIO_Pin_2)
#else
#include "port.h"

#define OLED_SCL_PIN  26
#define OLED_SDA_PIN  25
#define OLED_RES_PIN  27

#define OLED_SCL_Clr() PIN_OFF(OLED_SCL_PIN)//SCL
#define OLED_SCL_Set() PIN_ON(OLED_SCL_PIN)

#define OLED_SDA_Clr() PIN_OFF(OLED_SDA_PIN)//DIN
#define OLED_SDA_Set() PIN_ON(OLED_SDA_PIN)

#define OLED_RES_Clr() PIN_OFF(OLED_RES_PIN)//RES
#define OLED_RES_Set() PIN_ON(OLED_RES_PIN)
#endif

#define OLED_ShowString(x,y,p,s,m)  OLED_ShowString_old((x),(y),(uint8_t*)(p),(s),(m))

void OLED_ClearPoint(uint8_t x,uint8_t y);
void OLED_ColorTurn(uint8_t i);
void OLED_DisplayTurn(uint8_t i);
void OLED_DisPlay_On(void);
void OLED_DisPlay_Off(void);
void OLED_Refresh(void);
void OLED_Clear(void);
void OLED_DrawPoint(uint8_t x,uint8_t y,uint8_t t);
void OLED_DrawLine(uint8_t x1,uint8_t y1,uint8_t x2,uint8_t y2,uint8_t mode);
void OLED_DrawCircle(uint8_t x,uint8_t y,uint8_t r);
void OLED_ShowChar(uint8_t x,uint8_t y,uint8_t chr,uint8_t size1,uint8_t mode);
void OLED_ShowChar6x8(uint8_t x,uint8_t y,uint8_t chr,uint8_t mode);
void OLED_ShowString_old(uint8_t x,uint8_t y,uint8_t *chr,uint8_t size1,uint8_t mode);
void OLED_ShowNum(uint8_t x,uint8_t y,uint32_t num,uint8_t len,uint8_t size1,uint8_t mode);
void OLED_ShowChinese(uint8_t x,uint8_t y,uint8_t num,uint8_t size1,uint8_t mode);
void OLED_ScrollDisplay(uint8_t num,uint8_t space,uint8_t mode);
void OLED_ShowPicture(uint8_t x,uint8_t y,uint8_t sizex,uint8_t sizey,uint8_t BMP[],uint8_t mode);
void OLED_Init(void);
void OLED_display(void);
void OLED_display_data(uint32_t dist,int16_t X,int16_t Y,int16_t Z,uint8_t MODE);

#endif

