#include "dw3000.h"
#include "bsp_spi.h"
#include "port.h"
#include "common_config.h"

uint8_t AIR_Chan[2]={5,9};            //空中信道
uint8_t  DataRate[2]={DWT_BR_850K,DWT_BR_6M8};            //空中速率


/* Default communication configuration. We use default non-STS DW mode. */
static dwt_config_t config = {
    5,               /* Channel number. */
    DWT_PLEN_128,    /* Preamble length. Used in TX only. */
    DWT_PAC8,        /* Preamble acquisition chunk size. Used in RX only. */
    9,               /* TX preamble code. Used in TX only. */
    9,               /* RX preamble code. Used in RX only. */
    1,               /* 0 to use standard 8 symbol SFD, 1 to use non-standard 8 symbol, 2 for non-standard 16 symbol SFD and 3 for 4z 8 symbol SDF type */
    DWT_BR_6M8,      /* Data rate. */
    DWT_PHRMODE_STD, /* PHY header mode. */
    DWT_PHRRATE_STD, /* PHY header rate. */
    (129 + 8 - 8),   /* SFD timeout (preamble length + 1 + SFD length - PAC size). Used in RX only. (129 + 8 - 8)*/ 
    DWT_STS_MODE_OFF,
    DWT_STS_LEN_64,  /* STS length, see allowed values in Enum dwt_sts_lengths_e */
    DWT_PDOA_M0      /* PDOA mode off */
};

dwt_config_t config_options = {
    9,                /* Channel number. */
    DWT_PLEN_64,      /* Preamble length. Used in TX only. */
    DWT_PAC8,         /* Preamble acquisition chunk size. Used in RX only. */
    9,                /* TX preamble code. Used in TX only. */
    9,                /* RX preamble code. Used in RX only. */
    3,                /* 0 to use standard 8 symbol SFD, 1 to use non-standard 8 symbol, 2 for non-standard 16 symbol SFD and 3 for 4z 8 symbol SDF type */
    DWT_BR_850K,      /* Data rate. */
    DWT_PHRMODE_STD,  /* PHY header mode. */
    DWT_PHRRATE_STD,  /* PHY header rate. */
    (64 + 1 + 8 - 8), /* SFD timeout (preamble length + 1 + SFD length - PAC size). Used in RX only. */
    DWT_STS_MODE_OFF,   /* Mode 1 STS enabled */
    DWT_STS_LEN_64,   /* STS length*/
    DWT_PDOA_M0       /* PDOA mode off */
};

/*
 * TX Power Configuration Settings
 */
/* Values for the PG_DELAY and TX_POWER registers reflect the bandwidth and power of the spectrum at the current
 * temperature. These values can be calibrated prior to taking reference measurements. */
static dwt_txconfig_t txconfig_options =
{
    0x34,           /* PG delay. 0x34默认*/
    0xfdfdfdfd,      /* TX power. */
    0x0             /*PG count*/
};

static dwt_txconfig_t txconfig9_options =
{
    0x34,           /* PG delay. */
    0xfefefefe,      /* TX power. */
    0x0             /*PG count*/
};

void DW3000_Wakeup(void)
{
	nrf_gpio_cfg_output(DW3000_WAKEUP_PIN);
	nrf_gpio_pin_set(DW3000_WAKEUP_PIN);
	deca_sleep(1);
	nrf_gpio_pin_clear(DW3000_WAKEUP_PIN);
}

/* @fn    deca_irq_handler
 * @brief Configures the interrupt. Select the right respective I/O pin and disables it.
 * */
void dw_irq_init(void)
{
    ret_code_t err_code;

	#if DECAIRQ_EXTI_USEIRQ
    err_code = nrf_drv_gpiote_init();
    APP_ERROR_CHECK(err_code);

    nrf_drv_gpiote_in_config_t in_config = GPIOTE_CONFIG_IN_SENSE_LOTOHI(true);
    in_config.pull = NRF_GPIO_PIN_PULLDOWN;

    err_code = nrf_drv_gpiote_in_init(DW3000_IRQN_PIN, &in_config, deca_irq_handler);
    APP_ERROR_CHECK(err_code);

    nrf_drv_gpiote_in_event_enable(DW3000_IRQN_PIN, false);
    #endif
    nrf_gpio_cfg_output(DW3000_WAKEUP_PIN);

}


void Reset_DW3000_withio(void)
{
	nrf_gpio_cfg_output(DW3000_RSTN_PIN);
//	nrf_gpio_cfg(
//        DW3000_RSTN_PIN,
//        NRF_GPIO_PIN_DIR_OUTPUT,
//        NRF_GPIO_PIN_INPUT_DISCONNECT,
//        NRF_GPIO_PIN_NOPULL,
//        NRF_GPIO_PIN_H0H1,
//        NRF_GPIO_PIN_NOSENSE);
	nrf_gpio_pin_clear(DW3000_RSTN_PIN);
	deca_sleep(2);
	nrf_gpio_cfg_input(DW3000_RSTN_PIN, NRF_GPIO_PIN_NOPULL);
//	nrf_gpio_pin_set(DW3000_RSTN_PIN);
	deca_sleep(2);
}

