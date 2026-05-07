#ifndef COMMON_CONFIG_H
#define COMMON_CONFIG_H

#include <stdint.h>

#define _packed __attribute((packed))

#define MODULE_PG17   0
#define MODULE_PG25   1
#define MODULE_PG36   2
#define MODULE_PGPLUS 3
#define MODULE_PGRB   4
#define MODULE_PG23   5
#define MODULE_PG39   6
#define MODULE_PG46   7
#define MODULE_PG49   8

#define MODULE_USE 	MODULE_PG49   //修改这里对应使用不同的模块 本代码可适用于PG4.9

#if (MODULE_USE == MODULE_PG36 || MODULE_USE == MODULE_PGRB   \
     || MODULE_USE == MODULE_PGPLUS || MODULE_USE == MODULE_PG46 \
		 || MODULE_USE == MODULE_PG49 ) 
#define USE_PA        1          //PA模块使能 1使用PA 需硬件为PA模块 0不使用PA
#else
#define USE_PA        0
#endif


#define firmware_version 68 //固件版本号 
#define firmware_structure 1 //模块配置信息：0：b配置 1：c配置

#define ANCHOR_LIST_COUNT 16  //基站总数
#define SUB_ANC_STARTID   (255 - ANCHOR_LIST_COUNT + 1)  //次基站开始id

#define ANC_OUTPUT_RTLS   (1 << 0)    //主基站自动输出：输出定位坐标
#define ANC_OUTPUT_DIST   (1 << 1)    //主基站自动输出：输出各基站测距距离
#define ANC_OUTPUT_RXDIAG (1 << 2)    //主基站自动输出：输出本次标签接收信号信息
#define ANC_OUTPUT_TS     (1 << 3)    //主基站自动输出：输出本次与标签测距距离TWR算法使用的时间戳

#define TAG_OUTPUT_DIST (1 << 0)      //标签串口输出：是否输出与基站测距距离
#define TAG_OUTPUT_RTLS (1 << 1)      //标签串口输出：是否输出定位坐标（主基站硬件解算使能才有数据）

#define DEVICE_MODE_TAG 0             //设备角色：标签
#define DEVICE_MODE_SUBANC 1          //设备角色：次基站
#define DEVICE_MODE_MAINANC 2         //设备角色：主基站

#define DEVICE_RANGEMODE_DS  0        //设备测距方式：DS-TWR
#define DEVICE_RANGEMODE_HDS 1        //设备测距方式：HDS-TWR（自创）

#define DEVICE_STRUCTMODE_RANGE   0   //设备工作方式：测距模式
#define DEVICE_STRUCTMODE_2DRTLS  1   //设备工作方式：二维定位
#define DEVICE_STRUCTMODE_3DRTLS  2   //设备工作方式：三维定位

#define UWB_COMMU_DATA_MAXLEN (80)      //数据透传最大长度

#define RX_DATA_UART              0   //数据从串口获取
#define RX_DATA_BLE               1   //数据从蓝牙服务获取

typedef enum
{
	Workmode_idle = 0x00,                          //空闲
	Workmode_once_no_output,                    //单次测距不自动输出
	Workmode_continous_no_output,               //持续测距不自动输出
	Workmode_once_auto_output,                  //单次测距自动输出
	Workmode_continous_auto_output,             //持续测距自动输出
	Workmode_onstart_once_no_output,            //上电后单次测距不自动输出
	Workmode_onstart_continous_no_output,       //上电后持续测距不自动输出
	Workmode_onstart_once_auto_output,          //上电后单次测距自动输出
	Workmode_onstart_continous_auto_output,     //上电后持续测距自动输出
	Workmode_cancel_onstart,                     //取消上电后测距模式并恢复到空闲状态
	Workmode_remote_cfg,                        //远程配置模式
}Device_range_workmode_t;


typedef struct 
{
	int16_t  x;    //x坐标
	int16_t  y;    //y坐标
	int16_t  z;    //z坐标
	uint8_t  en;   //使能：1使用该基站 0：不使用 主基站默认使用
	uint32_t dist; //测得距离	
}_packed Anchor_t;

typedef struct
{
	uint8_t output_en;            //输出使能
	uint8_t output_format;        //输出内容格式选择
	uint8_t ouput_protocal;       //输出协议格式选择
}_packed Tag_output_config_t;

