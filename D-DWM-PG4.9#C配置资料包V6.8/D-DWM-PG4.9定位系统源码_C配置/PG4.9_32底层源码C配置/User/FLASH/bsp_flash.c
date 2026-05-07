#include "bsp_flash.h"
#include "nrf_log.h"
#include "nrf_log_ctrl.h"
#include "common_config.h"

#define FLASH_RECORD_CONFIG_KEY 0x000A      //范围需要在0x0001-0xBFFF之间
#define FLASH_RECORD_CONFIG_FILEID 0x0001   //范围需要在0x0000-0xBFFF之间

#define FLASH_APP_SIZE   (116)			  	    //数组长度
uint16_t app_save[FLASH_APP_SIZE];				  //FLASH整数缓存

//typedef struct 
//{
//	uint16_t app_save[FLASH_APP_SIZE];	
//}save_test_t;
//save_test_t test_app;

fds_record_desc_t Config_rec_desc = {0};
bool Config_record_has_init = false;

/* Flag to check fds initialization. */
static bool volatile m_fds_initialized;

/* Keep track of the progress of a delete_all operation. */
static struct
{
    bool delete_next;   //!< Delete next record.
    bool pending;       //!< Waiting for an fds FDS_EVT_DEL_RECORD event, to delete the next record.
} m_delete_all;

/* Array to map FDS events to strings. */
static char const * fds_evt_str[] =
{
    "FDS_EVT_INIT",
    "FDS_EVT_WRITE",
    "FDS_EVT_UPDATE",
    "FDS_EVT_DEL_RECORD",
    "FDS_EVT_DEL_FILE",
    "FDS_EVT_GC",
};

const char *fds_err_str(ret_code_t ret)
{
    /* Array to map FDS return values to strings. */
    static char const * err_str[] =
    {
        "FDS_ERR_OPERATION_TIMEOUT",
        "FDS_ERR_NOT_INITIALIZED",
        "FDS_ERR_UNALIGNED_ADDR",
        "FDS_ERR_INVALID_ARG",
        "FDS_ERR_NULL_ARG",
        "FDS_ERR_NO_OPEN_RECORDS",
        "FDS_ERR_NO_SPACE_IN_FLASH",
        "FDS_ERR_NO_SPACE_IN_QUEUES",
        "FDS_ERR_RECORD_TOO_LARGE",
        "FDS_ERR_NOT_FOUND",
        "FDS_ERR_NO_PAGES",
        "FDS_ERR_USER_LIMIT_REACHED",
        "FDS_ERR_CRC_CHECK_FAILED",
        "FDS_ERR_BUSY",
        "FDS_ERR_INTERNAL",
    };

    return err_str[ret - NRF_ERROR_FDS_ERR_BASE];
}

static void fds_evt_handler(fds_evt_t const * p_evt)
{
    if (p_evt->result == NRF_SUCCESS)
    {
        NRF_LOG_INFO("Event: %s received (NRF_SUCCESS)",
                      fds_evt_str[p_evt->id]);
    }
    else
    {
        NRF_LOG_INFO("Event: %s received (%s)",
                      fds_evt_str[p_evt->id],
                      fds_err_str(p_evt->result));
    }

    switch (p_evt->id)
    {
        case FDS_EVT_INIT:
		{
			if (p_evt->result == NRF_SUCCESS)
            {
                m_fds_initialized = true;
            }
            break;
		}
        case FDS_EVT_WRITE:
        {
            if (p_evt->result == NRF_SUCCESS)
            {
                NRF_LOG_INFO("Record ID:\t0x%04x",  p_evt->write.record_id);
                NRF_LOG_INFO("File ID:\t0x%04x",    p_evt->write.file_id);
                NRF_LOG_INFO("Record key:\t0x%04x", p_evt->write.record_key);
            }
			break;
        } 

        case FDS_EVT_DEL_RECORD:
        {
            if (p_evt->result == NRF_SUCCESS)
            {
                NRF_LOG_INFO("Record ID:\t0x%04x",  p_evt->del.record_id);
                NRF_LOG_INFO("File ID:\t0x%04x",    p_evt->del.file_id);
                NRF_LOG_INFO("Record key:\t0x%04x", p_evt->del.record_key);
            }
            m_delete_all.pending = false;
			break;
        } 
        default:
            break;
    }
}

