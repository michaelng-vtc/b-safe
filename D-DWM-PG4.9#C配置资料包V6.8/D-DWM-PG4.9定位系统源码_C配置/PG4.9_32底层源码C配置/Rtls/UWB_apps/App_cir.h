#ifndef _APP_CIR_H_
#define _APP_CIR_H_

#include "stdint.h"

#define CIR_UPLOAD_DATA_MAXLEN (264)  //需要能被4和6整除 且最大不能超过串口dma最大发送缓存数组长度400
#define CIR_READ_MAXLEN (1016)

typedef struct
{
	uint8_t * data_ptr;
	uint16_t data_len;
}App_cir_data_t;

typedef struct
{
	uint8_t now_upload_idx;
	uint8_t upload_count;
	uint16_t cir_start_idx;
	uint16_t cir_read_idx_len;
	App_cir_data_t cache;
}App_cir_inst_t;




extern App_cir_inst_t * const Cir_inst_ptr;

uint8_t App_cir_read_cir(void);
void App_cir_clear(void);
uint8_t App_cir_get_cache(uint16_t cache_idx);

#endif
