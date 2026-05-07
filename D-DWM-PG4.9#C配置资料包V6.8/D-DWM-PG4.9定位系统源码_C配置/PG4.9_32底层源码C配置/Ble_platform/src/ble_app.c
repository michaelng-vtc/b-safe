#include "ble_app.h"

#include "nordic_common.h"
#include "nrf.h"
#include "app_error.h"
#include "ble.h"
#include "ble_hci.h"
#include "ble_srv_common.h"
#include "ble_advdata.h"
#include "ble_advertising.h"
#include "ble_conn_params.h"
#include "nrf_sdh.h"
#include "nrf_sdh_soc.h"
#include "nrf_sdh_ble.h"
#include "fds.h"
#include "peer_manager.h"
#include "peer_manager_handler.h"
//#include "bsp_btn_ble.h"
#include "sensorsim.h"
#include "ble_conn_state.h"
#include "nrf_ble_gatt.h"
#include "nrf_ble_qwr.h"
#include "nrf_pwr_mgmt.h"
#include "nrf_queue.h"

#include "nrf_delay.h"
#include "app_timer.h"

#include "nrf_log.h"
#include "nrf_log_ctrl.h"
#include "nrf_log_default_backends.h"

#include "port.h"
#include "common_config.h"

#define DEVICE_NAME                     "PG49"                                    /**< Name of device. Will be included in the advertising data. */
#define MANUFACTURER_NAME               "GZLWKJ"                                /**< Manufacturer. Will be passed to Device Information Service. */
#define APP_ADV_INTERVAL                300                                     /**< The advertising interval (in units of 0.625 ms. This value corresponds to 187.5 ms). */
#define NUS_SERVICE_UUID_TYPE           BLE_UUID_TYPE_BLE                       /**< UUID type for the Nordic UART Service (vendor specific). */

#define APP_ADV_DURATION                18000                                   /**< The advertising duration (180 seconds) in units of 10 milliseconds. */
#define APP_BLE_OBSERVER_PRIO           3                                       /**< Application's BLE observer priority. You shouldn't need to modify this value. */
#define APP_BLE_CONN_CFG_TAG            1                                       /**< A tag identifying the SoftDevice BLE configuration. */

#define MIN_CONN_INTERVAL               MSEC_TO_UNITS(20, UNIT_1_25_MS)        /**< Minimum acceptable connection interval (0.1 seconds). 100*/  //原本100 这里加快速率
#define MAX_CONN_INTERVAL               MSEC_TO_UNITS(20, UNIT_1_25_MS)        /**< Maximum acceptable connection interval (0.2 second). 200*/   //原本200 这里加快速率
#define SLAVE_LATENCY                   0                                       /**< Slave latency. */
#define CONN_SUP_TIMEOUT                MSEC_TO_UNITS(4000, UNIT_10_MS)         /**< Connection supervisory timeout (4 seconds). */

#define FIRST_CONN_PARAMS_UPDATE_DELAY  APP_TIMER_TICKS(500)                   /**< Time from initiating event (connect or start of notification) to first time sd_ble_gap_conn_param_update is called (5 seconds). 500*/
#define NEXT_CONN_PARAMS_UPDATE_DELAY   APP_TIMER_TICKS(30000)                  /**< Time between each call to sd_ble_gap_conn_param_update after the first call (30 seconds). */
#define MAX_CONN_PARAMS_UPDATE_COUNT    3                                       /**< Number of attempts before giving up the connection parameter negotiation. */

#define SEC_PARAM_BOND                  1                                       /**< Perform bonding. */
#define SEC_PARAM_MITM                  0                                       /**< Man In The Middle protection not required. */
#define SEC_PARAM_LESC                  0                                       /**< LE Secure Connections not enabled. */
#define SEC_PARAM_KEYPRESS              0                                       /**< Keypress notifications not enabled. */
#define SEC_PARAM_IO_CAPABILITIES       BLE_GAP_IO_CAPS_NONE                    /**< No I/O capabilities. */
#define SEC_PARAM_OOB                   0                                       /**< Out Of Band data not available. */
#define SEC_PARAM_MIN_KEY_SIZE          7                                       /**< Minimum encryption key size. */
#define SEC_PARAM_MAX_KEY_SIZE          16                                      /**< Maximum encryption key size. */

#define DEAD_BEEF                       0xDEADBEEF                              /**< Value used as error code on stack dump, can be used to identify stack location on stack unwind. */