/**@brief   Sleep until an event is received. */
static void power_manage(void)
{
#ifdef SOFTDEVICE_PRESENT
    (void) sd_app_evt_wait();
#else
    __WFE();
#endif
}


/**@brief   Wait for fds to initialize. */
static void wait_for_fds_ready(void)
{
    while (!m_fds_initialized)
    {
        power_manage();
    }
}

void Flash_regs_value_to_config(void)
{
	uint16_t q;
//	Device_config_t *cfg_ptr = Get_Device_config();
	
	Device_cfg_ptr->Flash_Usart_BaudRate=app_save[0];
	Device_cfg_ptr->Flash_Modbus_ADDR=app_save[1];
	Device_cfg_ptr->Flash_Ranging_Mode = app_save[2] >> 8;
	Device_cfg_ptr->Flash_structure_Mode=app_save[2] & 0x00FF;
	Device_cfg_ptr->Flash_Device_Mode=app_save[3] >> 8;	
	Device_cfg_ptr->Device_range_work_mode = app_save[3] & 0x00FF;
	if(Device_cfg_ptr->Device_range_work_mode >= Workmode_idle && Device_cfg_ptr->Device_range_work_mode <= Workmode_continous_auto_output)
		Device_cfg_ptr->Device_range_work_mode = Workmode_idle;  //不是上电开始工作的模式 全部变为空闲不工作
	Device_cfg_ptr->Flash_Device_ID=app_save[4];
	Device_cfg_ptr->Uwb_config.UWB_Channel=app_save[5] >> 8;              //空中信道
	Device_cfg_ptr->Uwb_config.UWB_Data_rat=app_save[5] & 0x00FF;             //空中传输速率     
	Device_cfg_ptr->FLASH_KALMAN_Q=app_save[6];       	    //卡尔曼滤波-Q
	Device_cfg_ptr->FLASH_KALMAN_R=app_save[7];					    //卡尔曼滤波-R
	Device_cfg_ptr->Uwb_config.UWB_ANT_DLY=app_save[8];           //接收延时
	//app_save[9]留空
	Device_cfg_ptr->Calculate_Anc_en=app_save[10];

	for(q = 0; q < ANCHOR_LIST_COUNT; q++)
	{
		Anchor_t *a = &(Device_cfg_ptr->Anchor_List[q]);
		if(q == 0)			
			a -> en = 1;   //主基站默认使能			
		else
		{
			if((Device_cfg_ptr->Calculate_Anc_en >> q) & 0x01)
				a->en = 1;
			else
				a->en = 0;					
		}
	    a -> x = app_save[q * 3 + 11];			 
		a -> y = app_save[q * 3 + 12];
		a -> z = app_save[q * 3 + 13];					
	}

	Device_cfg_ptr->FLASH_CAL_xyz_En = app_save[59] >> 8 & 0x00FF;
	Device_cfg_ptr->Flash_TAG_NUM = app_save[59] & 0x00FF;       //标签数量

	
	for(q=0;q<50;q++)
	{
		Device_cfg_ptr->Flash_TAG_BUF[2*q+1]=(app_save[60+q]>>8)&0xFF;
		Device_cfg_ptr->Flash_TAG_BUF[2*q]=app_save[60+q]&0xFF;
	}

	Device_cfg_ptr->Tag_output_cfg.output_en = app_save[110] >> 8;
	Device_cfg_ptr->Tag_output_cfg.output_format = app_save[110] & 0x00FF;
	Device_cfg_ptr->Tag_output_cfg.ouput_protocal = app_save[111] >> 8;
	Device_cfg_ptr->Anchor_OutputProtocal = app_save[111] & 0x00FF;
	Device_cfg_ptr->Nrf_uart_mode = app_save[112] >> 8; 
	Device_cfg_ptr->Uwb_config.UWB_Is_Use_Trim = app_save[113] >> 8;
	Device_cfg_ptr->Uwb_config.UWB_Trim_Value = app_save[113] & 0x00FF;
//	Flash_FLAG=app_save[FLASH_APP_SIZE - 1];

}

