/*! ----------------------------------------------------------------------------
 * @file    deca_spi.c
 * @brief   SPI access functions
 *
 * @attention
 *
 * Copyright 2015 (c) DecaWave Ltd, Dublin, Ireland.
 *
 * All rights reserved.
 *
 * @author DecaWave
 */
#include <string.h>
#include "deca_spi.h"
#include "deca_device_api.h"
#include "bsp_spi.h"
#include "nrf_gpio.h"

#define DECA_SPI_DATABUFF_MAXLEN 300 
static uint8_t Deca_spi_sendbuff[DECA_SPI_DATABUFF_MAXLEN] = {0};
static uint8_t Deca_spi_recvbuff[DECA_SPI_DATABUFF_MAXLEN] = {0};

/****************************************************************************//**
 *
 *                              DW3000 SPI section
 *
 *******************************************************************************/
/*! ------------------------------------------------------------------------------------------------------------------
 * Function: openspi()
 *
 * Low level abstract function to open and initialise access to the SPI device.
 * returns 0 for success, or -1 for error
 */
int openspi(/*SPI_TypeDef* SPIx*/)
{
	Spi_open();
	return 0;
} // end openspi()

/*! ------------------------------------------------------------------------------------------------------------------
 * Function: closespi()
 *
 * Low level abstract function to close the the SPI device.
 * returns 0 for success, or -1 for error
 */
int closespi(void)
{
	Spi_close();
	return 0;
} // end closespi()




int writetospiwithcrc(uint16_t headerLength, const uint8_t *headerBuffer, uint16_t bodylength, const uint8_t *bodyBuffer, uint8_t crc8)
{
//	#ifdef DWT_ENABLE_CRC
	uint8_t *ptr_buff;  //数据操作指针
	uint32_t send_len = headerLength + bodylength + sizeof(crc8);  //idatalength
	decaIrqStatus_t stat ;
	
	if (send_len > DECA_SPI_DATABUFF_MAXLEN ) 
	{
		return NRF_ERROR_NO_MEM;
	}

	stat = decamutexon() ;

	Spi_open();	
	Spi_Cs_low();
	
	ptr_buff = Deca_spi_sendbuff;                   //操作指针指向待发送数组地址
	memcpy(ptr_buff, headerBuffer, headerLength);   //复制要发送的header数据到待发送数组
	ptr_buff += headerLength;                       //指针前移header数据长度
	memcpy(ptr_buff,bodyBuffer,bodylength);         //复制body数据到待发送数组，地址必须先提前移动
	ptr_buff += bodylength;                         //指针前移body数据长度
	memcpy(ptr_buff,&crc8,1);                       //复制crc数据

	Spi_transfer(Deca_spi_sendbuff, send_len, NULL, 0);  //读取无意义 不需要后续赋值

//	Spi_transfer(headerBuffer, headerLength, NULL, 0);  //读取无意义 不需要后续赋值
//	Spi_transfer(bodyBuffer, bodylength, NULL, 0);  //读取无意义 不需要后续赋值
//	Spi_transfer(&crc8, 1, NULL, 0);  //读取无意义 不需要后续赋值

	Spi_Cs_high();
	Spi_close();
  
	decamutexoff(stat) ;
//	#endif
	return 0;
	
}// end writetospiwithcrc()

/*! ------------------------------------------------------------------------------------------------------------------
 * Function: writetospi()
 *
 * Low level abstract function to write to the SPI
 * Takes two separate byte buffers for write header and write data
 * returns 0 for success
 */
//#pragma GCC optimize ("O3")
int writetospi(uint16_t headerLength, const uint8_t *headerBuffer, uint16_t bodylength, const uint8_t *bodyBuffer)
{
	uint8_t *ptr_buff;  //数据操作指针
	uint32_t send_len = headerLength + bodylength;  //idatalength
	decaIrqStatus_t  stat ;
	
	if (send_len > DECA_SPI_DATABUFF_MAXLEN ) 
	{
		return NRF_ERROR_NO_MEM;
	}

	stat = decamutexon() ;

	Spi_open();	
	Spi_Cs_low();
	
	ptr_buff = Deca_spi_sendbuff;                   //操作指针指向待发送数组地址
	memcpy(ptr_buff, headerBuffer, headerLength);   //复制要发送的header数据到待发送数组
	ptr_buff += headerLength;                       //指针前移header数据长度
	memcpy(ptr_buff,bodyBuffer,bodylength);         //复制body数据到待发送数组，地址必须先提前移动
	send_len = headerLength + bodylength;
	Spi_transfer(Deca_spi_sendbuff, send_len, NULL, 0);  //读取无意义 不需要后续赋值
//	Spi_transfer(bodyBuffer, bodylength, NULL, 0);  //读取无意义 不需要后续赋值

	Spi_Cs_high();
	Spi_close();
  
	decamutexoff(stat) ;
	return 0;
	
} // end writetospi()


/*! ------------------------------------------------------------------------------------------------------------------
 * Function: readfromspi()
 *
 * Low level abstract function to read from the SPI
 * Takes two separate byte buffers for write header and read data
 * returns the offset into read buffer where first byte of read data may be found,
 * or returns 0
 */
//#pragma GCC optimize ("O3")
int readfromspi(uint16_t headerLength, uint8_t *headerBuffer, uint16_t readlength, uint8_t *readBuffer)
{	
    uint8_t * ptr_buff;  //数据操作指针
    uint32_t idatalength = headerLength + readlength;
    decaIrqStatus_t stat ;
    if(idatalength > DECA_SPI_DATABUFF_MAXLEN) 
	{
		return NRF_ERROR_NO_MEM;
    }

    stat = decamutexon() ;
	Spi_open();
	Spi_Cs_low();
	  

    ptr_buff = Deca_spi_sendbuff;                         //数据指针指向待发送数组
    memcpy(ptr_buff, headerBuffer, headerLength);         //将发送数据赋值到待发送数组
    ptr_buff += headerLength;                             //指针前移header数据长度
    memset(ptr_buff, 0x00, readlength);                   //无body数据，赋值为0
    idatalength = headerLength + readlength;              //指定数据长度
	Spi_transfer(Deca_spi_sendbuff, idatalength, Deca_spi_recvbuff, idatalength);
    ptr_buff = Deca_spi_recvbuff + headerLength;          //接收数据前移，不读取接收到的头部数据
    memcpy(readBuffer, ptr_buff, readlength);             //赋值到接收输出
//    Spi_transfer(headerBuffer, headerLength, NULL, 0);  //读取无意义 不需要后续赋值		
//	Spi_transfer(NULL, 0, readBuffer, readlength);  
	
	Spi_Cs_high();
    Spi_close();
    
	decamutexoff(stat) ;

    return 0;	
	
} // end readfromspi()

/****************************************************************************//**
 *
 *                              END OF DW1000 SPI section
 *
 *******************************************************************************/