/* 新增 蓝牙缓存队列发送 */
#define NUS_TX_SEND_BUFFER_FRAME_NUM (30)
#define NUS_TX_SEND_BUFFER_MAXLEN (NUS_TX_SEND_BUFFER_FRAME_NUM * BLE_NUS_MAX_DATA_LEN)
uint8_t Ble_tx_array[NUS_TX_SEND_BUFFER_MAXLEN];
uint16_t Ble_now_tx_idx;
bool Is_send_retry = false;

typedef struct
{
	uint8_t *data_ptr;
	uint16_t data_len;
}Ble_tx_buffer_t;
Ble_tx_buffer_t Now_tx_buff = {0};

BLE_NUS_DEF(m_nus, NRF_SDH_BLE_TOTAL_LINK_COUNT);                               /**< BLE NUS service instance. */
NRF_BLE_GATT_DEF(m_gatt);                                                       /**< GATT module instance. */
NRF_BLE_QWR_DEF(m_qwr);                                                         /**< Context for the Queued Write module.*/
BLE_ADVERTISING_DEF(m_advertising);                                             /**< Advertising module instance. */
NRF_QUEUE_DEF(Ble_tx_buffer_t,m_queue, NUS_TX_SEND_BUFFER_FRAME_NUM ,NRF_QUEUE_MODE_NO_OVERFLOW);


static uint16_t   m_conn_handle          = BLE_CONN_HANDLE_INVALID;                 /**< Handle of the current connection. */
static uint16_t   m_ble_nus_max_data_len = BLE_GATT_ATT_MTU_DEFAULT - 3;            /**< Maximum length of data (in bytes) that can be transmitted to the peer by the Nordic UART service module. */

static Ble_commu_app_t Ble_commu_helper;
Ble_commu_app_t* const Ble_commu_helper_ptr = &Ble_commu_helper;
//uint8_t First_send = 0;




/* YOUR_JOB: Declare all services structure your application is using
 *  BLE_XYZ_DEF(m_xyz);
 */

// YOUR_JOB: Use UUIDs for service(s) used in your application.
static ble_uuid_t m_adv_uuids[] =                                               /**< Universally unique service identifiers. */
{
    {BLE_UUID_NUS_SERVICE, NUS_SERVICE_UUID_TYPE}
};


static void advertising_start(bool erase_bonds);


/**@brief Callback function for asserts in the SoftDevice.
 *
 * @details This function will be called in case of an assert in the SoftDevice.
 *
 * @warning This handler is an example only and does not fit a final product. You need to analyze
 *          how your product is supposed to react in case of Assert.
 * @warning On assert from the SoftDevice, the system can only recover on reset.
 *
 * @param[in] line_num   Line number of the failing ASSERT call.
 * @param[in] file_name  File name of the failing ASSERT call.
 */
void assert_nrf_callback(uint16_t line_num, const uint8_t * p_file_name)
{
    app_error_handler(DEAD_BEEF, line_num, p_file_name);
}

void Prepare_devicename(uint8_t * dev_name)
{
	strcpy(dev_name,DEVICE_NAME);
	char id[4] = {'0'};
	switch(Device_cfg_ptr->Flash_Device_Mode)
	{
		case DEVICE_MODE_TAG:
		{
			strcat(dev_name,"_Tag");
			sprintf(id,"%d",Device_cfg_ptr->Flash_Device_ID & 0x00FF);
			strcat(dev_name,id);			
			break;
		}
		case DEVICE_MODE_SUBANC:
		{
			strcat(dev_name,"_Sub");
			id[0] = 66 + (Device_cfg_ptr->Flash_Device_ID>>8)&0xFF;
			strcat(dev_name,id);
			break;
		}
		case DEVICE_MODE_MAINANC:
		{
			strcat(dev_name,"_MainA");
			break;
		}
	}
}

/**@brief Function for the GAP initialization.
 *
 * @details This function sets up all the necessary GAP (Generic Access Profile) parameters of the
 *          device including the device name, appearance, and the preferred connection parameters.
 */