void Flash_device_config_in_regs(void)
{
	uint16_t q;
	uint8_t temp;
//	Device_config_t *cfg_ptr = Get_Device_config();
	app_save[0]=Device_cfg_ptr->Flash_Usart_BaudRate;
	app_save[1]=Device_cfg_ptr->Flash_Modbus_ADDR;   //Modbus ID号 
	app_save[2]=((uint16_t)Device_cfg_ptr->Flash_Ranging_Mode << 8 & 0xFF00) | Device_cfg_ptr->Flash_structure_Mode;  //0：测距模式  1:二维定位模式 2：三维定位模式
	if(Device_cfg_ptr->Device_range_work_mode >= 5 && Device_cfg_ptr->Device_range_work_mode <= 9)  //代表上电自动工作模式才保存
	{		
		temp = Device_cfg_ptr->Device_range_work_mode == Workmode_cancel_onstart ? Workmode_idle : Device_cfg_ptr->Device_range_work_mode;
		Device_cfg_ptr->Device_range_work_mode = Device_cfg_ptr->Device_last_range_work_mode;  //下次上电才生效 保持本次的状态位不变
	}
	else
	{
		if((app_save[3] & 0x00FF) >= 5 && (app_save[3] & 0x00FF) <= 8)
			temp = app_save[3] & 0x00FF;
		else
			temp = Device_cfg_ptr->Device_range_work_mode;
	}
		
	app_save[3]=((uint16_t)Device_cfg_ptr->Flash_Device_Mode << 8 & 0xFF00) | temp; 
	app_save[4]=Device_cfg_ptr->Flash_Device_ID;
	app_save[5]=((uint16_t)Device_cfg_ptr->Uwb_config.UWB_Channel << 8 & 0xFF00) | Device_cfg_ptr->Uwb_config.UWB_Data_rat;              //空中传输速率   空中信道       
	app_save[6]=Device_cfg_ptr->FLASH_KALMAN_Q;       	    //卡尔曼滤波-Q
	app_save[7]=Device_cfg_ptr->FLASH_KALMAN_R;					    //卡尔曼滤波-R
	app_save[8]=Device_cfg_ptr->Uwb_config.UWB_ANT_DLY;           //接收延时
	app_save[9]=0;
	app_save[10]=Device_cfg_ptr->Calculate_Anc_en;

	for(q = 0;q < ANCHOR_LIST_COUNT; q++)  //输入基站位置坐标
	{
		Anchor_t *a = &(Device_cfg_ptr->Anchor_List[q]);
		app_save[11 + q * 3] = a -> x;
		app_save[12 + q * 3] = a -> y;
		app_save[13 + q * 3] = a -> z;		
	}
		
	app_save[59] = ((Device_cfg_ptr->FLASH_CAL_xyz_En<<8)&0xFF00)|Device_cfg_ptr->Flash_TAG_NUM ;      //标签数量
	
	for(q=0;q<50;q++)
	{
		app_save[60+q]=((Device_cfg_ptr->Flash_TAG_BUF[2*q+1]<<8)&0xFF00)|Device_cfg_ptr->Flash_TAG_BUF[2*q];
	}
	
	app_save[110] = Device_cfg_ptr->Tag_output_cfg.output_en << 8 | Device_cfg_ptr->Tag_output_cfg.output_format;
	app_save[111] = Device_cfg_ptr->Tag_output_cfg.ouput_protocal << 8 |  Device_cfg_ptr->Anchor_OutputProtocal;
	app_save[112] = Device_cfg_ptr->Nrf_uart_mode << 8 | 0x00;
	app_save[113] = Device_cfg_ptr->Uwb_config.UWB_Is_Use_Trim << 8 | Device_cfg_ptr->Uwb_config.UWB_Trim_Value;
//	app_save[FLASH_APP_SIZE - 1]=Flash_FLAG; 不需要保存了
}

