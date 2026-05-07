#include "bsp_twi.h"

#define MASTER_TWI_INST 1  //TWI0 和 SPI0 的外设ID相同 所以这里用TWI1

static const nrf_drv_twi_t Twi_master_inst = NRF_DRV_TWI_INSTANCE(MASTER_TWI_INST);

void TWI_Init(void)
{
	ret_code_t err_code;
	const nrf_drv_twi_config_t config =
  {
		 .scl                = TWI_SCL_PIN,
		 .sda                = TWI_SDA_PIN,
		 .frequency          = NRF_DRV_TWI_FREQ_100K,
		 .interrupt_priority = APP_IRQ_PRIORITY_HIGH,
		 .clear_bus_init     = false
  };
	err_code = nrf_drv_twi_init(&Twi_master_inst, &config, NULL, NULL);
  if (NRF_SUCCESS == err_code)
  {
    nrf_drv_twi_enable(&Twi_master_inst);
  }	
  APP_ERROR_CHECK(err_code);
}

ret_code_t TWI_Send_bytes(uint8_t address, uint8_t const *send_data,uint8_t length)
{
	return nrf_drv_twi_tx(&Twi_master_inst, address, send_data, length, false);
}