static void gap_params_init(void)
{
    ret_code_t              err_code;
    ble_gap_conn_params_t   gap_conn_params;
    ble_gap_conn_sec_mode_t sec_mode;
    uint8_t Device_id[18]={0};
    BLE_GAP_CONN_SEC_MODE_SET_OPEN(&sec_mode); //设置连接模式 是否需要加密 这里设置为开放链接无需密钥
    
	Prepare_devicename(Device_id);
	  /* 设置设备名称 如果之前设置显示的全名 注意长度小于18*/
    err_code = sd_ble_gap_device_name_set(&sec_mode,
                                          (const uint8_t *)Device_id,
                                          strlen(Device_id));
    APP_ERROR_CHECK(err_code);

    /* YOUR_JOB: Use an appearance value matching the application's use case. 是否设置自定义外观
       err_code = sd_ble_gap_appearance_set(BLE_APPEARANCE_);
       APP_ERROR_CHECK(err_code); */
																																					
	 /* 
			设置设备连接参数 实际连接到主机后，是使用主机的默认参数 下面参数是需要从机发起更新时使用 
			使用手机连接时候，手机作为主机已经写好了默认连接参数，可能不允许从机发起更新
	*/																			
    memset(&gap_conn_params, 0, sizeof(gap_conn_params));

    gap_conn_params.min_conn_interval = MIN_CONN_INTERVAL;  //从机最小连接间隔时间
    gap_conn_params.max_conn_interval = MAX_CONN_INTERVAL;  //从机最大连接间隔时间 连接间隔越小，通信越频繁，功耗对应增加
    gap_conn_params.slave_latency     = SLAVE_LATENCY;      //从机潜伏周期设置 范围0-499 表示当从机没有数据需要发送时跳过一定连接事件的值 越低响应越及时，但是功耗高
    gap_conn_params.conn_sup_timeout  = CONN_SUP_TIMEOUT;   //连接超时时间 大于该时间没有发生连接事件就会断开通信 范围10ms-3200s

	/* 上述参数需要满足公式 否则连接会不正常断开
	conn_sup_timeout > (1 + slave_latency) * (max_conn_interval - min_conn_interval)																		 
	*/																			
    err_code = sd_ble_gap_ppcp_set(&gap_conn_params);
    APP_ERROR_CHECK(err_code);
}

/**@brief Function for handling events from the GATT library. */
void gatt_evt_handler(nrf_ble_gatt_t * p_gatt, nrf_ble_gatt_evt_t const * p_evt)
{
    if ((m_conn_handle == p_evt->conn_handle) && (p_evt->evt_id == NRF_BLE_GATT_EVT_ATT_MTU_UPDATED))
    {
        m_ble_nus_max_data_len = p_evt->params.att_mtu_effective - OPCODE_LENGTH - HANDLE_LENGTH;
        NRF_LOG_INFO("Data len is set to 0x%X(%d)", m_ble_nus_max_data_len, m_ble_nus_max_data_len);
    }
    NRF_LOG_DEBUG("ATT MTU exchange completed. central 0x%x peripheral 0x%x",
                  p_gatt->att_mtu_desired_central,
                  p_gatt->att_mtu_desired_periph);
}

/**@brief Function for initializing the GATT module.
 */
static void gatt_init(void)
{
    ret_code_t err_code = nrf_ble_gatt_init(&m_gatt, gatt_evt_handler);
    APP_ERROR_CHECK(err_code);
	
    err_code = nrf_ble_gatt_att_mtu_periph_set(&m_gatt, NRF_SDH_BLE_GATT_MAX_MTU_SIZE);
    APP_ERROR_CHECK(err_code);	
}


/**@brief Function for handling Queued Write Module errors.
 *
 * @details A pointer to this function will be passed to each service which may need to inform the
 *          application about an error.
 *
 * @param[in]   nrf_error   Error code containing information about what went wrong.
 */
static void nrf_qwr_error_handler(uint32_t nrf_error)
{
    APP_ERROR_HANDLER(nrf_error);
}


/**@brief Function for handling the YYY Service events.
 * YOUR_JOB implement a service handler function depending on the event the service you are using can generate
 *
 * @details This function will be called for all YY Service events which are passed to
 *          the application.
 *
 * @param[in]   p_yy_service   YY Service structure.
 * @param[in]   p_evt          Event received from the YY Service.
 *
 *
static void on_yys_evt(ble_yy_service_t     * p_yy_service,
                       ble_yy_service_evt_t * p_evt)
{
    switch (p_evt->evt_type)
    {
        case BLE_YY_NAME_EVT_WRITE:
            APPL_LOG("[APPL]: charact written with value %s. ", p_evt->params.char_xx.value.p_str);
            break;

        default:
            // No implementation needed.
            break;
    }
}
*/

void Ble_uart_tx_clear(void)
{
	Is_send_retry = false;
	nrf_queue_reset(&m_queue);
	memset(Ble_tx_array,0,sizeof(Ble_tx_array));
	
}

