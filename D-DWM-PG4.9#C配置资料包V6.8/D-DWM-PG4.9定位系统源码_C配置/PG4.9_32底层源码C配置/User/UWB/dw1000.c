#include "bsp_spi.h"
#include "dw1000.h"
#include "port.h"
#include "common_config.h"

uint8_t AIR_Chan[6]={1,2,3,4,5,7};            //空中信道


static dwt_config_t config110K = {
    2,               /* Channel number.通道号。*/
    DWT_PRF_64M,     /* Pulse repetition frequency.脉冲重复频率*/
    DWT_PLEN_1024,   /* Preamble length. 前导长度。 */
    DWT_PAC32,       /* Preamble acquisition chunk size. Used in RX only. 前导获取块大小。仅用于RX。 */
    9,               /* TX preamble code. Used in TX only. TX前导码。只在TX使用。 */
    9,               /* RX preamble code. Used in RX only. RX前导码。仅用于RX。*/
    1,               /* Use non-standard SFD (Boolean)  使用非标准的SFD（布尔）*/
    DWT_BR_110K,     /* Data rate. 数据速率。 */
    DWT_PHRMODE_STD, /* PHY header mode. PHY头模式。 */
    (1025 + 64 - 32) /* SFD timeout (preamble length + 1 + SFD length - PAC size). Used in RX only.
												SFD超时（前导长度+ 1 +SFD长度-PAC大小）。仅用于RX。*/
};

static dwt_config_t config6M8 = {
    2,               /* Channel number.通道号。 2 */ 
    DWT_PRF_64M,     /* Pulse repetition frequency.脉冲重复频率*/
    DWT_PLEN_128,   /* Preamble length. 前导长度。 */
    DWT_PAC8,       /* Preamble acquisition chunk size. Used in RX only. 前导获取块大小。仅用于RX。 */
    9,               /* TX preamble code. Used in TX only. TX前导码。只在TX使用。 */
    9,               /* RX preamble code. Used in RX only. RX前导码。仅用于RX。*/
    1,               /* Use non-standard SFD (Boolean)  使用非标准的SFD（布尔）*/
    DWT_BR_6M8,     /* Data rate. 数据速率。 */ // DWT_BR_110K
    DWT_PHRMODE_STD, /* PHY header mode. PHY头模式。 */
    DWT_SFDTOC_DEF   /* SFD timeout (preamble length + 1 + SFD length - PAC size). Used in RX only. (129 + 64 - 8)  (128 + 1 + 16 - 8)
												SFD超时（前导长度+ 1 +SFD长度-PAC大小）。仅用于RX。*/
};

void Reset_DW1000(void)
{
	nrf_gpio_cfg_output(DW1000_RSTN_PIN);
	nrf_gpio_pin_clear(DW1000_RSTN_PIN);
	deca_sleep(2);
//	nrf_gpio_pin_set(DW1000_RSTN_PIN);
	nrf_gpio_cfg_input(DW1000_RSTN_PIN, NRF_GPIO_PIN_NOPULL);
	deca_sleep(2);
}


void DW1000_Init(void)
{
	uint32_t devid = 0;
	uint16_t Ant_tx_delay, Ant_rx_delay;                    //发送天线延时接收天线延时
	uint16_t test = 0;
	int ret = 0;
	Uwb_config_t *uwb_cfg_ptr = Get_Uwb_config();
	Reset_DW1000();//重启DW1000 
	Spi_Slow_rate();//降低SPI频率
	ret = dwt_initialise(DWT_LOADUCODE);//初始化DW1000	
	Spi_Fast_rate();//回复SPI频率
	if(ret == DWT_SUCCESS)
	{
    LED1_OFF();
		deca_sleep(500);
		LED1_ON();
	}
//  dwt_configure(&config6M8); 
	if(uwb_cfg_ptr->UWB_Data_rat == 2)       //根据不同情况配置DW1000
	{
		config6M8.chan=AIR_Chan[uwb_cfg_ptr->UWB_Channel];
		dwt_configure(&config6M8); 
	}			 
	else
	{
		config110K.chan = AIR_Chan[uwb_cfg_ptr->UWB_Channel];
		dwt_configure(&config110K);
	}
	
	devid = dwt_readdevid();
	uwb_cfg_ptr->UWB_chip_id = (devid >> 8) & 0x000000FF;
	
	//对发送和接收延时进行分比例 分比例依据：原厂官方说明中得出最优分比例系数
	Ant_tx_delay = (double)uwb_cfg_ptr->UWB_ANT_DLY * 0.44;
	Ant_rx_delay = (double)uwb_cfg_ptr->UWB_ANT_DLY * 0.56;
	uwb_cfg_ptr->UWB_ANT_TX_DLY = Ant_tx_delay;  //记录发送天线延时 标签延时发送要用到
 	
	dwt_settxantennadelay(Ant_tx_delay);		//设置发射天线延迟
	dwt_setrxantennadelay(Ant_rx_delay);		//设置接收天线延迟

	#if USE_PA
	dwt_setfinegraintxseq(0);  //关闭原本的Tx增益				
	dwt_setlnapamode(DWT_PA_ENABLE | DWT_LNA_ENABLE);
	#endif

	switch(uwb_cfg_ptr->UWB_Data_rat)//空中速率不同，那么看门狗报错计算时间也不同 单位ms
	{
		//为110K空中速率
		case 0: uwb_cfg_ptr->Twr_Error_max=100;
					break;
		//为850K空中速率
		case 1: uwb_cfg_ptr->Twr_Error_max=50;
					break;
		//为6M8空中速率
		case 2: uwb_cfg_ptr->Twr_Error_max=30;
					break;			
		default:break;
	}	
}

