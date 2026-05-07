#include "App_cir.h"
#include "stdlib.h"
#include "string.h"

#include "deca_device_api.h"
#include "deca_regs.h"

#define UWB_DW1000 (0)
#define UWB_DW3000 (1)
#define UWB_CHIP UWB_DW3000
#define IS_CHECK_MAXSPI_READNUM (1)
#define MAXSPI_READNUM (40)


#if UWB_CHIP == UWB_DW3000
#define CIR_DATA_SIZE (6)
#else
#define CIR_DATA_SIZE (4)
#endif

uint8_t* Cir_upload_data_ptr = NULL;
App_cir_inst_t Cir_inst = {0};
App_cir_inst_t * const Cir_inst_ptr = &Cir_inst;


uint8_t App_cir_read_cir(void)
{
	//计算需要保存数据的字节总数
	uint16_t read_len = Cir_inst.cir_read_idx_len * CIR_DATA_SIZE;
	uint8_t* ptr = NULL;
	uint8_t upload_package_count = read_len / CIR_UPLOAD_DATA_MAXLEN;
	
	#if IS_CHECK_MAXSPI_READNUM
	if(Cir_inst.cir_read_idx_len > MAXSPI_READNUM)
	{
		return 0;
	}
	#endif
	
	//预防上次没有释放内存
	if(Cir_upload_data_ptr != NULL)
	{
		App_cir_clear();
	}

	ptr = malloc(read_len + 1);
	if(ptr == NULL)  //空指针 无法分配内存
	{
		return 0;
	}
	Cir_inst.upload_count = read_len % CIR_UPLOAD_DATA_MAXLEN ? upload_package_count + 1 : upload_package_count;
	
	
	#if UWB_CHIP == UWB_DW3000
	dwt_readaccdata(ptr,read_len + 1,Cir_inst.cir_start_idx); //DW3000库传参规则和1000有不同
	#else
	dwt_readaccdata(ptr,read_len,Cir_inst.cir_start_idx * CIR_DATA_SIZE); //读取长度-1因为传参到api是指示要读取的字节数量 但是api输出的数据的第一个字节是脏数据需要去掉，输出的数据长度自动+1
	#endif
	Cir_upload_data_ptr = ptr;  //记录指针
	return 1;
}


void App_cir_clear(void)
{
	if(Cir_upload_data_ptr == NULL)
	{
		return;
	}
	free(Cir_upload_data_ptr);
	Cir_upload_data_ptr = NULL;
}


uint8_t App_cir_get_cache(uint16_t cache_idx)
{
	if(cache_idx >= Cir_inst.upload_count)
	{
		return 0;
	}
	Cir_inst.now_upload_idx = cache_idx;
	Cir_inst.cache.data_ptr = Cir_upload_data_ptr + 1 + cache_idx * CIR_UPLOAD_DATA_MAXLEN;
	if(cache_idx != Cir_inst.upload_count - 1)
	{
		//不是末尾		
		Cir_inst.cache.data_len = CIR_UPLOAD_DATA_MAXLEN;
	}
	else
	{
		//最后一个 剩余长度 可能不同
		Cir_inst.cache.data_len =  Cir_inst.cir_read_idx_len * CIR_DATA_SIZE -  cache_idx * CIR_UPLOAD_DATA_MAXLEN;
	}
	return 1;
}