void Ble_uart_tx_Handler(void)
{
	uint32_t err_code;
	uint16_t length = 0;	
	
	if(!Ble_commu_helper.Connected || Ble_commu_helper.Send_rdy == 0)  //蓝牙没连接 不做后续处理
	{
		return;
	}
		
	if(Ble_commu_helper.Send_Fin == 0)  //上次还没发送完
	{
		return;
	}
	
	if(Is_send_retry)  //上次没发送完
	{
		length = Now_tx_buff.data_len;
		err_code = ble_nus_data_send(&m_nus, Now_tx_buff.data_ptr, &length, m_conn_handle);
		//NRF_LOG_INFO("Data2: %d", m_buf.p_data[0]);
		
		if ((err_code != NRF_ERROR_INVALID_STATE)&& (err_code != NRF_ERROR_RESOURCES) &&
			(err_code != NRF_ERROR_NOT_FOUND) )
		{
			APP_ERROR_CHECK(err_code);
		}
		if (err_code == NRF_SUCCESS)
		{
			Is_send_retry = false;
			Ble_commu_helper.Send_Fin = 0;
		}
	}
	
	while(!Is_send_retry && !nrf_queue_is_empty(&m_queue))  //当且发送缓存队列不为空 尝试发送
	{
		err_code = nrf_queue_pop(&m_queue, &Now_tx_buff);
		APP_ERROR_CHECK(err_code);		
		length = Now_tx_buff.data_len;
		err_code = ble_nus_data_send(&m_nus, Now_tx_buff.data_ptr, &length, m_conn_handle);
		
		if ((err_code != NRF_ERROR_INVALID_STATE)&& (err_code != NRF_ERROR_RESOURCES) &&
			(err_code != NRF_ERROR_NOT_FOUND) )
		{
			APP_ERROR_CHECK(err_code);
		}
		if (err_code == NRF_SUCCESS)
		{
			Is_send_retry = false;
			Ble_commu_helper.Send_Fin = 0;
		}		
		else
		{
			Is_send_retry = true;
			break;
		}
	}
}


void Ble_uart_send_data(uint8_t* send_buff, uint16_t send_len)
{
	/* 新发送 带缓存 只是写入到缓存区等待后续统一发送*/
	uint16_t start_idx = 0;
	Ble_tx_buffer_t tx_buf = {0};
	if(!Ble_commu_helper.Connected || Ble_commu_helper.Send_rdy == 0)  //蓝牙没连接 不做后续处理
	{
		return;
	}
	
	if(send_len > BLE_NUS_MAX_DATA_LEN)
	{
		return;
	}
	if(nrf_queue_is_full(&m_queue))
	{
		return;
	}
	start_idx = Ble_now_tx_idx + send_len > NUS_TX_SEND_BUFFER_MAXLEN ? 0 : Ble_now_tx_idx;
	memcpy(&Ble_tx_array[start_idx],send_buff,send_len);
	Ble_now_tx_idx = start_idx;
	tx_buf.data_ptr = &Ble_tx_array[start_idx];
	tx_buf.data_len = send_len;
	nrf_queue_push(&m_queue,&tx_buf);  //上面已经检查队列是否满了 这里不用再检查
//	APP_ERROR_CHECK(nrf_queue_push(&m_queue,&tx_buf));
	/* 旧发送 不带缓存简单发送 有丢包情况
	if(!Ble_commu_helper.Connected || !Ble_commu_helper.Send_rdy)
	{
		return;
	}
	if(First_send == 0)
	{
		First_send = 1;
		Ble_commu_helper.Send_Fin = 1;
	}
	
	if(Ble_commu_helper.Send_Fin == 0)
	{
		return;
	};
	Ble_commu_helper.Send_Fin = 0;
	if(send_len > BLE_NUS_MAX_DATA_LEN)
		return;
	
	Ble_commu_helper.Ble_tx_len = send_len;	
	memcpy(Ble_commu_helper.Ble_tx_buffer, send_buff, send_len);
	ble_nus_data_send(&m_nus,Ble_commu_helper.Ble_tx_buffer,&Ble_commu_helper.Ble_tx_len,m_conn_handle);
	*/
}

/**@brief Function for handling the data from the Nordic UART Service.
 *
 * @details This function will process the data received from the Nordic UART BLE Service and send
 *          it to the UART module.
 *
 * @param[in] p_evt       Nordic UART Service event.
 */