typedef struct
{
	uint8_t UWB_chip_id;              //芯片id 这里读取低八位而已
	uint16_t UWB_Channel;              //空中信道
	uint16_t UWB_Data_rat;             //空中传输速率     
	uint16_t UWB_ANT_DLY;              //总天线延时
	uint16_t UWB_ANT_TX_DLY;            //发送天线延时
	uint16_t Twr_Error_max;                //做twr测距过程中超时最大值 会根据不同空中速率变化
	uint8_t UWB_Is_Use_Trim;      		//是否使用uwb频偏参数
	uint8_t UWB_Trim_Value;             //uwb频偏参数 0-0x3F
}_packed Uwb_config_t;

typedef struct
{
	uint8_t range_en;
	uint8_t range_max_num;		
	uint16_t range_id;
	uint16_t range_flag;
	uint16_t range_dist;
}_packed Anc_range_cfg_t;


typedef struct
{
	uint8_t Data_commu_En;                       //发送方：使能数据发送
	uint8_t Data_commu_RevID;                    //发送方：指定接收者id
	uint8_t Data_commu_len;                      //发送方：发送数据长度
	uint8_t DataBuff[UWB_COMMU_DATA_MAXLEN];     //发送方：发送数据
}__attribute((packed)) Uwb_commu_data_send_t;

typedef struct
{
	uint8_t Data_Has_recv;                        //接收方：是否接收到数据
	uint8_t Data_commu_SenderID;                  //接收方：发送者ID
	uint8_t Data_commu_len;                       //接收方：接收到的数据长度
	uint8_t DataBuff[UWB_COMMU_DATA_MAXLEN];      //接收方：接收到的数据
}__attribute((packed)) Uwb_commu_data_recv_t;

typedef struct 
{
	Uwb_commu_data_send_t Sender;                 //发送方结构
	Uwb_commu_data_recv_t Recver;                 //接收方结构
}__attribute((packed)) Uwb_commu_data_t;


typedef struct
{
	uint16_t   Flash_Usart_BaudRate;       //设备串口通讯波特率 0：4800  1：9600 2：14400 3：19200 4：38400 5：56000 6：57600 7：115200  8：128000 9：256000
	uint16_t   Flash_Modbus_ADDR;        	//Modbus ID号 
	uint16_t   Flash_structure_Mode;     	//0:测距模式 1:二维模式 2：三维模式
	uint16_t   Flash_Ranging_Mode;         //测距模式   0：DS-TWR 1：高性能TWR
	uint16_t   Flash_Device_Mode;       		//设备模式 0：标签 1：次基站 2：主基站
	uint16_t   Flash_Device_ID;        	  //高8位为次基站ID，范围0~14  低8位为标签ID 0~99    （程序内部 标签ID为0~247  次基站ID为240~254  主基站ID为255）

	uint16_t   Flash_TAG_NUM;			 //测量标签ID数量
	uint8_t    Flash_TAG_BUF[100];         //标签ID列表
	uint16_t   FLASH_KALMAN_Q;       	    //卡尔曼滤波-Q
	uint16_t   FLASH_KALMAN_R;					    //卡尔曼滤波-R
	uint8_t    FLASH_CAL_xyz_En;           //定位解算使能
	
	uint16_t   Calculate_Anc_en;           //基站使能情况字节 1位为1代表使能 一个位代表基站使能定位 主基站必定使能 例如0F 代表主基站和次基站BCD使能
	Device_range_workmode_t   Device_range_work_mode;       		   	//设备工作模式
	Device_range_workmode_t   Device_last_range_work_mode;       	//设备工作模式
	uint8_t    Anchor_OutputProtocal;            //基站串口输出协议
	uint8_t    Nrf_uart_mode;                //串口输出模式 nrf52832只有一个串口 对应不同模式切换不同引脚输出
	Tag_output_config_t Tag_output_cfg;      //标签串口输出内容设置
	Anchor_t Anchor_List[ANCHOR_LIST_COUNT];  //基站位置列表 
	Uwb_config_t Uwb_config;                //uwb部分配置
	Anc_range_cfg_t Anc_range_cfg;          //基站互相测距配置
	
	uint8_t RF_test_En;				//硬件测试使能
	uint8_t RF_test_mode;			//测试频谱的模式

}_packed Device_config_t;  /* 设备配置参数 这里先保持命名和之前的一样 */


Device_config_t* Get_Device_config(void);
Uwb_config_t* Get_Uwb_config(void);
void Set_Default_Device_config(void);
extern Device_config_t* const Device_cfg_ptr;
extern Uwb_commu_data_t* const Uwb_commu_helper_ptr;

extern uint8_t System_config_mode;

#endif
