#include "bsp_spi.h"
#include "nrf_drv_spi.h"
#include "nrf_gpio.h"
#include "nrf_delay.h"

#define SPI_INSTANCE  0 /**< SPI instance index. */
#define SPI_DECA_FREQ_SLOW NRF_DRV_SPI_FREQ_2M
#define SPI_DECA_FREQ_HIGH NRF_DRV_SPI_FREQ_8M

static nrf_drv_spi_t Spi_instance = NRF_DRV_SPI_INSTANCE(SPI_INSTANCE);
static nrf_drv_spi_config_t Spi_config = NRF_DRV_SPI_DEFAULT_CONFIG;

static volatile bool Spi_xfer_done;


/**
 * @brief SPI user event handler.
 * @param event
 */
void spi_event_handler(nrf_drv_spi_evt_t const * p_event,
                       void *                    p_context)
{
    Spi_xfer_done = true;
}



void SPI_Init(void)
{
	Spi_config.ss_pin   = NRFX_SPIM_PIN_NOT_USED;
	Spi_config.miso_pin = SPI_MISO_PIN;
	Spi_config.mosi_pin = SPI_MOSI_PIN;
	Spi_config.sck_pin  = SPI_CLK_PIN;
	Spi_config.bit_order = NRF_DRV_SPI_BIT_ORDER_MSB_FIRST;
	Spi_config.mode = NRF_DRV_SPI_MODE_0;
	Spi_config.orc = 0xFF;
	Spi_config.frequency = SPI_DECA_FREQ_SLOW;
	APP_ERROR_CHECK(nrf_drv_spi_init(&Spi_instance, &Spi_config, NULL, NULL));  //spi_event_handler

	nrf_gpio_cfg_output(SPI_CSN_PIN);
	nrf_gpio_pin_set(SPI_CSN_PIN);
	nrf_delay_ms(2);
}

void Spi_Slow_rate(void)
{
	nrf_drv_spi_uninit(&Spi_instance); //失能之前的配置
	Spi_config.frequency = SPI_DECA_FREQ_SLOW;
	APP_ERROR_CHECK(nrf_drv_spi_init(&Spi_instance, &Spi_config, NULL, NULL));
	nrf_delay_ms(2);
}

void Spi_Fast_rate(void)
{
	nrf_drv_spi_uninit(&Spi_instance); //失能之前的配置
	Spi_config.frequency = SPI_DECA_FREQ_HIGH;
	APP_ERROR_CHECK(nrf_drv_spi_init(&Spi_instance, &Spi_config, NULL, NULL));
		//原厂还额外设置了两个IO为H0H1，现在暂时不做看看效果
//	nrf_gpio_cfg(SPI_CLK_PIN,
//        NRF_GPIO_PIN_DIR_OUTPUT,
//        NRF_GPIO_PIN_INPUT_CONNECT,
//        NRF_GPIO_PIN_NOPULL,
//        NRF_GPIO_PIN_H0H1,
//        NRF_GPIO_PIN_NOSENSE);
//	nrf_gpio_cfg(SPI_MOSI_PIN,
//				NRF_GPIO_PIN_DIR_OUTPUT,
//				NRF_GPIO_PIN_INPUT_DISCONNECT,
//				NRF_GPIO_PIN_NOPULL,
//				NRF_GPIO_PIN_H0H1,
//				NRF_GPIO_PIN_NOSENSE);
	nrf_delay_ms(2);
}

void Spi_Cs_low(void)
{
	nrf_gpio_pin_clear(SPI_CSN_PIN);
}

void Spi_Cs_high(void)
{
	nrf_gpio_pin_set(SPI_CSN_PIN);
}

void Spi_open(void)
{
	nrf_spim_enable(Spi_instance.u.spim.p_reg);
}

void Spi_close(void)
{
	nrf_spim_disable(Spi_instance.u.spim.p_reg);
	
}


void Spi_transfer(uint8_t const * p_tx_buffer,
					uint8_t       tx_buffer_length,
					uint8_t       *p_rx_buffer,
					uint8_t       rx_buffer_length)
{
//	Spi_xfer_done = false;
	APP_ERROR_CHECK(nrf_drv_spi_transfer(&Spi_instance, p_tx_buffer, tx_buffer_length, p_rx_buffer, rx_buffer_length));
//	while(!Spi_xfer_done);
}