/**@snippet [Handling the data received over BLE] */
static void nus_data_handler(ble_nus_evt_t * p_evt)
{

    if (p_evt->type == BLE_NUS_EVT_RX_DATA)  //BLE接收到数据
    {
//      uint32_t err_code;
		NRF_LOG_INFO("Received data from BLE NUS.");
		NRF_LOG_HEXDUMP_INFO(p_evt->params.rx_data.p_data, p_evt->params.rx_data.length);
     
		Ble_commu_helper.Recv_Fin = 1;
		Ble_commu_helper.Ble_rx_len = p_evt->params.rx_data.length;
		memcpy(Ble_commu_helper.Ble_rx_buffer, p_evt->params.rx_data.p_data, Ble_commu_helper.Ble_rx_len);      			
    }
	else if(p_evt->type == BLE_NUS_EVT_TX_RDY)
	{
		Ble_commu_helper.Send_Fin = 1;
		NRF_LOG_INFO("BLE NUS tx ok.");
	}
}
/**@snippet [Handling the data received over BLE] */


/**@brief Function for initializing services that will be used by the application.
 */
static void services_init(void)
{
    ret_code_t         err_code;
	ble_nus_init_t     nus_init;
    nrf_ble_qwr_init_t qwr_init = {0};

    // Initialize Queued Write Module.
    qwr_init.error_handler = nrf_qwr_error_handler;

    err_code = nrf_ble_qwr_init(&m_qwr, &qwr_init);
    APP_ERROR_CHECK(err_code);

	/* 添加蓝牙串口服务 */
	memset(&nus_init, 0, sizeof(nus_init));

    nus_init.data_handler = nus_data_handler;
    
    err_code = ble_nus_init(&m_nus, &nus_init);  //记得提前设置好服务私有uuid的数量 这里只开启了蓝牙串口服务 不然会提示 NO_MEM
    APP_ERROR_CHECK(err_code);
    /* YOUR_JOB: Add code to initialize the services used by the application.
       ble_xxs_init_t                     xxs_init;
       ble_yys_init_t                     yys_init;

       // Initialize XXX Service.
       memset(&xxs_init, 0, sizeof(xxs_init));

       xxs_init.evt_handler                = NULL;
       xxs_init.is_xxx_notify_supported    = true;
       xxs_init.ble_xx_initial_value.level = 100;

       err_code = ble_bas_init(&m_xxs, &xxs_init);
       APP_ERROR_CHECK(err_code);

       // Initialize YYY Service.
       memset(&yys_init, 0, sizeof(yys_init));
       yys_init.evt_handler                  = on_yys_evt;
       yys_init.ble_yy_initial_value.counter = 0;

       err_code = ble_yy_service_init(&yys_init, &yy_init);
       APP_ERROR_CHECK(err_code);
     */
}


/**@brief Function for handling the Connection Parameters Module.
 *
 * @details This function will be called for all events in the Connection Parameters Module which
 *          are passed to the application.
 *          @note All this function does is to disconnect. This could have been done by simply
 *                setting the disconnect_on_fail config parameter, but instead we use the event
 *                handler mechanism to demonstrate its use.
 *
 * @param[in] p_evt  Event received from the Connection Parameters Module.
 */
static void on_conn_params_evt(ble_conn_params_evt_t * p_evt)
{
    ret_code_t err_code;

    if (p_evt->evt_type == BLE_CONN_PARAMS_EVT_FAILED)  //如果更新请求失败断开连接
    {
        err_code = sd_ble_gap_disconnect(m_conn_handle, BLE_HCI_CONN_INTERVAL_UNACCEPTABLE);
        APP_ERROR_CHECK(err_code);
    }
	else if(p_evt->evt_type == BLE_CONN_PARAMS_EVT_SUCCEEDED)  //更新成功
	{
		NRF_LOG_INFO("Update conn params ok!");
		Ble_commu_helper.Send_rdy = 1;
		Ble_commu_helper.Send_Fin = 1;
	}
}


/**@brief Function for handling a Connection Parameters error.
 *
 * @param[in] nrf_error  Error code containing information about what went wrong.
 */
static void conn_params_error_handler(uint32_t nrf_error)
{
    APP_ERROR_HANDLER(nrf_error);
}


/**@brief Function for initializing the Connection Parameters module.
 */
