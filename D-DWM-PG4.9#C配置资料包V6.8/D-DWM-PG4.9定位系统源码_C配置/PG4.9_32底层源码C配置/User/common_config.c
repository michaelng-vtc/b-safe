#include "common_config.h"


Device_config_t Device_cfg;
Device_config_t* const Device_cfg_ptr = &Device_cfg;

Uwb_commu_data_t Uwb_commu_helper;
Uwb_commu_data_t* const Uwb_commu_helper_ptr = &Uwb_commu_helper;

uint8_t System_config_mode = 0;


Device_config_t* Get_Device_config(void)
{
	return &Device_cfg;
}

Uwb_config_t* Get_Uwb_config(void)
{
	return &(Device_cfg.Uwb_config);
}

void Set_Default_Device_config(void)
{
	uint16_t q;
	Device_cfg.Flash_Usart_BaudRate=0x0007;
	Device_cfg.Flash_Modbus_ADDR=0x0001;
	Device_cfg.Flash_Device_Mode=DEVICE_MODE_TAG;
	Device_cfg.Flash_Device_ID=0x0000;
	Device_cfg.Flash_structure_Mode=DEVICE_STRUCTMODE_RANGE;
	
	Device_cfg.Flash_Ranging_Mode=DEVICE_RANGEMODE_HDS;         //测距方式
	Device_cfg.Uwb_config.UWB_Channel=0;     //空中信道
	Device_cfg.Uwb_config.UWB_Data_rat=1;   //空中传输速率
	Device_cfg.FLASH_CAL_xyz_En = 1;         //由硬件解算		
	Device_cfg.Device_range_work_mode = Workmode_idle;
	Device_cfg.Nrf_uart_mode = 3;          //默认串口3输出 即usb输出
	//接收延时  PA 33000  1.7 32945
	if(MODULE_USE == MODULE_PG17)
		Device_cfg.Uwb_config.UWB_ANT_DLY = 32875;
	else if(MODULE_USE == MODULE_PG25)
		Device_cfg.Uwb_config.UWB_ANT_DLY = 33015;
	else if(MODULE_USE == MODULE_PG36)
		Device_cfg.Uwb_config.UWB_ANT_DLY = 33040;
	else if(MODULE_USE == MODULE_PG46)
	{
		Device_cfg.Uwb_config.UWB_ANT_DLY = 32875;
	}
	else if(MODULE_USE == MODULE_PG49)
	{
		Device_cfg.Uwb_config.UWB_ANT_DLY = 32875;
	}
	Device_cfg.FLASH_KALMAN_Q=3;       	    //卡尔曼滤波-Q
	Device_cfg.FLASH_KALMAN_R=10;					    //卡尔曼滤波-R
	Device_cfg.Flash_TAG_NUM=1;              //标签数量

	Device_cfg.Calculate_Anc_en = 1;
	 for(q = 0; q < ANCHOR_LIST_COUNT; q++)
	 {
		Anchor_t *a = &(Device_cfg.Anchor_List[q]);
		if(q == 0)					
			a -> en = 1;   //主基站默认使能											
		else				
			a -> en = 0;
		a -> x = 0;			 
		a -> y = 0;
		a -> z = 0;	
		a -> dist = 0;
	 }
	 
	for(q=0;q<100;q++)
	{
		Device_cfg.Flash_TAG_BUF[q]=0x0000;
	}
	
	Device_cfg.Tag_output_cfg.output_en = 1;
	Device_cfg.Tag_output_cfg.output_format = TAG_OUTPUT_DIST | TAG_OUTPUT_RTLS;
	Device_cfg.Tag_output_cfg.ouput_protocal = 1;
	Device_cfg.Anchor_OutputProtocal = ANC_OUTPUT_RTLS | ANC_OUTPUT_DIST;
	
	Device_cfg.Anc_range_cfg.range_en = 0;
	Device_cfg.Uwb_config.UWB_Is_Use_Trim = 0;
	Device_cfg.Uwb_config.UWB_Trim_Value = 0x10;
}
	