void wakeup_device_with_io(void)
{
	Reset_DW3000_withio();
}

void DW3000_GPIO7_control(uint8_t en)
{
	if(en)
	{
		
		dwt_write16bitoffsetreg(GPIO_OUT_ID, 0, GPIO_OUT_GOP7_BIT_MASK);
	}
	else
	{
		
		dwt_write16bitoffsetreg(GPIO_OUT_ID, 0, 0);
	}
}

void DW3000_Init(void)
{
	uint32_t devid = 0;
	uint16_t Ant_tx_delay, Ant_rx_delay;                    //发送天线延时接收天线延时
	int ret = 0;
	Uwb_config_t *uwb_cfg_ptr = Get_Uwb_config();
	uint32_t reg_temp = 0;
	
	dw_irq_init();
	
	Spi_Fast_rate();//回复SPI频率	
	
	Reset_DW3000_withio();//重启DW1000 
	
	deca_sleep(2); // Time needed for DW3000 to start up (transition from INIT_RC to IDLE_RC, or could wait for SPIRDY event)
	
	while (!dwt_checkidlerc()) /* Need to make sure DW IC is in IDLE_RC before proceeding */
    { };
	
	if(dwt_initialise(DWT_DW_INIT) == DWT_SUCCESS)
	{       
		LED1_OFF();
		deca_sleep(500);
	}
	else
	{
		return;
	}
	
	#if USE_PA
	dwt_setfinegraintxseq(0);  //关闭原本的Tx增益				
	dwt_setlnapamode(DWT_PA_ENABLE | DWT_LNA_ENABLE);
	#endif
	
	config.chan=AIR_Chan[uwb_cfg_ptr->UWB_Channel];
	config.dataRate = DataRate[uwb_cfg_ptr->UWB_Data_rat];
  /* if the dwt_configure returns DWT_ERROR either the PLL or RX calibration has failed the host should reset the device */
	ret = dwt_configure(&config);  //
	
	if(ret == DWT_SUCCESS)
	{
		LED1_ON();
	}
	else
	{
		return;
	}

//	Spi_Fast_rate();//回复SPI频率	
	devid = dwt_readdevid();
	NRF_LOG_INFO("id:%x",devid);

	uwb_cfg_ptr->UWB_chip_id = (devid >> 8) & 0x000000FF;
	
	Ant_tx_delay = (double)uwb_cfg_ptr->UWB_ANT_DLY * 0.5;
	Ant_rx_delay = (double)uwb_cfg_ptr->UWB_ANT_DLY * 0.5;
	uwb_cfg_ptr->UWB_ANT_TX_DLY = Ant_tx_delay;  //记录发送天线延时 标签延时发送要用到
	/* Configure the TX spectrum parameters (power PG delay and PG Count) */
	dwt_configuretxrf(&txconfig9_options);
	dwt_settxantennadelay(Ant_tx_delay);		//设置发射天线延迟
	dwt_setrxantennadelay(Ant_rx_delay);		//设置接收天线延迟
	dwt_configciadiag(1);

	if(uwb_cfg_ptr->UWB_Is_Use_Trim)
	{
		Spi_Slow_rate();//降低SPI频率
		dwt_setxtaltrim(uwb_cfg_ptr->UWB_Trim_Value);
		Spi_Fast_rate();//回复SPI频率	
	}
	
	switch(uwb_cfg_ptr->UWB_Data_rat)//空中速率不同，那么看门狗报错计算时间也不同 单位ms
	{
		//为850K空中速率
		case 0: uwb_cfg_ptr->Twr_Error_max=50;
				break;
		//为6M8空中速率
		case 1: uwb_cfg_ptr->Twr_Error_max=30;
				break;			
		default:break;
	}	
}

/******************************************************************************
						 硬件测试模式
*******************************************************************************/
void Dw3000_Continuous_frame(uint8_t chan)
{
	uint8 msg[5]= "DECA";
	int temp = 0;
	Spi_Slow_rate();//降低SPI频率
	 /* Activate continuous frame mode. */
    /* Once configured, continuous frame must be started like a normal transmission. */
    dwt_configcontinuousframemode(0x3CF00, chan);
	Spi_Fast_rate();
	dwt_writetxdata(5, (uint8 *) msg, 0) ;
	dwt_writetxfctrl(5, 0, 0);
	dwt_starttx(DWT_START_TX_IMMEDIATE);
}

void Dw3000_Continuous_wave(uint8_t chan)
{
	Spi_Slow_rate();//降低SPI频率
	dwt_configcwmode(chan);
	Spi_Fast_rate();
}

void Dw3000_Rf_Handle(uint8_t mode, uint8_t chan)
{
	switch(mode)
	{
		case 0:	//测量连续帧
			Dw3000_Continuous_frame(chan);
			break;
		case 1:	//测量连续波
			Dw3000_Continuous_wave(chan);
			break;
		default:
			break;
	}
}