static void conn_params_init(void)
{
    ret_code_t             err_code;
    ble_conn_params_init_t cp_init;

    memset(&cp_init, 0, sizeof(cp_init));

    cp_init.p_conn_params                  = NULL;                            //获取GAP设置参数 如果为NULL 则从正在使用的链路中获取
    cp_init.first_conn_params_update_delay = FIRST_CONN_PARAMS_UPDATE_DELAY;  //从机初始化后第一次发起更新配置的时间间隔
    cp_init.next_conn_params_update_delay  = NEXT_CONN_PARAMS_UPDATE_DELAY;   //从机每次发起请求的时间间隔
    cp_init.max_conn_params_update_count   = MAX_CONN_PARAMS_UPDATE_COUNT;    //最大申请次数
    cp_init.start_on_notify_cccd_handle    = BLE_GATT_HANDLE_INVALID;         //操作句柄
    cp_init.disconnect_on_fail             = false;                           //如果更新失败是否断开连接
    cp_init.evt_handler                    = on_conn_params_evt;              //连接事件
    cp_init.error_handler                  = conn_params_error_handler;       //错误事件

    err_code = ble_conn_params_init(&cp_init);
    APP_ERROR_CHECK(err_code);
}


/**@brief Function for starting timers.
 */
static void application_timers_start(void)
{
    /* YOUR_JOB: Start your timers. below is an example of how to start a timer.
       ret_code_t err_code;
       err_code = app_timer_start(m_app_timer_id, TIMER_INTERVAL, NULL);
       APP_ERROR_CHECK(err_code); */

}


/**@brief Function for putting the chip into sleep mode.
 *
 * @note This function will not return.
 */
static void sleep_mode_enter(void)
{
//    ret_code_t err_code;

//    err_code = bsp_indication_set(BSP_INDICATE_IDLE);
//    APP_ERROR_CHECK(err_code);

//    // Prepare wakeup buttons.
//    err_code = bsp_btn_ble_sleep_mode_prepare();
//    APP_ERROR_CHECK(err_code);

//    // Go to system-off mode (this function will not return; wakeup will cause a reset).
//    err_code = sd_power_system_off();
//    APP_ERROR_CHECK(err_code);
}





/**@brief Function for handling BLE events.
 *
 * @param[in]   p_ble_evt   Bluetooth stack event.
 * @param[in]   p_context   Unused.
 */
static void ble_evt_handler(ble_evt_t const * p_ble_evt, void * p_context)
{
    ret_code_t err_code = NRF_SUCCESS;

    switch (p_ble_evt->header.evt_id)
    {
        case BLE_GAP_EVT_DISCONNECTED:  //蓝牙断开事件
            NRF_LOG_INFO("Disconnected.");
			Ble_commu_helper.Connected = 0;
			Ble_commu_helper.Send_rdy = 0;
			Ble_uart_tx_clear();
			LED2_Change_mode(LED_MODE_ADV);
            // LED indication will be changed when advertising starts.
            break;

        case BLE_GAP_EVT_CONNECTED:   //蓝牙连上事件
            NRF_LOG_INFO("Connected.");
//            err_code = bsp_indication_set(BSP_INDICATE_CONNECTED);
//            APP_ERROR_CHECK(err_code);
            m_conn_handle = p_ble_evt->evt.gap_evt.conn_handle;  //更新蓝牙连接句柄
            err_code = nrf_ble_qwr_conn_handle_assign(&m_qwr, m_conn_handle);				
            APP_ERROR_CHECK(err_code);
			sd_ble_gap_conn_param_update(m_conn_handle,NULL);  //连接上后发起更新连接参数请求
			Ble_commu_helper.Connected = 1;
			LED2_Change_mode(LED_MODE_CONNECTED);
            break;

        case BLE_GAP_EVT_PHY_UPDATE_REQUEST:  //PHY更新参数应答
        {
            NRF_LOG_DEBUG("PHY update request.");
            ble_gap_phys_t const phys =
            {
                .rx_phys = BLE_GAP_PHY_AUTO,
                .tx_phys = BLE_GAP_PHY_AUTO,
            };
            err_code = sd_ble_gap_phy_update(p_ble_evt->evt.gap_evt.conn_handle, &phys);
            APP_ERROR_CHECK(err_code);
        } break;

        case BLE_GATTC_EVT_TIMEOUT:  //GATT客户端超时
            // Disconnect on GATT Client timeout event.
            NRF_LOG_DEBUG("GATT Client Timeout.");
            err_code = sd_ble_gap_disconnect(p_ble_evt->evt.gattc_evt.conn_handle,
                                             BLE_HCI_REMOTE_USER_TERMINATED_CONNECTION);
            APP_ERROR_CHECK(err_code);
            break;

        case BLE_GATTS_EVT_TIMEOUT:  //GATT服务端超时
            // Disconnect on GATT Server timeout event.
            NRF_LOG_DEBUG("GATT Server Timeout.");
            err_code = sd_ble_gap_disconnect(p_ble_evt->evt.gatts_evt.conn_handle,
                                             BLE_HCI_REMOTE_USER_TERMINATED_CONNECTION);
            APP_ERROR_CHECK(err_code);
            break;

        default:
            // No implementation needed.
            break;
    }
//		NRF_LOG_FLUSH();
}


