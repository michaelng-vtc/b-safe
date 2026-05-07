#ifndef BSP_SPI_H
#define BSP_SPI_H

#include <stdbool.h>
#include <stdint.h>

#define SPI_CLK_PIN  16
#define SPI_CSN_PIN  17
#define SPI_MISO_PIN 18
#define SPI_MOSI_PIN 20

void SPI_Init(void);
void Spi_Slow_rate(void);
void Spi_Fast_rate(void);
void Spi_Cs_low(void);
void Spi_Cs_high(void);
void Spi_open(void);
void Spi_close(void);
void Spi_transfer(uint8_t const * p_tx_buffer,
									uint8_t         tx_buffer_length,
									uint8_t       * p_rx_buffer,
									uint8_t         rx_buffer_length);

#endif
