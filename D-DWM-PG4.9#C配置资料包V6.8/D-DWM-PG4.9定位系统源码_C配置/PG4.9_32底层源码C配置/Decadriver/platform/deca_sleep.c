/*! ----------------------------------------------------------------------------
 * @file    deca_sleep.c
 * @brief   platform dependent sleep implementation
 *
 * @attention
 *
 * Copyright 2015 (c) DecaWave Ltd, Dublin, Ireland.
 *
 * All rights reserved.
 *
 * @author DecaWave
 */

#include "deca_device_api.h"
#include "nrf_delay.h"

/* Wrapper function to be used by decadriver. Declared in deca_device_api.h */
__INLINE void deca_sleep(unsigned int time_ms)
{
	nrf_delay_ms(time_ms);
}

/* Wrapper function to be used by decadriver. Declared in deca_device_api.h */
__INLINE void deca_usleep(unsigned long time_us)
{
  nrf_delay_us(time_us);
}