/**@brief Function for initializing the BLE stack.
 *
 * @details Initializes the SoftDevice and the BLE event interrupt.
 */
static void ble_sdh_init(void)
{
    ret_code_t err_code;

    err_code = nrf_sdh_enable_request();
    APP_ERROR_CHECK(err_code);

    // Configure the BLE stack using the default settings.
    // Fetch the start address of the application RAM.
    uint32_t ram_start = 0;
    err_code = nrf_sdh_ble_default_cfg_set(APP_BLE_CONN_CFG_TAG, &ram_start);
    APP_ERROR_CHECK(err_code);

    // Enable BLE stack.
    err_code = nrf_sdh_ble_enable(&ram_start);
    APP_ERROR_CHECK(err_code);

    // Register a handler for BLE events.
    NRF_SDH_BLE_OBSERVER(m_ble_observer, APP_BLE_OBSERVER_PRIO, ble_evt_handler, NULL);
}


/**@brief Function for handling Peer Manager events.
 *
 * @param[in] p_evt  Peer Manager event.
 */
static void pm_evt_handler(pm_evt_t const * p_evt)
{
    pm_handler_on_pm_evt(p_evt);
    pm_handler_disconnect_on_sec_failure(p_evt);
    pm_handler_flash_clean(p_evt);

    switch (p_evt->evt_id)
    {
        case PM_EVT_PEERS_DELETE_SUCCEEDED:
            advertising_start(false);
            break;

        default:
            break;
    }
}


/**@brief Function for the Peer Manager initialization.
 */
static void peer_manager_init(void)
{
    ble_gap_sec_params_t sec_param;
    ret_code_t           err_code;

    err_code = pm_init();
    APP_ERROR_CHECK(err_code);

    memset(&sec_param, 0, sizeof(ble_gap_sec_params_t));

    // Security parameters to be used for all security procedures.
    sec_param.bond           = SEC_PARAM_BOND;
    sec_param.mitm           = SEC_PARAM_MITM;
    sec_param.lesc           = SEC_PARAM_LESC;
    sec_param.keypress       = SEC_PARAM_KEYPRESS;
    sec_param.io_caps        = SEC_PARAM_IO_CAPABILITIES;
    sec_param.oob            = SEC_PARAM_OOB;
    sec_param.min_key_size   = SEC_PARAM_MIN_KEY_SIZE;
    sec_param.max_key_size   = SEC_PARAM_MAX_KEY_SIZE;
    sec_param.kdist_own.enc  = 1;
    sec_param.kdist_own.id   = 1;
    sec_param.kdist_peer.enc = 1;
    sec_param.kdist_peer.id  = 1;

    err_code = pm_sec_params_set(&sec_param);
    APP_ERROR_CHECK(err_code);

    err_code = pm_register(pm_evt_handler);
    APP_ERROR_CHECK(err_code);
}


/**@brief Clear bond information from persistent storage.
 */
static void delete_bonds(void)
{
    ret_code_t err_code;

    NRF_LOG_INFO("Erase bonds!");

    err_code = pm_peers_delete();
    APP_ERROR_CHECK(err_code);
}


/**@brief Function for handling events from the BSP module.
 *
 * @param[in]   event   Event generated when button is pressed.
 */
//static void bsp_event_handler(bsp_event_t event)
//{
//    ret_code_t err_code;

//    switch (event)
//    {
//        case BSP_EVENT_SLEEP:
//            sleep_mode_enter();
//            break; // BSP_EVENT_SLEEP

//        case BSP_EVENT_DISCONNECT:
//            err_code = sd_ble_gap_disconnect(m_conn_handle,
//                                             BLE_HCI_REMOTE_USER_TERMINATED_CONNECTION);
//            if (err_code != NRF_ERROR_INVALID_STATE)
//            {
//                APP_ERROR_CHECK(err_code);
//            }
//            break; // BSP_EVENT_DISCONNECT

