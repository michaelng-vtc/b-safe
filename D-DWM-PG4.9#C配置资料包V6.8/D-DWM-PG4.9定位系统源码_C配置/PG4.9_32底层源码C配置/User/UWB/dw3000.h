#ifndef DW3000_H
#define DW3000_H

#include "deca_device_api.h"
#include "deca_regs.h"

#define DW3000_RSTN_PIN   24
#define DW3000_WAKEUP_PIN 10
#define DW3000_IRQN_PIN   19

#define DECAIRQ_EXTI_USEIRQ         0

#if DECAIRQ_EXTI_USEIRQ
#define DECAIRQ_PIN                 19
#define port_GetEXT_IRQStatus()     nrf_drv_gpiote_in_is_set(DW3000_IRQN_PIN)
#define port_DisableEXT_IRQ()       nrf_drv_gpiote_in_event_disable(DW3000_IRQN_PIN);
#define port_EnableEXT_IRQ()        nrf_drv_gpiote_in_event_enable(DW3000_IRQN_PIN, true);
#define port_CheckEXT_IRQ()         nrf_gpio_pin_read(DW3000_IRQN_PIN)
#endif

void Reset_DW3000_withio(void);
void DW3000_Init(void);
void DW3000_GPIO7_control(uint8_t en);
void Dw3000_Rf_Handle(uint8_t mode, uint8_t chan);

#endif