/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 初始化FDS(Flash data storage)内存管理模块
 * 这里使用蓝牙softdevice控制flash，必须要提前先启用蓝牙SDH模块
 * 如果不使用蓝牙 在sdk_config中设置FDS_BACKEND切换使用NVMC来控制
 * input parameters
 * @param
 * @param
 * output parameters
 * 
 */
void Flash_fds_Init(void)
{
	ret_code_t ret;
	/* Register first to receive an event when initialization is complete. */
	(void) fds_register(fds_evt_handler);
	NRF_LOG_INFO("Initializing fds...");
	
	NRF_LOG_INFO("u16 addr:%x,%d",app_save,is_word_aligned(&app_save));
	
	ret = fds_init();
	APP_ERROR_CHECK(ret);	
	
	/* Wait for fds to initialize. */
	wait_for_fds_ready();	
	fds_stat_t stat = {0};
	ret = fds_stat(&stat);
	APP_ERROR_CHECK(ret);
	
	NRF_LOG_INFO("Found %d valid records.", stat.valid_records);
	NRF_LOG_INFO("Found %d dirty records (ready to be garbage collected).", stat.dirty_records);

	if(stat.dirty_records > 5)
	{
		//运行gc
		NRF_LOG_INFO("Records gc run...");
		APP_ERROR_CHECK(fds_gc());
	}
	
	fds_find_token_t  tok  = {0};
	ret = fds_record_find(FLASH_RECORD_CONFIG_FILEID,FLASH_RECORD_CONFIG_KEY,&Config_rec_desc,&tok);
	if(ret == FDS_ERR_NOT_FOUND)  //没有找到 赋予初值并写入到flash中
	{
		/* System config not found; write a new one. */
		NRF_LOG_INFO("Writing config file...");
		Set_Default_Device_config();
		//写入到flash当中
		Flash_device_config_in_regs();
		Flash_write_config();
	}
	else if(ret == NRF_SUCCESS)
	{
		//读取flash数据并赋值到配置中
		Flash_read_config();
		Config_record_has_init = true;
	}	
	NRF_LOG_PROCESS();
}


void Flash_write_config(void)
{
	ret_code_t ret;
	Flash_device_config_in_regs();
	fds_record_t write_rec;
	write_rec.key = FLASH_RECORD_CONFIG_KEY;
	write_rec.file_id = FLASH_RECORD_CONFIG_FILEID;
	write_rec.data.p_data = app_save;
	write_rec.data.length_words = sizeof(app_save) / sizeof(uint32_t);  //app_save为16位，两个字节 转换成多少个32位数据
	if(Config_record_has_init == true)
	{
		ret = fds_record_update(&Config_rec_desc, &write_rec);  //如果之前写入了 则是更新 否则一直递增record
	}
	else
	{
		ret = fds_record_write(&Config_rec_desc, &write_rec);
	}
	if ((ret != NRF_SUCCESS) && (ret == FDS_ERR_NO_SPACE_IN_FLASH))
	{
		NRF_LOG_INFO("No space in flash, delete some records to update the config file.");
	}
	else
	{
		APP_ERROR_CHECK(ret);
		wait_for_fds_ready();	//等待写入完成
		if(Config_record_has_init == false)
		{
			Config_record_has_init = true;
		}
	}
	
}

void Flash_read_config(void)
{
	ret_code_t ret;
	fds_flash_record_t config = {0};
	/* Open the record and read its contents. */
	ret = fds_record_open(&Config_rec_desc, &config);
	APP_ERROR_CHECK(ret);

	/* Copy the configuration from flash into m_dummy_cfg. */
	memcpy(app_save, config.p_data, sizeof(app_save));
	
	/* Close the record when done reading. */
	ret = fds_record_close(&Config_rec_desc);
	APP_ERROR_CHECK(ret);
	
	NRF_LOG_INFO("Get flash data.");
	
	Flash_regs_value_to_config();
	
}