//        case BSP_EVENT_WHITELIST_OFF:
//            if (m_conn_handle == BLE_CONN_HANDLE_INVALID)
//            {
//                err_code = ble_advertising_restart_without_whitelist(&m_advertising);
//                if (err_code != NRF_ERROR_INVALID_STATE)
//                {
//                    APP_ERROR_CHECK(err_code);
//                }
//            }
//            break; // BSP_EVENT_KEY_0

//        default:
//            break;
//    }
//}

/**@brief Function for handling advertising events.
 *
 * @details This function will be called for advertising events which are passed to the application.
 *
 * @param[in] ble_adv_evt  Advertising event.
 */
static void on_adv_evt(ble_adv_evt_t ble_adv_evt)
{
//    ret_code_t err_code;

    switch (ble_adv_evt)
    {
        case BLE_ADV_EVT_FAST:
            NRF_LOG_INFO("Fast advertising.");
//            err_code = bsp_indication_set(BSP_INDICATE_ADVERTISING);
//            APP_ERROR_CHECK(err_code);
            break;

        case BLE_ADV_EVT_IDLE:
            NRF_LOG_INFO("adv idle.");
            advertising_start(false);  //指定时间没有连接 目前重新发起广播
            break;

        default:
            break;
    }
//		NRF_LOG_FLUSH();
}

/**@brief Function for initializing the Advertising functionality.
 */
static void advertising_init(void)
{
    ret_code_t             err_code;
    ble_advertising_init_t init;

    memset(&init, 0, sizeof(init));

    init.advdata.name_type               = BLE_ADVDATA_FULL_NAME;  //广播时候显示全名
    init.advdata.include_appearance      = true;                   //是否显示图标
    init.advdata.flags                   = BLE_GAP_ADV_FLAGS_LE_ONLY_LIMITED_DISC_MODE;  //模式
    init.advdata.uuids_complete.uuid_cnt = sizeof(m_adv_uuids) / sizeof(m_adv_uuids[0]); //
    init.advdata.uuids_complete.p_uuids  = m_adv_uuids;  //独立UUID

    init.config.ble_adv_fast_enabled  = true;  //使能广播
    init.config.ble_adv_fast_interval = APP_ADV_INTERVAL;  //广播间隔
    init.config.ble_adv_fast_timeout  = APP_ADV_DURATION;  //广播超时

    init.evt_handler = on_adv_evt;

    err_code = ble_advertising_init(&m_advertising, &init);  
    APP_ERROR_CHECK(err_code);

    ble_advertising_conn_cfg_tag_set(&m_advertising, APP_BLE_CONN_CFG_TAG);  //设置广播识别号
}


/**@brief Function for initializing power management.
 */
static void power_management_init(void)
{
    ret_code_t err_code;
    err_code = nrf_pwr_mgmt_init();
    APP_ERROR_CHECK(err_code);
}

/**@brief Function for handling the idle state (main loop).
 *
 * @details If there is no pending log operation, then sleep until next the next event occurs.
 */
static void idle_state_handle(void)
{
    if (NRF_LOG_PROCESS() == false)
    {
        nrf_pwr_mgmt_run();
    }
}


/**@brief Function for starting advertising.
 */
static void advertising_start(bool erase_bonds)
{
    if (erase_bonds == true)
    {
        delete_bonds();
        // Advertising is started by PM_EVT_PEERS_DELETED_SUCEEDED event
    }
    else
    {
        ret_code_t err_code = ble_advertising_start(&m_advertising, BLE_ADV_MODE_FAST);

        APP_ERROR_CHECK(err_code);
    }
}


void Ble_stack_init(void)
{
	power_management_init();    //能源管理
	ble_sdh_init();             //蓝牙协议栈初始化	
}

void Ble_app_init(void)
{	
	gap_params_init();          //Generic Access Profile GAP初始化 蓝牙通信和连接相关配置
	gatt_init();                //Generic Attribute Profile GATT初始化
	services_init();            //服务初始化 目前为空
	advertising_init();         //广播初始化
	conn_params_init();         //连接参数初始化 目的是连接后对主机发起请求更新从机的连接参数
	peer_manager_init();        
	application_timers_start();
	advertising_start(false);  //erase_bonds
	LED2_Change_mode(LED_MODE_ADV);
}


