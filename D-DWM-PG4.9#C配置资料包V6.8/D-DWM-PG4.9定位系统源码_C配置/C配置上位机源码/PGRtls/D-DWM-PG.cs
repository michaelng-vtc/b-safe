/*! ----------------------------------------------------------------------------
* PGRtls显示上位机
* @author 广州联网科技有限公司
* @web www.gzlwkj.com
*/

/*
 * 修改日志
 * 修改日期：2021/06/06 edition V4.5
 * 修改项目：提供另一种串口接收的中断写法 不用以前的延时方法
 *           修正了使用ttl转串口模块数据解析错误的问题
 *           加入了对手环和工牌标签电量和报警信息的响应
 *           加入了对两个通道数据表的双缓存设置
 *           修改了天线延时的说明
 *           修正了不停止定位然后模块直接拔掉后 软件无法正常关闭的问题
 *           
 *           
 * 修改日期：2021/12/9 edition V4.7
 * 修改项目：加入了对机器人标签的通讯显示
 *           加入了TCP连接设备功能
 *           修改了接收处理线程方式
 *           修改了数据表的显示和保存方式
 *           添加了串口实时判断有无拔插掉线处理
 *    
 *  修改日期：2022/4/21 edition5.0
 *  修改项目：加入16基站拓展
 *            重写三维显示界面
 *            增加基站测距数据分析页面及功能   
 *            修改了二维和三维的定位算法
 *            
 *  修改日期：2022/6/21 edition5.3
 *  修改项目：修改部分bug 
 *            添加对DW3000的识别和支持
 *            
 *  修改日期：2022/7/1 edition5.3
 *  修改项目：增加速度的描述 可粗略计算定位时标签移动速度（cm/s）作为参考
 *            增加串口描述
 *            增加自动上电定位模式设置
 *            修复了PG2.3识别不当问题
 *            
 *  修改日期：2023/2/10 edition5.3
 *  修改项目：增加导航小车功能对接
 *            修改画图部分实现
 *            修改UDP搜索基站时候 打开的监听地址为本机任意ip
 *            
 *  修改日期：2023/5/26 edition5.8
 *  修改项目：通道数据表加入隔多少个数据记录一次功能
 *            加入基站自动标定功能
 *            匹配5.8版本使用           
 *       
 *  修改日期：2024/1/15 edition5.8
 *  修改项目：匹配D-POEV3.0新网络串串口方案使用
 *  
 *  修改日期：2024/6/18 edition6.6
 *  修改项目：增加cir数据获取显示 增加轨迹回放功能
 *            整合远程配置功能
 *  
 *  修改日期：2025/6/9 edition6.6
 *  修改项目：修正dw3000系列接收强度计算错误问题
 *  
 */
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.IO.Ports;
using System.Threading;
using System.IO;
using PGRtls.Model;
using PGRtls.ModbusHelper;
using static PGRtls.ModbusHelper.ModbusRTUState;
using NPOI;
using PGRtls.ATHelper;
using System.Reflection;
using System.Data;
using PGRtls.MyWindows;
using System.Collections.ObjectModel;
using System.ComponentModel;
using PGRtls.Tool;
using PGRtls.OpenTKHelper;
using OpenTK;
using OpenTK.Graphics.OpenGL;
using OxyPlot;
using System.Management;
using PGRtls.Rtls;
using PGRtls.Services;
using System.Diagnostics;
using static ICSharpCode.SharpZipLib.Zip.ExtendedUnixData;
using OxyPlot.Legends;
using OxyPlot.WindowsForms;
using OxyPlot.Axes;
using OxyPlot.Series;
using NPOI.SS.Formula.Functions;

namespace PGRtls
{
    public partial class Main_Form : Form
    {
        /****************************************************/
        #region 变量
        const int Software_structure = 1;    //软件配置包 C配置
        readonly byte App_Version = 68;      //软件版本号
        Int16 time_SCAN_NUM = 0;              //扫描MODBUS—ID标志计数用
        int[] Flag_BaudRate_Delay = new int[] {13,10,4,3,2,1,1,1,1,1};      //波特率决定接收延时
        int Flag_BaudRate= 0;                                           //波特率选择，默认选择为115200
        Byte NOW_ID = 0;                    //连接设备的ID号
        List<string> ID_buf = new List<string>(); //设备搜索的缓存
        bool isGJ = false;                  //是否开启轨迹

        GDI_DrawHelper GDI_Rtls_Draw;       //画图辅助实例
        int KALMAN_Q = 1;      	                     //卡尔曼-Q
        int KALMAN_R = 500;					         //卡尔曼-R  

        int Channel1_index = 0;
        int Channel2_index = 0;
        int Analyze_index = 0;

        Bitmap bMap_BX_P;       //波形图说明变量
        Graphics gph_BX_P;      //波形图说明变量

        byte[] Data_Send_Periodically;  //数据透传缓存数组

        static readonly object Recv_lock = new object();
        const int recv_buffer_max = 20480;  //接收处理最大缓存数量
        List<byte> recv_buffer = new List<byte>(recv_buffer_max);  //接收缓存区

        Rx_Diag Rxdiag = new Rx_Diag();  //接收信号相关信息实例
        List<Tag> TagList = new List<Tag>();       //标签列表
        int Tag_Size = 8;                          //标签大小
        BindingList<Anchor> AnchorList = new BindingList<Anchor>();
        Anchor[] AnchorGroup = new Anchor[ANCHOR_MAX_COUNT];      //基站列表
        const int ANCHOR_MAX_COUNT = 16;
        int Draw_Flag = 0;                         //画图状态标志位
        float Target_real_pos_x, Target_real_pos_y;  //导航目的位置坐标点
        private const int DRAW_TARGET_SIZE = 40;

        /* 三维显示相关变量  */
        private int Draw_VBO;
        private int Draw_VAO;
        private List<DrawModel> VerticesList = new List<DrawModel>();
        private float[] Vertices_Array;
        DrawConfig _DrawConfig = new DrawConfig();
        int Axis_LineNum = 0;
        int Axis_Plane_Num = 0;
        Shader shader;      
        Camera User_Camera;
        bool Mouse_HasClick = false;
        Vector2 Origin_Pos;
        float sensitivity = 0.1f;
        bool TK_HasTrace = false;
        DrawHelper TK_tagTraceHelper;
        int TK_pointStart_ptrIdx = 0;

        //Modbus ModbusRTU.Instance.Modbus_com = new Modbus(0x01, 0x03, 0x00, 0x00);  //modbus操作类实例
        bool IsCalInModule = true;                       //是否硬件解算
        Color OK_color = Color.FromArgb(144, 238, 144);  //表格成功颜色
        Color NG_color = Color.FromArgb(255, 48, 48);    //表格失败颜色

        const int DataTable_MaxLen = 6000;         //历史数据记录最大数量
        DataTable DataTable_Trace1;                //通道一记录数据表
        DataTable DataTable_Trace2;                //通道二记录数据表
        DataTable DataTable_Analyse;               //测距数据分析表
        bool Is_Analyse = false;                   //指示是否开始记录
        int Analyse_format = 0;               

        //int GJ1_Index = 0;                         //通道一数据当前位置
        //int GJ2_Index = 0;                         //通道二数据当前位置
        int GJ1_ID = 0;                            //通道一的ID
        int GJ2_ID = 1;                            //通道二的ID
        //int Dt1_idx = 0;
        //int Dt2_idx = 0;

        int GJ1_record_per_data = 1;               //通道表1每多少个数据保存到数据表
        int GJ1_now_record = 0;                    //通道表1当前记录第几个数据
        int GJ2_record_per_data = 1;               //通道表2每多少个数据保存到数据表
        int GJ2_now_record = 0;                    //通道表2当前记录第几个数据

        IMU_Remote_commu Imu_unity_commu = new IMU_Remote_commu();  //imu数据发送到unity
        bool Is_open_unity = false;

        string Analyze_TagID = string.Empty;      //要保存监测信息的标签ID        
        readonly string[] Anchor_IDstr = new string[16]
        {
            "A基站","B基站","C基站","D基站",
            "E基站","F基站","G基站","H基站",
            "I基站","J基站","K基站","L基站",
            "M基站","N基站","O基站","P基站",
        };
        readonly string[] Module_catalogue = new string[]
         {
            "PG1.7","PG2.5","PG3.6","PG_Plus","PG_RB","PG2.3","PG3.9","PG4.6","PG4.9"
         };
        readonly string[] Module1000_chan_list = new string[]
        {
            "1","2","3","4","5","7"
        };
        readonly string[] Module3000_chan_list = new string[]
        {
            "5","9"
        };
        readonly string[] Module1000_datarate_list = new string[]
        {
            "110K","850K","6M8"
        };
        readonly string[] Module3000_datarate_list = new string[]
        {
            "850K","6M8"
        };


        bool AT_Recv_Message_Show = true;          //指示是否显示接收区的信息
        bool AT_Recv_Show_Tips = false;            //指示获得了OK回应后的输出情况

        int AT_Send_Fin_Time = 0;                  //发送完成 的定时器颜色指示
        IMUData imudata;                           //IMU实例
        byte Imu_display_id = 0;                   //IMU远程模式下显示数据的id
        bool Get_ModuleVersion = false;            //指示是否获得模块的版本信息
        bool Is_Magn_correct_calib= false;        //指示是否磁力计进入校准状态

        bool Is_OpenNavi = false;                 //指示是否打开导航页面
        bool Is_NaviSelecting = false;            //指示是否导航正在选择目的点
        bool Is_SelectNavi = false;               //指示是否已经选择导航目的
        DataClient Tcp_dataClient = new DataClient(1024);  //TCP连接的实例
        //FormResizeHelper ResizeHelper = new FormResizeHelper();

        OxyPlotHelper PlotHelper_CH1;
        OxyPlotHelper PlotHelper_CH2;
        OxyPlotHelper PlotHelper_Cir;

        System.Timers.Timer RtlsTimer = new System.Timers.Timer();

        /* 远程配置相关变量 */
        Remote_tag_cfg Selected_cfg = new Remote_tag_cfg();
        BindingList<Remote_tag_cfg> Remote_cfg_taglist = new BindingList<Remote_tag_cfg>();
        bool Is_in_remotecfg_mode = false;
        bool Is_single_cfg = true;

        byte Hardware_Test_Mode = 0x00;   //指示进入硬件测试的模式

        private event EventHandler Send_NaviMsgEvent;  //发送导航信息事件
        private event EventHandler<SelectPointEventArg> Send_Navi_SelectPoint_Event;  //发送选中导航目的事件
        private event EventHandler<CommuDataReceiveEventArg> Send_CalibPos_Event;  //发送自动标定接收数据事件


        const int ANC_PROTOCAL_RTLS = 0;
        const int ANC_PROTOCAL_DIST = 1;
        const int ANC_PROTOCAL_RXDIAG = 2;
        const int ANC_PROTOCAL_TIMESTAMP = 3;

        //通讯方式指示
        private enum ConnectMode
        {
            USB,           //USB连接
            TCP,           //TCP连接
            Unknown        //未连接
        }
        ConnectMode Connect_Mode = ConnectMode.Unknown;

        //连接状态指示
        private enum ConnectState
        {
            DisConnect,                  //连接断开
            DisConnecting,               //断开连接中
            Connecting,                  //连接设备中
            Connected,                   //设备已连接
            Connect_WrongVersion         //连接到错误版本硬件
        }
        ConnectState Connect_State = ConnectState.DisConnect;

        //工作状态指示
        private enum WorkState
        {
            Idle,               //空闲
            ScanModbusID,       //扫描ModbusID
            ReadConfig,         //读取配置
            WriteConfig,        //写入配置
            RtlsStart,          //定位开始指令发出
            RtlsStop,           //定位停止指令发出
            Rtlsing,            //定位中
            ReadIMUConfig,      //读取IMU配置
            WriteIMUConfig,     //写入IMU配置
            ReadIMUState,       //读取IMU状态
            CalibIMU,           //命令校准IMU
            CalibMagn,          //命令校准磁力计
            CalibMagn_fin,      //校准磁力计完成
            WriteOutputConfig,  //写入标签输出定位信息的配置
            IntoAutoCalibPos,   //基站进入自动标定 主基站有效
            AutoCalibPos,       //基站自动标定 主基站有效
            OutAutoCalibPos,     //基站退出自动标定 主基站有效
            Cir_testing,         //Cir测量中
            In_Remote_cfg,       //进入远程配置状态
            Remote_cfg,          //远程配置状态中
            Out_Remote_cfg,       //离开远程配置模式
            IntoHardwareTest_cfg,       //进入硬件测试
            OutHardwareTest_cfg       //退出硬件测试
        }
        WorkState Work_State = WorkState.Idle;

        //模块工作模式指示
        private enum RtlsMode
        {
            Ranging,
            Rtls_2D,
            Rtls_3D
        }
        RtlsMode Rtls_State = RtlsMode.Ranging;

        //模块功能
        private enum ModuleMode
        {
            tag,
            sub_anc,
            main_anc
        }
        ModuleMode Module_Mode = ModuleMode.tag;

        //Imu状态
        private enum IMUState
        {
            NoConnect,
            Running,
            Calibing,
            RemoteTrans
        }
        IMUState IMU_State = IMUState.NoConnect;

        //IMU校准时所用的数据结构
        private struct IMU_Calib_t
        {
            public bool Acc_Ok { get; set; }
            public bool Gyro_Ok { get; set; }
            public bool Calib_OK { get; set; }
            public int Retry_Time { get; set; }

            public void Imu_Calib_Init()
            {
                Acc_Ok = false;
                Gyro_Ok = false;
                Calib_OK = false;
                Retry_Time = 0;
            }
        }
        IMU_Calib_t Imu_calib = new IMU_Calib_t();
        IMUConfig Imu_config = new IMUConfig();


        private enum Cir_work_flag_t
        {
            wait_getdist = 0,
            get_correctdist,
            get_otherdist,
            wait_readcir_response,
            get_readcir_response,
            wait_cir_data,
            get_cir_data,
            wait_cir_fin,
            get_cir_fin
        }

        private class Cir_work_t
        {
            public const int CIR_MAX_NUM = 1016;
            /// <summary>
            /// 固定分包一次读取的cir数据数量
            /// </summary>
            public const int CIR_SPILIT_READ_NUM = 40;
            public Cir_work_flag_t Flag { get; set; }
            public bool Need_split_package { get; set; }
            public byte Cir_test_tagid { get; set; }
            public ushort Cir_read_startaddr { get; set; }
            public ushort Cir_read_num { get; set; }
            public bool Is_get_readresp_ok { get; set; }
            public byte Now_cir_read_idx { get; set; }
            public byte Now_cir_totalcount { get; set; }
            public List<byte> Cir_data_list { get; set; }

            public void Init()
            {
                Flag = Cir_work_flag_t.wait_getdist;
                Need_split_package = false;
                Is_get_readresp_ok = false;
                Cir_test_tagid = 0;
                Now_cir_totalcount = 0;
                Now_cir_read_idx = 0;
                Cir_read_startaddr = 0;
                Cir_read_num = 0;
                if (Cir_data_list == null)
                {
                    Cir_data_list = new List<byte>(Cir_work_t.CIR_MAX_NUM * 4 + 1);
                }
                else
                {
                    Cir_data_list.Clear();
                }
            }
        }
        Cir_work_t Cir_work_instance = new Cir_work_t();


        private enum Module_Chip_t
        {
            DW1000 = 0,
            DW3000
        }
        Module_Chip_t Module_use_chip = Module_Chip_t.DW1000;

        //用于读取标签输出的定位测距信息的数组
        readonly string[] Tag_Dist_Resolve = new string[16] {"AncA",
                                                            "AncB" ,
                                                            "AncC" ,
                                                            "AncD" ,
                                                            "AncE" ,
                                                            "AncF" ,
                                                            "AncG" ,
                                                            "AncH",
                                                            "AncI" ,
                                                            "AncJ" ,
                                                            "AncK" ,
                                                            "AncL" ,
                                                            "AncM" ,
                                                            "AncN" ,
                                                            "AncO" ,
                                                            "AncP" 
        };

        readonly char[] Tag_Rtls_Resolve = new char[3] { 'X', 'Y', 'Z' };

        private byte[,] plot_colors = new byte[ANCHOR_MAX_COUNT, 3] 
        {
            {255,0,0 },{0,255,0 },{0,0,255 },{255,255,0 },
            {255,0,255 },{0,255,255 },{255,125,0 },{255,125,125 },
            {125,255,125 },{125,125,255 },{255,255,125 },{255,125,255 },
            {125,255,255 },{255,40,180 },{40,255,180 },{18,40,255 }
        };

        

        private AutoResetEvent RecvThread_Are = new AutoResetEvent(false);  //用于对接收处理线程的同步处理

        //数据表分页显示配置
        private DataGrid_SplitHelper Data_channel1;
        private DataGrid_SplitHelper Data_channel2;
        private DataGrid_SplitHelper Data_analyze;

        ushort[] last_dist = new ushort[ANCHOR_MAX_COUNT];  //记录上一次标签的测距值
        short[] last_xyz = new short[3];     //记录上一次标签的定位值

        #endregion
        /****************************************************/

        /****************************************************/
        #region 寻找标签列表中的对应ID标签
        private Tag FindTag(int id)
        {
            foreach(Tag t in TagList)
            {
                if (t.Id == id)
                    return t;
            }
            return null;
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 主程序入口    
        public Main_Form()
        {
            try
            {
                
                AppDomain.CurrentDomain.UnhandledException += CurrentDomain_UnhandledException;
                InitializeComponent();
                AnchorInit();                                //基站类数组初始化
                DataBindingInit();                           //初始化数据绑定               
                DataTableInit();                             //通道数据表的初始化
                

                /* 对TCP客户端的处理函数设置 如果新建实例必须设置 否则无法正常工作 */
                Tcp_dataClient.Set_RecvCallback(Tcp_RecvHandler);         //设置TCP接收处理函数
                Tcp_dataClient.Set_DisconnCallback(Tcp_Close_Handler);    //设置TCP掉线处理函数

                //设置通道数据表的双缓存
                Type dgvType = dataGridView_TAG.GetType();
                PropertyInfo pi = dgvType.GetProperty("DoubleBuffered", BindingFlags.Instance | BindingFlags.NonPublic);
                pi.SetValue(dataGridView_TAG, true, null);

                dgvType = dataGridView_GJ1.GetType();
                pi = dgvType.GetProperty("DoubleBuffered", BindingFlags.Instance | BindingFlags.NonPublic);
                pi.SetValue(dataGridView_GJ1, true, null);

                dgvType = dataGridView_GJ2.GetType();
                pi = dgvType.GetProperty("DoubleBuffered", BindingFlags.Instance | BindingFlags.NonPublic);
                pi.SetValue(dataGridView_GJ2, true, null);

                dgvType = dataGridView_AncAnalys.GetType();
                pi = dgvType.GetProperty("DoubleBuffered", BindingFlags.Instance | BindingFlags.NonPublic);
                pi.SetValue(dataGridView_AncAnalys, true, null);

                dgvType = DataGridView_tag_cfg.GetType();
                pi = dgvType.GetProperty("DoubleBuffered", BindingFlags.Instance | BindingFlags.NonPublic);
                pi.SetValue(DataGridView_tag_cfg, true, null);

                Thread Recv_thread = new Thread(Data_RecvHandler);  //开启接收处理线程
                Recv_thread.IsBackground = true;
                Recv_thread.Start();

                RtlsTimer.Interval = 1000; //1s触发一次
                RtlsTimer.Elapsed += RtlsTimer_Elapsed;
                RtlsTimer.Stop();
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message);
                throw;
            }
            
        }

        private void RtlsTimer_Elapsed(object sender, System.Timers.ElapsedEventArgs e)
        {
            //轮询标签列表 扫描计算标签的速度和未响应情况
            for(int i = 0; i < TagList.Count; i++)
            {
                Tag t = TagList[i];
                if (t != null)
                {
                    t.TagNotFound_time++;
                    t.Cal_Velocity(t.x, t.y, t.z);

                    if(t.TagNotFound_time > 2)
                    {
                        t.TagNotFound_time = 0;
                        MethodInvoker mi = new MethodInvoker(() => 
                        { 
                            for(int j = 0; j<dataGridView_TAG.Columns.Count;j++)
                            {
                                dataGridView_TAG.Rows[t.Index].Cells[j].Style.BackColor = NG_color;
                            }
                        });
                        mi.Invoke();
                    }
                }
            }
        }

        private void CurrentDomain_UnhandledException(object sender, UnhandledExceptionEventArgs e)
        {
            MessageBox.Show(e.ExceptionObject.ToString());
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 设置画图区的参数  
        void Draw_Config_init()
        {
            

        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 设置数据绑定  
        private void DataBindingInit()
        {
            /* cir分析 - 接收信号强度绑定 */
            Text_maxNoise.DataBindings.Add("Text", Rxdiag, "maxNoise");
            Text_stdNoise.DataBindings.Add("Text", Rxdiag, "stdNoise");
            Text_FpAmp1.DataBindings.Add("Text", Rxdiag, "firstPathAmp1");
            Text_FpAmp2.DataBindings.Add("Text", Rxdiag, "firstPathAmp2");
            Text_FpAmp3.DataBindings.Add("Text", Rxdiag, "firstPathAmp3");
            Text_CIR.DataBindings.Add("Text", Rxdiag, "maxGrowthCIR");
            Text_PreamCount.DataBindings.Add("Text", Rxdiag, "rxPreamCount");
            Text_FP.DataBindings.Add("Text", Rxdiag, "firstPath");

            /* IMU数据强度绑定 */
            imudata = new IMUData();
            Text_accx.DataBindings.Add("Text", imudata, "Acc_x");
            Text_accy.DataBindings.Add("Text", imudata, "Acc_y");
            Text_accz.DataBindings.Add("Text", imudata, "Acc_z");
            Text_gyrox.DataBindings.Add("Text", imudata, "Gyro_x");
            Text_gyroy.DataBindings.Add("Text", imudata, "Gyro_y");
            Text_gyroz.DataBindings.Add("Text", imudata, "Gyro_z");
            Text_magnx.DataBindings.Add("Text", imudata, "Magn_x");
            Text_magny.DataBindings.Add("Text", imudata, "Magn_y");
            Text_magnz.DataBindings.Add("Text", imudata, "Magn_z");
            Textbox_magn_H.DataBindings.Add("Text", imudata, "Magn_H");
            Text_rotaX.DataBindings.Add("Text", imudata, "Rotation_x");
            Text_rotaY.DataBindings.Add("Text", imudata, "Rotation_y");
            Text_rotaZ.DataBindings.Add("Text", imudata, "Rotation_z");            
            Text_tempera.DataBindings.Add("Text", imudata, "Temperature");
            Text_q0.DataBindings.Add("Text", imudata, "q0");
            Text_q1.DataBindings.Add("Text", imudata, "q1");
            Text_q2.DataBindings.Add("Text", imudata, "q2");
            Text_q3.DataBindings.Add("Text", imudata, "q3");

            /* 基站列表数据绑定 */
            //dataGridView_BS_SET.DataBindings.Add()
            dataGridView_BS_SET.AutoGenerateColumns = false;
            DataGrid_BS_IsUse.DataPropertyName = "isUse";
            DataGrid_BS_ID.DataPropertyName = "Id";
            DataGrid_BS_x.DataPropertyName = "x";
            DataGrid_BS_y.DataPropertyName = "y";
            DataGrid_BS_z.DataPropertyName = "z";
            dataGridView_BS_SET.DataSource = AnchorList;

            /* 远程配置数据绑定 */
            DataGridView_tag_cfg.AutoGenerateColumns = false;
            Column_id.DataPropertyName = "ID";
            Column_frame.DataPropertyName = "Frame";
            Column_pgid.DataPropertyName = "Pg_id";
            Column_static_freq.DataPropertyName = "Static_freq";
            Column_alarm_freq.DataPropertyName = "Alarm_freq";
            Column_move_freq.DataPropertyName = "Moving_freq";
            Column_imu_en.DataPropertyName = "Imu_en_str";
            Column_imu_sensitive.DataPropertyName = "Imu_sense_str";
            Column_send_move.DataPropertyName = "Move_Pack";
            Column_send_static.DataPropertyName = "Static_Pack";
            Column_antdelay.DataPropertyName = "RxAntDelay";
            Column_kind.DataPropertyName = "TagKind_Show";
            Column_version.DataPropertyName = "TagVer_Show";
            Column_smartpwr_en.DataPropertyName = "PowerSet_Show";
            Column_power_db.DataPropertyName = "Power_Show";
            Column_nosleep_freq.DataPropertyName = "Nosleep_freq";
            Column_poweroff_en.DataPropertyName = "Poweroff_en_Show";
            Column_poweron_time.DataPropertyName = "PowerOnTime";
            Column_heart.DataPropertyName = "Heart_Rate";
            DataGridView_tag_cfg.DataSource = Remote_cfg_taglist;
            DataGridView_tag_cfg.ClearSelection();

            float k = 0;
            for (int i = 0; i < Remote_tag_cfg.PowerHex.Length; i++)
            {
                Combo_power_db.Items.Add(k);
                k += 0.5f;
            }
           

            Tb_id.DataBindings.Add("Text", Selected_cfg, "ID");
            Label_kind.DataBindings.Add("Text", Selected_cfg, "TagKind_Show");
            Label_version.DataBindings.Add("Text", Selected_cfg, "TagVer_Show");
            NumericUpDown_pgid.DataBindings.Add("Value", Selected_cfg, "Pg_id");
            NumericUpDown_static_freq.DataBindings.Add("Value", Selected_cfg, "Static_freq");
            NumericUpDown_move_freq.DataBindings.Add("Value", Selected_cfg, "Moving_freq");
            NumericUpDown_alarm_freq.DataBindings.Add("Value", Selected_cfg, "Alarm_freq");
            NumericUpDown_move_parkage.DataBindings.Add("Value", Selected_cfg, "Move_Pack");
            NumericUpDown_staic_package.DataBindings.Add("Value", Selected_cfg, "Static_Pack");
            Checkbox_rc_imu_en.DataBindings.Add("Checked", Selected_cfg, "Imu_en");
            Combo_imu_sensitive.DataBindings.Add("SelectedIndex", Selected_cfg, "Imu_sense");
            NumericUpDown_antdelay.DataBindings.Add("Text", Selected_cfg, "RxAntDelay");
            Checkbox_smartpwr_en.DataBindings.Add("Checked", Selected_cfg, "PowerSet_EN");
            Combo_power_db.DataBindings.Add("SelectedItem", Selected_cfg, "Power_Show");
            NumericUpDown_nosleep_freq.DataBindings.Add("Value", Selected_cfg, "Nosleep_freq");
            Checkbox_poweroff_en.DataBindings.Add("Checked", Selected_cfg, "Poweroff_en");
            NumericUpDown_poweron_time.DataBindings.Add("Value", Selected_cfg, "PowerOnTime");
            NumericUpDown_heart_rate.DataBindings.Add("Value", Selected_cfg, "Heart_Rate");
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 基站列表初始化
        private void AnchorInit()
        {
            int i = 0;
            for (i = 0; i < AnchorGroup.Length; i++)
            {
                AnchorList.Add(new Anchor(Anchor_IDstr[i]));
                if (i == 0)
                    AnchorList.First().IsUse = true;
                AnchorGroup[i] = new Anchor();   //初始化基站实例
            }            
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 历史数据通道数据表初始化
        private void DataTableInit()
        {
            int i, j;
            DataTable_Trace1 = new DataTable();
            DataTable_Trace1.Columns.Add("Time", typeof(string));
            DataTable_Trace1.Columns.Add("x", typeof(string));
            DataTable_Trace1.Columns.Add("y", typeof(string));
            DataTable_Trace1.Columns.Add("z", typeof(string));
            DataTable_Trace1.Columns.Add("A", typeof(string));
            DataTable_Trace1.Columns.Add("B", typeof(string));
            DataTable_Trace1.Columns.Add("C", typeof(string));
            DataTable_Trace1.Columns.Add("D", typeof(string));
            DataTable_Trace1.Columns.Add("E", typeof(string));
            DataTable_Trace1.Columns.Add("F", typeof(string));
            DataTable_Trace1.Columns.Add("G", typeof(string));
            DataTable_Trace1.Columns.Add("H", typeof(string));
            DataTable_Trace1.Columns.Add("I", typeof(string));
            DataTable_Trace1.Columns.Add("J", typeof(string));
            DataTable_Trace1.Columns.Add("K", typeof(string));
            DataTable_Trace1.Columns.Add("L", typeof(string));
            DataTable_Trace1.Columns.Add("M", typeof(string));
            DataTable_Trace1.Columns.Add("N", typeof(string));
            DataTable_Trace1.Columns.Add("O", typeof(string));
            DataTable_Trace1.Columns.Add("P", typeof(string));
            DataTable_Trace1.Columns.Add("Flag", typeof(string));
            DataTable_Trace1.Columns.Add("Velocity", typeof(string));
            for (i = 0; i < DataTable_MaxLen; i++)
            {
                DataRow dr = DataTable_Trace1.NewRow();
                for (j = 0; j < dr.ItemArray.Length; j++)
                    dr[j] = "0";  
                DataTable_Trace1.Rows.Add(dr);
            }

            DataTable_Trace2 = new DataTable();
            DataTable_Trace2.Columns.Add("Time", typeof(string));
            DataTable_Trace2.Columns.Add("x", typeof(string));
            DataTable_Trace2.Columns.Add("y", typeof(string));
            DataTable_Trace2.Columns.Add("z", typeof(string));
            DataTable_Trace2.Columns.Add("A", typeof(string));
            DataTable_Trace2.Columns.Add("B", typeof(string));
            DataTable_Trace2.Columns.Add("C", typeof(string));
            DataTable_Trace2.Columns.Add("D", typeof(string));
            DataTable_Trace2.Columns.Add("E", typeof(string));
            DataTable_Trace2.Columns.Add("F", typeof(string));
            DataTable_Trace2.Columns.Add("G", typeof(string));
            DataTable_Trace2.Columns.Add("H", typeof(string));
            DataTable_Trace2.Columns.Add("I", typeof(string));
            DataTable_Trace2.Columns.Add("J", typeof(string));
            DataTable_Trace2.Columns.Add("K", typeof(string));
            DataTable_Trace2.Columns.Add("L", typeof(string));
            DataTable_Trace2.Columns.Add("M", typeof(string));
            DataTable_Trace2.Columns.Add("N", typeof(string));
            DataTable_Trace2.Columns.Add("O", typeof(string));
            DataTable_Trace2.Columns.Add("P", typeof(string));
            DataTable_Trace2.Columns.Add("Flag", typeof(string));
            DataTable_Trace2.Columns.Add("Velocity", typeof(string));
            for (i = 0; i < DataTable_MaxLen; i++)
            {
                DataRow dr = DataTable_Trace2.NewRow();
                for (j = 0; j < dr.ItemArray.Length; j++)
                    dr[j] = "0";
                DataTable_Trace2.Rows.Add(dr);
            }

            
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 接收或发送的信息打印到窗口
        void printf_data(byte[] Frame, int Length,int T_R)   //打印串口数据
        {
            
            Int16 i_len; 
            StringBuilder s = new StringBuilder();
             
            if(T_R == 0) 
                s.Append("发送：");
            else 
                s.Append("接收：");
            for (i_len = 0; i_len < Length; i_len++)       //打印字符串
            {
               s.Append(Frame[i_len].ToString("X2"));
               s.Append(" ");
            }
            s.Append("[" + DateTime.Now.ToString("HH:mm:ss fff") + "]");
            s.Append("\r\n");
            string str_show = s.ToString();
            MethodInvoker mi = new MethodInvoker(() => 
            {
                if (textBox_com_data.Lines.Count() > 20)                
                    textBox_com_data.Clear();
                textBox_com_data.AppendText(str_show);
            });
            BeginInvoke(mi);
            /*
            textBox_com_data.Focus(); //获取焦点
            textBox_com_data.Select(textBox_com_data.TextLength, 0);//光标
            textBox_com_data.ScrollToCaret(); //滚动条*/
        }

        void printf_data(byte[] Frame, int Mode)
        {
            try
            {
                StringBuilder sb = new StringBuilder();                
                string Frame_str = Encoding.UTF8.GetString(Frame);
                Frame_str = Frame_str.Replace("\0", "");
                if (!string.IsNullOrEmpty(Frame_str))
                {
                    string time_now = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss fff");
                    sb.Append("[" + time_now + "]\r\n");
                    if (Mode == 1)
                        sb.Append("发送：");
                    if (Mode == 0)
                        sb.Append("接收：");
                    sb.Append(Frame_str);
                    Frame_str = sb.ToString();
                    MethodInvoker mi = new MethodInvoker(() =>
                    {
                        if (textBox_ATRecv.Lines.Length > 50)
                            textBox_ATRecv.Clear();
                        textBox_ATRecv.AppendText(sb.ToString());

                    });
                    BeginInvoke(mi);
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message);
            }
        }

        void printf_data(string s)
        {
            try
            {
                if (!AT_Recv_Message_Show)
                {
                    return;
                }
                if (!string.IsNullOrEmpty(s))
                {
                    StringBuilder sb = new StringBuilder();
                    string time_now = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss fff");
                    sb.Append("\r\n[" + time_now + "]\r\n");
                    sb.Append("接收：");
                    sb.Append(s);
                    MethodInvoker mi = new MethodInvoker(() =>
                    {
                        if (textBox_ATRecv.Lines.Length > 50)
                            textBox_ATRecv.Clear();
                        textBox_ATRecv.AppendText(sb.ToString());

                    });
                    BeginInvoke(mi);
                }
            }
            catch(Exception ex)
            {
                MessageBox.Show(ex.Message);
            }
        }
        #endregion
        /****************************************************/

        /// <summary>
        /// 两个字节组成一个无符号位16进制数
        /// </summary>
        /// <param name="hi">高八位</param>
        /// <param name="lo">低八位</param>
        /// <returns>无符号位16进制数</returns>
        private ushort Byte2Ushort(byte hi,byte lo)
        {
            return (ushort)(((ushort)(hi << 8) & 0xFF00) | lo);
        }

        /// <summary>
        /// 两个字节组成一个有符号位16进制数
        /// </summary>
        /// <param name="hi">高八位</param>
        /// <param name="lo">低八位</param>
        /// <returns>有符号位16进制数</returns>
        private short Byte2Short(byte hi, byte lo)
        {
            return (short)(((short)(hi << 8) & 0xFF00) | lo);
        }

        /****************************************************/
        #region 上位机发送数据

        /// <summary>
        /// 总发送数据 可根据当前连接状态更改通讯方式
        /// </summary>
        /// <param name="buff">要发送的数据</param>
        /// <param name="Mode">0 发送信息显示 1 接收信息显示</param>
        void APP_Send_Data(byte[] buff, int Mode)
        {
            if (Mode == 0)
                Task.Run(() => printf_data(buff, buff.Length, 0));  //显示发送信息
            else if (Mode == 1)
                Task.Run(() => printf_data(buff, 1));

            if (Connect_Mode == ConnectMode.TCP)
                Tcp_SendData(buff);
            else if (Connect_Mode == ConnectMode.USB)
                Serial_SendData(buff);
        }

        void APP_Send_Data(byte[] buff)
        {           
            Task.Run(() => printf_data(buff, buff.Length, 0));  //显示发送信息

            if (Connect_Mode == ConnectMode.TCP)
                Tcp_SendData(buff);
            else if (Connect_Mode == ConnectMode.USB)
                Serial_SendData(buff);
        }

        /// <summary>
        /// TCP发送数据
        /// </summary>
        /// <param name="buff">要发送的数据</param>
        void Tcp_SendData(byte[] buff)
        {         
            try
            {
                Tcp_dataClient.Send(buff);
            }
            catch
            {
                MessageBox.Show("TCP通讯错误", "提示");
                Tcp_dataClient.DisConnect(true);
                timer_SCAN_ID.Enabled = false;
                Connect_State = ConnectState.DisConnect;
                Task.Run(() => UI_ConnectChange());
                return;
            }
        }

        /// <summary>
        /// 串口发送数据
        /// </summary>
        /// <param name="buff">要发送的数据</param>
        void Serial_SendData(byte[] buff) 
        {
            try
            {
                serialPort1.Write(buff, 0, buff.Length);
            }
            catch
            {
                MessageBox.Show("串口通讯错误", "提示");
                serialPort1.Close();
                timer_SCAN_ID.Enabled = false;
                Connect_State = ConnectState.DisConnect;
                Task.Run(() => UI_ConnectChange());
                return;
            }

        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 二维地图与波形图画图的初始化函数
        void Drawing_init()   //画图初始化函数
        {
            //画图初始化    
            Draw_Config_init();                          //画图参数初始化
            GDI_Rtls_Draw = new GDI_DrawHelper();
            
            GDI_Rtls_Draw.Draw_config_Init(pictureBox_2d.Width, pictureBox_2d.Height);
            GDI_Rtls_Draw.Set_Map_Config(400, pictureBox_2d.Height / 2, 0, 0);
            GDI_Rtls_Draw.Draw_Clear();

            //显示在pictureBox1控件中
            this.pictureBox_2d.Image = GDI_Rtls_Draw.Get_Bitmap();

            //数据波形图初始化
            PlotHelper_CH1 = new OxyPlotHelper("通道一波形图", ANCHOR_MAX_COUNT, 100);
            PlotHelper_CH1.InitAxes();
            PlotHelper_CH2 = new OxyPlotHelper("通道二波形图", ANCHOR_MAX_COUNT, 100);
            PlotHelper_CH2.InitAxes();
            PlotHelper_Cir = new OxyPlotHelper("CIR图", 2, Cir_work_t.CIR_MAX_NUM);
            PlotHelper_Cir.InitAxes(false);  //不是时间-测距轴

            for (int i = 0; i < ANCHOR_MAX_COUNT; i++)
            {
                PlotHelper_CH1.AddLineConfig(OxyColor.FromRgb(plot_colors[i, 0], plot_colors[i, 1], plot_colors[i, 2]), Anchor_IDstr[i]);
                PlotHelper_CH2.AddLineConfig(OxyColor.FromRgb(plot_colors[i, 0], plot_colors[i, 1], plot_colors[i, 2]), Anchor_IDstr[i]);
            }
            PlotHelper_CH1.InitLines();  //根据添加的线系列标识初始化线系列，并添加到画图模型中
            PlotHelper_CH2.InitLines();  //根据添加的线系列标识初始化线系列，并添加到画图模型中
            plotView_CH1.Model = PlotHelper_CH1.Plot;  //注入画图模型到ui
            plotView_CH2.Model = PlotHelper_CH2.Plot;  //注入画图模型到ui

            PlotHelper_Cir.AddLineConfig(OxyColors.BlueViolet, "Cir值", true);
            //PlotHelper_Cir.AddLineConfig(OxyColors.Red, "FP_idx");
            PlotHelper_Cir.InitLines();  //根据添加的线系列标识初始化线系列，并添加到画图模型中
            PlotView_Cir.Model = PlotHelper_Cir.Plot;  //注入画图模型到ui
            PlotView_Cir.Model.Legends.Add(new Legend());  //加入图例 这样才有注解
            Anc_PlotIntroduce_Init();  //画出波形图颜色说明

        }

        /// <summary>
        /// 波形图颜色说明 -直接画图说明
        /// </summary>
        void Anc_PlotIntroduce_Init()
        {
            //波形图颜色说明
            //画图初始化    
            bMap_BX_P = new Bitmap(pictureBox_introduce.Width, pictureBox_introduce.Height);
            gph_BX_P = Graphics.FromImage(bMap_BX_P);
            gph_BX_P.Clear(Color.White);
            Pen draw_pen;
            for(int i = 0; i < ANCHOR_MAX_COUNT; i++)
            {
                draw_pen = new Pen(Color.FromArgb(plot_colors[i, 0], plot_colors[i, 1], plot_colors[i, 2]), 2);
                gph_BX_P.DrawLine(draw_pen, 0, 25 + i * 25, pictureBox_introduce.Width, 25 + i * 25);
                gph_BX_P.DrawString(Anchor_IDstr[i], new Font("宋体", 12), Brushes.Black, 14, 5 + i * 25);  //画字
            }

            this.pictureBox_introduce.Image = bMap_BX_P;
        }



        #endregion
        /****************************************************/

        /****************************************************/
        #region 波形图画图函数

        /// <summary>
        /// 波形图1画图函数
        /// </summary>
        void Drawing_Boxing1_Update(uint[] y_values)
        {
            DateTime time_now = DateTime.Now;
            for(int i = 0;i < y_values.Length; i++)            
                PlotHelper_CH1.AddPoint(time_now, (double)y_values[i] / 100, i);
            PlotHelper_CH1.RefreshPlot();
        }

        /// <summary>
        /// 波形图2画图函数
        /// </summary>
        void Drawing_Boxing2_Update(uint[] y_values)
        {
            DateTime time_now = DateTime.Now;
            for (int i = 0; i < y_values.Length; i++)
                PlotHelper_CH2.AddPoint(time_now, (double)y_values[i] / 100, i);
            PlotHelper_CH2.RefreshPlot();
        }

        private void numericUpDown_CH1_max_ValueChanged(object sender, EventArgs e)
        {
            double max = (double)numericUpDown_CH1_max.Value;
            PlotHelper_CH1.Set_YAxis_Max(max);
        }

        private void numericUpDown_CH2_max_ValueChanged(object sender, EventArgs e)
        {
            double max = (double)numericUpDown_CH2_max.Value;
            PlotHelper_CH2.Set_YAxis_Max(max);
        }


        private void button_CH1_Reset_Click(object sender, EventArgs e)
        {
            PlotHelper_CH1.ResetDisplay();
        }

        private void button_CH2_Reset_Click(object sender, EventArgs e)
        {
            PlotHelper_CH2.ResetDisplay();
        }

        #endregion
        /****************************************************/

        /****************************************************/
        #region 点对点 测距模式下画图函数 除了标签都画 
        void Drawing_update_one_to_one()  
         {
            int i;
            GDI_Rtls_Draw.Draw_Clear();

            //载入地图
            if (GDI_Rtls_Draw.Has_Map)
            {
                GDI_Rtls_Draw.Draw_Map();
            }

            //画坐标轴 
            if (checkBox_axis.Checked == true)
                GDI_Rtls_Draw.Draw_Axis();

            //画基站
            if (checkBox_name.Checked == true)
            {
                for (i = 0; i < AnchorGroup.Length; i++)  //画基站
                {
                    Anchor a = AnchorGroup[i];
                    if (a.IsUse)
                    {
                        GDI_Rtls_Draw.Draw_Anchor((int)a.x, (int)a.y, (char)(0x41 + i) + "基站", 40);
                        //Drawing_draw_bs((Int16)(a.x / map_multiple + Axis_origin_x), (Int16)(Draw_size_y - (a.y / map_multiple + Axis_origin_y)));
                        //gph.DrawString((char)(0x41 + i) + "基站", new Font("宋体", 10), Brushes.Black, new PointF((float)(a.x / map_multiple + Axis_origin_x - 12), (float)(Draw_size_y - (a.y / map_multiple - 18 + Axis_origin_y))));
                    }
                }
            }

            //测距圆勾选 
            if (checkBox_draw_round.Checked == true)
            {
                UInt16 dis_buff;
                for (i = 0; i < AnchorGroup.Length; i++)
                {
                    if (!AnchorGroup[i].IsUse)
                        continue;
                    int Draw_Tag_Id = -1;
                    if (comboBox_CircleTag.SelectedIndex != -1)
                        Draw_Tag_Id = Convert.ToInt32(comboBox_CircleTag.SelectedItem.ToString());
                    if (Draw_Tag_Id == -1)
                        continue;
                    Tag t = FindTag(Draw_Tag_Id);
                    if (t != null)
                    {
                        dis_buff = Convert.ToUInt16(t.Dist[i]);
                        GDI_Rtls_Draw.Draw_DistCircle((int)AnchorGroup[i].x, (int)AnchorGroup[i].y, dis_buff);
                        //gph.DrawEllipse(Pens.Red, ((float)((AnchorGroup[i].x - dis_buff) / map_multiple) + Axis_origin_x), (float)(Draw_size_y - (((AnchorGroup[i].y + dis_buff) / map_multiple) + Axis_origin_y)), dis_buff * 2 / map_multiple, dis_buff * 2 / map_multiple);
                    }
                }
            }

            if (Is_NaviSelecting)  //选择定位点中 显示当前鼠标代表的真实位置坐标
            {
                GDI_Rtls_Draw.Draw_cursor_tx((int)GDI_Rtls_Draw.Mouse_LastPoint[0], (int)GDI_Rtls_Draw.Mouse_LastPoint[1]);
            }

            if (Is_SelectNavi)  //已经选中目标点 显示目标图标
            {
                GDI_Rtls_Draw.Draw_Target_Image((int)Target_real_pos_x, (int)Target_real_pos_y, DRAW_TARGET_SIZE);
            }

        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 二维定位画图函数
        //清除画面
        void Draw_Render()
        {
            int i;
            GDI_Rtls_Draw.Draw_Clear();

            //载入地图
            if (GDI_Rtls_Draw.Has_Map)
            {
                GDI_Rtls_Draw.Draw_Map();
            }

            //画坐标轴 
            if (checkBox_axis.Checked == true)
                GDI_Rtls_Draw.Draw_Axis();

            //画基站
            if (checkBox_name.Checked == true)
            {                
                for (i = 0; i < AnchorGroup.Length; i++)  //画基站
                {
                    Anchor a = AnchorGroup[i];
                    if (a.IsUse)
                    {
                        GDI_Rtls_Draw.Draw_Anchor((int)a.x, (int)a.y, (char)(0x41 + i) + "基站", 40);
                        //Drawing_draw_bs((Int16)(a.x / map_multiple + Axis_origin_x), (Int16)(Draw_size_y - (a.y / map_multiple + Axis_origin_y)));
                        //gph.DrawString((char)(0x41 + i) + "基站", new Font("宋体", 10), Brushes.Black, new PointF((float)(a.x / map_multiple + Axis_origin_x - 12), (float)(Draw_size_y - (a.y / map_multiple - 18 + Axis_origin_y))));
                    }
                }
            }

            //测距圆勾选 
            if (checkBox_draw_round.Checked == true)
            {
                UInt16 dis_buff;
                for (i = 0; i < AnchorGroup.Length; i++)
                {
                    if (!AnchorGroup[i].IsUse)
                        continue;
                    int Draw_Tag_Id = -1;
                    if (comboBox_CircleTag.SelectedIndex != -1)
                        Draw_Tag_Id = Convert.ToInt32(comboBox_CircleTag.SelectedItem.ToString());
                    if (Draw_Tag_Id == -1)
                        continue;
                    Tag t = FindTag(Draw_Tag_Id);
                    if (t != null)
                    {
                        dis_buff = Convert.ToUInt16(t.Dist[i]);
                        GDI_Rtls_Draw.Draw_DistCircle((int)AnchorGroup[i].x, (int)AnchorGroup[i].y, dis_buff);
                        //gph.DrawEllipse(Pens.Red, ((float)((AnchorGroup[i].x - dis_buff) / map_multiple) + Axis_origin_x), (float)(Draw_size_y - (((AnchorGroup[i].y + dis_buff) / map_multiple) + Axis_origin_y)), dis_buff * 2 / map_multiple, dis_buff * 2 / map_multiple);
                    }
                }
            }

            //选择定位点中 显示当前鼠标代表的真实位置坐标
            if (Is_NaviSelecting)  
            {
                GDI_Rtls_Draw.Draw_cursor_tx((int)GDI_Rtls_Draw.Mouse_LastPoint[0], (int)GDI_Rtls_Draw.Mouse_LastPoint[1]);
            }

            //已经选中目标点 显示目标图标
            if (Is_SelectNavi)  
            {
                GDI_Rtls_Draw.Draw_Target_Image((int)Target_real_pos_x, (int)Target_real_pos_y, DRAW_TARGET_SIZE);
            }

            //画标签
            for (i = 0; i < TagList.Count; i++)
            {
                Tag t = TagList[i];
                if (t == null)
                    continue;
                //t.x += 1;
                //t.y += 1;
                if (t.IsNavi)
                {
                    if (GDI_Rtls_Draw.Has_trace)
                    {
                        GDI_Rtls_Draw.Draw_Tag(Color.FromArgb(0x22,0xB1,0x4C), (int)t.x, (int)t.y, Tag_Size / 2, true);
                    }
                    GDI_Rtls_Draw.Draw_Navi_tag((int)t.x, (int)t.y, 32, t.Navi_angle);
                }
                else  //普通标签显示
                {
                    Color tag_color = Color.Black;
                    if ((i % 2) == 1)
                    {
                        if (t.IsAlarm)
                        {
                            if (t.Alarm_count < 2)
                            {
                                tag_color = Color.Blue;
                                t.Alarm_count++;
                            }
                            else if (t.Alarm_count < 4)
                            {
                                tag_color = Color.Yellow;
                                t.Alarm_count++;
                            }
                            else
                            {
                                tag_color = Color.Blue;
                                t.Alarm_count = 0;
                            }
                        }
                        else
                        {
                            tag_color = Color.Blue;
                            t.Alarm_count = 0;
                        }
                    }
                    else
                    {
                        if (t.IsAlarm)
                        {
                            if (t.Alarm_count < 2)
                            {
                                tag_color = Color.Red;
                                t.Alarm_count++;
                            }
                            else if (t.Alarm_count < 4)
                            {
                                tag_color = Color.Yellow;
                                t.Alarm_count++;
                            }
                            else
                            {
                                tag_color = Color.Red;
                                t.Alarm_count = 0;
                            }
                        }
                        else
                        {
                            tag_color = Color.Red;
                            t.Alarm_count = 0;
                        }
                    }

                    GDI_Rtls_Draw.Draw_Tag(tag_color, (int)t.x, (int)t.y, Tag_Size, GDI_Rtls_Draw.Has_trace);
                }
               

                if (checkBox_coordinate.Checked == true) //画标签坐标
                { 
                    string show_str = $"({t.x}cm,{t.y}cm) {t.Velocity} cm/s\r\n标签{t.Id}";
                    GDI_Rtls_Draw.Draw_Tag_tx(show_str, (int)(t.x), (int)(t.y));     
                }
            }
            if (GDI_Rtls_Draw.Has_trace)
            {
                GDI_Rtls_Draw.Draw_TagRecord();
            }


            pictureBox_2d.Image = GDI_Rtls_Draw.Get_Bitmap();

        }

        #endregion
        /****************************************************/

        /****************************************************/
        #region 当窗口运行时加载图形界面函数
        private void Form1_Load(object sender, EventArgs e) //加载界面程序
        {
            //int real, imagine;
           
            //real = (int)((int)0x24 | ((int)0x00 << 8) | ((int)(0x00 & 0x03) << 16));
            //imagine = (int)((int)0xC0 | ((int)0xFF << 8) | ((int)(0xFF & 0x03) << 16));
            //if ((real & 0x020000) > 0)
            //{
            //    real = (int)(real | 0xFFFC0000);
            //}
            //if ((imagine & 0x020000) > 0)
            //{
            //    imagine = (int)(imagine | 0xFFFC0000);
            //}


            Resize_Init();
            Drawing_init();//画图初始化
            //数据通道表1初始化
            Data_channel1 = new DataGrid_SplitHelper(DataTable_MaxLen, 100);
            label_GJ1_allpage.Text = Data_channel1.All_page.ToString();
            Data_channel1.Refresh(DataTable_Trace1, dataGridView_GJ1);
            //数据通道表2初始化
            Data_channel2 = new DataGrid_SplitHelper(DataTable_MaxLen, 100);
            label_GJ2_allpage.Text = Data_channel2.All_page.ToString();
            Data_channel2.Refresh(DataTable_Trace2, dataGridView_GJ2);
            //测距数据分析初始化
            Data_analyze = new DataGrid_SplitHelper(DataTable_MaxLen, 100);
            label_anal_allpage.Text = Data_analyze.All_page.ToString();

            dataGridView_TAG.Rows.Add(); //添加行
            for (int j = 0; j < dataGridView_TAG.Columns.Count; j++)
            {
                dataGridView_TAG.Rows[0].Cells[j].Value = 0;
            }

            DataGridView_tag_cfg.ClearSelection();

            //搜索串口
            Search_Port();


        }

        private void Resize_Init()
        {
            //ResizeHelper.Form_Width = this.Width;
            //ResizeHelper.Form_Height = this.Height;
            //ResizeHelper.controllInitializeSize(this);
            //ResizeHelper.Get_SceenSize();
            //this.MaximumSize = new Size(ResizeHelper.Screen_Width, ResizeHelper.Screen_Height);
            //this.MinimumSize = new Size((int)(ResizeHelper.Screen_Width * 0.4), (int)(ResizeHelper.Screen_Height * 0.4));
            //ResizeHelper.SetTag(this);
        }

        #endregion
        /****************************************************/

        /****************************************************/
        #region 监听windows发来的服务信息 判断串口插拔
        /// <summary>
        /// 重写接收windows系统消息的处理 实现对串口拔插的反应
        /// </summary>
        /// <param name="m"></param>       
        protected override void WndProc(ref Message m)
        {
            base.WndProc(ref m);
            switch (m.Msg)
            {
                case 0x219:  //有设备改变的事件发生
                    {
                        if((int)m.WParam == 0x8004)  //设备移除
                        {
                            if (serialPort1.IsOpen == false && Connect_State != ConnectState.DisConnect 
                                && Connect_Mode == ConnectMode.USB)  //正在连接的串口断开了
                            {
                                //全部回到初始状态
                                Serial_Close_Handler();
                                MessageBox.Show("串口已断开！");
                            }
                                
                        }                        
                        break;
                    }
                default:break;
            }
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 关闭窗口前先停止定位
        private void Form1_FormClosing(object sender, FormClosingEventArgs e)
        {
            //已弃用
            /* 如果定位中 则先执行停止定位 */
            //if (Work_State == WorkState.Rtlsing)
            //{
            //    int retry_times = 0;
            //    modbus.ModbusID = NOW_ID;
            //    modbus.Addr = 0x28;
            //    modbus.FunctionCode = 0x10;
            //    modbus.RegNum = 1;

            //    byte[] temp = new byte[2];
            //    temp[0] = 0x00;
            //    temp[1] = 0x00;
            //    byte[] send_buff = ModbusRTU.ModubsHelper.Modbus10Send(modbus, temp);
            //    if (send_buff != null)
            //    {
            //        Work_State = WorkState.RtlsStop;
            //        do
            //        {
            //            Thread.Sleep(100);
            //            APP_Send_Data(send_buff, 0);
            //            retry_times++;
            //        }
            //        while (Work_State != WorkState.Idle && serialPort1.IsOpen && retry_times > 10);
            //    }

            //    timer_display.Enabled = false;
            //}

        }
        #endregion
        /****************************************************/
        
        /****************************************************/
        #region 接收数据处理
        /// <summary>
        /// TCP接收处理
        /// </summary>
        /// <param name="Recv_byte">接收到的数据</param>
        /// <param name="recv_len">接收到的长度</param>
        void Tcp_RecvHandler(byte[] Recv_byte, int recv_len)
        {
            lock (Recv_lock)
            {
                if (recv_buffer.Count + recv_len > recv_buffer_max)  //缓存超过字节数 先丢弃前面的字节           
                    recv_buffer.RemoveRange(0, recv_buffer_max);
                byte[] temp = new byte[recv_len];
                Array.Copy(Recv_byte, 0, temp, 0, recv_len);
                //存入缓存区
                recv_buffer.AddRange(temp);  
                RecvThread_Are.Set();
            }
           
            
            //Data_RecvHandler(ref tcp_recv_buffer);
        }

        /*
           说明：串口接收的另一种写法 不靠延时而是开辟缓存区 根据具体协议内容获取一帧数据
                 现默认使用这个方式来做接收中断处理 如想用回以前的 需要对应更改串口接收中断的注册事件
           修改日期：2021/6/6
         */
        private void SerialDataReceive(object sender, SerialDataReceivedEventArgs e)
        {
            if (serialPort1.IsOpen == false)
            {
                serialPort1.Close();
                return;
            }

            int Byte_len = serialPort1.BytesToRead;
            if (Byte_len <= 0)
                return;
            byte[] Recv_byte = new byte[Byte_len];
            serialPort1.Read(Recv_byte, 0, Byte_len);

            lock (Recv_lock)
            {
                if (recv_buffer.Count > recv_buffer_max)  //缓存超过字节数 先丢弃前面的字节           
                    recv_buffer.RemoveRange(0, recv_buffer_max);

                recv_buffer.AddRange(Recv_byte);  //存入缓存区
                RecvThread_Are.Set();
            }

            
            //Data_RecvHandler(ref sp_buffer);
        }

        /// <summary>
        /// 对接收到的数据根据协议判断处理线程
        /// </summary>
        private void Data_RecvHandler()
        {

            while (true)
            {
                RecvThread_Are.WaitOne();
                bool Is_Modbus = false;
                if (recv_buffer.Count >= 4)
                {
                    while (recv_buffer.Count >= 4)
                    {
                        byte[] ReceiveByte = new byte[1];
                        int ReceieveByte_length = -1;
                        Is_Modbus = false;
                        if (recv_buffer[0] == ModbusRTU.Instance.Modbus_com.ModbusID)
                        {
                            //接收到modbus数据
                            //判断是否Modbus功能码
                            if (recv_buffer[1] == 0x03 || recv_buffer[1] == 0x10 
                                || recv_buffer[1] == 0x06 || recv_buffer[1] == 0x41 || recv_buffer[1] == 0x42)
                            {
                                Is_Modbus = true;
                                if (recv_buffer[1] == 0x03)  //根据第三个字节来取缓存区的字节数
                                {
                                    int len = recv_buffer[2];
                                    ReceieveByte_length = len + 5;
                                    if (ReceieveByte_length > recv_buffer.Count)  //还没接收完全
                                        break;
                                    ReceiveByte = new byte[ReceieveByte_length];
                                }
                                else if (recv_buffer[1] == 0x10 || recv_buffer[1] == 0x06)  //总数固定为8字节
                                {
                                    ReceieveByte_length = 8;
                                    if (ReceieveByte_length > recv_buffer.Count)  //还没接收完全
                                        break;
                                    ReceiveByte = new byte[ReceieveByte_length];
                                }
                                else if (recv_buffer[1] == 0x41)
                                {
                                    ReceieveByte_length = 6;
                                    if (ReceieveByte_length > recv_buffer.Count)  //还没接收完全
                                        break;
                                    ReceiveByte = new byte[ReceieveByte_length];
                                }
                                else if (recv_buffer[1] == 0x42)
                                {
                                    if (recv_buffer[2] == 0xA0)
                                    {
                                        if (recv_buffer.Count < 6) //还没接收完全
                                        {
                                            break;
                                        }
                                        ReceieveByte_length = (ushort)(recv_buffer[4] << 8 | recv_buffer[5]) + 8;
                                        if (ReceieveByte_length > recv_buffer.Count)  //还没接收完全
                                            break;
                                        ReceiveByte = new byte[ReceieveByte_length];
                                    }
                                    else if (recv_buffer[2] == 0xA1)
                                    {
                                        ReceieveByte_length = 5;
                                        if (ReceieveByte_length > recv_buffer.Count)  //还没接收完全
                                            break;
                                        ReceiveByte = new byte[ReceieveByte_length];
                                    }
                                }
                                else if(recv_buffer[1] == 0x43)
                                {
                                    if (recv_buffer.Count < 6) //还没接收完全
                                    {
                                        break;
                                    }
                                    ReceieveByte_length = 6;
                                    if (ReceieveByte_length > recv_buffer.Count)  //还没接收完全
                                        break;
                                    ReceiveByte = new byte[ReceieveByte_length];
                                }
                                recv_buffer.CopyTo(0, ReceiveByte, 0, ReceieveByte_length);  //获取符合协议的帧数据以解析
                                recv_buffer.RemoveRange(0, ReceieveByte_length);  //需要从缓存区中删除该数据
                                                                                  
                                Task.Run(() => printf_data(ReceiveByte, ReceieveByte_length, 1));  //显示数据
                                switch (ModbusRTU.Instance.Modbus_com.FunctionCode)
                                {
                                    case 0x03:
                                        {
                                            ReceiveState state = ReceiveState.RecvOk;
                                            if (Work_State == WorkState.Idle || Work_State == WorkState.Rtlsing
                                                || Work_State == WorkState.AutoCalibPos || Work_State == WorkState.Cir_testing 
                                                || Work_State == WorkState.Remote_cfg)
                                                state = ModbusRTU.Instance.Modbus03Recv(ReceiveByte, ReceieveByte_length, false);
                                            else
                                                state = ModbusRTU.Instance.Modbus03Recv(ReceiveByte, ReceieveByte_length, true);

                                            if (state == ReceiveState.RecvOk)
                                                Modbus03Recv_Handler(ReceiveByte, ReceieveByte_length);
                                            else  //协议判断不正确 继续接收下面的
                                                continue;
                                            break;
                                        }
                                    case 0x10:
                                        {
                                            ReceiveState state = ModbusRTU.Instance.Modbus10Recv(ReceiveByte, ReceieveByte_length, true);
                                            if (state == ReceiveState.RecvOk)
                                                Modbus10Recv_Handler(ReceiveByte, ReceieveByte_length);
                                            else //协议判断不正确 继续接收下面的
                                                continue;
                                            break;
                                        }
                                    case 0x06:
                                        {
                                            ReceiveState state = ModbusRTU.Instance.Modbus06Recv(ReceiveByte, ReceieveByte_length);
                                            if (state == ReceiveState.RecvOk)
                                                Modbus06Recv_Handler();
                                            else //协议判断不正确 继续接收下面的
                                                continue;
                                            break;
                                        }
                                    case 0x41: //自定义功能码：请求获取cir数据
                                        {
                                            ReceiveState state = ModbusRTU.Instance.Modbus_Custom_Recv(ReceiveByte, ReceieveByte_length);
                                            if (state == ReceiveState.RecvOk)
                                                Modbus41Recv_Handler(ReceiveByte);
                                            else //协议判断不正确 继续接收下面的
                                                continue;
                                            break;
                                        }
                                    case 0x42:  //自定义功能码：分包获取cir数据
                                        {
                                            ReceiveState state = ModbusRTU.Instance.Modbus_Custom_Recv(ReceiveByte, ReceieveByte_length);
                                            if (state == ReceiveState.RecvOk)
                                                Modbus42Recv_Handler(ReceiveByte, ReceieveByte_length);
                                            else //协议判断不正确 继续接收下面的
                                                continue;
                                            break;
                                        }
                                    case 0x43:  //自定义功能码：远程配置标签发送
                                        {
                                            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x03;
                                            break;
                                        }
                                    default:
                                        break;
                                }
                            }
                            else
                            {
                                //第一个是ID但跟着的不是功能码 
                                Is_Modbus = false;
                            }
                        }

                        if (!Is_Modbus)
                        {
                            //不是Modbus协议 可能是自由协议                      
                            if ((recv_buffer[0] == 'A' && recv_buffer[1] == 'T') ||
                                (recv_buffer[0] == 'O' && recv_buffer[1] == 'K') ||
                                (recv_buffer[0] == 'D' && recv_buffer[1] == 'i') ||
                                (recv_buffer[0] == 'R' && recv_buffer[1] == 't'))
                            {
                                //符合需要的自由协议 找帧结尾有没有0D 0A
                                int idx_d, idx_a;
                                idx_d = recv_buffer.IndexOf(0x0D);
                                idx_a = recv_buffer.IndexOf(0x0A);
                                if (idx_d != -1 && idx_a != -1)
                                {
                                    if (idx_a - idx_d == 1)
                                    {
                                        ReceieveByte_length = idx_a + 1;
                                        ReceiveByte = new byte[ReceieveByte_length];
                                        recv_buffer.CopyTo(0, ReceiveByte, 0, ReceieveByte_length);  //获取符合协议的帧数据以解析
                                        recv_buffer.RemoveRange(0, ReceieveByte_length);  //需要从缓存区中删除该数据

                                        if ((ReceiveByte[0] == 'D' && ReceiveByte[1] == 'i') ||
                                          (ReceiveByte[0] == 'R' && ReceiveByte[1] == 't'))
                                        {
                                            if (Connect_State == ConnectState.Connected && Module_Mode == ModuleMode.tag)
                                                Tag_RtlsDataRecv(ReceiveByte, 1);
                                        }
                                        else
                                        {
                                            if (AT_Recv_Message_Show)
                                                Task.Run(() => printf_data(ReceiveByte, 0));  //打印获取到的字符

                                            AT.ATRecvState recvState = AT.AT_Recv(ReceiveByte);
                                            if (recvState == AT.ATRecvState.Error)
                                                MessageBox.Show("发送失败！");
                                            else if (recvState == AT.ATRecvState.Good)
                                            {
                                                if (AT_Recv_Show_Tips)
                                                {
                                                    MessageBox.Show("发送成功！");
                                                }
                                                else
                                                {
                                                    AT_Send_Fin_Time = 0;
                                                    MethodInvoker mi = new MethodInvoker(() =>
                                                    {
                                                        label_ATSendOK.Visible = true;
                                                        pictureBox_ATSendOK.Visible = true;
                                                        timer_ATSendOK.Enabled = true;
                                                        timer_ATSendOK.Start();
                                                    });
                                                    BeginInvoke(mi);
                                                }
                                            }
                                        }
                                    }
                                    else
                                        break;
                                }
                                else
                                {
                                    recv_buffer.RemoveAt(0);
                                }
                            }
                            else  //都不是 去除这个字节
                                recv_buffer.RemoveAt(0);

                        }

                    }
                }
            }
            
        }

        #endregion
        /****************************************************/

        /****************************************************/
        #region 串口接收中断函数 旧 已弃用
        /*
         *  说明：旧串口接收中断函数 采用固定延时来获取全下位机发来的数据
         *  使用TTL转串口 及使用不同串口波特率时候需要微调参数
         *  2021/6/6后改用新接收方式 该方式不再同步更新
         */
        [Obsolete]
        private void SerDataReceive(object sender, SerialDataReceivedEventArgs e)  //串口接收数据程序
        {
            if (serialPort1.IsOpen == false)
            {
                serialPort1.Close();
                return;
            }
            
            try
            {

                while (serialPort1.BytesToRead > 4 && serialPort1.IsOpen)
                {
                    //根据数据量和不同情况设定少量延时时间
                    //延时是为了上位机能够接收全单片机发过来的数据
                    if (Connect_State == ConnectState.Connecting)
                    {
                        Thread.Sleep((Int32)(Flag_BaudRate_Delay[Flag_BaudRate]) * 30);
                    }
                    else
                    {
                        if (Module_Mode != ModuleMode.tag)
                            Thread.Sleep((Int32)(Flag_BaudRate_Delay[Flag_BaudRate]) * 4);
                        else
                            Thread.Sleep((Int32)(Flag_BaudRate_Delay[Flag_BaudRate]) * 15);
                    }

                    int Receievebuff_length = 0;
                    byte[] ReceiveByte = new byte[serialPort1.BytesToRead];   //串口数据接收数组

                    int FirstByte = serialPort1.ReadByte();
                    if (FirstByte == -1)
                        return;
                    int SecondByte = serialPort1.ReadByte();
                    if (SecondByte == -1)
                        return;
                    //判断是否Modbus功能码
                    if (SecondByte == 0x03 || SecondByte == 0x10 || SecondByte == 0x06)
                    {
                        if (SecondByte == 0x03)  //根据第三个字节来取缓存区的字节数
                        {
                            int len = serialPort1.ReadByte();
                            if (len == -1)
                                return;
                            ReceiveByte = new byte[len + 5];
                            ReceiveByte[0] = (byte)FirstByte;
                            ReceiveByte[1] = (byte)SecondByte;
                            ReceiveByte[2] = (byte)len;
                            Receievebuff_length = serialPort1.Read(ReceiveByte, 3, len + 2);
                            Receievebuff_length += 3;
                        }
                        if (SecondByte == 0x10 || SecondByte == 0x06)  //总数固定为8字节
                        {
                            ReceiveByte = new byte[8];
                            ReceiveByte[0] = (byte)FirstByte;
                            ReceiveByte[1] = (byte)SecondByte;
                            Receievebuff_length = serialPort1.Read(ReceiveByte, 2, 6);
                            Receievebuff_length += 2;
                        }
                        //if (e.EventType == SerialData.Eof)  //避免在0x1A报错
                        //    return;
                        Task.Run(() => printf_data(ReceiveByte, Receievebuff_length, 1));
                        switch (ModbusRTU.Instance.Modbus_com.FunctionCode)
                        {
                            case 0x03:
                                {
                                    ReceiveState state = ModbusRTU.Instance.Modbus03Recv(ReceiveByte, Receievebuff_length, true);
                                    if (state == ReceiveState.RecvOk)
                                        Modbus03Recv_Handler(ReceiveByte, Receievebuff_length);
                                    else
                                        serialPort1.DiscardInBuffer();
                                    break;
                                }
                            case 0x10:
                                {
                                    ReceiveState state = ModbusRTU.Instance.Modbus10Recv(ReceiveByte, Receievebuff_length, true);
                                    if (state == ReceiveState.RecvOk)
                                        Modbus10Recv_Handler(ReceiveByte, Receievebuff_length);
                                    else
                                        serialPort1.DiscardInBuffer();
                                    break;
                                }
                            case 0x06:
                                {
                                    ReceiveState state = ModbusRTU.Instance.Modbus06Recv(ReceiveByte, Receievebuff_length);
                                    if (state == ReceiveState.RecvOk)
                                        Modbus06Recv_Handler();
                                    else
                                        serialPort1.DiscardInBuffer();
                                    break;
                                }
                            default:
                                break;
                        }
                    }
                    else     //自由协议 读取直到遇到了换行符
                    {
                        ReceiveByte[0] = (byte)FirstByte;
                        ReceiveByte[1] = (byte)SecondByte;
                        Receievebuff_length = 2;
                        while (ReceiveByte[Receievebuff_length - 2] != 0x0D && ReceiveByte[Receievebuff_length - 1] != 0x0A)
                        {
                            int next_byte = serialPort1.ReadByte();
                            if (next_byte == -1)
                                return;
                            ReceiveByte[Receievebuff_length++] = (byte)next_byte;
                        }

                        if (AT_Recv_Message_Show)
                            Task.Run(() => printf_data(ReceiveByte,0));  //打印获取到的字符

                        AT.ATRecvState recvState = AT.AT_Recv(ReceiveByte);
                        if (recvState == AT.ATRecvState.Error)
                            MessageBox.Show("发送失败！");
                        else if(recvState == AT.ATRecvState.Good)
                        {
                            if (AT_Recv_Show_Tips)
                            {
                                MessageBox.Show("发送成功！");
                            }
                            else
                            {
                                if (recvState == AT.ATRecvState.Good)
                                {
                                    AT_Send_Fin_Time = 0;
                                    MethodInvoker mi = new MethodInvoker(() =>
                                    {
                                        label_ATSendOK.Visible = true;
                                        pictureBox_ATSendOK.Visible = true;
                                        timer_ATSendOK.Enabled = true;
                                        timer_ATSendOK.Start();
                                    });
                                    BeginInvoke(mi);
                                }
                            }
                        }
                        


                    }
                }
                
        
            }
            catch
            {

            }     
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region Modbus03码接收处理
        private void Modbus03Recv_Handler(byte[] temp, int length)
        {
            //根据具体模式来写不同的判断  
            switch (Work_State)
            {
                case WorkState.ReadConfig:  //读取配置
                    {
                        if (length < 241)
                            break;
                        do
                        {
                            int i;
                            
                            /* 先判断版本信息 */
                            if (temp[225] != App_Version)//若为版本以外的
                            {
                                if (temp[225] == 0)
                                {
                                    //可能是旧版本
                                    MessageBox.Show($"该固件版本为V{temp[213] / 10}.{temp[213] % 10}\r\n" +
                                        $"不支持此设备固件版本，请使用V{App_Version / 10}.{App_Version % 10}固件版本的设备，请关闭软件谢谢！", "提示");
                                }
                                else
                                {
                                    MessageBox.Show($"不支持此设备固件版本，请使用V{App_Version / 10}.{App_Version % 10}固件版本的设备，请关闭软件谢谢！", "提示");
                                }
                                Connect_State = ConnectState.Connect_WrongVersion;
                                break;
                            }
                            if (((temp[226] >> 4) & 0x03) != Software_structure)
                            {
                                Connect_State = ConnectState.Connect_WrongVersion;
                                MessageBox.Show($"该固件版本为V{App_Version / 10}.{App_Version % 10}B配置固件\r\n" +
                                    $"该软件为C配置软件，请使用V{App_Version / 10}.{App_Version % 10}C配置固件对应设备，请关闭软件谢谢！", "提示");
                                break;
                            }
                            /* 对应界面改变 */
                            MethodInvoker mi = new MethodInvoker(() =>
                            {

                                if (!Get_ModuleVersion)
                                {
                                    if (temp[226] >> 6 == 3)
                                    {
                                        numericUpDown_uwb_trim.Maximum = 63;
                                        Module_use_chip = Module_Chip_t.DW3000;
                                    }
                                    else
                                    {
                                        numericUpDown_uwb_trim.Maximum = 31;
                                        Module_use_chip = Module_Chip_t.DW1000;
                                    }
                                    toolStripStatusLabel__firmware_version.Text = $"设备固件版本：V{temp[225] / 10}.{temp[225] % 10}C + {Module_catalogue[temp[226] & 0x0F]}";
                                    Get_ModuleVersion = true;
                                }

                                comboBox_AIR_CHAN.Items.Clear();
                                comboBox_AIR_RAT.Items.Clear();
                                switch (Module_use_chip)
                                {
                                    case Module_Chip_t.DW1000:
                                        {
                                            comboBox_AIR_CHAN.Items.AddRange(Module1000_chan_list);
                                            comboBox_AIR_RAT.Items.AddRange(Module1000_datarate_list);
                                            break;
                                        }
                                    case Module_Chip_t.DW3000:
                                        {
                                            comboBox_AIR_CHAN.Items.AddRange(Module3000_chan_list);
                                            comboBox_AIR_RAT.Items.AddRange(Module3000_datarate_list);
                                            break;
                                        }
                                    default: break;
                                }

                                ushort data_temp = 0;
                                comboBox_MODBUS_RATE.SelectedIndex = temp[4];   //设备波特率
                                numericUpDown_ID.Value = temp[6];               //MODBUS_ID
                                comboBox_RANGING.SelectedIndex = temp[7];      //测距方式                               
                                comboBox_DW_MODE.SelectedIndex = temp[8];      //定位方式
                                comboBox_TAG_or_BS.SelectedIndex = temp[10];   //设备模式
                                if (temp[10] == 0) numericUpDown_TAG_or_BS_ID.Value = temp[12];     //标签ID
                                if (temp[10] == 1) numericUpDown_TAG_or_BS_ID.Value = temp[11];    //次基站ID
                                if (temp[10] == 2) numericUpDown_TAG_or_BS_ID.Value = 0;            //主基站ID

                                comboBox_AIR_CHAN.SelectedIndex = temp[13];  //空中信道
                                comboBox_AIR_RAT.SelectedIndex = temp[14];   //空中波特率

                                numericUpDown_KAM_Q.Value = ((temp[15] << 8) & 0xFF00) | temp[16]; //卡尔曼滤波—Q
                                numericUpDown_KAM_R.Value = ((temp[17] << 8) & 0xFF00) | temp[18]; //卡尔曼滤波—R
                                numericUpDown_RX_DELAY.Value = ((temp[19] << 8) & 0xFF00) | temp[20]; //接收天线延时

                                //data_temp = Byte2Ushort(temp[21], temp[22]); 目前为空
                                data_temp = Byte2Ushort(temp[23], temp[24]);

                                /* 基站坐标 */
                                Anchor anc;
                                for (i = 0; i < ANCHOR_MAX_COUNT; i++)
                                {
                                    anc = AnchorList[i];
                                    if (i == 0)
                                    {
                                        //主基站必然使能
                                        anc.IsUse = true;
                                    }
                                    else
                                    {
                                        if (Check_BitIsTrue(data_temp, i))
                                            anc.IsUse = true;
                                        else
                                            anc.IsUse = false;
                                    }

                                    anc.x = Byte2Short(temp[25 + i * 6], temp[26 + i * 6]);
                                    anc.y = Byte2Short(temp[27 + i * 6], temp[28 + i * 6]);
                                    anc.z = Byte2Short(temp[29 + i * 6], temp[30 + i * 6]);
                                }
                                //121
                                CheckBox_AutoRtls.Checked = temp[122] == 8 ? true : false;

                                checkBox_JS.Checked = temp[123] == 1 ? true : false; 
                                numericUpDown_TAG_num.Value = temp[124];

                                //根据标签数量来写入标签的ID显示
                                for (i = 0; i < temp[124]; i++)
                                {
                                    if (i % 2 == 0) //偶数
                                        dataGridView_TAG.Rows[i].Cells[0].Value = temp[126 + i];  //写入标签ID信息
                                    else
                                        dataGridView_TAG.Rows[i].Cells[0].Value = temp[124 + i];
                                }

                                TagList.Clear();
                                for (i = 0; i < dataGridView_TAG.Rows.Count; i++)
                                {
                                    int Tag_id = int.Parse(dataGridView_TAG.Rows[i].Cells["TAG_ID"].Value.ToString());
                                    TagList.Add(new Tag(Tag_id, i));
                                }
                                //标签输出使能
                                checkBox_AT_PrintEn.Checked = temp[227] == 1 ? true : false;
                                //标签输出内容格式
                                checkBox_AT_outDist.Checked = Check_BitIsTrue(temp[228], 0);
                                checkBox_AT_outRtls.Checked = Check_BitIsTrue(temp[228], 1);
                                //标签输出协议
                                if (temp[230] <= 1)
                                    comboBox_AT_Protocal.SelectedIndex = temp[230];
                                //主基站输出内容格式
                                Analyse_format = temp[232];   //记录赋值
                                checkBox_RtlsEn.Checked = Check_BitIsTrue(temp[232], ANC_PROTOCAL_RTLS);
                                checkBox_DistEn.Checked = Check_BitIsTrue(temp[232], ANC_PROTOCAL_DIST);
                                checkBox_rxDiagEn.Checked = Check_BitIsTrue(temp[232], ANC_PROTOCAL_RXDIAG);
                                checkBox_TsEn.Checked = Check_BitIsTrue(temp[232], ANC_PROTOCAL_TIMESTAMP);
                                CheckBox_is_use_uwb_trim.Checked = temp[237] == 1;
                                numericUpDown_uwb_trim.Value = (byte)temp[238];

                                DataTable_Analyze_Init();

                                MessageBox.Show("读取配置成功", "提示");
                            });
                            BeginInvoke(mi);
                        } while (false);
                        Task.Run(() => UI_ConnectChange());
                        Work_State = WorkState.Idle;
                        break;
                    }
                case WorkState.Idle:       //空闲收到了数据 如果是定位包 那么需要切换到定位中的模式
                    {
                        if (Connect_State == ConnectState.Connected)
                        {
                            if(Module_Mode == ModuleMode.main_anc)
                            {
                                if (temp[3] == 0xCA && temp[4] == 0xDA)
                                {
                                    //确定是定位中的信息
                                    Work_State = WorkState.RtlsStart;
                                    ModbusRTU.Instance.Modbus_com.FunctionCode = 0x03;
                                    Rtls_Init();
                                    Task.Run(() => UI_WorkStateChange());
                                }
                            }
                            else if(Module_Mode == ModuleMode.tag)
                            {
                                if(temp[3] == 0xAC && temp[4] == 0xDA)
                                {
                                    //收到定位数据包
                                    Task.Run(() => Tag_RtlsDataRecv(temp,0));
                                }
                            }
                        }
                        break;
                    }
                case WorkState.Rtlsing:   //定位中
                    {
                        if (temp[3] == 0xCA && temp[4] == 0xDA)
                            Rtls_DataRecv(temp);
                            //Task.Run(() => Rtls_DataRecv(temp));                     
                        break;
                    }
                case WorkState.ScanModbusID:  //搜索ModbusID
                    {
                        //找到对应ID了
                        ID_buf.Add(ModbusRTU.Instance.Modbus_com.ModbusID.ToString());
                        break;
                    }
                case WorkState.ReadIMUConfig:  //读取IMU配置
                    {
                        int i = 0;
                        if (temp[24] != 0xA6) //不是六轴
                        {
                            Work_State = WorkState.Idle;
                            IMU_State = IMUState.NoConnect;
                            break;
                        } 
                        else
                            IMU_State = IMUState.Running;

                        /* 六轴版本 */
                        double imu_version = temp[23] / 10 + (double)temp[23] % 10;
                        Imu_config.version = temp[23];

                        UI_ImuVesion_Change();

                        MethodInvoker mi = new MethodInvoker(() => 
                        {
                            toolStripStatusLabel__firmware_version.Text = $"设备固件版本： {App_Version / 10}.{App_Version % 10}C+PGRBV{temp[23] / 10}.{temp[23] % 10}";

                            if (temp[3] == 0x01)
                                checkBox_ImuOutputEn.Checked = true;
                            else
                                checkBox_ImuOutputEn.Checked = false;

                            if (Check_BitIsTrue(temp[4], 0))
                                checkBox_imu_en.Checked = true;
                            else
                                checkBox_imu_en.Checked = false;

                            /* 安装方向 */
                            if (Imu_config.version < IMUConfig.IMU_RB_VERSION_V2)
                            {
                               comboBox_IMU_Mount.SelectedIndex = Check_BitIsTrue(temp[4], 2) ? 0 : 1;                                
                            }
                            else
                            {
                                if (temp[26] >= 0 && temp[26] <= 1)
                                    comboBox_IMU_Mount.SelectedIndex = temp[26];
                            }
                                
                            numericUpDown_outputrate.Value = temp[5] << 8 | temp[6];
                            byte output_format = temp[7];
                            bool Istrue = false;
                            for (i = 0; i < 6; i++)
                            {
                                Istrue = Check_BitIsTrue(output_format,i);
                                switch (i)
                                {
                                    case 0:
                                        {
                                            checkBox_en_acc.Checked = Istrue;
                                            break;
                                        }
                                    case 1:
                                        {
                                            checkBox_en_gyro.Checked = Istrue;
                                            break;
                                        }
                                    case 2:
                                        {
                                            checkBox_en_euler.Checked = Istrue;
                                            break;
                                        }
                                    case 3:
                                        {
                                            checkBox_en_temp.Checked = Istrue;
                                            break;
                                        }
                                    case 4:
                                        {
                                            checkBox_en_q.Checked = Istrue;
                                            break;
                                        }
                                    case 5:
                                        {
                                            checkBox_en_magn.Checked = Istrue;
                                            break;
                                        }
                                    default:break;
                                }
                            }

                            /* 采样频率 */
                            if(Imu_config.version < IMUConfig.IMU_RB_VERSION_V2)
                            {
                                if (temp[8] >= 1 && temp[8] <= 11)
                                    comboBox_odr.SelectedIndex = temp[8] - 1;
                                else if (temp[8] == 0x0F)
                                    comboBox_odr.SelectedIndex = 11;
                            }
                            else
                            {
                                if (temp[8] >= 0 && temp[8] <= 8)
                                    comboBox_odr.SelectedIndex = temp[8];
                            }
                            Imu_config.Set_Odr(temp[8]);

                            /* 加速度量程 */
                            if (temp[9] >= 0 && temp[9] <= 3)
                                comboBox_acc_fsr.SelectedIndex = temp[9];
                            Imu_config.Set_Acc_fsr(temp[9]);

                            /* 陀螺仪量程 */
                            if (temp[10] >= 0 && temp[10] <= 7)
                                comboBox_gyro_fsr.SelectedIndex = temp[10];
                            Imu_config.Set_Gyro_fsr(temp[10]);

                            /* 加速度零偏 */                           
                            textBox_accx_bias.Text = Data_Lsb2Real((short)(temp[11] << 8 | temp[12]), Imu_config.Bias_acc_fsr).ToString();
                            textBox_accy_bias.Text = Data_Lsb2Real((short)(temp[13] << 8 | temp[14]), Imu_config.Bias_acc_fsr).ToString();
                            textBox_accz_bias.Text = Data_Lsb2Real((short)(temp[15] << 8 | temp[16]), Imu_config.Bias_acc_fsr).ToString();

                            /* 陀螺仪零偏 */
                            textBox_gyrox_bias.Text = Data_Lsb2Real((short)(temp[17] << 8 | temp[18]), Imu_config.Bias_gyro_fsr).ToString();
                            textBox_gyroy_bias.Text = Data_Lsb2Real((short)(temp[19] << 8 | temp[20]), Imu_config.Bias_gyro_fsr).ToString();
                            textBox_gyroz_bias.Text = Data_Lsb2Real((short)(temp[21] << 8 | temp[22]), Imu_config.Bias_gyro_fsr).ToString();

                            /* 算法选择 */
                            if (temp[25] >= 0 && temp[25] <= 1)
                                comboBox_Algo_select.SelectedIndex = temp[25];

                            /* 磁力计量程 */
                            if (temp[27] >= 0 && temp[27] <= 3)
                                comboBox_magn_fsr.SelectedIndex = temp[27];
                            Imu_config.Set_Magn_fsr(temp[27]);

                            /* 磁力计采样频率 */
                            if (temp[28] >= 0 && temp[28] <= 3)
                                comboBox_magn_odr.SelectedIndex = temp[28];
                            Imu_config.Set_Magn_odr(temp[28]);

                            /* 磁力计是否使用校准 */
                            Imu_config.Is_use_magncorrect = temp[29] == 1;

                            /* 是否使能uwb回传数据 */
                            Imu_config.Is_use_uwbtrans = temp[30] == 1;
                            checkBox_en_uwb.Checked = Imu_config.Is_use_uwbtrans;

                            /* 磁力计校正参数 */
                            for (i = 0; i < 3; i++)
                            {
                                Imu_config.Magn_bias[i] = (short)(temp[31 + i * 2] << 8 | temp[32 + i * 2]);
                                imudata.Magn_bias[i] = Data_Lsb2Real(Imu_config.Magn_bias[i], Imu_config.Magn_fsr * Imu_config.Magn_fsr_scale);
                                Imu_config.Magn_scale[i] = (short)(temp[37 + i * 2] << 8 | temp[38 + i * 2]);
                                imudata.Magn_scale[i] = (double)(Imu_config.Magn_scale[i]) / 1000;
                            }

                            /* 磁力算法范围 */
                            Imu_config.Magn_algo_min = (ushort)(temp[43] << 8 | temp[44]);
                            Imu_config.Magn_algo_max = (ushort)(temp[45] << 8 | temp[46]);
                            numericUpDown_magn_min.Value = (decimal)Imu_config.Magn_algo_min;
                            numericUpDown_magn_max.Value = (decimal)Imu_config.Magn_algo_max;

                            if (!Imu_config.Config_Init)
                                Imu_config.Config_Init = true;
                            else
                                MessageBox.Show("读取配置成功！");

                            Work_State = WorkState.Idle;
                        });
                        BeginInvoke(mi);
                        break; 
                    }
                case WorkState.AutoCalibPos:  //自动标定获取数据
                    {
                        if (temp[3] == 0xDA && temp[4] == 0xDA)  //符合帧功能码
                        {
                            Send_CalibPos_Event?.Invoke(this, new CommuDataReceiveEventArg(temp, length));
                        }
                        break;
                    }
                case WorkState.Cir_testing:  //cir测试返回测距值 但需要判断是否要测试的id
                    {                        
                        if (temp[3] == 0xCA && temp[4] == 0xDA)
                        {
                            ushort tag_id = (ushort)(temp[7] << 8 | temp[8]);
                            Rtls_DataRecv(temp);
                            if ((byte)tag_id != Cir_work_instance.Cir_test_tagid)
                            {
                                Cir_work_instance.Flag = Cir_work_flag_t.get_otherdist;
                            }
                            else
                            {
                                Cir_work_instance.Flag = Cir_work_flag_t.get_correctdist;
                            }
                        }
                        break;
                    }
                case WorkState.Remote_cfg:  //接收到配置上报包
                    {
                        if (temp[3] == 0x6D && temp[4] == 0xDA)
                        {
                            Remote_cfg_RecvHandler(temp);
                        }
                        break;
                    }
                default:break;
            }

            /* 无关模式 接收到就响应 */
            if (temp[4] == 0xDA)
            {
               
                if (temp[3] == 0xED)   //收到透传信息 
                {
                    //收到透传数据
                    string str = string.Empty;
                    if (Module_Mode == ModuleMode.tag)
                        str += "Main Anc: ";
                    else if (Module_Mode == ModuleMode.main_anc)
                    {
                        str += $"Tag {temp[6]}: ";
                    }
                    byte[] data_recv = new byte[temp[2] - 4];
                    Array.Copy(temp, 7, data_recv, 0, data_recv.Length);
                    

                    if (Module_Mode == ModuleMode.main_anc)
                    {
                        if (!Check_SpecialTag(temp[6], data_recv))
                        {
                            //不是工牌手环标签才显示
                            //2024/3/6 加上pgrb部分
                            str += Encoding.UTF8.GetString(data_recv);
                            Task.Run(() => printf_data(str));
                        }
                        //开启了自动导航 发送到自动导航处理
                        if (Is_OpenNavi)
                        {
                            Send_NaviMsgEvent(this, new MessageReceiveEventArg(temp[6], data_recv));
                        }
                    }
                    else
                    {
                        str += Encoding.UTF8.GetString(data_recv);
                        Task.Run(() => printf_data(str));
                    }
                        


                }
                else if (temp[3] == 0xBF)  //收到姿态信息
                {
                    if (IMU_State != IMUState.NoConnect)
                        IMU_DataRecv(temp);
                        //Task.Run(() => IMU_DataRecv(temp));
                }
                else if(temp[3] == 0xBA)  //收到校准信息
                {
                    if (IMU_State == IMUState.Calibing)
                    {
                        Imu_calib.Acc_Ok = Check_BitIsTrue(temp[6], 4);
                        Imu_calib.Gyro_Ok = Check_BitIsTrue(temp[6], 5);
                        Imu_calib.Calib_OK = true;
                        MethodInvoker mi = new MethodInvoker(() => 
                        {
                            /* 加速度零偏 */
                            textBox_accx_bias.Text = Data_Lsb2Real((short)(temp[7] << 8 | temp[8]), Imu_config.Bias_acc_fsr).ToString();
                            textBox_accy_bias.Text = Data_Lsb2Real((short)(temp[9] << 8 | temp[10]), Imu_config.Bias_acc_fsr).ToString();
                            textBox_accz_bias.Text = Data_Lsb2Real((short)(temp[11] << 8 | temp[12]), Imu_config.Bias_acc_fsr).ToString();

                            /* 陀螺仪零偏 */
                            textBox_gyrox_bias.Text = Data_Lsb2Real((short)(temp[13] << 8 | temp[14]), Imu_config.Bias_gyro_fsr).ToString();
                            textBox_gyroy_bias.Text = Data_Lsb2Real((short)(temp[15] << 8 | temp[16]), Imu_config.Bias_gyro_fsr).ToString();
                            textBox_gyroz_bias.Text = Data_Lsb2Real((short)(temp[17] << 8 | temp[18]), Imu_config.Bias_gyro_fsr).ToString();
                        });
                        BeginInvoke(mi);
                    }
                }
            }
            

        }


        /// <summary>
        /// 判断是否为工牌标签 如果是需要更新电量和报警信息
        /// </summary>
        /// <param name="tag_id">标签ID</param>
        /// <param name="temp">数据透传内容</param>
        /// <returns>true 为工牌手环标签 false则不是</returns>
        private bool Check_SpecialTag(byte tag_id,byte[] temp)
        {
            if(temp == null)
            {
                return false;
            }
            if(temp.Length < 4)
            {
                return false;
            }

            if (temp[2] == 0xFF && temp[3] == 0xCC)
            {
                //获取标签回传报警信息和电量信息
                Tag t = FindTag(tag_id);
                if (t != null)
                {
                    //是否报警
                    if (temp[0] == 0x00)
                        t.IsAlarm = false;
                    else if (temp[0] == 0x01)
                        t.IsAlarm = true;
                        
                    //电量显示
                    t.Qc = temp[1];
                    if (temp.Length > 4)
                    {
                        //获取标签心率跟血氧值和是否时钟同步标志
                        t.Heart = temp[4];
                        t.Blood= temp[5];
                    }
                    return true;
                }
            }
            else if (temp[1] == 0xBF && temp[2] == 0xDA)
            {
                //收到透传的pgrb姿态数据
                Tag t = FindTag(tag_id);
                if (t == null)
                {
                    return false;
                }
                if(IMU_State != IMUState.RemoteTrans)
                {
                    IMU_State = IMUState.RemoteTrans;
                    Task.Run(() => UI_IMUStateChange());
                }
                IMU_DataRecv_remote(temp, tag_id);
            }
            return false;
        }

        #endregion
        /****************************************************/

        /****************************************************/
        #region Modbus10码接收处理
        private void Modbus10Recv_Handler(byte[] recv_buff, int recv_len)
        {
            //根据具体模式来写不同的判断
            switch (Work_State)
            {
                case WorkState.WriteConfig:
                    {
                        MessageBox.Show("写入成功!","提示");
                        Work_State = WorkState.Idle;
                        ModbusRTU.Instance.Modbus_com.FunctionCode = 0x03;
                        break;
                    }
                case WorkState.RtlsStart:
                    {                        
                        ModbusRTU.Instance.Modbus_com.FunctionCode = 0x03;
                        //modbus.RegNum = ModbusRTU.RegNum_Rtls;
                        Task.Run(() => UI_WorkStateChange());
                        break;
                    }
                case WorkState.RtlsStop:
                    {
                        Work_State = WorkState.Idle;
                        Task.Run(() => UI_WorkStateChange());
                        break;
                    }
                case WorkState.CalibIMU:
                    {
                        Work_State = WorkState.Idle;
                        //代表开始校准了
                        Thread thread = new Thread(Imu_Calib_Handler);
                        thread.IsBackground = true;
                        thread.Start();
                        break;
                    }
                case WorkState.CalibMagn:
                    {
                        Work_State = WorkState.Idle;
                        //代表开始校准了
                        ModbusRTU.Instance.Modbus_com.FunctionCode = 0x03;
                        Is_Magn_correct_calib = true;
                        break;
                    }
                case WorkState.CalibMagn_fin:
                    {
                        Work_State = WorkState.Idle;
                        ModbusRTU.Instance.Modbus_com.FunctionCode = 0x03;
                        MessageBox.Show("磁力计校准完成！");
                        break;
                    }
                case WorkState.WriteOutputConfig:
                case WorkState.WriteIMUConfig:
                    {
                        Work_State = WorkState.Idle;
                        ModbusRTU.Instance.Modbus_com.FunctionCode = 0x03;
                        MessageBox.Show("写入完成！");                       
                        break;
                    }
                case WorkState.IntoAutoCalibPos:
                    {
                        Work_State = WorkState.AutoCalibPos;
                        break;
                    }              
                case WorkState.OutAutoCalibPos:
                case WorkState.Out_Remote_cfg:
                    {
                        Work_State = WorkState.Idle;
                        break;
                    }
                case WorkState.AutoCalibPos:
                    {
                        Send_CalibPos_Event?.Invoke(this, new CommuDataReceiveEventArg(recv_buff, recv_len));                       
                        break;
                    }
                case WorkState.Cir_testing:
                    {
                        ModbusRTU.Instance.Modbus_com.FunctionCode = 0x03;
                        break;
                    }
                case WorkState.In_Remote_cfg:  //进入远程配置收到回应
                    {
                        Work_State = WorkState.Remote_cfg;
                        ModbusRTU.Instance.Modbus_com.FunctionCode = 0x03;
                        break;
                    }

                default:break;
            }
            

        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region Modbus06码接收处理
        private void Modbus06Recv_Handler()
        {
            //根据具体模式来写不同的判断
            MessageBox.Show("写入完成");
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x03;
            ModbusRTU.Instance.Modbus_com.RegNum = 14;
            if(Work_State == WorkState.IntoHardwareTest_cfg
                || Work_State == WorkState.OutHardwareTest_cfg)
            {
                Task.Run(() => UI_WorkStateChange());
            }
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region Modbus41码接收处理
        private void Modbus41Recv_Handler(byte[] temp)
        {          
            if (temp[2] == 0x01)
            {
                //请求成功
                Cir_work_instance.Now_cir_totalcount = temp[3];
                Cir_work_instance.Is_get_readresp_ok = true;
            }
            else
            {
                Cir_work_instance.Is_get_readresp_ok = false;
            }
            Cir_work_instance.Flag = Cir_work_flag_t.get_readcir_response;
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region Modbus42码接收处理
        private void Modbus42Recv_Handler(byte[] temp, int len)
        {
            //根据具体模式来写不同的判断
            if (temp[2] == 0xA0)
            {
                if (temp[3] != Cir_work_instance.Now_cir_read_idx)
                {
                    return;
                }
                ushort data_len = (ushort)(temp[4] << 8 | temp[5]);
                byte[] data_buff = new byte[data_len];
                Array.Copy(temp, 6, data_buff, 0, data_len);
                Cir_work_instance.Cir_data_list.AddRange(data_buff);
                Cir_work_instance.Flag = Cir_work_flag_t.get_cir_data;
            }
            else if(temp[2] == 0xA1)
            {
                Cir_work_instance.Flag = Cir_work_flag_t.get_cir_fin;
            }
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 基站接收到定位信息的处理
        private void Rtls_DataRecv(byte[] RecvBuff)
        {
            int i, index = 5;

            ushort output_protocal = (ushort)(RecvBuff[index++] << 8 | RecvBuff[index++]);
            ushort Tag_ID = (ushort)(RecvBuff[index++] << 8 | RecvBuff[index++]);
            //寻找标签类
            Tag t = FindTag(Tag_ID);
            if (t == null)
                return;
            t.TagNotFound_time = 0;

            uint Cal_Flag = (uint)(RecvBuff[index++] << 24 | RecvBuff[index++] << 16 | RecvBuff[index++] << 8 | RecvBuff[index++]);


            if (Check_BitIsTrue(output_protocal, ANC_PROTOCAL_RTLS))
            {
                //根据解算是否在上位机解算获取定位解算值
                if (IsCalInModule)  //由硬件解算
                {
                    if (!Check_BitIsTrue(Cal_Flag, 16))   //定位解算没有计算成功   ((Cal_Flag >> 8) & 0x01) == 0x00              
                    {
                        t.CalSuccess = false;
                        index += 6;
                    } 
                    else
                    {
                        t.CalSuccess = true;

                        //获取坐标值

                        t.x = (short)(((ushort)(RecvBuff[index++] << 8) & 0xFF00) | RecvBuff[index++]);
                        t.y = (short)(((ushort)(RecvBuff[index++] << 8) & 0xFF00) | RecvBuff[index++]);
                        t.z = (short)(((ushort)(RecvBuff[index++] << 8) & 0xFF00) | RecvBuff[index++]);

                        //t.x = (short)(RecvBuff[index++] << 8 | RecvBuff[index++]);
                        //t.y = (short)(RecvBuff[index++] << 8 | RecvBuff[index++]);
                        //t.z = (short)(RecvBuff[index++] << 8 | RecvBuff[index++]);                       
                    }
                }
                else               //由软件解算
                {
                    if (Rtls_State == RtlsMode.Ranging)  //测距时不用输出x、y、z坐标
                    {
                        t.x = 0;
                        t.y = 0;
                        t.z = 0;
                        t.CalSuccess = false;
                    }
                    else if (Rtls_State == RtlsMode.Rtls_2D) //二维模式
                    {
                        double[] point_xy;
                        if (RtlsHelp.Rtls_2D_Handler(AnchorGroup, t, out point_xy))
                        {
                            //滤波
                            t.Last_x = t.x;
                            t.Last_y = t.y;
                            double[] Filter_Result = Filter.Filter_Kalman(point_xy[0], t.Last_x, t.P_last_x, KALMAN_Q, KALMAN_R);
                            t.x = Filter_Result[0];
                            t.P_last_x = Filter_Result[1];
                            Filter_Result = Filter.Filter_Kalman(point_xy[1], t.Last_y, t.P_last_y, KALMAN_Q, KALMAN_R);
                            t.y = Filter_Result[0];
                            t.P_last_y = Filter_Result[1];
                            
                        }
                        else
                            t.CalSuccess = false;
                    }
                    else if (Rtls_State == RtlsMode.Rtls_3D) //三维模式
                    {
                        double[] point_xyz;
                        if (RtlsHelp.Rtls_3D_Handler(AnchorGroup, t, out point_xyz))
                        {
                            //滤波
                            t.Last_x = t.x;
                            t.Last_y = t.y;
                            t.Last_z = t.z;
                            double[] Filter_Result = Filter.Filter_Kalman(point_xyz[0], t.Last_x, t.P_last_x, KALMAN_Q, KALMAN_R);
                            t.x = Filter_Result[0];
                            t.P_last_x = Filter_Result[1];
                            Filter_Result = Filter.Filter_Kalman(point_xyz[1], t.Last_y, t.P_last_y, KALMAN_Q, KALMAN_R);
                            t.y = Filter_Result[0];
                            t.P_last_y = Filter_Result[1];
                            Filter_Result = Filter.Filter_Kalman(point_xyz[2], t.Last_z, t.P_last_z, KALMAN_Q, KALMAN_R);
                            t.z = Filter_Result[0];
                            t.P_last_z = Filter_Result[1];
                        }
                        else
                            t.CalSuccess = false;
                    }
                    index += 6;
                }
            }

            if (Check_BitIsTrue(output_protocal, ANC_PROTOCAL_DIST))  //距离可输出
            {
                //获取距离值
                for (i = 0; i < ANCHOR_MAX_COUNT; i++)
                {
                    if (Check_BitIsTrue(Cal_Flag, i)) //((Cal_Flag >> i) & 0x01) == 0x01
                    {
                        t.Dist[i] = (ushort)(((ushort)(RecvBuff[index++] << 8) & 0xFF00) | RecvBuff[index++]);
                        t.Dist_Success[i] = true;
                    }
                    else
                    {
                        t.Dist_Success[i] = false;
                        index += 2;
                    }
                       
                }
            }

            if (Check_BitIsTrue(output_protocal, ANC_PROTOCAL_RXDIAG))  //接收强度信息
            {
                //获取接收强度信息
                if (Work_State == WorkState.Cir_testing)
                {
                    if (t.Id == Cir_work_instance.Cir_test_tagid)
                    {
                        t.Rx_diag.Max_noise = (ushort)(RecvBuff[index++] << 8 | RecvBuff[index++]);
                        t.Rx_diag.Std_noise = (ushort)(RecvBuff[index++] << 8 | RecvBuff[index++]);
                        t.Rx_diag.Fp_amp1 = (ushort)(RecvBuff[index++] << 8 | RecvBuff[index++]);
                        t.Rx_diag.Fp_amp2 = (ushort)(RecvBuff[index++] << 8 | RecvBuff[index++]);
                        t.Rx_diag.Fp_amp3 = (ushort)(RecvBuff[index++] << 8 | RecvBuff[index++]);
                        t.Rx_diag.Max_growthCIR = (ushort)(RecvBuff[index++] << 8 | RecvBuff[index++]);
                        t.Rx_diag.Rx_preambleCount = (ushort)(RecvBuff[index++] << 8 | RecvBuff[index++]);
                        t.Rx_diag.Fp = (ushort)((RecvBuff[index++] << 8 | RecvBuff[index++]) / 64);  //除以64 取实数部分
                        t.Rx_diag.DGC_dbg = (byte)t.Rx_diag.Max_noise;  //3000系列时候没有maxnoise 用这个来传递dgc
                        t.Rx_diag.Fp_power = Cal_FPPower(t.Rx_diag);
                        t.Rx_diag.Rx_power = Cal_RxPower(t.Rx_diag);
                       
                    }
                    else
                        index += 16;
                }
                else
                {
                    if (Is_Analyse && !string.IsNullOrWhiteSpace(Analyze_TagID))
                    {
                        if (t.Id == int.Parse(Analyze_TagID))
                        {
                            
                            t.Rx_diag.Max_noise = (ushort)(RecvBuff[index++] << 8 | RecvBuff[index++]);
                            t.Rx_diag.Std_noise = (ushort)(RecvBuff[index++] << 8 | RecvBuff[index++]);
                            t.Rx_diag.Fp_amp1 = (ushort)(RecvBuff[index++] << 8 | RecvBuff[index++]);
                            t.Rx_diag.Fp_amp2 = (ushort)(RecvBuff[index++] << 8 | RecvBuff[index++]);
                            t.Rx_diag.Fp_amp3 = (ushort)(RecvBuff[index++] << 8 | RecvBuff[index++]);
                            t.Rx_diag.Max_growthCIR = (ushort)(RecvBuff[index++] << 8 | RecvBuff[index++]);
                            t.Rx_diag.Rx_preambleCount = (ushort)(RecvBuff[index++] << 8 | RecvBuff[index++]);
                            t.Rx_diag.Fp = (ushort)((RecvBuff[index++] << 8 | RecvBuff[index++]) / 64);  //除以64 取实数部分
                            t.Rx_diag.DGC_dbg = (byte)t.Rx_diag.Max_noise;  //3000系列时候没有maxnoise 用这个来传递dgc
                            t.Rx_diag.Fp_power = Cal_FPPower(t.Rx_diag);
                            t.Rx_diag.Rx_power = Cal_RxPower(t.Rx_diag);
                        }
                        else
                            index += 16;
                    }
                    else
                        index += 16;
                }
            }

            if (Check_BitIsTrue(output_protocal, ANC_PROTOCAL_TIMESTAMP))
            {
                if(Is_Analyse && t.Id == int.Parse(Analyze_TagID))
                {
                    for (i = 0; i < 6; i++)
                    {
                        t.Time_ts[i] = (uint)(RecvBuff[index++] << 24 | RecvBuff[index++] << 16 | RecvBuff[index++] << 8 | RecvBuff[index++]);
                    }
                }
            }
            
            //界面显示
            if (t.Index != -1)
            {
                //如果记录轨迹 则保存到对应位置
                if (TK_HasTrace)
                    TK_tagTraceHelper.Add_HistoryPoint(t.Index, Float2Vector3(RealPoint2DrawPoint((float)(t.x / 100.0f), (float)(t.y / 100.0f), (float)(t.z / 100.0f))));

                MethodInvoker mi = new MethodInvoker(() =>
                {
                    /*** 更新数值 ***/
                    dataGridView_TAG.Rows[t.Index].Cells["TAG_ID"].Style.BackColor = OK_color;
                    //更新定位坐标
                    if (t.CalSuccess)
                    {
                        dataGridView_TAG.Rows[t.Index].Cells["DW_X"].Value = t.x;
                        dataGridView_TAG.Rows[t.Index].Cells["DW_X"].Style.BackColor = OK_color;
                        dataGridView_TAG.Rows[t.Index].Cells["DW_Y"].Value = t.y;
                        dataGridView_TAG.Rows[t.Index].Cells["DW_Y"].Style.BackColor = OK_color;
                        dataGridView_TAG.Rows[t.Index].Cells["DW_Z"].Value = t.z;
                        dataGridView_TAG.Rows[t.Index].Cells["DW_Z"].Style.BackColor = OK_color;
                    }
                    else
                    {
                        dataGridView_TAG.Rows[t.Index].Cells["DW_X"].Style.BackColor = NG_color;
                        dataGridView_TAG.Rows[t.Index].Cells["DW_Y"].Style.BackColor = NG_color;
                        dataGridView_TAG.Rows[t.Index].Cells["DW_Z"].Style.BackColor = NG_color;
                    }

                    //更新测距值
                    for (i = 0; i < ANCHOR_MAX_COUNT; i++)
                    {
                        if (t.Dist_Success[i])
                        {
                            dataGridView_TAG.Rows[t.Index].Cells[4 + i].Value = t.Dist[i];
                            dataGridView_TAG.Rows[t.Index].Cells[4 + i].Style.BackColor = OK_color;
                        }
                        else
                        {
                            dataGridView_TAG.Rows[t.Index].Cells[4 + i].Style.BackColor = NG_color;                                                       
                        }
                            
                    }

                    //更新电量
                    dataGridView_TAG.Rows[t.Index].Cells["Column_Qc"].Value = t.Qc;
                    dataGridView_TAG.Rows[t.Index].Cells["Column_Qc"].Style.BackColor = OK_color;

                    //更新速度
                    dataGridView_TAG.Rows[t.Index].Cells["Column_velocity"].Value = t.Velocity;
                    dataGridView_TAG.Rows[t.Index].Cells["Column_velocity"].Style.BackColor = OK_color;

                    //更新心率
                    dataGridView_TAG.Rows[t.Index].Cells["Column_HbValue"].Value = t.Heart;
                    dataGridView_TAG.Rows[t.Index].Cells["Column_HbValue"].Style.BackColor = OK_color;

                    //更新血氧
                    dataGridView_TAG.Rows[t.Index].Cells["Column_Blood"].Value = t.Blood;
                    dataGridView_TAG.Rows[t.Index].Cells["Column_Blood"].Style.BackColor = OK_color;

                    if (Work_State == WorkState.Cir_testing)
                    {
                        if (t.Dist_Success[0])
                        {
                            Text_cir_dist.BackColor = OK_color;                          
                        }
                        else
                        {
                            Text_cir_dist.BackColor = NG_color;
                        }
                        Text_cir_dist.Text = t.Dist[0].ToString();
                        Rxdiag.maxNoise = t.Rx_diag.Max_noise;
                        Rxdiag.stdNoise = t.Rx_diag.Std_noise;
                        Rxdiag.firstPathAmp1 = t.Rx_diag.Fp_amp1;
                        Rxdiag.firstPathAmp2 = t.Rx_diag.Fp_amp2;
                        Rxdiag.firstPathAmp3 = t.Rx_diag.Fp_amp3;
                        Rxdiag.maxGrowthCIR = t.Rx_diag.Max_growthCIR;
                        Rxdiag.rxPreamCount = t.Rx_diag.Rx_preambleCount;
                        Rxdiag.firstPath = t.Rx_diag.Fp; 
                    }

                });
                BeginInvoke(mi);
            }

            //Log.Logger.Instance.WriteLog("get data\r\n");
            //是否需要将该标签信息保存到数据表中
            if (t.Id == GJ1_ID)
            {
                GJ1_now_record++;
                if(GJ1_now_record >= GJ1_record_per_data)
                {
                    GJ1_now_record = 0;
                    string time_now = DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss fff");
                    if (Channel1_index >= DataTable_MaxLen)
                        Channel1_index = 0;
                    Save_TagData((int)t.x, (int)t.y, (int)t.z, t.Dist, Channel1_index, time_now, Cal_Flag, t.Velocity, 1);
                    Channel1_index++;

                    Task.Run(() => Drawing_Boxing1_Update(t.Dist));  //更新到通道表1
                    
                }
            }
            if(t.Id == GJ2_ID)
            {
                GJ2_now_record++;
                if (GJ2_now_record >= GJ2_record_per_data)
                {
                    GJ2_now_record = 0;
                    string time_now = DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss fff");
                    if (Channel2_index >= DataTable_MaxLen)
                        Channel2_index = 0;
                    Save_TagData((int)t.x, (int)t.y, (int)t.z, t.Dist, Channel2_index, time_now, Cal_Flag, t.Velocity, 2);
                    Channel2_index++;

                    //Drawing_Boxing2_Update(t.Dist);
                    Task.Run(() => Drawing_Boxing2_Update(t.Dist));  //更新到通道表2
                }
                
            }
            //如果需要监测 将数据保存到监测数据表中
            if(Is_Analyse && t.Id == int.Parse(Analyze_TagID))
            {
                string time_now = DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss fff");

                if (Analyze_index >= DataTable_MaxLen)
                    Analyze_index = 0;

                Save_AnalyzeData(Analyze_index, time_now, (int)Cal_Flag >> 16, (int)t.x, (int)t.y, (int)t.z, (int)Cal_Flag & 0x0000FFFF, t.Dist, t.Rx_diag, t.Time_ts);
                Analyze_index++;
            }
            //Task.Run(() => Save_TagData(t));
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 标签输出定位信息接收处理
        /// <summary>
        /// 标签接收到定位信息的处理
        /// </summary>
        /// <param name="RecvBuff">要解析的数据</param>
        /// <param name="mode">0 modbus模式 1字符</param>
        private void Tag_RtlsDataRecv(byte[] RecvBuff, int mode)
        {
            bool[] ok_flags = new bool[ANCHOR_MAX_COUNT + 1];  //0 xyz成功标志 1-17 测距A-P基站成功标志 
            bool ascii_read_dist = false;
            if (mode == 0) //modbus解析
            {
                int buff_idx = 7;
                int i;
                if (Check_BitIsTrue(RecvBuff[6], 0))
                {
                    //测距使能
                    ushort dist_flag = (ushort)(RecvBuff[buff_idx++] << 8 | RecvBuff[buff_idx++]);
                    for (i = 0; i < ANCHOR_MAX_COUNT; i++)
                    {
                        ok_flags[i + 1] = Check_BitIsTrue(dist_flag, i);
                        if(ok_flags[i + 1])
                        {
                            last_dist[i] = (ushort)(RecvBuff[buff_idx++] << 8 | RecvBuff[buff_idx++]);
                        }
                        else
                        {
                            buff_idx += 2;
                        }
                        
                    }                   
                                          
                }
                if(Check_BitIsTrue(RecvBuff[6], 1))
                {
                    //定位使能                    
                    ok_flags[0] = (RecvBuff[buff_idx++] << 8 | RecvBuff[buff_idx++]) == 1;
                    if (ok_flags[0])
                    {
                        for (i = 0; i < 3; i++)
                        {
                            last_xyz[i] = (short)(RecvBuff[buff_idx++] << 8 | RecvBuff[buff_idx++]);
                        }
                    }
                   
                       
                }
            }
            else if(mode == 1)  //字符格式解析
            {                
                string recv_str = string.Empty;                
                if(RecvBuff[0] == 'D' && RecvBuff[1] == 'i')
                {
                    //测距信息解析
                    ascii_read_dist = true;
                    recv_str = Encoding.ASCII.GetString(RecvBuff);
                    if (!string.IsNullOrEmpty(recv_str))
                        Tag_DistRead(recv_str, ref last_dist, ref ok_flags);
                }
                else if (RecvBuff[0] == 'R' && RecvBuff[1] == 't')
                {
                    //定位信息解析
                    ascii_read_dist = false;
                    recv_str = Encoding.ASCII.GetString(RecvBuff);
                    if (!string.IsNullOrEmpty(recv_str))
                        ok_flags[0] = Tag_RtlsRead(recv_str, ref last_xyz);
                }

            }

            //显示到界面
            MethodInvoker mi = new MethodInvoker(() =>
            {
                int i;
                //分情况显示 因为自由输出信息的时候距离和位置数据不是同时解析
                if(mode == 0)
                {
                    dataGridView_TAG.Rows[0].Cells["DW_X"].Value = last_xyz[0];
                    dataGridView_TAG.Rows[0].Cells["DW_X"].Style.BackColor = ok_flags[0] ? OK_color : NG_color;
                    dataGridView_TAG.Rows[0].Cells["DW_Y"].Value = last_xyz[1];
                    dataGridView_TAG.Rows[0].Cells["DW_Y"].Style.BackColor = ok_flags[0] ? OK_color : NG_color;
                    dataGridView_TAG.Rows[0].Cells["DW_Z"].Value = last_xyz[2];
                    dataGridView_TAG.Rows[0].Cells["DW_Z"].Style.BackColor = ok_flags[0] ? OK_color : NG_color;

                    for (i = 0; i < ANCHOR_MAX_COUNT; i++)
                    {
                        dataGridView_TAG.Rows[0].Cells[4 + i].Value = last_dist[i];
                        dataGridView_TAG.Rows[0].Cells[4 + i].Style.BackColor = ok_flags[i + 1] ? OK_color : NG_color;
                    }
                }
                else if(mode == 1)
                {
                    if (ascii_read_dist)
                    {
                        for (i = 0; i < ANCHOR_MAX_COUNT; i++)
                        {
                            dataGridView_TAG.Rows[0].Cells[4 + i].Value = last_dist[i];
                            dataGridView_TAG.Rows[0].Cells[4 + i].Style.BackColor = ok_flags[i + 1] ? OK_color : NG_color;
                        }
                    }
                    else
                    {
                        dataGridView_TAG.Rows[0].Cells["DW_X"].Value = last_xyz[0];
                        dataGridView_TAG.Rows[0].Cells["DW_X"].Style.BackColor = ok_flags[0] ? OK_color : NG_color;
                        dataGridView_TAG.Rows[0].Cells["DW_Y"].Value = last_xyz[1];
                        dataGridView_TAG.Rows[0].Cells["DW_Y"].Style.BackColor = ok_flags[0] ? OK_color : NG_color;
                        dataGridView_TAG.Rows[0].Cells["DW_Z"].Value = last_xyz[2];
                        dataGridView_TAG.Rows[0].Cells["DW_Z"].Style.BackColor = ok_flags[0] ? OK_color : NG_color;
                    }
                }
            });
            BeginInvoke(mi);

        }

        /// <summary>
        /// 判断字符串形式的测距信息
        /// </summary>
        /// <param name="str">标签测距字符串</param>
        /// <param name="dist">返回距离保存数组</param>
        private void Tag_DistRead(string str, ref ushort[] dist, ref bool[] ok_flags)
        {
            int anc_idx = 0;
            int anc_next_idx = 1;
            int cm_idx = 0;
            try
            {
                for (int i = 0; i < ANCHOR_MAX_COUNT; i++)
                {
                    if (i != ANCHOR_MAX_COUNT - 1)
                    {
                        anc_idx = str.IndexOf(Tag_Dist_Resolve[i]);
                        anc_next_idx = str.IndexOf(Tag_Dist_Resolve[i + 1]);
                        if(anc_next_idx == -1)
                        {
                            //未找到后续的 可能是DS模式下只输出与A基站的测距值 5.3版本后不会只输出一个距离
                            cm_idx = str.LastIndexOf("cm");
                            string str_temp = str.Substring(anc_idx, cm_idx - anc_idx);
                            if (string.IsNullOrEmpty(str_temp))
                                return;
                            string value_temp = str_temp.Substring(5, str_temp.Length - 5 - 1);  //8
                            if (!string.IsNullOrEmpty(value_temp))
                            {
                                int dist_value = Convert.ToInt32(value_temp);
                                if (dist_value != -1)
                                {
                                    dist[i] = (ushort)dist_value;
                                    ok_flags[1 + i] = true;
                                }
                                else
                                {
                                    ok_flags[1 + i] = false;
                                }
                                break;
                            }
                        }
                        else
                        {
                            string str_temp = str.Substring(anc_idx, anc_next_idx - anc_idx);
                            if (string.IsNullOrEmpty(str_temp))
                                return;
                            cm_idx = str_temp.IndexOf("cm");
                            if (cm_idx > 0)
                            {
                                string value_temp = str_temp.Substring(5, cm_idx - 5 - 1);
                                if (!string.IsNullOrEmpty(value_temp))
                                {
                                    int dist_value = Convert.ToInt32(value_temp);
                                    if (dist_value != -1)
                                    {
                                        dist[i] = (ushort)dist_value;
                                        ok_flags[1 + i] = true;
                                    }
                                    else
                                    {
                                        ok_flags[1 + i] = false;
                                    }
                                }
                            }
                        }
                        
                    }
                    else
                    {
                        anc_idx = str.IndexOf(Tag_Dist_Resolve[i]);
                        cm_idx = str.LastIndexOf("cm");
                        string str_temp = str.Substring(anc_idx, cm_idx - anc_idx);
                        if (string.IsNullOrEmpty(str_temp))
                            return;
                        string value_temp = str_temp.Substring(5, str_temp.Length - 5 - 1);
                        if (!string.IsNullOrEmpty(value_temp))
                        {
                            int dist_value = Convert.ToInt32(value_temp);
                            if(dist_value != -1)
                            {
                                dist[i] = (ushort)dist_value;
                                ok_flags[1 + i] = true;
                            }
                            else
                            {
                                ok_flags[1 + i] = false;
                            }
                        }
                        else
                        {
                            ok_flags[1 + i] = false;
                        }
                    }
                }
            }
            catch(Exception ex)
            {
                MessageBox.Show(ex.Message);
                return;
            }
            
        }

        /// <summary>
        /// 判断字符串形式的定位信息
        /// </summary>
        /// <param name="str">标签定位字符串</param>
        /// <param name="rtls">返回定位信息保存数组</param>
        private bool Tag_RtlsRead(string str, ref short[] rtls)
        {
            int now_idx = 0;
            int next_idx = 1;
            int cm_idx = 0;
            bool result = false;
            try
            {
                if (str.Contains("Yes"))
                {
                    result = true;
                }
                for (int i = 0; i < 3; i++)
                {
                    if (i != 2)
                    {
                        now_idx = str.IndexOf(Tag_Rtls_Resolve[i]);
                        next_idx = str.IndexOf(Tag_Rtls_Resolve[i + 1]);
                        if (next_idx == -1)
                        {
                            //未找到后续的 可能是输出二维坐标只有x和y
                            cm_idx = str.LastIndexOf("cm");
                            string str_temp = str.Substring(now_idx, cm_idx - now_idx);
                            if (string.IsNullOrEmpty(str_temp))
                                return false;
                            string value_temp = str_temp.Substring(4, str_temp.Length - 4 - 1);
                            if (!string.IsNullOrEmpty(value_temp))
                            {
                                rtls[i] = Convert.ToInt16(value_temp);
                                break;
                            }
                        }
                        else
                        {
                            string str_temp = str.Substring(now_idx, next_idx - now_idx);
                            if (string.IsNullOrEmpty(str_temp))
                                return false;
                            cm_idx = str_temp.IndexOf("cm");
                            if (cm_idx > 0)
                            {
                                string value_temp = str_temp.Substring(4, cm_idx - 4 - 1);
                                if (!string.IsNullOrEmpty(value_temp))
                                    rtls[i] = Convert.ToInt16(value_temp);
                                else
                                    return false;
                            }
                        }

                    }
                    else
                    {
                        now_idx = str.IndexOf(Tag_Rtls_Resolve[i]);
                        if(now_idx == -1)
                        {
                            //没找到 只有xy
                            return true;
                        }
                        cm_idx = str.LastIndexOf("cm");
                        string str_temp = str.Substring(now_idx, cm_idx - now_idx);
                        if (string.IsNullOrEmpty(str_temp))
                            return false;
                        string value_temp = str_temp.Substring(4, str_temp.Length - 4 - 1);
                        if (!string.IsNullOrEmpty(value_temp))
                            rtls[i] = Convert.ToInt16(value_temp);
                        else
                            return false;
                    }
                }
                return result;
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message);
                return false;
            }

        }

        #endregion
        /****************************************************/

        /****************************************************/
        #region 接收到IMU输出的数据
        /// <summary>
        /// 接收到IMU的数据处理
        /// </summary>
        /// <param name="RecvBuff">接收数据数组</param>
        private void IMU_DataRecv(byte[] RecvBuff)
        {
            //int i;

            ushort print_en = (ushort)(RecvBuff[5] << 8 | RecvBuff[6]);
            ushort idx = 7;

            if ((print_en & IMUData.IMU_DATA_ACC_EN) > 0) //使能加速度输出
            {
                imudata.Acc_x = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), Imu_config.Acc_fsr);  //Imu_config.Acc_fsr
                imudata.Acc_y = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), Imu_config.Acc_fsr);
                imudata.Acc_z = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), Imu_config.Acc_fsr);
            }
            if ((print_en & IMUData.IMU_DATA_GYRO_EN) > 0) //使能陀螺仪输出
            {
                imudata.Gyro_x = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), Imu_config.Gyro_fsr); //Imu_config.Gyro_fsr
                imudata.Gyro_y = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), Imu_config.Gyro_fsr);
                imudata.Gyro_z = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), Imu_config.Gyro_fsr);
            }
            if ((print_en & IMUData.IMU_DATA_EULER_EN) > 0) //使能姿态角度输出
            {
                imudata.Rotation_x = (double)(short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]) / 100;
                imudata.Rotation_y = (double)(short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]) / 100;
                imudata.Rotation_z = (double)(short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]) / 100;
            }
            if ((print_en & IMUData.IMU_DATA_TEMP_EN) > 0) //使能温度输出
            {
                
                //ushort raw_temperature;
                //raw_temperature = (ushort)(RecvBuff[idx++] << 8 | RecvBuff[idx++]);
                //imudata.Temperature = Math.Round((double)raw_temperature / 132.48 + 25, 3);  //132.48 + 25,3
                imudata.Temperature = Math.Round(Imu_config.Imu_GetTemperature(RecvBuff[idx++], RecvBuff[idx++]), 3);
            }
            if ((print_en & IMUData.IMU_DATA_Q_EN) > 0) //使能四元数输出
            {
                imudata.q0 = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), 1);
                imudata.q1 = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), 1);
                imudata.q2 = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), 1);
                imudata.q3 = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), 1);
            }
            if((print_en & IMUData.IMU_DATA_MAGN_EN) > 0)  //使能磁力计输出
            {
                imudata.Is_get_newdata = true;
                imudata.Magn_x = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), Imu_config.Magn_fsr * Imu_config.Magn_fsr_scale); //1Gauss = 100uT
                imudata.Magn_y = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), Imu_config.Magn_fsr * Imu_config.Magn_fsr_scale);
                imudata.Magn_z = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), Imu_config.Magn_fsr * Imu_config.Magn_fsr_scale);
                imudata.Cal_Magn_H();
            }
        }

        private void IMU_DataRecv_remote(byte[] RecvBuff, byte tag_id)
        {
            
            if (Imu_display_id != tag_id)
            {
                return;
            }


            Imu_config.Set_Acc_fsr(RecvBuff[3]);
            Imu_config.Set_Gyro_fsr(RecvBuff[4]);
            Imu_config.Set_Magn_fsr(RecvBuff[5], false);

            ushort print_en = (ushort)(RecvBuff[7] << 8 | RecvBuff[8]);
            ushort idx = 9;

            if ((print_en & IMUData.IMU_DATA_ACC_EN) > 0) //使能加速度输出
            {
                imudata.Acc_x = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), Imu_config.Acc_fsr);  //Imu_config.Acc_fsr
                imudata.Acc_y = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), Imu_config.Acc_fsr);
                imudata.Acc_z = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), Imu_config.Acc_fsr);
            }
            if ((print_en & IMUData.IMU_DATA_GYRO_EN) > 0) //使能陀螺仪输出
            {
                imudata.Gyro_x = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), Imu_config.Gyro_fsr); //Imu_config.Gyro_fsr
                imudata.Gyro_y = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), Imu_config.Gyro_fsr);
                imudata.Gyro_z = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), Imu_config.Gyro_fsr);
            }
            if ((print_en & IMUData.IMU_DATA_EULER_EN) > 0) //使能姿态角度输出
            {
                imudata.Rotation_x = (double)(short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]) / 100;
                imudata.Rotation_y = (double)(short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]) / 100;
                imudata.Rotation_z = (double)(short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]) / 100;
            }
            if ((print_en & IMUData.IMU_DATA_TEMP_EN) > 0) //使能温度输出
            {

                //ushort raw_temperature;
                //raw_temperature = (ushort)(RecvBuff[idx++] << 8 | RecvBuff[idx++]);
                //imudata.Temperature = Math.Round((double)raw_temperature / 132.48 + 25, 3);  //132.48 + 25,3
                imudata.Temperature = Math.Round(Imu_config.Imu_GetTemperature(RecvBuff[idx++], RecvBuff[idx++]), 3);
            }
            if ((print_en & IMUData.IMU_DATA_Q_EN) > 0) //使能四元数输出
            {
                imudata.q0 = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), 1);
                imudata.q1 = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), 1);
                imudata.q2 = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), 1);
                imudata.q3 = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), 1);
            }
            if ((print_en & IMUData.IMU_DATA_MAGN_EN) > 0)  //使能磁力计输出
            {
                imudata.Is_get_newdata = true;
                imudata.Magn_x = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), Imu_config.Magn_fsr * Imu_config.Magn_fsr_scale); //1Gauss = 100uT
                imudata.Magn_y = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), Imu_config.Magn_fsr * Imu_config.Magn_fsr_scale);
                imudata.Magn_z = Data_Lsb2Real((short)(RecvBuff[idx++] << 8 | RecvBuff[idx++]), Imu_config.Magn_fsr * Imu_config.Magn_fsr_scale);
                imudata.Cal_Magn_H();
            }

            if (Imu_unity_commu.Is_start_send)
            {
                Imu_unity_commu.Send2Unity(imudata.Rotation_x * 100, imudata.Rotation_y * 100, imudata.Rotation_z * 100);
            }

        }

        /// <summary>
        /// 将单片机中检测到的数据转换为真实数据
        /// </summary>
        /// <param name="raw_data">待转换数据</param>
        /// <param name="fsr">数据量程</param>
        /// <returns>真实数据</returns>
        private double Data_Lsb2Real(short raw_data,double fsr)
        {
            double result;
            result = (double)raw_data / 32768 * fsr;
            result = Math.Round(result,3);  //结果输出为小数点后3位
            return result;
        }

        /// <summary>
        /// 将真实数据按照量程转换为lsb
        /// </summary>
        /// <param name="raw_data">待转换数据</param>
        /// <param name="fsr">数据量程</param>
        /// <returns>lsb</returns>
        private short Data_Real2Lsb(double raw_data, double fsr)
        {
            return (short)(raw_data / fsr * 32768);
        }

        #endregion
        /****************************************************/

        /****************************************************/
        #region 接收到远程配置上报包

        //指定长度的字节数组转换为字符串
        private string Byte2String(byte[] buff, int offset, int length)
        {
            string buffer = "";
            if (offset + length < buff.Length)
            {
                for (int i = offset; i < offset + length; i++)
                {
                    //buffer += Convert.ToString(buff[i], 16);
                    buffer += buff[i].ToString("X2");
                }
                return buffer;
            }
            else return null;
        }

        private byte[] strToHexByte(string hexString)
        {

            hexString = hexString.Replace(" ", "");
            if ((hexString.Length % 2) != 0)
                hexString = "0" + hexString;
            byte[] returnBytes = new byte[hexString.Length / 2];
            for (int i = 0; i < returnBytes.Length; i++)
            {
                returnBytes[i] = Convert.ToByte(hexString.Substring(i * 2, 2), 16);
            }
            return returnBytes;
        }

        private bool Try_find_tag_cfg(string tagId, out Remote_tag_cfg cfg)
        {
            cfg = new Remote_tag_cfg();
            foreach (Remote_tag_cfg t in Remote_cfg_taglist)
            {
                if (t.ID == tagId)
                {
                    cfg = t;
                    return true;
                }
            }
            return false;
        }

        private void Remote_cfg_RecvHandler(byte[] recv_buff)
        {
            string id = Byte2String(recv_buff, 5, 6);
            if (!Try_find_tag_cfg(id, out Remote_tag_cfg cfg))
            {
                //需要添加
                cfg.ID = id;
                MethodInvoker mi = new MethodInvoker(() =>
                {
                    Remote_cfg_taglist.Add(cfg);
                    DataGridView_tag_cfg.ClearSelection();
                });
                Invoke(mi);
            }
            cfg.Static_freq= (ushort)(recv_buff[11] << 8 | recv_buff[12]);
            cfg.Alarm_freq = (ushort)(recv_buff[13] << 8 | recv_buff[14]);
            cfg.Moving_freq = (ushort)(recv_buff[15] << 8 | recv_buff[16]);
            if (recv_buff[17] == 0x00)
                cfg.Imu_en = true;
            else
                cfg.Imu_en = false;
            cfg.Imu_sense = recv_buff[18];
            cfg.Move_Pack = recv_buff[19];
            cfg.Static_Pack = recv_buff[20];
            cfg.RxAntDelay = (ushort)(recv_buff[21] << 8 | recv_buff[22]);
            cfg.Tag_Kind = recv_buff[23];
            cfg.Frame = recv_buff[24];
            cfg.TagVersion = (ushort)(recv_buff[25] << 8 | recv_buff[26]);
            if (recv_buff[27] == 0x00)
                cfg.PowerSet_EN = false;
            else
                cfg.PowerSet_EN = true;
            cfg.Power_db = recv_buff[28];
            cfg.Nosleep_freq = (ushort)(recv_buff[29] << 8 | recv_buff[30]);
            cfg.PowerOnTime = recv_buff[31];
            cfg.Pg_id = recv_buff[32];
            if (recv_buff[33] == 0x00)
                cfg.Poweroff_en = true;
            else
                cfg.Poweroff_en = false;
            cfg.Heart_Rate = recv_buff[34];
        }

       

        #endregion
        /****************************************************/

        /****************************************************/
        #region 计算接收强度等信息
        private double Cal_FPPower(Tag.Rx_diag_t rx_diag)
        {
            //计算FP power
            double result = Math.Pow(rx_diag.Fp_amp1, 2) + Math.Pow(rx_diag.Fp_amp2, 2) + Math.Pow(rx_diag.Fp_amp3, 2);
            double N_squre = Math.Pow(rx_diag.Rx_preambleCount, 2);
            result /= N_squre;
            /* 250314：按照说明书 FP的值是包含2位小数 即如果使用整数部分需要先右移2位即除以4 再平方就是16*/
            if (Module_use_chip == Module_Chip_t.DW3000) 
                result /= 16;
            result = 10 * Math.Log10(result) - 121.74;
            /* 250314：按照说明书应该要加上6*D D的取值目前占用dw3000没有的maxnoise*/
            if (Module_use_chip == Module_Chip_t.DW3000)
                result += rx_diag.DGC_dbg * 6;
            //if (Module_use_chip == Module_Chip_t.DW3000)
            //    result += 36;
            return Math.Round(result, 3);
        }

        private double Cal_RxPower(Tag.Rx_diag_t rx_diag)
        {
            //计算rx power
            double pow_value = 0;
            if (Module_use_chip == Module_Chip_t.DW1000)
                pow_value = Math.Pow(2, 17);
            else
                pow_value = Math.Pow(2, 21);
            double N_squre = Math.Pow(rx_diag.Rx_preambleCount, 2);
            double result = rx_diag.Max_growthCIR * pow_value / N_squre;

            result = 10 * Math.Log10(result) - 121.74;
            /* 250314：按照说明书应该要加上6*D D的取值目前占用dw3000没有的maxnoise*/
            if (Module_use_chip == Module_Chip_t.DW3000)
                result += rx_diag.DGC_dbg * 6;
            //if (Module_use_chip == Module_Chip_t.DW3000)
            //    result += 36;
            return Math.Round(result, 3);
        }
        #endregion
        /****************************************************/

        

        /****************************************************/
        #region 根据不同连接状态更改界面
        private void UI_ConnectChange()
        {
            MethodInvoker mi = new MethodInvoker(() =>
              {
                  switch (Connect_State)
                  {
                      case ConnectState.DisConnect:  //断开连接
                          {
                              Connect_Mode = ConnectMode.Unknown;
                              Get_ModuleVersion = false;
                              toolStripStatusLabel_state.Text = "软件状态：通讯未建立";
                              toolStripStatusLabel__firmware_version.Text = "设备固件版本：未连接设备";
                              toolStripStatusLabel_commu.Text = "未设置";
                              ToolStripMenuItem_SCAN.Enabled = true;  //关闭扫描串口按钮
                              ToolStripMenuItem1_OPEN_CLOSE.Enabled = true;
                              ToolStripMenuItem1_OPEN_CLOSE.Text = "打开串口";
                              ToolStripMenuItem_Connect.Text = "连接设备";
                              ToolStripMenuItem_Tcp.Text = "TCP连接";
                              ToolStripMenuItem_Tcp.Enabled = true;
                              toolStripComboBox_com.Enabled = true;  //串口选择
                              toolStripComboBox_Rate.Enabled = true; //串口波特率选择
                              toolStripMenuItem_SB.Enabled = false; //连接设备按钮
                              ToolStripMenuItem_SCAN_ID.Enabled = false;//扫描设备按钮
                              toolStripComboBox_ID.Enabled = true;//设备ID编辑框
                              ToolStripMenuItem_LJ.Enabled = true; //轨迹输出
                              ToolStripMenuItem_BJ.Enabled = true;//背景设置

                              comboBox_MODBUS_RATE.Enabled = false;//设置波特率
                              numericUpDown_ID.Enabled = false; //设置modbusID
                              comboBox_TAG_or_BS.Enabled = false; //设备模式
                              comboBox_DW_MODE.Enabled = false; //定位模式
                              numericUpDown_TAG_or_BS_ID.Enabled = false;//设备ID
                              button_readdata.Enabled = false; //读取配置按钮
                              button_wrdaata.Enabled = false;//载入配置按钮
                              comboBox_RANGING.Enabled = false;    //测距方式选择
                              comboBox_AIR_CHAN.Enabled = false;   //空中信道选择
                              comboBox_AIR_RAT.Enabled = false;   //空中速率选择
                              numericUpDown_KAM_Q.Enabled = false;  //卡尔曼Q
                              numericUpDown_KAM_R.Enabled = false;  //卡尔曼R
                              numericUpDown_RX_DELAY.Enabled = false;  //接收延时
                              btn_Navigate.Enabled = false;         //导航控制 
                              Btn_AutoCalibPos.Enabled = false; //自动标定
                              numericUpDown_origin_X.Enabled = false; //地图X坐标
                              numericUpDown_origin_Y.Enabled = false; //地图Y坐标
                              numericUpDown_map_multiple.Enabled = false; //地图比例
                              checkBox_draw_round.Enabled = false; //地图设置
                              checkBox_axis.Enabled = false;       //地图设置
                              checkBox_coordinate.Enabled = false;  //地图设置
                              checkBox_name.Enabled = false;       //地图设置

                              checkBox_JS.Enabled = false;//地图设置
                              CheckBox_AutoRtls.Enabled = false;

                              numericUpDown_TAG_num.Enabled = false;  //标签数量框
                              button_CJ_OPEN.Enabled = false;         //开始定位按钮
                              button_CJ_STOP.Enabled = false;       //取消定位按钮

                              dataGridView_TAG.Enabled = false;    //标签列表
                              dataGridView_BS_SET.Enabled = false; //基站列表
                              CheckBox_is_use_uwb_trim.Enabled = false; //是否设备uwb频偏
                              numericUpDown_uwb_trim.Enabled = false;    //频偏参数
                              button_write_uwb_trim.Enabled = false;      //写入频偏按钮
                              ToolStripMenuItem_ContinuousFrame.Enabled = false;  //连续帧测试
                              ToolStripMenuItem_ContinuousWave.Enabled = false;   //连续波测试
                              ToolStripMenuItem_Hardware_exit.Enabled = false;    //退出硬件测试
                              break;
                          }
                      case ConnectState.Connecting:  //连接设备，成功读取配置
                          {
                              toolStripStatusLabel_state.Text = "软件状态：读取设备成功";
                              if(Connect_Mode == ConnectMode.TCP)
                              {
                                  ToolStripMenuItem_Tcp.Text = "断开连接";
                                  ToolStripMenuItem1_OPEN_CLOSE.Enabled = false;
                              }
                              else
                              {
                                  ToolStripMenuItem1_OPEN_CLOSE.Text = "关闭串口";
                                  ToolStripMenuItem1_OPEN_CLOSE.Enabled = true;
                                  ToolStripMenuItem_Tcp.Enabled = false;
                              }
                              ToolStripMenuItem_SCAN.Enabled = false;  //关闭扫描串口按钮
                              toolStripComboBox_com.Enabled = false;  //串口选择
                              toolStripComboBox_Rate.Enabled = false; //串口波特率选择
                              ToolStripMenuItem_Connect.Text = "断开连接";
                              toolStripMenuItem_SB.Enabled = true; //连接设备按钮
                              ToolStripMenuItem_SCAN_ID.Enabled = false;//扫描设备按钮
                              toolStripComboBox_ID.Enabled = false;//设备ID编辑框
                              ToolStripMenuItem_LJ.Enabled = true; //轨迹输出
                              ToolStripMenuItem_BJ.Enabled = true;//背景设置

                              comboBox_MODBUS_RATE.Enabled = true;//设置波特率
                              numericUpDown_ID.Enabled = true; //设置modbusID

                              
                              comboBox_TAG_or_BS.Enabled = true; //设备模式
                              

                              comboBox_DW_MODE.Enabled = true; //定位模式
                              //numericUpDown_TAG_or_BS_ID.Enabled = true;//设备ID
                              button_readdata.Enabled = true; //读取配置按钮
                              button_wrdaata.Enabled = true;//载入配置按钮

                              comboBox_RANGING.Enabled = true;    //测距方式选择
                              //comboBox_AIR_CHAN.Enabled = true;   //空中信道选择
                              //comboBox_AIR_RAT.Enabled = true;   //空中速率选择
                              numericUpDown_KAM_Q.Enabled = true;  //卡尔曼Q
                              numericUpDown_KAM_R.Enabled = true;  //卡尔曼R
                              numericUpDown_RX_DELAY.Enabled = true;  //接收延时

                              numericUpDown_origin_X.Enabled = true; //地图X坐标
                              numericUpDown_origin_Y.Enabled = true; //地图Y坐标
                              numericUpDown_map_multiple.Enabled = true; //地图比例
                              checkBox_draw_round.Enabled = true; //地图设置
                              checkBox_axis.Enabled = true;       //地图设置
                              checkBox_coordinate.Enabled = true;  //地图设置
                              checkBox_name.Enabled = true;       //地图设置

                              checkBox_JS.Enabled = true;//地图设置
                              CheckBox_AutoRtls.Enabled = true;

                              if(comboBox_TAG_or_BS.SelectedIndex == 2) //如果是主基站
                              {
                                  btn_Navigate.Enabled = true;         //导航控制 
                                  Btn_AutoCalibPos.Enabled = true; //自动标定
                              }
                              //button_CJ_OPEN.Enabled = false;         //开始定位按钮
                              //button_CJ_STOP.Enabled = false;       //取消定位按钮
                              CheckBox_is_use_uwb_trim.Enabled = true; //是否设备uwb频偏
                              numericUpDown_uwb_trim.Enabled = true;    //频偏参数
                              button_write_uwb_trim.Enabled = true;      //写入频偏按钮
                              ToolStripMenuItem_ContinuousFrame.Enabled = true;  //连续帧测试
                              ToolStripMenuItem_ContinuousWave.Enabled = true;   //连续波测试
                              Connect_State = ConnectState.Connected;
                              break;
                          }

                      case ConnectState.Connect_WrongVersion:   //错误版本，禁止使用
                          {
                              toolStripStatusLabel__firmware_version.Text = "设备固件版本：版本错误";
                              break;
                          }
                      default:
                          break;
                  }
              });
            BeginInvoke(mi);
        }

        private void UI_WorkStateChange()
        {
            MethodInvoker mi = new MethodInvoker(() =>
            {
                switch(Work_State)
                {
                    case WorkState.RtlsStart:
                    {
                            comboBox_MODBUS_RATE.Enabled = false;//设置波特率
                            numericUpDown_ID.Enabled = false; //设置modbusID
                            comboBox_TAG_or_BS.Enabled = false; //设备模式
                            comboBox_DW_MODE.Enabled = false; //定位模式
                            numericUpDown_TAG_or_BS_ID.Enabled = false;//设备ID
                            button_readdata.Enabled = false; //读取配置按钮
                            button_wrdaata.Enabled = false;//载入配置按钮
                            toolStripComboBox_com.Enabled = false;  //串口选择
                            toolStripComboBox_Rate.Enabled = false; //串口波特率选择
                            comboBox_RANGING.Enabled = false;    //测距方式选择
                            comboBox_AIR_CHAN.Enabled = false;   //空中信道选择
                            comboBox_AIR_RAT.Enabled = false;   //空中速率选择
                            numericUpDown_KAM_Q.Enabled = false;  //卡尔曼Q
                            numericUpDown_KAM_R.Enabled = false;  //卡尔曼R
                            numericUpDown_RX_DELAY.Enabled = false;  //接收延时
                            numericUpDown_TAG_num.Enabled = false;  //标签数量框
                            dataGridView_TAG.Enabled = true;    //标签列表
                            dataGridView_BS_SET.Enabled = false; //基站列表
                            groupBox_AncProtocalConfig.Enabled = false;  //配置基站输出协议
                            CheckBox_AutoRtls.Enabled = false;
                            button_CJ_STOP.Enabled = true;
                            button_CJ_OPEN.Enabled = false;
                            btn_Navigate.Enabled = true;         //导航控制 
                            Btn_AutoCalibPos.Enabled = false;   //自动标定
                            CheckBox_is_use_uwb_trim.Enabled = false; //是否设备uwb频偏
                            numericUpDown_uwb_trim.Enabled = false;    //频偏参数
                            button_write_uwb_trim.Enabled = false;      //写入频偏按钮
                            ToolStripMenuItem_ContinuousFrame.Enabled = false;  //连续帧测试
                            ToolStripMenuItem_ContinuousWave.Enabled = false;   //连续波测试
                            ToolStripMenuItem_Hardware_exit.Enabled = false;    //退出硬件测试
                            ToolStripMenuItem_LJ.Enabled = false;               //轨迹输出
                            toolStripStatusLabel_state.Text = "软件状态：正在定位扫描";
                            Work_State = WorkState.Rtlsing;
                            break;
                    }
                    case WorkState.Idle:
                        {
                            comboBox_MODBUS_RATE.Enabled = true;//设置波特率
                            numericUpDown_ID.Enabled = true; //设置modbusID
                            comboBox_TAG_or_BS.Enabled = true; //设备模式
                            comboBox_DW_MODE.Enabled = true; //定位模式
                            button_readdata.Enabled = true; //读取配置按钮
                            button_wrdaata.Enabled = true;//载入配置按钮
                            comboBox_RANGING.Enabled = true;    //测距方式选择
                            numericUpDown_KAM_Q.Enabled = true;  //卡尔曼Q
                            numericUpDown_KAM_R.Enabled = true;  //卡尔曼R
                            numericUpDown_RX_DELAY.Enabled = true;  //接收延时
                            button_CJ_STOP.Enabled = false;
                            button_CJ_OPEN.Enabled = true;
                            dataGridView_TAG.Enabled = true;    //标签列表
                            dataGridView_BS_SET.Enabled = true; //基站列表
                            CheckBox_AutoRtls.Enabled = true;
                            btn_Navigate.Enabled = true;         //导航控制
                            groupBox_AncProtocalConfig.Enabled = true;  //配置基站输出协议
                            toolStripStatusLabel_state.Text = "软件状态：读取设备成功";
                            Btn_AutoCalibPos.Enabled = true;  //自动标定
                            CheckBox_is_use_uwb_trim.Enabled = true; //是否设备uwb频偏
                            numericUpDown_uwb_trim.Enabled = true;    //频偏参数
                            button_write_uwb_trim.Enabled = true;      //写入频偏按钮
                            ToolStripMenuItem_ContinuousFrame.Enabled = true;  //连续帧测试
                            ToolStripMenuItem_ContinuousWave.Enabled = true;   //连续波测试
                            ToolStripMenuItem_LJ.Enabled = true;               //轨迹输出
                            break;
                        }
                    case WorkState.IntoHardwareTest_cfg:
                        {
                            switch(Hardware_Test_Mode)
                            {
                                case 0x00:
                                    toolStripStatusLabel_state.Text = "软件状态：连续帧模式测试";
                                    break;
                                case 0x01:
                                    toolStripStatusLabel_state.Text = "软件状态：连续波模式测试";
                                    break;
                                default:break;
                            }
                            ToolStripMenuItem_Hardware_exit.Enabled = true;    //退出硬件测试
                            break;
                        }
                    case WorkState.OutHardwareTest_cfg:
                        {
                            toolStripStatusLabel_state.Text = "软件状态：读取设备成功";
                            ToolStripMenuItem_Hardware_exit.Enabled = false;    //退出硬件测试
                            Work_State = WorkState.Idle;
                            break;
                        }
                    default:break;
                }
            });
            BeginInvoke(mi);
        }

        private void UI_IMUStateChange()
        {
            MethodInvoker mi = new MethodInvoker(() => 
            {
                switch (IMU_State)
                {
                    case IMUState.NoConnect:
                        {
                            pictureBox_IMUStatus.BackColor = Color.Red;
                            label_IMUStatus.Text = "无IMU传感器连接...";
                            groupBox_imu_data.Enabled = false;
                            groupBox_imu_config.Enabled = false;
                            groupBox_imu_calib.Enabled = false;
                            Panel_Output_En.Enabled = false;                           
                            break;
                        }
                    case IMUState.Running:
                        {
                            pictureBox_IMUStatus.BackColor = Color.Green;
                            label_IMUStatus.Text = "IMU传感器已连接...";
                            groupBox_imu_data.Enabled = true;
                            groupBox_imu_config.Enabled = true;
                            groupBox_imu_calib.Enabled = true;
                            Panel_Output_En.Enabled = true;
                            comboBox_TAG_or_BS.Enabled = false;
                            comboBox_TAG_or_BS.SelectedIndex = 0;
                            break;
                        }
                    case IMUState.Calibing:
                        {
                            pictureBox_IMUStatus.BackColor = Color.Yellow;
                            label_IMUStatus.Text = "校准中...";
                            groupBox_imu_data.Enabled = false;
                            groupBox_imu_config.Enabled = false;
                            groupBox_imu_calib.Enabled = false;
                            Panel_Output_En.Enabled = false;
                            break;
                        }
                    case IMUState.RemoteTrans:
                        {
                            pictureBox_IMUStatus.BackColor = Color.Blue;
                            label_IMUStatus.Text = "远程传输数据中...";
                            groupBox_imu_data.Enabled = true;
                            groupBox_imu_config.Enabled = false;
                            groupBox_imu_calib.Enabled = false;
                            Panel_Output_En.Enabled = false;
                            break;
                        }
                    default:break;
                }
            });
            BeginInvoke(mi);
        }

        private void UI_ImuVesion_Change()
        {
            MethodInvoker mi = new MethodInvoker(() =>
            {
                if(Imu_config.version < IMUConfig.IMU_RB_VERSION_V2)  //RBV1
                {
                    //加速度计量程集合修改
                    comboBox_acc_fsr.Items.Clear();
                    comboBox_acc_fsr.Items.AddRange(Imu_config.RBV1_config_acc_fsr);
                    //陀螺仪量程集合修改
                    comboBox_gyro_fsr.Items.Clear();
                    comboBox_gyro_fsr.Items.AddRange(Imu_config.RBV1_config_gyro_fsr);
                    //采样频率集合修改
                    comboBox_odr.Items.Clear();
                    comboBox_odr.Items.AddRange(Imu_config.RBV1_config_odr);
                    //没有磁力计 
                    comboBox_magn_fsr.Enabled = false;
                    comboBox_magn_odr.Enabled = false;
                    checkBox_en_magn.Enabled = false;
                    checkBox_en_magn.Checked = false;
                    comboBox_Algo_select.SelectedIndex = 0;
                    comboBox_Algo_select.Enabled = false;
                }
                else  //RBV2
                {
                    //加速度计量程集合修改
                    comboBox_acc_fsr.Items.Clear();
                    comboBox_acc_fsr.Items.AddRange(Imu_config.RBV2_config_acc_fsr);
                    //陀螺仪量程集合修改
                    comboBox_gyro_fsr.Items.Clear();
                    comboBox_gyro_fsr.Items.AddRange(Imu_config.RBV2_config_gyro_fsr);
                    //采样频率集合修改
                    comboBox_odr.Items.Clear();
                    comboBox_odr.Items.AddRange(Imu_config.RBV2_config_odr);
                    //有磁力计 
                    comboBox_magn_fsr.Enabled = true;
                    comboBox_magn_odr.Enabled = true;
                    checkBox_en_magn.Enabled = true;
                    comboBox_Algo_select.Enabled = true;
                }
                
            });
            BeginInvoke(mi);
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 定时器函数 用于MODBUS扫描ID是轮询发送询问协议
        private void timer_SCAN_ID_Tick(object sender, EventArgs e)
         {
           
             if (time_SCAN_NUM < 256)
             {
                toolStripProgressBar_SCAN.Value = time_SCAN_NUM;
                ModbusRTU.Instance.Modbus_com.ModbusID = (byte)time_SCAN_NUM;
                ModbusRTU.Instance.Modbus_com.FunctionCode = 0x03;
                ModbusRTU.Instance.Modbus_com.Addr = 0x0000;
                ModbusRTU.Instance.Modbus_com.RegNum = 0x0000;

                byte[] send_buf = ModbusRTU.Instance.Modbus03Send();
                if (send_buf != null)
                {
                    APP_Send_Data(send_buf,0);
                    Work_State = WorkState.ScanModbusID;
                }
                 time_SCAN_NUM++;
             }
             else
             {
                time_SCAN_NUM = 0;
                timer_SCAN_ID.Enabled = false;
                Work_State = WorkState.Idle;
                toolStripComboBox_ID.Items.Clear();
                if (ID_buf.Count > 0 && ID_buf != null)
                {
                    // Array.Resize<string>(ref ID_buf, ID_buf.Length + 1);
                    string[] ID_Count = new string[ID_buf.Count] ;
                    ID_buf.CopyTo(ID_Count);
                    toolStripComboBox_ID.Items.AddRange(ID_Count);
                    toolStripComboBox_ID.SelectedIndex = 0;
                }
                MessageBox.Show("搜索ID完成!");
             }
         }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 把对应标签ID的数据写入列表
        private void Save_TagData(int x, int y, int z, uint[] dists, int index, string time ,uint Cal_Flag, double velocity, int Mode)
        {
            DataRow dt;
            if (index > DataTable_MaxLen)
                return;
            if (Mode == 1)
            {                
                dt = DataTable_Trace1.Rows[index];
                dt["Time"] = time;
                dt["x"] = x.ToString();
                dt["y"] = y.ToString();
                dt["z"] = z.ToString();

                for (int i = 0; i < ANCHOR_MAX_COUNT; i++)
                    dt[4 + i] = dists[i].ToString();

                dt["Flag"] = Cal_Flag.ToString();
                dt["Velocity"] = velocity.ToString();
            }
            else
            {
                
                dt = DataTable_Trace2.Rows[index];                
                dt["Time"] = time;
                dt["x"] = x.ToString();
                dt["y"] = y.ToString();
                dt["z"] = z.ToString();

                for (int i = 0; i < ANCHOR_MAX_COUNT; i++)
                    dt[4 + i] = dists[i].ToString();

                dt["Flag"] = Cal_Flag.ToString();
                dt["Velocity"] = velocity.ToString();
            }           
        }

        private void Save_AnalyzeData(int row_idx ,string time,int cal_flag, int x, int y, int z, int dist_flag , uint[] dists, Tag.Rx_diag_t rxdiag, uint[] ts)
        {
            DataRow dr = DataTable_Analyse.Rows[row_idx];
            int idx = 0, i = 0;
            dr[idx++] = time;
            if (Check_BitIsTrue((byte)Analyse_format, ANC_PROTOCAL_RTLS))
            {
                dr[idx++] = cal_flag;
                dr[idx++] = x;
                dr[idx++] = y;
                dr[idx++] = z;
            }
            if (Check_BitIsTrue((byte)Analyse_format, ANC_PROTOCAL_DIST))
            {
                dr[idx++] = dist_flag;
                for (i = 0; i < ANCHOR_MAX_COUNT; i++)                
                    dr[idx++] = dists[i];               
            }
            if (Check_BitIsTrue((byte)Analyse_format, ANC_PROTOCAL_RXDIAG))
            {
                dr[idx++] = rxdiag.Max_noise;
                dr[idx++] = rxdiag.Std_noise;
                dr[idx++] = rxdiag.Fp_amp1;
                dr[idx++] = rxdiag.Fp_amp2;
                dr[idx++] = rxdiag.Fp_amp3;
                dr[idx++] = rxdiag.Max_growthCIR;
                dr[idx++] = rxdiag.Rx_preambleCount;
                dr[idx++] = rxdiag.Fp;
                dr[idx++] = rxdiag.Fp_power;
                dr[idx++] = rxdiag.Rx_power;
            }
            if (Check_BitIsTrue((byte)Analyse_format, ANC_PROTOCAL_TIMESTAMP))
            {
                for (i = 0; i < 6; i++)
                    dr[idx++] = ts[i];
            }
        }


        #endregion
        /****************************************************/

        /****************************************************/
        #region 按下读取配置按钮
        private void button_readdata_Click(object sender, EventArgs e)
         {
            ModbusRTU.Instance.Modbus_com.ModbusID = NOW_ID;
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x03;
            ModbusRTU.Instance.Modbus_com.Addr = 0x00;
            ModbusRTU.Instance.Modbus_com.RegNum = ModbusRTU.RegNum_ReadConfig;
            byte[] send_byte = ModbusRTU.Instance.Modbus03Send();
            if (send_byte != null)
                APP_Send_Data(send_byte,0);
            Work_State = WorkState.ReadConfig;
         }
        #endregion 
        /****************************************************/

        /****************************************************/
        #region 按下写入配置按钮
        private void button_wrdaata_Click(object sender, EventArgs e)
         {
            int i;
            byte[] buff_temp = new byte[ModbusRTU.RegNum_WriteConfig * 2];

            //串口波特率 0-9各对应不同
            buff_temp[0] = 0x00;
            buff_temp[1] = (byte)(comboBox_MODBUS_RATE.SelectedIndex);  
            //modbusID
            buff_temp[2] = 0x00;
            buff_temp[3] = (byte)(numericUpDown_ID.Value);
            //测距方式 DS0 1HDS 定位工作模式 一对一0 二维定位1 三维定位2
            buff_temp[4] = (byte)(comboBox_RANGING.SelectedIndex);
            buff_temp[5] = (byte)(comboBox_DW_MODE.SelectedIndex);
            //设备模式 标签0 次基站1 主基站2
            buff_temp[6] = 0x00;
            buff_temp[7] = (byte)(comboBox_TAG_or_BS.SelectedIndex);
            //设备ID 根据设备模式而不同
            if (comboBox_TAG_or_BS.SelectedIndex == 0) //标签
            {
                buff_temp[8] = 0x00; 
                buff_temp[9] = (byte)(numericUpDown_TAG_or_BS_ID.Value); 
            }
            if (comboBox_TAG_or_BS.SelectedIndex == 1) //次基站
            {
                buff_temp[8] = (byte)(numericUpDown_TAG_or_BS_ID.Value);
                buff_temp[9] = 0x00; 
            }
            if (comboBox_TAG_or_BS.SelectedIndex == 2)  //主基站
            {
                buff_temp[8] = 0x00;
                buff_temp[9] = 0x00; 
            }
            //空中信道 空中速率
            buff_temp[10] = (byte)(comboBox_AIR_CHAN.SelectedIndex);
            buff_temp[11] = (byte)(comboBox_AIR_RAT.SelectedIndex);
            //卡尔曼Q
            buff_temp[12] = (byte)(numericUpDown_KAM_Q.Value / 256);
            buff_temp[13] = (byte)(numericUpDown_KAM_Q.Value % 256);
            //卡尔曼R
            buff_temp[14] = (byte)(numericUpDown_KAM_R.Value / 256);
            buff_temp[15] = (byte)(numericUpDown_KAM_R.Value % 256);
            //天线延时
            buff_temp[16] = (byte)(numericUpDown_RX_DELAY.Value / 256);
            buff_temp[17] = (byte)(numericUpDown_RX_DELAY.Value % 256);
            //基站使能情况和各基站位置
            buff_temp[18] = 0;
            buff_temp[19] = 0;
            ushort Cal_AncEN = 0;
            Anchor anc;
            for(i = 0; i < ANCHOR_MAX_COUNT; i++)
            {
                anc = AnchorList[i];
                if (anc.IsUse)
                    Cal_AncEN |= (ushort)(1 << i);
                buff_temp[22 + i * 6] = (byte)((short)anc.x >> 8);
                buff_temp[23 + i * 6] = (byte)((short)anc.x& 0x00FF);
                buff_temp[24 + i * 6] = (byte)((short)anc.y >> 8);
                buff_temp[25 + i * 6] = (byte)((short)anc.y & 0x00FF);
                buff_temp[26 + i * 6] = (byte)((short)anc.z >> 8);
                buff_temp[27 + i * 6] = (byte)((short)anc.z & 0x00FF);
            }
            buff_temp[20] = (byte)(Cal_AncEN >> 8);
            buff_temp[21] = (byte)(Cal_AncEN & 0x00FF);

            if (CheckBox_AutoRtls.Checked)
            {
                //定位使能 
                buff_temp[118] = 0;
                buff_temp[119] = 8;
            }
            else
            {
                //定位使能 
                buff_temp[118] = 0;
                buff_temp[119] = 9;
            }

            //是否由模块解算
            buff_temp[120] = IsCalInModule == true ? (byte)1 : (byte)0;
            //定位标签数量
            buff_temp[121] = (byte)numericUpDown_TAG_num.Value;
            //要定位标签ID

            for (i = 0; i < (byte)numericUpDown_TAG_num.Value; i++)
            {
                if (i % 2 != 0)  //奇数
                {
                    if (dataGridView_TAG.Rows[i].Cells[0].Value == null)                    
                        buff_temp[121 + i] = 0;
                    else
                        buff_temp[121 + i] = Convert.ToByte(dataGridView_TAG.Rows[i].Cells[0].Value);
                }
                else
                {
                    if (dataGridView_TAG.Rows[i].Cells[0].Value == null)
                        buff_temp[123 + i] = 0;
                    else
                        buff_temp[123 + i] = Convert.ToByte(dataGridView_TAG.Rows[i].Cells[0].Value);
                }
            }
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x10;
            ModbusRTU.Instance.Modbus_com.Addr = 0x00;
            ModbusRTU.Instance.Modbus_com.RegNum = ModbusRTU.RegNum_WriteConfig;
            ModbusRTU.Instance.Modbus_com.ModbusID = NOW_ID;
            byte[] buff = ModbusRTU.Instance.Modbus10Send(buff_temp);
            if (buff != null)
                APP_Send_Data(buff,0);
            Work_State = WorkState.WriteConfig;
         }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 导航控制
        private void btn_Navigate_Click(object sender, EventArgs e)
        {
            NavigationWindow navi_win = new NavigationWindow(TagList, new Action<byte[]>(APP_Send_Data), new Action(Navi_Close_Handler));
            Send_NaviMsgEvent += navi_win.GetMessageFromMain;  //登记接收事件 主界面接收到数据后会发起事件委托
            Send_Navi_SelectPoint_Event += navi_win.GetSelectPointFromMain;
            navi_win.OnStartSelectPoint_EventHandler += Get_OnStartSelectPoint_Event;
            Is_OpenNavi = true;
            navi_win.Show();
        }

        void Get_OnStartSelectPoint_Event(object sender, EventArgs e)
        {
            this.Cursor = Cursors.Cross;            
            Is_NaviSelecting = true;
            Is_SelectNavi = false;
            tabControl1.SelectedIndex = 1; //自动跳转到定位显示页面
            
        }

        /// <summary>
        /// 导航窗口关闭事件
        /// </summary>
        private void Navi_Close_Handler()
        {
            Is_OpenNavi = false;
            //结束发送导航信息
            if(Send_NaviMsgEvent != null)
            {
                Delegate[] dels = Send_NaviMsgEvent.GetInvocationList();
                foreach(Delegate del in dels)
                {
                    Send_NaviMsgEvent -= del as EventHandler;
                }
            }
            if (Send_Navi_SelectPoint_Event != null)
            {
                Delegate[] dels = Send_Navi_SelectPoint_Event.GetInvocationList();
                foreach (Delegate del in dels)
                {
                    Send_Navi_SelectPoint_Event -= del as EventHandler<SelectPointEventArg>;
                }
            }
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 二维地图比例参数被改变
        private void numericUpDown_map_multiple_ValueChanged(object sender, EventArgs e)
         {
            GDI_Rtls_Draw.Axis_multiple = (float)numericUpDown_map_multiple.Value;
         }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 地图原点坐标X轴参数被改变
        private void numericUpDown_origin_X_ValueChanged(object sender, EventArgs e)
         {
             GDI_Rtls_Draw.Map_origin_x = (Int16)(numericUpDown_origin_X.Value);
         }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 地图原点坐标Y轴参数被改变
        private void numericUpDown_origin_Y_ValueChanged(object sender, EventArgs e)
         {
            GDI_Rtls_Draw.Map_origin_y = (Int16)(numericUpDown_origin_Y.Value);
         }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 检测的标签数量参数被改变
        private void numericUpDown_TAG_num_ValueChanged(object sender, EventArgs e)
         {
            Int16 num;
            int i;
            if (numericUpDown_TAG_num.Value == 0) 
               numericUpDown_TAG_num.Value = 1;
            else if(numericUpDown_TAG_num.Value > 100)
               numericUpDown_TAG_num.Value = 100;


            num = (Int16)(this.dataGridView_TAG.Rows.Count);

            if (num < numericUpDown_TAG_num.Value)
            {
                for(i=0;i<numericUpDown_TAG_num.Value-num;i++)
                {
                    dataGridView_TAG.Rows.Add();
                    for (int j = 0; j < dataGridView_TAG.ColumnCount; j++)
                    {
                        dataGridView_TAG.Rows[num + i].Cells[j].Value = 0;
                    }                     
                }

            }
            if (num > numericUpDown_TAG_num.Value)
            {
                for (i = 0; i < num - numericUpDown_TAG_num.Value; i++)
                {
                    this.dataGridView_TAG.Rows.RemoveAt(this.dataGridView_TAG.Rows.Count - 1);
                }
            }
         }
        #endregion
        /****************************************************/

        /****************************************************/
        #region MODBUS-ID参数被改变
        private void numericUpDown_ID_ValueChanged(object sender, EventArgs e)
         {
             int ff;
             textBox_MODBUS_ID.Text = "0x";
             ff = (int)numericUpDown_ID.Value % 256 / 16;
             if (ff > 9)
             {
                 switch (ff)
                 {
                     case 10: textBox_MODBUS_ID.Text += "A"; break;
                     case 11: textBox_MODBUS_ID.Text += "B"; break;
                     case 12: textBox_MODBUS_ID.Text += "C"; break;
                     case 13: textBox_MODBUS_ID.Text += "D"; break;
                     case 14: textBox_MODBUS_ID.Text += "E"; break;
                     case 15: textBox_MODBUS_ID.Text += "F"; break;
                     default: break;
                 }
             }
             else textBox_MODBUS_ID.Text += ff.ToString();
             ff = (int)numericUpDown_ID.Value % 16;
             if (ff > 9)
             {
                 switch (ff)
                 {
                     case 10: textBox_MODBUS_ID.Text += "A"; break;
                     case 11: textBox_MODBUS_ID.Text += "B"; break;
                     case 12: textBox_MODBUS_ID.Text += "C"; break;
                     case 13: textBox_MODBUS_ID.Text += "D"; break;
                     case 14: textBox_MODBUS_ID.Text += "E"; break;
                     case 15: textBox_MODBUS_ID.Text += "F"; break;
                     default: break;
                 }
             }
             else textBox_MODBUS_ID.Text += ff.ToString(); 
         }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 定时器 用于视图刷新
        private void timer_display_Tick(object sender, EventArgs e)
         {
             
            if (Rtls_State == RtlsMode.Rtls_2D || Rtls_State == RtlsMode.Rtls_3D)   //二维或三维定位模式
            {
                Draw_Render();
                //Drawing_update();
                if (Rtls_State == RtlsMode.Rtls_3D)  //三维定位渲染
                    Render();
            }
            else if (Rtls_State == RtlsMode.Ranging) //一对一测距模式
            {
                //T_B.Start();
                Drawing_update_one_to_one();
            }
            

            //Drawing_Boxing1_Update();
            //Drawing_Boxing2_Update();
            //Drawing_BOXING1_update(0);
            //Drawing_BOXING2_update(0);

            
            

        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 点击串口搜索按钮
        private void ToolStripMenuItem_SCAN_Click(object sender, EventArgs e)
        {
            //string[] str = SerialPort.GetPortNames();
            //toolStripComboBox_com.Items.Clear();
            //if(str.Length > 0)
            //{
            //    toolStripComboBox_com.Items.AddRange(str);
            //    toolStripComboBox_com.SelectedIndex = 0;
            //    toolStripComboBox_Rate.SelectedIndex = 7;
            //}
            //else
            //{
            //    MessageBox.Show("当前无串口连接！");
            //}
            Search_Port();
        }

        private void Search_Port()
        {
            try
            {
                //string[] str = SerialPort.GetPortNames();
                toolStripComboBox_com.Items.Clear();
                List<string> comList = GetPortDeviceName();
                if (comList.Count > 0)
                {
                    toolStripComboBox_com.SelectedIndex = 0;
                    toolStripComboBox_Rate.SelectedIndex = 7;
                }
                else
                {
                    MessageBox.Show("当前无串口连接！");
                }
                //if (str.Length > 0)
                //{
                //    GetPortDeviceName();
                //    toolStripComboBox_com.Items.AddRange(str);
                //    toolStripComboBox_com.SelectedIndex = 0;
                //    toolStripComboBox_Rate.SelectedIndex = 7;
                //}
                //else
                //{
                //    MessageBox.Show("当前无串口连接！");
                //}
            }
            catch(Exception ex)
            {
                MessageBox.Show("串口设备详细信息获取失败！");
                //MessageBox.Show(ex.Message + ex.StackTrace);
                string[] str = SerialPort.GetPortNames();
                if (str.Length > 0)
                {
                    toolStripComboBox_com.Items.AddRange(str);
                    toolStripComboBox_com.SelectedIndex = 0;
                    toolStripComboBox_Rate.SelectedIndex = 7;
                }
                else
                {
                    MessageBox.Show("当前无串口连接！");
                }
            }
        }

        private List<string> GetPortDeviceName()
        {
            List<string> ComList = new List<string>();
            using (ManagementObjectSearcher searcher = new ManagementObjectSearcher
                ("select * from Win32_PnPEntity where Name like '%(COM%'"))
            {
                ManagementObjectCollection comInfos = searcher.Get();
                foreach (ManagementObject info in comInfos)
                {
                    if (info.Properties["Name"].Value != null)
                    {
                        string deviceName = info.Properties["Name"].Value.ToString();
                        int startIndex = deviceName.IndexOf("(");
                        int endIndex = deviceName.IndexOf(")");
                        string comName = deviceName.Substring(startIndex + 1, endIndex - startIndex - 1);
                        string comDescription = deviceName.Substring(0, startIndex);
                        ComList.Add(comName + ":" + comDescription);
                    }
                }
                if (ComList.Count > 0)
                {
                    toolStripComboBox_com.Items.AddRange(ComList.ToArray());
                }

                return ComList;
            }
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 点击打开串口/关闭串口按钮
        private void ToolStripMenuItem1_OPEN_CLOSE_Click(object sender, EventArgs e)
         {
            if (!serialPort1.IsOpen)
            {
                if (toolStripComboBox_com.SelectedItem == null)
                {
                    MessageBox.Show("请选择正确的串口", "提示");
                    return;
                }
                //serialPort1.PortName = toolStripComboBox_com.SelectedItem.ToString();
                string com = toolStripComboBox_com.SelectedItem.ToString();
                if(com.IndexOf(":") != -1)
                {
                    serialPort1.PortName = com.Substring(0, com.IndexOf(":"));
                }
                else
                {
                    serialPort1.PortName = com;
                }
                serialPort1.BaudRate = Convert.ToInt32(toolStripComboBox_Rate.SelectedItem.ToString());
                Flag_BaudRate = toolStripComboBox_Rate.SelectedIndex;

                serialPort1.DataBits = 8;
                serialPort1.StopBits = StopBits.One;
                serialPort1.Parity = Parity.None;
                serialPort1.ReadTimeout = 75;
                serialPort1.WriteTimeout = 100;
                try
                {
                    serialPort1.Open();
                }
                catch
                {
                    MessageBox.Show("串口打开失败", "提示");
                    return;
                }
                Connect_Mode = ConnectMode.USB;
                serialPort1.DataReceived += new SerialDataReceivedEventHandler(SerialDataReceive);
                ToolStripMenuItem1_OPEN_CLOSE.Text = "关闭串口";
                toolStripStatusLabel_state.Text = "软件状态：未连接设备";
                toolStripStatusLabel_commu.Text = "串口连接";
                toolStripComboBox_com.Enabled = false;
                toolStripComboBox_Rate.Enabled = false;
                ToolStripMenuItem_Tcp.Enabled = false;
                toolStripMenuItem_SB.Enabled = true;
                toolStripComboBox_ID.Enabled = true;
                ToolStripMenuItem_SCAN_ID.Enabled = true;
            }
            else
            {
                //Connect_State = ConnectState.DisConnecting;
                Serial_Close_Handler();
            }
        }

        /// <summary>
        /// 串口关闭后需要完成的动作
        /// </summary>
        private void Serial_Close_Handler()
        {
            Connect_Mode = ConnectMode.Unknown;
            serialPort1.DataReceived -= SerialDataReceive; 
            try  //这里try catch 是因为可能串口已经被拔掉 导致端口关闭
            {
                serialPort1.DiscardInBuffer();
                serialPort1.Close();
            }
            catch
            {

            }

            Work_State = WorkState.Idle;
            Connect_State = ConnectState.DisConnect;
            IMU_State = IMUState.NoConnect;
            Imu_config.Config_Init = false;
            Get_ModuleVersion = false;
            RtlsTimer.Stop();
            Task.Run(() => UI_ConnectChange());
            Task.Run(() => UI_IMUStateChange());
        }

        /// <summary>
        /// 检测到tcp服务端断开后的动作
        /// </summary>
        private void Tcp_Close_Handler()
        {
            MessageBox.Show("TCP服务器断开连接！");
            Work_State = WorkState.Idle;
            Connect_State = ConnectState.DisConnect;
            IMU_State = IMUState.NoConnect;
            Imu_config.Config_Init = false;
            Get_ModuleVersion = false;
            Task.Run(() => UI_ConnectChange());
            Task.Run(() => UI_IMUStateChange());
        }

        #endregion
        /****************************************************/

        /****************************************************/
        #region 点击扫描ID按钮
        private void ToolStripMenuItem_SCAN_ID_Click(object sender, EventArgs e)// 扫描设备ID
         {
             //    Array.Clear(ID_buf,0 , ID_buf.Length);
             ID_buf.Clear();
             timer_SCAN_ID.Enabled = true;
             toolStripProgressBar_SCAN.Value = 0;
         }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 点击连接设备按钮
        private void ToolStripMenuItem_Connect_Click(object sender, EventArgs e)  //连接设备
         {
            if (Connect_State != ConnectState.Connected)  //设备未连接
            {
                int timeout = 0;
                /* 先读取uwb部分 */
                try
                {
                    NOW_ID = (byte)Convert.ToInt16(toolStripComboBox_ID.Text.ToString());
                }
                catch
                {
                    MessageBox.Show("请输入正确ID", "提示");
                    return;
                }
                ModbusRTU.Instance.Modbus_com.ModbusID = NOW_ID;
                ModbusRTU.Instance.Modbus_com.FunctionCode = 0x03;
                ModbusRTU.Instance.Modbus_com.Addr = 0x00;
                ModbusRTU.Instance.Modbus_com.RegNum = ModbusRTU.RegNum_ReadConfig;
                byte[] send_byte = ModbusRTU.Instance.Modbus03Send();
                if (send_byte != null)
                    APP_Send_Data(send_byte,0);
                Connect_State = ConnectState.Connecting;
                Work_State = WorkState.ReadConfig;
                toolStripStatusLabel__firmware_version.Text = "软件状态：读取设备失败";

                do
                {
                    Thread.Sleep(50);
                    timeout++;
                } while (Work_State != WorkState.Idle && timeout < 10);

                if (Work_State != WorkState.Idle) //本次读取失败
                {
                    Work_State = WorkState.Idle;
                    return;
                }
                
                Thread read_imu_thread = new Thread(Imu_First_Read_Handler);
                read_imu_thread.IsBackground = true;
                read_imu_thread.Start();
                
            }             
            else if(Connect_State == ConnectState.Connected)
            {
                Connect_State = ConnectState.DisConnecting;
                
                if(Connect_Mode == ConnectMode.TCP)
                {
                    Tcp_dataClient.DisConnect(false); //主动断开
                }
                else if(Connect_Mode == ConnectMode.USB)
                {
                    serialPort1.DiscardInBuffer();
                    serialPort1.Close();
                }
                
                Work_State = WorkState.Idle;
                Connect_State = ConnectState.DisConnect;
                IMU_State = IMUState.NoConnect;
                Imu_config.Config_Init = false;
                Get_ModuleVersion = false;
                Task.Run(() => UI_ConnectChange());
                Task.Run(() => UI_IMUStateChange());
            }

            return;            
         }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 点击地图导入按钮
        private void ToolStripMenuItem_map_in_Click(object sender, EventArgs e)
         {
             OpenFileDialog file = new OpenFileDialog();
             file.InitialDirectory = ".";
             file.Filter = "所有文件(*.*)|*.*";
             file.ShowDialog();
             if (!string.IsNullOrWhiteSpace(file.FileName))
             {
                    //获得文件的绝对路径
                 try
                 {
                    GDI_Rtls_Draw.Set_Map_Img(file.FileName);
                    //this.pictureBox_2d.Load(pathname);
                }
                 catch (Exception ex)
                 {
                     MessageBox.Show(ex.Message);
                 }
             }
         }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 地图清除按钮
        private void ToolStripMenuItem1_map_clear_Click(object sender, EventArgs e)
         {
            //pathname = null;
            //gph.Clear(Color.White);
            //this.pictureBox_2d.Image = bMap;
            GDI_Rtls_Draw.Clear_Map();
         }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 双击串口数据流串口，清除数据
        private void textBox_com_data_DoubleClick(object sender, EventArgs e)
         {
             textBox_com_data.Clear();
         }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 点击开始定位按钮
        private void button_CJ_OPEN_Click(object sender, EventArgs e)
         {

            //更换基站信息
            //Array.Clear(AnchorGroup, 0, AnchorGroup.Length);
            Rtls_Init();

            //发送命令
            ModbusRTU.Instance.Modbus_com.ModbusID = NOW_ID;
            ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_ModuleMode;
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x10;
            ModbusRTU.Instance.Modbus_com.RegNum = 1;

            byte[] temp = new byte[2];
            temp[0] = 0x00;
            temp[1] = 0x04;  //持续定位自动上报数据
            byte[] send_buff = ModbusRTU.Instance.Modbus10Send(temp);
            if (send_buff != null)
                APP_Send_Data(send_buff,0);
            Work_State = WorkState.RtlsStart;

            //timer_DW.Enabled = true;
            timer_display.Enabled = true;
            RtlsTimer.Start();
         }

        /// <summary>
        /// 初始化定位信息
        /// </summary>
        private void Rtls_Init()
        {
            for (int i = 0; i < AnchorGroup.Length; i++)
            {
                AnchorGroup[i].x = AnchorList[i].x;
                AnchorGroup[i].y = AnchorList[i].y;
                AnchorGroup[i].z = AnchorList[i].z;
                AnchorGroup[i].IsUse = AnchorList[i].IsUse;
            }

            //更换标签信息
            TagList.Clear();
            for (int i = 0; i < dataGridView_TAG.Rows.Count; i++)
            {
                int Tag_id = int.Parse(dataGridView_TAG.Rows[i].Cells["TAG_ID"].Value.ToString());
                TagList.Add(new Tag(Tag_id, i));
            }

            //初始化接收强度信息
            Rxdiag.rx_diagnostic_init();

            //初始化三维部分信息
            int traceLen = (int)numericUpDown_TKTraceLen.Value;
            if (TK_tagTraceHelper != null)
                TK_tagTraceHelper.Dispose();
            TK_tagTraceHelper = new DrawHelper(traceLen, TagList.Count);

        }


        #endregion
        /****************************************************/

        /****************************************************/
        #region 按下停止定位按钮
        private void button_CJ_STOP_Click(object sender, EventArgs e)
        {
            ModbusRTU.Instance.Modbus_com.ModbusID = NOW_ID;
            ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_ModuleMode;
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x10;
            ModbusRTU.Instance.Modbus_com.RegNum = 1;

            byte[] temp = new byte[2];
            temp[0] = 0x00;
            temp[1] = 0x00;  
            byte[] send_buff = ModbusRTU.Instance.Modbus10Send(temp);
            if (send_buff != null)
            {
                Work_State = WorkState.RtlsStop;
                do
                {
                   Thread.Sleep(100);
                   APP_Send_Data(send_buff,0);                   
                }
                while (Work_State != WorkState.Idle);
            }

            timer_display.Enabled = false;
            RtlsTimer.Stop();
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 点击公司LOGO
        private void toolStripStatusLabel2_Click(object sender, EventArgs e)
         {
             System.Diagnostics.Process.Start("www.gzlwkj.com");
         }
        #endregion
        /****************************************************/



        /****************************************************/
        #region 点击轨迹开关按钮
         private void button_GJ_Click(object sender, EventArgs e)
         {
            if(!isGJ)
            {
                isGJ = true;                
                //checkBox_draw_round.Checked = false;
                //checkBox_draw_round.Enabled = false;
                button_GJ.Text = "清除轨迹显示";
            }
            else
            {
                isGJ = false;
                //checkBox_draw_round.Enabled = true;
                button_GJ.Text = "保持轨迹显示";
            }
            GDI_Rtls_Draw.Change_Trace_Status(isGJ);
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 数据透传发送
        //确认发送
        private void Btn_ConfirmSend_Click(object sender, EventArgs e)
        {
            int i;
            //转化输入字符为字节数组形式
            string str = Text_DataSend.Text;
            byte[] temp = Get_DataSend_byte(str, checkBox_HexInput.Checked);

            if (temp == null)
                return;

            //确认字符串转换的字节数组的长度小于最大长度 若大于最大长度 则只发送最大长度以内的
            byte[] data_send = new byte[temp.Length];

            if (temp.Length > AT.AT_DATA_SENDLEN_MAX)
            {
                MessageBox.Show(string.Format("要发送的数据字节长度大于设置最大长度{0}，只发送最大长度内的数据！", AT.AT_DATA_SENDLEN_MAX));
                data_send = new byte[AT.AT_DATA_SENDLEN_MAX];
                for (i = 0; i < AT.AT_DATA_SENDLEN_MAX; i++)
                    data_send[i] = temp[i];
            }
            else
            {
                for (i = 0; i < temp.Length; i++)
                    data_send[i] = temp[i];
            }
            //AT协议发送到基站
            string recv_id = comboBox_DataSendID.Text.ToString();
            if (string.IsNullOrEmpty(recv_id))
            {
                MessageBox.Show("请先选择要数据透传的标签ID！");
                return;
            }
            if (recv_id == "主基站")
                recv_id = "255";

            if (checkBox_HexInput.Checked)
            {
                byte[] send_buff = AT.AT_DataSend_Write(data_send, recv_id);
                if (send_buff != null)
                {
                    AT_Recv_Show_Tips = false;
                    APP_Send_Data(send_buff, 1);
                }
            }
            else
            {
                string at_send_str = Encoding.UTF8.GetString(data_send);
                if (!string.IsNullOrEmpty(at_send_str))
                {
                    byte[] send_buff = AT.AT_DataSend_Write(at_send_str, recv_id);
                    if (send_buff != null)
                    {
                        AT_Recv_Show_Tips = false;
                        APP_Send_Data(send_buff, 1);
                    }
                }
            }
        }

        //循环发送
        private void checkBox_SendPeriod_CheckedChanged(object sender, EventArgs e)
        {
            if (checkBox_SendPeriod.Checked == true)
            {
                string str_period = Text_PeriodTime.Text;
                if (string.IsNullOrEmpty(str_period))
                {
                    MessageBox.Show("请输入循环发送时间！");
                    checkBox_SendPeriod.Checked = false;
                    return;
                }
                int period_time = int.Parse(str_period);
                if (period_time < 10)
                {
                    MessageBox.Show("请将循环发送时间设置大于10ms!");
                    checkBox_SendPeriod.Checked = false;
                    return;
                }
                timer_DataSendPeriod.Interval = period_time;  //设置周期时间

                /*******设置发送字节数组*******/
                int i;
                //转化输入字符为字节数组形式                
                string str = Text_DataSend.Text;
                byte[] temp = Get_DataSend_byte(str, checkBox_HexInput.Checked);

                if (temp == null)
                    return;

                //确认字符串转换的字节数组的长度小于10 若大于10 则只发送10以内的
                byte[] data_send = new byte[temp.Length];
                if (temp.Length > AT.AT_DATA_SENDLEN_MAX)
                {
                    MessageBox.Show(string.Format("要发送的数据字节长度大于设置最大长度{0}，只发送最大长度内的数据！", AT.AT_DATA_SENDLEN_MAX));
                    data_send = new byte[AT.AT_DATA_SENDLEN_MAX];
                    for (i = 0; i < AT.AT_DATA_SENDLEN_MAX; i++)
                        data_send[i] = temp[i];
                }
                else
                {
                    for (i = 0; i < temp.Length; i++)
                        data_send[i] = temp[i];
                }
                //AT协议发送到基站
                string at_send_str = Encoding.UTF8.GetString(data_send);
                string recv_id = comboBox_DataSendID.Text.ToString();
                if (string.IsNullOrEmpty(recv_id))
                {
                    MessageBox.Show("请先选择要数据透传的标签ID！");
                    return;
                }
                if (recv_id == "主基站")
                    recv_id = "255";
                if (!string.IsNullOrEmpty(at_send_str))
                {
                    Data_Send_Periodically = AT.AT_DataSend_Write(at_send_str, recv_id);
                    if (Data_Send_Periodically != null)
                    {
                        Text_DataSend.Enabled = false;
                        Text_PeriodTime.Enabled = false;
                        Btn_ConfirmSend.Enabled = false;
                        comboBox_DataSendID.Enabled = false;
                        timer_DataSendPeriod.Start();
                    }
                    else
                        MessageBox.Show("请输入正确数据!");
                }
            }
            else
            {
                timer_DataSendPeriod.Stop();
                Text_DataSend.Enabled = true;
                Text_PeriodTime.Enabled = true;
                Btn_ConfirmSend.Enabled = true;
                comboBox_DataSendID.Enabled = true;
            }
        }

        //循环发送计时器
        private void timer_DataSendPeriod_Tick(object sender, EventArgs e)
        {
            APP_Send_Data(Data_Send_Periodically, 1);
        }

        /// <summary>
        /// 通过输入的字符串转换成字节数据
        /// </summary>
        /// <param name="input_str">输入字符串</param>
        /// <param name="Is_hex">是否hex发送</param>
        /// <returns></returns>
        byte[] Get_DataSend_byte(string input_str, bool Is_hex)
        {
            byte[] send_buff = new byte[AT.AT_DATA_SENDLEN_MAX];
            if (string.IsNullOrEmpty(input_str))
            {
                MessageBox.Show("请输入正确字符串！");
                return null;
            }
            ////排除首尾多余的空格
            while (input_str.IndexOf(' ') == 0)
                input_str = input_str.Remove(0, 1);
            while (input_str.LastIndexOf(' ') == input_str.Length - 1)
                input_str = input_str.Remove(input_str.Length - 1);
            //转换成数组
            if (Is_hex)
            {
                //转换为16进制
                string[] str_sp = input_str.Split(' ');
                if (str_sp.Length > 0)
                {
                    int sp_len = str_sp.Length > AT.AT_DATA_SENDLEN_MAX ? AT.AT_DATA_SENDLEN_MAX : str_sp.Length;
                    try
                    {
                        for (int i = 0; i < sp_len; i++)
                        {
                            send_buff[i] = Convert.ToByte(str_sp[i], 16);
                        }
                    }
                    catch
                    {
                        MessageBox.Show("请输入16进制字符0-9或A-F，字节之间加入空格！");
                        return null;
                    }
                }
            }
            else
            {

                try
                {
                    send_buff = Encoding.UTF8.GetBytes(input_str);
                }
                catch (Exception)
                {
                    MessageBox.Show("请输入正确字符！");
                    return null;
                }
            }
            return send_buff;
        }


        #endregion
        /****************************************************/

        /****************************************************/
        #region 地图界面更改变化
        //载入的地图宽度变化
        private void numericUpDown_MapWidth_ValueChanged(object sender, EventArgs e)
        {
            GDI_Rtls_Draw.Map_width = (int)numericUpDown_MapWidth.Value;
        }

        //载入的地图高度变化
        private void numericUpDown_MapHeight_ValueChanged(object sender, EventArgs e)
        {
            GDI_Rtls_Draw.Map_height = (int)numericUpDown_MapHeight.Value;
        }

        //标签大小变化
        private void numericUpDown_TagSize_ValueChanged(object sender, EventArgs e)
        {
            Tag_Size = (int)numericUpDown_TagSize.Value;
        }

        //页面控件切换动作
        private void tabControl1_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (tabControl1.SelectedIndex == 1)
            {
                //根据标签列表来更改ComboBox的内容项
                comboBox_CircleTag.Items.Clear();
                foreach (Tag t in TagList)
                {
                    comboBox_CircleTag.Items.Add(t.Id.ToString());
                }
                if (comboBox_CircleTag.Items.Count != 0)
                    comboBox_CircleTag.SelectedIndex = 0;
            }
            if(tabControl1.SelectedIndex == 4)
            {
                //重新刷新数据表
                Data_channel1.Refresh(DataTable_Trace1, dataGridView_GJ1);
            }
            if (tabControl1.SelectedIndex == 5)
            {
                //重新刷新数据表
                Data_channel2.Refresh(DataTable_Trace2, dataGridView_GJ2);
            }
            if (tabControl1.SelectedIndex == 7)
            {
                //根据标签列表来更改ComboBox的内容项
                comboBox_DataSendID.Items.Clear();      
                if(Module_Mode == ModuleMode.main_anc)
                {
                    foreach (Tag t in TagList)
                        comboBox_DataSendID.Items.Add(t.Id.ToString());
                }
                else if(Module_Mode == ModuleMode.tag)
                {
                    comboBox_DataSendID.Items.Add("主基站");
                }
                
                if (comboBox_DataSendID.Items.Count != 0)
                    comboBox_DataSendID.SelectedIndex = 0;
                
            }
            if (tabControl1.SelectedIndex == 8)
            {
                //基站测距列表
                comboBox_Anal_Tag_ID.Items.Clear();
                foreach (Tag t in TagList)
                    comboBox_Anal_Tag_ID.Items.Add(t.Id.ToString());
                if (comboBox_Anal_Tag_ID.Items.Count != 0)
                    comboBox_Anal_Tag_ID.SelectedIndex = 0;
                //刷新数据表
                
                Data_analyze.Refresh_Itemsource(DataTable_Analyse, dataGridView_AncAnalys);

            }

            if(tabControl1.SelectedIndex == 9)
            {
                //根据标签列表来更改ComboBox的内容项
                Combo_pgrb.Items.Clear();
                foreach (Tag t in TagList)
                    Combo_pgrb.Items.Add(t.Id.ToString());
                if(TagList.Count > 0)
                {
                    Combo_pgrb.SelectedIndex = 0;
                }
            }

            if (tabControl1.SelectedIndex == 10)
            {
                //根据标签列表来更改ComboBox的内容项
                Combo_cir_tagid.Items.Clear();
                foreach (Tag t in TagList)
                    Combo_cir_tagid.Items.Add(t.Id.ToString());
                if (TagList.Count > 0)
                {
                    Combo_cir_tagid.SelectedIndex = 0;
                }

                if(Work_State == WorkState.Rtlsing)
                {
                    GroupBox_Cir_data.Enabled = false;
                    GroupBox_cir_figure.Enabled = false;
                }
                else
                {
                    GroupBox_Cir_data.Enabled = true;
                    GroupBox_cir_figure.Enabled = true;

                }

            }

        }

        #endregion
        /****************************************************/

        /****************************************************/
        #region 设备模式切换界面相应变化
        private void comboBox_TAG_or_BS_SelectedIndexChanged(object sender, EventArgs e)
        {            
            if (comboBox_TAG_or_BS.SelectedIndex == 0) //标签
            {
                Module_Mode = ModuleMode.tag;
                comboBox_DW_MODE.Enabled = false; //定位模式
                numericUpDown_TAG_or_BS_ID.Enabled = true;//设备ID
                button_readdata.Enabled = true; //读取配置按钮
                button_wrdaata.Enabled = true;//载入配置按钮
                toolStripComboBox_com.Enabled = false;  //串口选择
                toolStripComboBox_Rate.Enabled = false; //串口波特率选择
                comboBox_RANGING.Enabled = true;    //测距方式选择
                comboBox_AIR_CHAN.Enabled = true;   //空中信道选择
                comboBox_AIR_RAT.Enabled = true;   //空中速率选择
                numericUpDown_KAM_Q.Enabled = false;  //卡尔曼Q
                numericUpDown_KAM_R.Enabled = false;  //卡尔曼R
                numericUpDown_RX_DELAY.Enabled = true;  //接收延时

                numericUpDown_origin_X.Enabled = false; //地图X坐标
                numericUpDown_origin_Y.Enabled = false; //地图Y坐标
                numericUpDown_map_multiple.Enabled = false; //地图比例
                checkBox_draw_round.Enabled = false; //地图设置
                checkBox_axis.Enabled = false;       //地图设置
                checkBox_coordinate.Enabled = false;  //地图设置
                checkBox_name.Enabled = false;       //地图设置

                checkBox_JS.Enabled = false;//地图设置

                numericUpDown_TAG_num.Enabled = false;  //标签数量框
                button_CJ_OPEN.Enabled = false;         //开始定位按钮
                button_CJ_STOP.Enabled = false;       //取消定位按钮                  

                /* 模块ID变更 */
                if (numericUpDown_TAG_or_BS_ID.Value > 99)
                    numericUpDown_TAG_or_BS_ID.Value = 99;
                string Tag_ID = numericUpDown_TAG_or_BS_ID.Value.ToString();
                textBox_TAG_or_BS_ID.Text = Tag_ID;
                btn_Navigate.Enabled = false;         //导航控制
                dataGridView_TAG.Enabled = true;    //标签列表
                dataGridView_BS_SET.Enabled = false; //基站列表
                Btn_AutoCalibPos.Enabled = false;  //自动标定
            }
            if (comboBox_TAG_or_BS.SelectedIndex == 1) //次基站
            {
                Module_Mode = ModuleMode.sub_anc;
                comboBox_DW_MODE.Enabled = false; //定位模式
                numericUpDown_TAG_or_BS_ID.Enabled = true;//设备ID
                button_readdata.Enabled = true; //读取配置按钮
                button_wrdaata.Enabled = true;//载入配置按钮
                toolStripComboBox_com.Enabled = false;  //串口选择
                toolStripComboBox_Rate.Enabled = false; //串口波特率选择
                comboBox_RANGING.Enabled = true;    //测距方式选择
                comboBox_AIR_CHAN.Enabled = true;   //空中信道选择
                comboBox_AIR_RAT.Enabled = true;   //空中速率选择
                numericUpDown_KAM_Q.Enabled = false;  //卡尔曼Q
                numericUpDown_KAM_R.Enabled = false;  //卡尔曼R
                numericUpDown_RX_DELAY.Enabled = true;  //接收延时

                numericUpDown_origin_X.Enabled = false; //地图X坐标
                numericUpDown_origin_Y.Enabled = false; //地图Y坐标
                numericUpDown_map_multiple.Enabled = false; //地图比例
                checkBox_draw_round.Enabled = false; //地图设置
                checkBox_axis.Enabled = false;       //地图设置
                checkBox_coordinate.Enabled = false;  //地图设置
                checkBox_name.Enabled = false;       //地图设置
                checkBox_JS.Enabled = false;//地图设置
                numericUpDown_TAG_num.Enabled = false;  //标签数量框
                button_CJ_OPEN.Enabled = false;         //开始定位按钮
                button_CJ_STOP.Enabled = false;       //取消定位按钮
                btn_Navigate.Enabled = false;         //导航控制
                dataGridView_TAG.Enabled = false;    //标签列表
                dataGridView_BS_SET.Enabled = false; //基站列表
                Btn_AutoCalibPos.Enabled = false;  //自动标定

                /* 模块ID变更 */
                if (numericUpDown_TAG_or_BS_ID.Value > 14)
                    numericUpDown_TAG_or_BS_ID.Value = 14;
                int sub_id = (int)numericUpDown_TAG_or_BS_ID.Value;
                textBox_TAG_or_BS_ID.Text = Anchor_IDstr[sub_id + 1];

                for(int i=1;i<dataGridView_TAG.Columns.Count;i++)
                {
                    dataGridView_TAG.Rows[0].Cells[i].Value = 0;
                    dataGridView_TAG.Rows[0].Cells[i].Style.BackColor = Color.White;                                         
                }

            }
            if (comboBox_TAG_or_BS.SelectedIndex == 2) //主基站
            {
                Module_Mode = ModuleMode.main_anc;
                comboBox_DW_MODE.Enabled = true; //定位模式
                numericUpDown_TAG_or_BS_ID.Enabled = false;//设备ID
                numericUpDown_TAG_or_BS_ID.Value = 0;
                button_readdata.Enabled = true; //读取配置按钮
                button_wrdaata.Enabled = true;//载入配置按钮
                toolStripComboBox_com.Enabled = false;  //串口选择
                toolStripComboBox_Rate.Enabled = false; //串口波特率选择
                comboBox_RANGING.Enabled = true;    //测距方式选择
                comboBox_AIR_CHAN.Enabled = true;   //空中信道选择
                comboBox_AIR_RAT.Enabled = true;   //空中速率选择
                numericUpDown_KAM_Q.Enabled = true;  //卡尔曼Q
                numericUpDown_KAM_R.Enabled = true;  //卡尔曼R
                numericUpDown_RX_DELAY.Enabled = true;  //接收延时
                btn_Navigate.Enabled = true;         //导航控制 
                Btn_AutoCalibPos.Enabled = true;     //自动标定
                numericUpDown_origin_X.Enabled = true; //地图X坐标
                numericUpDown_origin_Y.Enabled = true; //地图Y坐标
                numericUpDown_map_multiple.Enabled = true; //地图比例
                checkBox_draw_round.Enabled = true; //地图设置
                checkBox_axis.Enabled = true;       //地图设置
                checkBox_coordinate.Enabled = true;  //地图设置
                checkBox_name.Enabled = true;       //地图设置
                checkBox_JS.Enabled = true;//地图设置

                numericUpDown_TAG_num.Enabled = true;  //标签数量框
                button_CJ_OPEN.Enabled = true;         //开始定位按钮
                button_CJ_STOP.Enabled = false;       //取消定位按钮

                textBox_TAG_or_BS_ID.Text = "A基站";

                dataGridView_TAG.Enabled = true;    //标签列表
                dataGridView_BS_SET.Enabled = true; //基站列表


                for (int i = 1; i < dataGridView_TAG.Columns.Count; i++)
                {
                    dataGridView_TAG.Rows[0].Cells[i].Value = 0;
                    dataGridView_TAG.Rows[0].Cells[i].Style.BackColor = Color.White;
                }
               
            }

            if (comboBox_RANGING.SelectedIndex == 1)  //选中了HDS测距 无法修改信道和速率 20220608可修改信道
            {
                comboBox_AIR_CHAN.Enabled = true;   //空中信道选择
                comboBox_AIR_RAT.Enabled = false;   //空中速率选择
                //comboBox_AIR_CHAN.SelectedIndex = 1;
                if (Module_use_chip == Module_Chip_t.DW1000)
                    comboBox_AIR_RAT.SelectedIndex = 2;
                else
                    comboBox_AIR_RAT.SelectedIndex = 1;
            }
            else
            {
                comboBox_AIR_CHAN.Enabled = true;   //空中信道选择
                comboBox_AIR_RAT.Enabled = true;   //空中速率选择
            }
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 根据不同测距模式而更改界面限制
        private void comboBox_RANGING_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (comboBox_RANGING.SelectedIndex == 1)  //选中了HDS测距 无法修改信道和速率
            {
                comboBox_AIR_CHAN.Enabled = true;   //空中信道选择
                comboBox_AIR_RAT.Enabled = false;   //空中速率选择
                //comboBox_AIR_CHAN.SelectedIndex = 1;
                if (Module_use_chip == Module_Chip_t.DW1000)
                    comboBox_AIR_RAT.SelectedIndex = 2;
                else
                    comboBox_AIR_RAT.SelectedIndex = 1;
            }
            else
            {
                comboBox_AIR_CHAN.Enabled = true;   //空中信道选择
                comboBox_AIR_RAT.Enabled = true;   //空中速率选择
            }
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 是否在上位机解算改变事件
        private void checkBox_JS_CheckedChanged(object sender, EventArgs e)
        {
            if (checkBox_JS.Checked)
                IsCalInModule = true;
            else
                IsCalInModule = false;
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 设备模式使能改变事件
        private void comboBox_TAG_or_BS_EnabledChanged(object sender, EventArgs e)
        {
            if (comboBox_TAG_or_BS.Enabled)
            {
                if (comboBox_TAG_or_BS.SelectedIndex == 0) //标签
                {
                    comboBox_DW_MODE.Enabled = false; //定位模式
                    numericUpDown_TAG_or_BS_ID.Enabled = true;//设备ID
                    button_readdata.Enabled = true; //读取配置按钮
                    button_wrdaata.Enabled = true;//载入配置按钮
                    toolStripComboBox_com.Enabled = false;  //串口选择
                    toolStripComboBox_Rate.Enabled = false; //串口波特率选择
                    comboBox_RANGING.Enabled = true;    //测距方式选择
                    comboBox_AIR_CHAN.Enabled = true;   //空中信道选择
                    comboBox_AIR_RAT.Enabled = true;   //空中速率选择
                    numericUpDown_KAM_Q.Enabled = false;  //卡尔曼Q
                    numericUpDown_KAM_R.Enabled = false;  //卡尔曼R
                    numericUpDown_RX_DELAY.Enabled = true;  //接收延时

                    numericUpDown_origin_X.Enabled = false; //地图X坐标
                    numericUpDown_origin_Y.Enabled = false; //地图Y坐标
                    numericUpDown_map_multiple.Enabled = false; //地图比例
                    checkBox_draw_round.Enabled = false; //地图设置
                    checkBox_axis.Enabled = false;       //地图设置
                    checkBox_coordinate.Enabled = false;  //地图设置
                    checkBox_name.Enabled = false;       //地图设置

                    checkBox_JS.Enabled = false;//地图设置

                    numericUpDown_TAG_num.Enabled = false;  //标签数量框
                    button_CJ_OPEN.Enabled = false;         //开始定位按钮
                    button_CJ_STOP.Enabled = false;       //取消定位按钮                  

                    dataGridView_TAG.Enabled = true;    //标签列表
                    dataGridView_BS_SET.Enabled = false; //基站列表
                  
                }
                if (comboBox_TAG_or_BS.SelectedIndex == 1) //次基站
                {
                    comboBox_DW_MODE.Enabled = false; //定位模式
                    numericUpDown_TAG_or_BS_ID.Enabled = true;//设备ID
                    button_readdata.Enabled = true; //读取配置按钮
                    button_wrdaata.Enabled = true;//载入配置按钮
                    toolStripComboBox_com.Enabled = false;  //串口选择
                    toolStripComboBox_Rate.Enabled = false; //串口波特率选择
                    comboBox_RANGING.Enabled = true;    //测距方式选择
                    comboBox_AIR_CHAN.Enabled = true;   //空中信道选择
                    comboBox_AIR_RAT.Enabled = true;   //空中速率选择
                    numericUpDown_KAM_Q.Enabled = false;  //卡尔曼Q
                    numericUpDown_KAM_R.Enabled = false;  //卡尔曼R
                    numericUpDown_RX_DELAY.Enabled = true;  //接收延时

                    numericUpDown_origin_X.Enabled = false; //地图X坐标
                    numericUpDown_origin_Y.Enabled = false; //地图Y坐标
                    numericUpDown_map_multiple.Enabled = false; //地图比例
                    checkBox_draw_round.Enabled = false; //地图设置
                    checkBox_axis.Enabled = false;       //地图设置
                    checkBox_coordinate.Enabled = false;  //地图设置
                    checkBox_name.Enabled = false;       //地图设置
                    checkBox_JS.Enabled = false;//地图设置
                    numericUpDown_TAG_num.Enabled = false;  //标签数量框
                    button_CJ_OPEN.Enabled = false;         //开始定位按钮
                    button_CJ_STOP.Enabled = false;       //取消定位按钮


                    dataGridView_TAG.Enabled = false;    //标签列表
                    dataGridView_BS_SET.Enabled = false; //基站列表
                    

                }
                if (comboBox_TAG_or_BS.SelectedIndex == 2) //主基站
                {
                    comboBox_DW_MODE.Enabled = true; //定位模式
                    numericUpDown_TAG_or_BS_ID.Enabled = false;//设备ID
                    button_readdata.Enabled = true; //读取配置按钮
                    button_wrdaata.Enabled = true;//载入配置按钮
                    toolStripComboBox_com.Enabled = false;  //串口选择
                    toolStripComboBox_Rate.Enabled = false; //串口波特率选择
                    comboBox_RANGING.Enabled = true;    //测距方式选择
                    comboBox_AIR_CHAN.Enabled = true;   //空中信道选择
                    comboBox_AIR_RAT.Enabled = true;   //空中速率选择
                    numericUpDown_KAM_Q.Enabled = true;  //卡尔曼Q
                    numericUpDown_KAM_R.Enabled = true;  //卡尔曼R
                    numericUpDown_RX_DELAY.Enabled = true;  //接收延时

                    numericUpDown_origin_X.Enabled = true; //地图X坐标
                    numericUpDown_origin_Y.Enabled = true; //地图Y坐标
                    numericUpDown_map_multiple.Enabled = true; //地图比例
                    checkBox_draw_round.Enabled = true; //地图设置
                    checkBox_axis.Enabled = true;       //地图设置
                    checkBox_coordinate.Enabled = true;  //地图设置
                    checkBox_name.Enabled = true;       //地图设置
                    checkBox_JS.Enabled = true;//地图设置

                    numericUpDown_TAG_num.Enabled = true;  //标签数量框
                    button_CJ_OPEN.Enabled = true;         //开始定位按钮
                    button_CJ_STOP.Enabled = false;       //取消定位按钮


                    dataGridView_TAG.Enabled = true;    //标签列表
                    dataGridView_BS_SET.Enabled = true; //基站列表
                    

                }

                if (comboBox_RANGING.SelectedIndex == 1)  //选中了HDS测距 无法修改信道和速率 5.0后可修改信道
                {
                    //comboBox_AIR_CHAN.Enabled = true;   //空中信道选择
                    comboBox_AIR_RAT.Enabled = false;   //空中速率选择
                    //comboBox_AIR_CHAN.SelectedIndex = 1;
                    if (Module_use_chip == Module_Chip_t.DW1000)
                        comboBox_AIR_RAT.SelectedIndex = 2;
                    else
                        comboBox_AIR_RAT.SelectedIndex = 1;
                }
                else
                {
                    //comboBox_AIR_CHAN.Enabled = true;   //空中信道选择
                    comboBox_AIR_RAT.Enabled = true;   //空中速率选择
                }
            }
        }
        #endregion
        /****************************************************/

        #region 说明弹窗
        /****************************************************/
        #region 说明弹窗 串口波特率说明
        private void button1_Click(object sender, EventArgs e)
        {
            MessageBox.Show("串口波特率说明\n<使用说明>设备串口通讯的波特率\n<默认设置>115200bps\n<生效说明>配置载入后模块重新上电生效");
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 MODBUS-ID说明
        private void button2_Click_1(object sender, EventArgs e)
        {
            MessageBox.Show("MODBUS-ID说明\n<使用说明>串口采用标准的MODBUS-RTU协议\n                    设备需要通过对应的ID才可进行串口通讯\n                    一般无需改动\n<默认设置>1\n<生效说明>配置载入后立即生效");
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 卡尔曼滤波-Q说明
        private void button9_Click(object sender, EventArgs e)
        {
            MessageBox.Show("卡尔曼滤波-Q说明\n<使用说明>卡尔曼滤波算法在软硬件计算坐标中使用\n                    过程噪声参数Q\n                    如果Q比R大很多，系统响应加快，但抖动会增加。反之则延迟增加，但更加平滑\n<默认设置>3\n<生效说明>配置载入后立即生效");
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 卡尔曼滤波-R说明
        private void button10_Click(object sender, EventArgs e)
        {
            MessageBox.Show("卡尔曼滤波-R说明\n<使用说明>卡尔曼滤波算法在软硬件计算坐标中使用\n                    测量噪声参数Q\n                   如果Q比R大很多，系统响应加快，但抖动会增加。反之则延迟增加，但更加平滑\n<默认设置>10\n<生效说明>配置载入后立即生效");
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 天线及二手延时说明
        private void button11_Click(object sender, EventArgs e)
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("天线总延时说明\n");
            sb.Append("<使用说明>DW1000芯片接收数据包到达时间戳的计算延时参数\n");
            sb.Append("                    用于校准测距距离，所有设备的天线延时参数一般完全相同即可\n");
            sb.Append("                    若需要更严格的测距需求，所有设备的天线延时需要根据原厂校准方法校准 具体可见资料包中相关文档\n");
            sb.Append("                    设置该参数后，天线发送延时和接收延时会按照总和的比例设置\n");
            sb.Append("                    发送延时占比44%，接收延时占比56%\n");
            sb.Append("                    对于经验值设置：若参数变大，测量距离结果变小，每次调整可以增减15调整\n");
            sb.Append("<默认设置>每个硬件天线延时都会有所区别 下列数据只为同一批次出货默认参数 如发现测距偏差大可手动校准\n");
            sb.Append("                    PG2.5: 32975\n");
            sb.Append("                    PG1.7: 32955\n");
            sb.Append("                    PG3.6: 33015\n");
            sb.Append("<生效说明>配置载入后立即生效生效");
            MessageBox.Show(sb.ToString());
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 测量标签数量说明
        private void button12_Click(object sender, EventArgs e)
        {
            MessageBox.Show("测量标签数量说明\n<使用说明>该系统需要测量的标签数量\n                    系统内部根据标签列表的ID进行轮询扫描测量\n                    该系统最大支持100个标签\n<默认设置>1\n<生效说明>配置载入后立即生效生效");
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 设备类型说明
        private void button3_Click(object sender, EventArgs e)
        {
            MessageBox.Show("设备类型说明\n<使用说明>该设备在定位功能中的角色\n                    A基站为主基站，B/C/D/E/F/G/H基站为次基站\n                    为A基站不需要设置设备ID\n                    机器人模块只能做标签\n<默认设置>标签\n<生效说明>配置载入后立即生效生效");
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 设备ID说明
        private void button4_Click(object sender, EventArgs e)
        {
            MessageBox.Show("设备ID说明\n<使用说明>次基站模式：B=0,C=1,D=2,E=3,F=4,G=5,H=6,I=7,J=8,K=9,L=10,M=11,N=12,O=13,P=14\n                    标签模式：ID范围0~99\n                    A基站模式不需要设置设备ID\n<默认设置>0\n<生效说明>配置载入后立即生效生效");
        }
        #endregion  
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 定位模式说明
        private void button5_Click(object sender, EventArgs e)
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("定位模式说明\r\n");
            sb.Append("<使用说明>\n");
            sb.Append("    测距模式：基站与标签进行测距，不计算定位坐标\n");
            sb.Append("    二维定位模式模式：至少需要三个基站一个标签运行才可计算出二维坐标\n");
            sb.Append("    三维定位模式模式：至少需要四个基站一个标签运行才可计算出三维坐标\n");
            sb.Append("    多个标签，根据标签列表设置的标签ID进行轮询测量\n");
            sb.Append("<默认设置>\n");
            sb.Append("    测距模式\n");
            sb.Append("<生效说明>\n");
            sb.Append("    配置载入后立即生效生效\n");
            MessageBox.Show(sb.ToString());
            sb.Clear();
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 测距方式说明
        private void button6_Click(object sender, EventArgs e)
        {
            MessageBox.Show("测距方式说明\n<使用说明>若选择使用HDS-TWR，则速率都固定6M8且需要所有基站和标签同时更改该测距模式！\n <默认设置>HDS-TWR\n<生效说明>配置载入后立即生效");
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 空中信道
        private void button7_Click(object sender, EventArgs e)
        {
            MessageBox.Show("空中信道\n<使用说明>dw1000数据包传输的空中信道\n                    同一个区域内不同信道直接会数据干扰\n                    所有设备需参数一致，2通道距离较为常用，距离最远\n<默认设置>2\n<生效说明>配置载入后立即生效生效");
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 空中速率
        private void button8_Click(object sender, EventArgs e)
        {
            MessageBox.Show("空中速率\n<使用说明>dw1000数据包传输的空中速率\n                    所有设备需参数一致，速率越快，通讯距离越短\n<默认设置>6M8\n<生效说明>配置载入后立即生效生效");
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 动态3D试图
        private void button13_Click(object sender, EventArgs e)
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("动态3D视图信息更改说明\r\n");
            sb.Append("<使用说明>\n");
            sb.Append("    <x轴量程>改变地图x轴代表实际范围 蓝色为x轴\n");
            sb.Append("    <y轴量程>改变地图y轴代表实际范围 绿色为y轴\n");
            sb.Append("    <z轴量程>改变地图z轴代表实际范围 红色为z轴\n");
            sb.Append("    <x轴步长>x轴网格线代表实际数值 需要设置小于x轴最大范围\n");
            sb.Append("    <y轴步长>y轴网格线代表实际数值 需要设置小于y轴最大范围\n");
            sb.Append("    <z轴步长>z轴网格线代表实际数值 需要设置小于z轴最大范围\n");
            sb.Append("    <轨迹长度>标签显示轨迹的最大长度\n");
            sb.Append("<更改生效>\n");
            sb.Append("    需点击更改配置后配置生效\n");
            sb.Append("<画面移动>\n");
            sb.Append("    可通过鼠标左键拖动移动视角 滚轮缩放\n");
            sb.Append("    wsad分别前后左右移动摄像机位置\n");
            sb.Append("    zc分别上下移动摄像机位置\n");
            sb.Append("    画面视角调整需要在三维定位工作中才可以调整\n");

            MessageBox.Show(sb.ToString());
            sb.Clear();
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 数据计算选择
        private void button16_Click(object sender, EventArgs e)
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("数据计算选择\r\n");
            sb.Append("<使用说明>\n");
            sb.Append("    选择数据由硬件/上位机解算\n");
            sb.Append("<控制说明>\n");
            sb.Append("    勾选为数据由硬件结算，否则为软件\n");
            sb.Append("    更改后需要写入配置以生效\n");
            sb.Append("    更改后，如果由软件解算，则硬件获得测距值后不会进行解算直接上报数据\n");
            sb.Append("    对于三维定位的情况，如果使用基站数量大于10个，硬件会解算出现问题 此时需使用软件解算\n");

            MessageBox.Show(sb.ToString());
            sb.Clear();
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 波形图
        private void button17_Click(object sender, EventArgs e)
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("波形图\r\n");
            sb.Append("<使用说明>\n");
            sb.Append("    波形图一/二与通道数据表一/二对应\n");
            sb.Append("<控制说明>\n");
            sb.Append("    可编辑对应通道的标签ID，以获取想要标签的数据\n");
            sb.Append("    图表中可以通过鼠标左键点击线条获取详细值\n");
            sb.Append("    图表中可以通过鼠标右键暂停滚动并移动视图\n");
            sb.Append("    图表中可以通过鼠标滚轮放大缩小\n");
            sb.Append("    鼠标操作后，图表滚动停止 可以通过 复位显示来复位\n");
            sb.Append("<默认设置>\n");
            sb.Append("    通道一标签ID：0 通道二标签ID：1\n");
            sb.Append("<生效说明>\n");
            sb.Append("    更改ID后回车键生效\n");

            MessageBox.Show(sb.ToString());
            sb.Clear();

        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 数据透传
        private void button18_Click_1(object sender, EventArgs e)
        {
            MessageBox.Show("数据透传说明\n<使用说明>可将最多10个字节的字符数据数据定位测距时传到标签中\n                   传输最大字节数需要上位机下位机配套对应修改\n <默认设置>最大传递数据为10字节 例如发送：呼叫tag0");
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 数据透传
        private void button19_Click_1(object sender, EventArgs e)
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("数据透传说明\r\n");
            sb.Append("<使用说明>\n");
            sb.Append("    <循环发送>勾选后则根据设定的循环时间（ms为单位）发送透传数据\n");
            sb.Append("    <透传数据>将要写入数据串口发送到主基站以发送给标签\n");
            sb.Append("    <16进制输入>输入的字符为16进制数并以空格隔开 例如02 0A\n");
            sb.Append("                如果不勾选，则将输入的字符串以ascii码转换为字节发送\n");

            MessageBox.Show(sb.ToString());
            sb.Clear();
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 主基站输出协议修改
        private void button20_Click_1(object sender, EventArgs e)
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("主基站输出数据格式\r\n");
            sb.Append("<使用说明>\n");
            sb.Append("    勾选了对应选项并点击确认更改才可使配置生效\n");
            sb.Append("    在定位中无法设置该选项\n");
            MessageBox.Show(sb.ToString());
            sb.Clear();            
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 动态2D图片参数说明
        private void button14_Click(object sender, EventArgs e)
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("动态2D视图信息更改说明\r\n");
            sb.Append("<使用说明>\n");
            sb.Append("    <原点坐标>改变地图的原点X和Y坐标\n");
            sb.Append("    <地图大小>改变地图的宽和高大小\n");
            sb.Append("    <标签名称坐标-显示>定位时显示标签的坐标和名称\n");
            sb.Append("    <标签大小>改变标签点在图上的大小\n");
            sb.Append("    <坐标轴缩放比例>改变基站所在坐标轴与现实的比例\n");
            sb.Append("    <坐标轴-显示>显示基站所在的坐标轴\n");
            sb.Append("    <测距圆-显示>显示基站与选择显示的标签测距圆\n");
            sb.Append("    <显示测距圆标签>选择显示的标签测距圆\n");
            sb.Append("    <设备名称-显示>显示基站的名称及图片\n");
            sb.Append("<更改生效>\n");
            sb.Append("    定位时更改生效\n");

            MessageBox.Show(sb.ToString());
            sb.Clear();
        }

        /****************************************************/
        #region 标签信号强度ID选择说明
        private void button23_Click(object sender, EventArgs e)
        {
            MessageBox.Show("需要观测信号强度的标签ID\n<使用说明>选择的标签ID将是用于观测信号强度的标签ID 该功能仅主基站有效！\n");
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 信号强度滤波说明
        private void button21_Click(object sender, EventArgs e)
        {
            StringBuilder sb = new StringBuilder(200);
            sb.Append("数据滤波系数\n<使用说明>参数列表中进行数据滤波的系数a\n");
            sb.Append("<计算公式>低通滤波 本次输出=上一次 * (1-a) + 这一次 * a\n");
            sb.Append("<参数说明>系数a越大，变化更快，数据波动越大。反之则变化越慢，波动越平缓\n");
            sb.Append("<默认参数>0.35");
            MessageBox.Show(sb.ToString());
        }
        #endregion
        /****************************************************/


        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 频偏设置
        private void button26_Click(object sender, EventArgs e)
        {
            MessageBox.Show("频偏参数\n<使用说明>dw1000配置范围0~31\n                    dw3000配置范围0~63\n<默认设置>不使用频偏配置\n<生效说明>配置载入后立即生效生效");
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region AT指令控制说明
        private void button22_Click(object sender, EventArgs e)
        {
            StringBuilder sb = new StringBuilder(600);
            sb.Append("AT指令控制\n<使用说明>对模块通过AT指令控制命令\n");
            sb.Append("<发送指令>\r\n");
            sb.Append("   可自由输入AT指令到模块串口 会自动添加换行符\n");
            sb.Append("   具体协议为\n");
            sb.Append("       启动数据透传指令：AT+DataSend=\"A\",\"B\"\n");
            sb.Append("          A表示要透传的数据 最大为10字节的字符 超过10字节则取前10字节的数据发送\n");
            sb.Append("          B表示接收数据的模块ID 主基站则是填写标签ID：0-100 标签只能填写主基站ID：255\n");
            sb.Append("          示例：AT+DataSend=\"呼叫tag\",\"0\"\n");
            sb.Append("<配置串口输出模式>\r\n");
            sb.Append("    仅标签有效 用于配置标签获得定位或测距信息后的输出情况 该配置断电保存\r\n");
            MessageBox.Show(sb.ToString());
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 串口输出模式说明
        private void button25_Click(object sender, EventArgs e)
        {
            StringBuilder sb = new StringBuilder(300);
            sb.Append("配置串口输出模式\n<使用说明>仅标签有效 用于配置标签获得定位或测距信息后的输出情况\n");
            sb.Append("<使能串口输出>\r\n");
            sb.Append("   勾选后 标签会串口输出获得的测距值或定位信息\n");
            sb.Append("<串口输出模式>\r\n");
            sb.Append("   可以选择既输出定位信息和测距信息，或者两者中的其一\r\n");
            MessageBox.Show(sb.ToString());
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 数据透传页面接收区说明
        private void button24_Click(object sender, EventArgs e)
        {
            StringBuilder sb = new StringBuilder(300);
            sb.Append("接收区\n<使用说明>显示从串口获取的非Modbus协议的数据\n");
            sb.Append("<暂停显示>\r\n");
            sb.Append("   可暂停当前的显示框的数据显示\n");
            sb.Append("<清除接收>\r\n");
            sb.Append("   可清除所有接收区的信息\r\n");
            MessageBox.Show(sb.ToString());
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 波形图
        private void button19_Click(object sender, EventArgs e)
        {
            MessageBox.Show("数据表\n<使用说明>自动记录历史6000次信息\n");
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 动态2D试图
        private void button20_Click(object sender, EventArgs e)
        {
            MessageBox.Show("动态2D视图\n<使用说明>简单2D视图DOME演示\n<控制说明>鼠标左击+鼠标移动=移动视图\n                    鼠标滚轮调地图比例\n<生效说明>二维定位解算\n");
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 姿态显示配置
        private void button28_Click(object sender, EventArgs e)
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("IMU参数配置说明\r\n");
            sb.Append("<使用说明>\n");
            sb.Append("    <六轴工作使能>勾选则六轴工作\n");
            sb.Append("    <加速度量程>选择加速度量程\n");
            sb.Append("    <陀螺仪量程>选择陀螺仪量程\n");
            sb.Append("    <采样频率>选择加速度和陀螺仪的采样频率\n");
            sb.Append("    <数据输出频率>姿态角度和数据输出的频率 范围为10-65535\n");
            sb.Append("    <安装方向>可选择水平或垂直安装 如果更改了方向 建议在更改后水平或垂直放置重新校准设备\n");
            sb.Append("    <数据输出格式>勾选则输出对应的数据 否则不输出\n");
            sb.Append("    <校准设备>重新校准设备获得零偏值 校准过程中 建议按照安装方向水平或垂直静止放置5秒直到校准完成\n");
            sb.Append("              校准完成后，零偏参数将自动写入到设备中 不需要再写入配置\n");
            sb.Append("<更改生效>\n");
            sb.Append("    点击写入配置生效 写入配置不写入偏差信息 读取配置可以读取所有配置及校准信息\n");

            MessageBox.Show(sb.ToString());
            sb.Clear();
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 姿态显示配置
        private void button29_Click(object sender, EventArgs e)
        {
            MessageBox.Show("数据显示\n<使用说明>显示IMU输出的加速度，角速度，角度，温度和四元数信息\n");
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 说明弹窗 测距分析设置 
        private void button32_Click(object sender, EventArgs e)
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("测距分析设置\r\n");
            sb.Append("<使用说明>\n");
            sb.Append("    <观测标签ID>选择要记录测距相关信息的标签ID\n");
            sb.Append("    <保存记录>将当前记录的数据表输出到excel表格中 只能在记录停止的时候输出\n");
            sb.Append("    <清除记录>将当前记录的数据表记录清除\n");
            MessageBox.Show(sb.ToString());
            sb.Clear();
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 接收强度说明
        private void button15_Click(object sender, EventArgs e)
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("测距数据记录表\n");
            sb.Append("<使用说明>\n");
            sb.Append("         该数据表会根据主基站输出格式不同而由不同的列组成\n");
            sb.Append("         <定位数据使能>则会输出xyz坐标\n");
            sb.Append("         <测距数据使能>则会输出16个基站的测距值\n");
            sb.Append("         <接收信号信息使能>则会输出标签与主基站的接收信号相关信息\n");
            sb.Append("         第一路径接收强度和接收信号强度计算公式请查阅说明书《DW1000 User Manual》的4.7.1节\"Estimating the signal power in the first path\"和4.7.2节\"Estimating the receive signal power\n");
            sb.Append("         <测距时间戳信息使能>则会输出标签与主基站本次计算距离值的六个时间戳，单位为15.65ps\n");
            sb.Append("         每个时间戳的意义可见资料包定位系统原理说明书\n");
            MessageBox.Show(sb.ToString());
            sb.Clear();
            
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 下次上电后自动定位
        private void button21_Click_1(object sender, EventArgs e)
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("下次上电后自动定位\n");
            sb.Append("<使用说明>\n");
            sb.Append("         勾选后 下次上电主基站将自动开始定位\n");
            sb.Append("<生效说明>\n");
            sb.Append("         需写入配置后生效\n");
            MessageBox.Show(sb.ToString());
            sb.Clear();
        }
        #endregion
        /****************************************************/

        /// <summary>
        /// cir数据说明
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void button27_Click(object sender, EventArgs e)
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("Cir数据分析");
            sb.AppendLine("<使用说明>");
            sb.AppendLine("该功能只能在非定位的时候使用!");
            sb.AppendLine("    <监测标签ID>选择要测距的标签ID");
            sb.AppendLine("    <cir起始读取地址>CIR数据在目前模块使用的prf为64M情况下可以读取1016个地址内容");
            sb.AppendLine("    <cir读取数量>读取最大数量为1016，需要地址+数量不大于1016");
            sb.AppendLine("    <测量数据>开始做一次测距并输出本次测距的cir数据");
            sb.AppendLine("              cir数据数量很大，不适合在常规定位场景下使用，只是作为测试分析");
            sb.AppendLine("             一般只关注第一路径附近的数据，第一路径范围一般在730-750");
            sb.AppendLine("    CIR数据相关说明可查阅说明书");
            MessageBox.Show(sb.ToString());
            sb.Clear();
        }

        #endregion


        /****************************************************/
        #region 鼠标焦点在二维视图 鼠标滚轮
        public void pictureBox_2d_MouseWheel(object sender, MouseEventArgs e)
        {
            if (e.Delta > 0)
            {
                if (numericUpDown_map_multiple.Value <= numericUpDown_map_multiple.Minimum)
                    numericUpDown_map_multiple.Value = numericUpDown_map_multiple.Minimum;
                else
                    numericUpDown_map_multiple.Value -= (decimal)0.01;
            }
            else
            {
                if (numericUpDown_map_multiple.Value >= numericUpDown_map_multiple.Maximum)
                    numericUpDown_map_multiple.Value = numericUpDown_map_multiple.Maximum;
                else
                    numericUpDown_map_multiple.Value += (decimal)0.01;
            }
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 鼠标焦点在二维视图 鼠标移动
        private void pictureBox_2d_MouseMove(object sender, MouseEventArgs e)//鼠标点击移动胡时候
        {
            if (MouseButtons.Left == e.Button)//按下左键
            {
                if (Is_NaviSelecting)
                {
                    Point real_select_point = GDI_Rtls_Draw.Transform2RealPoint(e.X, e.Y);
                    Target_real_pos_x = real_select_point.X;
                    Target_real_pos_y = real_select_point.Y;
                    //发起事件通知
                    Send_Navi_SelectPoint_Event?.Invoke(this, new SelectPointEventArg(real_select_point.X, real_select_point.Y, true));
                    this.Cursor = Cursors.Default;
                    Is_NaviSelecting = false;
                    Is_SelectNavi = true;
                }
                else
                {
                    GDI_Rtls_Draw.Mouse_MoveHandler(e.X, e.Y);
                }
                
            }
            else if(MouseButtons.Right == e.Button)
            {
                if (Is_NaviSelecting)  //取消选择状态
                {
                    Send_Navi_SelectPoint_Event?.Invoke(this, new SelectPointEventArg(e.X, e.Y, false));
                    this.Cursor = Cursors.Default;
                    Is_NaviSelecting = false;
                }
            }
            GDI_Rtls_Draw.Mouse_LastPoint[0] = e.X;
            GDI_Rtls_Draw.Mouse_LastPoint[1] = e.Y;

        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region  说明书
        private void dDWMPG17说明书ToolStripMenuItem_Click(object sender, EventArgs e)
        {
           System.Diagnostics.Process.Start("http://www.gzlwkj.com/static-file/D-DWM-PG-Datasheet(CodeV4.5).pdf");
        }

        private void dDWMPG说明书CodeV47ToolStripMenuItem_Click(object sender, EventArgs e)
        {
            System.Diagnostics.Process.Start("http://www.gzlwkj.com/static-file/D-DWM-PG-Datasheet(CodeV4.7).pdf");
        }

        private void dDWMPG说明书CodeV50ToolStripMenuItem_Click(object sender, EventArgs e)
        {
            System.Diagnostics.Process.Start("http://www.gzlwkj.com/static-file/D-DWM-PG-Datasheet(CodeV5.0).pdf");
        }

        private void dDWMPG说明书CodeV53ToolStripMenuItem_Click(object sender, EventArgs e)
        {
            System.Diagnostics.Process.Start("http://www.gzlwkj.com/static-file/D-DWM-PG-Datasheet(CodeV5.3).pdf");
        }

        private void dDWMPG说明书CodeV58ToolStripMenuItem_Click(object sender, EventArgs e)
        {
            System.Diagnostics.Process.Start("https://www.gzlwkj.com/static-file/D_DWM_PG(CodeV5.8).pdf");
        }

        private void 视频教程链接ToolStripMenuItem_Click(object sender, EventArgs e)
        {
            System.Diagnostics.Process.Start("https://space.bilibili.com/1330660738?spm_id_from=333.337.0.0");
        }

        private void dDWMPG说明书CodeV66ToolStripMenuItem_Click(object sender, EventArgs e)
        {
            System.Diagnostics.Process.Start("https://www.gzlwkj.com/static-file/D_DWM_PG(CodeV6.6).pdf");

        }
        private void dDWMPG说明书CodeV68ToolStripMenuItem_Click(object sender, EventArgs e)
        {
            System.Diagnostics.Process.Start("https://www.gzlwkj.com/static-file/D_DWM_PG(CodeV6.8).pdf");
        }
        #endregion
        /****************************************************/


        /****************************************************/
        #region PG2.5说明书网页链接
        private void dDWMPG25说明书ToolStripMenuItem_Click(object sender, EventArgs e)
       {
           System.Diagnostics.Process.Start("http://gzlwkj.com/res/D-DWM-PG2.5-Datasheet.pdf");
       }
        #endregion
        /****************************************************/





        /****************************************************/
        #region 轨迹输出设置

        /// <summary>
        /// 通道一历史定位数据导出函数
        /// </summary>
        private void CH1_ExportDataToExcel()
        {
            SaveFileDialog sd = new SaveFileDialog();
            sd.Title = "请选择导出位置";
            sd.Filter = "Excel文件| *.xls";
            if (sd.ShowDialog() == DialogResult.OK)
            {
                string filename = sd.FileName;
                if (!string.IsNullOrEmpty(filename))
                {
                    try
                    {
                        //创建Excel文件的对象
                        NPOI.HSSF.UserModel.HSSFWorkbook book = new NPOI.HSSF.UserModel.HSSFWorkbook();
                        //添加一个sheet
                        NPOI.SS.UserModel.ISheet sheet1 = book.CreateSheet("Sheet1");

                        //给sheet1添加第一行的头部标题
                        NPOI.SS.UserModel.IRow row1 = sheet1.CreateRow(0);
                        row1.CreateCell(0).SetCellValue("时间");
                        row1.CreateCell(1).SetCellValue("通道1x坐标");
                        row1.CreateCell(2).SetCellValue("通道1y坐标");
                        row1.CreateCell(3).SetCellValue("通道1z坐标");
                        row1.CreateCell(4).SetCellValue("A基站测距值");
                        row1.CreateCell(5).SetCellValue("B基站测距值");
                        row1.CreateCell(6).SetCellValue("C基站测距值");
                        row1.CreateCell(7).SetCellValue("D基站测距值");
                        row1.CreateCell(8).SetCellValue("E基站测距值");
                        row1.CreateCell(9).SetCellValue("F基站测距值");
                        row1.CreateCell(10).SetCellValue("G基站测距值");
                        row1.CreateCell(11).SetCellValue("H基站测距值");
                        row1.CreateCell(12).SetCellValue("I基站测距值");
                        row1.CreateCell(13).SetCellValue("J基站测距值");
                        row1.CreateCell(14).SetCellValue("K基站测距值");
                        row1.CreateCell(15).SetCellValue("L基站测距值");
                        row1.CreateCell(16).SetCellValue("M基站测距值");
                        row1.CreateCell(17).SetCellValue("N基站测距值");
                        row1.CreateCell(18).SetCellValue("O基站测距值");
                        row1.CreateCell(19).SetCellValue("P基站测距值");
                        row1.CreateCell(20).SetCellValue("定位测距成功标志");
                        row1.CreateCell(21).SetCellValue("速度");
                        int i, j;

                        for (i = 0; i < DataTable_Trace1.Rows.Count; i++)
                        {
                            NPOI.SS.UserModel.IRow rowtemp = sheet1.CreateRow(i + 1);
                            for (j = 0; j < DataTable_Trace1.Columns.Count; j++)
                            {
                                if (j == 0)  //第一列是时间 字符串形式输出
                                    rowtemp.CreateCell(j).SetCellValue(DataTable_Trace1.Rows[i][j].ToString());
                                else  //其余列为数字输出
                                    rowtemp.CreateCell(j).SetCellValue(double.Parse(DataTable_Trace1.Rows[i][j].ToString()));
                            }
                        }

                        FileStream ms = File.OpenWrite(sd.FileName.ToString());
                        try
                        {
                            book.Write(ms);
                            ms.Seek(0, SeekOrigin.Begin);
                            MessageBox.Show("导出成功");
                        }
                        catch
                        {
                            MessageBox.Show("导出失败!");
                        }
                        finally
                        {
                            if (ms != null)
                            {
                                ms.Close();
                            }
                        }
                    }
                    catch
                    {

                    }
                }
            }
        }

        /// <summary>
        /// 通道二历史定位数据导出函数
        /// </summary>
        private void CH2_ExportDataToExcel()
        {
            SaveFileDialog sd = new SaveFileDialog();
            sd.Title = "请选择导出位置";
            sd.Filter = "Excel文件| *.xls";
            if (sd.ShowDialog() == DialogResult.OK)
            {
                string filename = sd.FileName;
                if (!string.IsNullOrEmpty(filename))
                {
                    try
                    {
                        //创建Excel文件的对象
                        NPOI.HSSF.UserModel.HSSFWorkbook book = new NPOI.HSSF.UserModel.HSSFWorkbook();
                        //添加一个sheet
                        NPOI.SS.UserModel.ISheet sheet1 = book.CreateSheet("Sheet1");

                        //给sheet1添加第一行的头部标题
                        NPOI.SS.UserModel.IRow row1 = sheet1.CreateRow(0);
                        row1.CreateCell(0).SetCellValue("时间");
                        row1.CreateCell(1).SetCellValue("通道1x坐标");
                        row1.CreateCell(2).SetCellValue("通道1y坐标");
                        row1.CreateCell(3).SetCellValue("通道1z坐标");
                        row1.CreateCell(4).SetCellValue("A基站测距值");
                        row1.CreateCell(5).SetCellValue("B基站测距值");
                        row1.CreateCell(6).SetCellValue("C基站测距值");
                        row1.CreateCell(7).SetCellValue("D基站测距值");
                        row1.CreateCell(8).SetCellValue("E基站测距值");
                        row1.CreateCell(9).SetCellValue("F基站测距值");
                        row1.CreateCell(10).SetCellValue("G基站测距值");
                        row1.CreateCell(11).SetCellValue("H基站测距值");
                        row1.CreateCell(12).SetCellValue("I基站测距值");
                        row1.CreateCell(13).SetCellValue("J基站测距值");
                        row1.CreateCell(14).SetCellValue("K基站测距值");
                        row1.CreateCell(15).SetCellValue("L基站测距值");
                        row1.CreateCell(16).SetCellValue("M基站测距值");
                        row1.CreateCell(17).SetCellValue("N基站测距值");
                        row1.CreateCell(18).SetCellValue("O基站测距值");
                        row1.CreateCell(19).SetCellValue("P基站测距值");
                        row1.CreateCell(20).SetCellValue("定位测距成功标志");
                        row1.CreateCell(21).SetCellValue("速度");
                        int i, j;

                        for (i = 0; i < DataTable_Trace2.Rows.Count; i++)
                        {
                            NPOI.SS.UserModel.IRow rowtemp = sheet1.CreateRow(i + 1);
                            for (j = 0; j < DataTable_Trace2.Columns.Count; j++)
                            {
                                if (j == 0)  //第一列是时间 字符串形式输出
                                    rowtemp.CreateCell(j).SetCellValue(DataTable_Trace2.Rows[i][j].ToString());
                                else  //其余列为数字输出
                                    rowtemp.CreateCell(j).SetCellValue(double.Parse(DataTable_Trace2.Rows[i][j].ToString()));
                            }
                        }

                        FileStream ms = File.OpenWrite(sd.FileName.ToString());
                        try
                        {
                            book.Write(ms);
                            ms.Seek(0, SeekOrigin.Begin);
                            MessageBox.Show("导出成功");
                        }
                        catch
                        {
                            MessageBox.Show("导出失败!");
                        }
                        finally
                        {
                            if (ms != null)
                            {
                                ms.Close();
                            }
                        }
                    }
                    catch
                    {

                    }
                }
            }
        }

        /// <summary>
        /// 输出通道一定位数据按钮
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void ToolStripMenuItem_SCLJ_Click(object sender, EventArgs e)
        {
            CH1_ExportDataToExcel();
        }

        /// <summary>
        /// 输出通道二定位数据按钮
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void ToolStripMenuItem_SCLJ2_Click(object sender, EventArgs e)
        {
            CH2_ExportDataToExcel();
        }

        /// <summary>
        /// 清空通道一轨迹数据
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void ToolStripMenuItem_ClearCH1Data_Click(object sender, EventArgs e)
        {
            if (MessageBox.Show("确认清除通道一数据？", "提醒", MessageBoxButtons.YesNo, MessageBoxIcon.Exclamation) == DialogResult.Yes)
            {
                int i, j;
                
                for (i = 0; i < DataTable_Trace1.Rows.Count; i++)
                {
                    for (j = 0; j < DataTable_Trace1.Columns.Count; j++)
                    {
                        DataTable_Trace1.Rows[i][j] = "0";
                    }
                }
                Channel1_index = 0;
                Data_channel1.Now_page = 1;
                Data_channel1.Refresh(DataTable_Trace1, dataGridView_GJ1);
                MessageBox.Show("清空完成！");
            }
        }

        /// <summary>
        /// 清空通道二轨迹数据
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void ToolStripMenuItem_ClearCH2Data_Click(object sender, EventArgs e)
        {
            if (MessageBox.Show("确认清除通道二数据？", "提醒", MessageBoxButtons.YesNo, MessageBoxIcon.Exclamation) == DialogResult.Yes)
            {
                int i, j;
                
                for (i = 0; i < DataTable_Trace2.Rows.Count; i++)
                {
                    for (j = 0; j < DataTable_Trace2.Columns.Count; j++)
                    {
                        DataTable_Trace2.Rows[i][j] = "0";
                    }
                }
                Channel2_index = 0;
                Data_channel2.Now_page = 1;
                Data_channel2.Refresh(DataTable_Trace2, dataGridView_GJ2);

                MessageBox.Show("清空完成！");
            }
        }

        /// <summary>
        /// 通道一轨迹回放
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void ToolStripMenuItem_GJ1_replay_Click(object sender, EventArgs e)
        {
            
            TagHistoryWindow tw = new TagHistoryWindow(DataTable_Trace1, GDI_Rtls_Draw, AnchorList.ToList());
            tw.Show();
        }

        /// <summary>
        /// 通道二轨迹回放
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void ToolStripMenuItem_GJ2_replay_Click(object sender, EventArgs e)
        {
            TagHistoryWindow tw = new TagHistoryWindow(DataTable_Trace2, GDI_Rtls_Draw, AnchorList.ToList());
            tw.Show();
        }

        #endregion
        /****************************************************/

        /****************************************************/
        #region 对应不同工作模式下的模块ID改变的变化
        private void numericUpDown_TAG_or_BS_ID_ValueChanged(object sender, EventArgs e)
        {
            switch (comboBox_TAG_or_BS.SelectedIndex)
            {
                case 0:  //标签
                    {                      
                        if (numericUpDown_TAG_or_BS_ID.Value > 99)
                            numericUpDown_TAG_or_BS_ID.Value = 99;
                        string Tag_ID = numericUpDown_TAG_or_BS_ID.Value.ToString();
                        textBox_TAG_or_BS_ID.Text = Tag_ID;
                        break;
                    }
                case 1:  //次基站
                    {
                        if (numericUpDown_TAG_or_BS_ID.Value > 14)
                            numericUpDown_TAG_or_BS_ID.Value = 14;
                        int sub_id = (int)numericUpDown_TAG_or_BS_ID.Value;
                        textBox_TAG_or_BS_ID.Text = Anchor_IDstr[sub_id + 1];
                        break;
                    }
                case 2:  //主基站
                    {
                        textBox_TAG_or_BS_ID.Text = "A基站";
                        break;
                    }
                default:break;
            }
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 工作模式更改
        private void comboBox_DW_MODE_SelectedIndexChanged(object sender, EventArgs e)
        {
            switch (comboBox_DW_MODE.SelectedIndex)
            {
                case 0:
                    {
                        Rtls_State = RtlsMode.Ranging;
                        break;
                    }
                case 1:
                    {
                        Rtls_State = RtlsMode.Rtls_2D;
                        break;
                    }
                case 2:
                    {
                        Rtls_State = RtlsMode.Rtls_3D;
                        break;
                    }
                default:break;
            }
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 接收信号强度的标签ID更改
        private void comboBox_RSSITag_ID_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (comboBox_Anal_Tag_ID.SelectedIndex != -1)
            {
                //初始化接收强度信息
                Rxdiag.rx_diagnostic_init();

                Analyze_TagID = comboBox_Anal_Tag_ID.Text;
            }
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region AT指令发送按键
        private void Btn_AT_Send_Click(object sender, EventArgs e)
        {
            //发送输入的信息 只添加新行 不做判断协议正确
            string send_str = textBox_ATSend.Text;
            if (!string.IsNullOrEmpty(send_str))
            {
                send_str += "\r\n";
                byte[] send_byte = Encoding.UTF8.GetBytes(send_str);
                if (send_byte != null)
                {
                    APP_Send_Data(send_byte,1);
                    AT_Recv_Show_Tips = true;
                }
                                                      
            }
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 配置串口输出模式确认更改
        private void Btn_AT_ConfirmChange_Click(object sender, EventArgs e)
        {
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x10;
            ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_TagOutputConfig;
            ModbusRTU.Instance.Modbus_com.RegNum = ModbusRTU.RegNum_TagOutputConfig;

            byte[] Write_buff = new byte[ModbusRTU.Instance.Modbus_com.RegNum * 2];

            if (checkBox_AT_PrintEn.Checked)
                Write_buff[0] = 1;
            else
                Write_buff[0] = 0;

            byte format = 0;
            if (checkBox_AT_outDist.Checked)
                format |= 1 << 0;
            if (checkBox_AT_outRtls.Checked)
                format |= 1 << 1;
            Write_buff[1] = format;

            Write_buff[2] = 0;
            int protocal = comboBox_AT_Protocal.SelectedIndex;
            if (protocal == -1)
            {
                MessageBox.Show("请选择输出协议！");
                return;
            }
            Write_buff[3] = (byte)protocal;

            byte[] send_byte = ModbusRTU.Instance.Modbus10Send(Write_buff);
            if (send_byte != null)
            {
                APP_Send_Data(send_byte, 0);
                Work_State = WorkState.WriteOutputConfig;
            }
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 暂停/恢复显示
        private void button_AtRecvShow_Click(object sender, EventArgs e)
        {
            if(AT_Recv_Message_Show)
            {
                AT_Recv_Message_Show = false;
                button_AtRecvShow.Text = "恢复显示";
            }
            else
            {
                AT_Recv_Message_Show = true;
                button_AtRecvShow.Text = "暂停显示";
            }
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 清除接收区
        private void Btn_AT_ClearRecv_Click(object sender, EventArgs e)
        {
            textBox_ATRecv.Clear();
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 通道一标签ID更改
        private void numericUpDown_pass1_ID_ValueChanged(object sender, EventArgs e)
        {
            GJ1_ID = (int)numericUpDown_pass1_ID.Value;
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 通道二标签ID更改
        private void numericUpDown_pass2_ID_ValueChanged(object sender, EventArgs e)
        {
            GJ2_ID = (int)numericUpDown_pass2_ID.Value;
        }
        #endregion
        /****************************************************/


        /****************************************************/
        #region AT指令发送成功计时器
        private void timer_ATSendOK_Tick(object sender, EventArgs e)
        {
            if (AT_Send_Fin_Time <= 255)
            {
                label_ATSendOK.ForeColor = Color.FromArgb(AT_Send_Fin_Time, AT_Send_Fin_Time, AT_Send_Fin_Time);
                AT_Send_Fin_Time += 17;
            }
            else
            {
                pictureBox_ATSendOK.Visible = false;
                label_ATSendOK.Visible = false;                
                timer_ATSendOK.Stop();
                timer_ATSendOK.Enabled = false;
                AT_Send_Fin_Time = 0;
            }
                
        }
        #endregion
        /****************************************************/


        /****************************************************/
        #region 姿态页面

        /// <summary>
        /// 读取imu配置
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void button_imu_readconfig_Click(object sender, EventArgs e)
        {
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x03;
            ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_IMU;
            ModbusRTU.Instance.Modbus_com.RegNum = ModbusRTU.RegNum_IMU_ReadConfig;
            byte[] Send_byte = ModbusRTU.Instance.Modbus03Send();
            if(Send_byte != null)
            {
                APP_Send_Data(Send_byte, 0);
            }
            Work_State = WorkState.ReadIMUConfig;
        }

        /// <summary>
        /// 校准设备命令
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void button_imu_calib_Click(object sender, EventArgs e)
        {
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x10;
            ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_IMU;
            ModbusRTU.Instance.Modbus_com.RegNum = 0x01;
            byte[] write_buff = new byte[2];
            write_buff[0] = 0x01;
            write_buff[1] = 0x03;
            if (comboBox_IMU_Mount.SelectedIndex == 0)
                write_buff[1] |= (0x01 << 2);
            byte[] send_byte = ModbusRTU.Instance.Modbus10Send(write_buff);
            if (send_byte != null)
                APP_Send_Data(send_byte, 0);
            Work_State = WorkState.CalibIMU;
        }

        /// <summary>
        /// 校准后台线程处理
        /// </summary>
        private void Imu_Calib_Handler()
        {
            Imu_calib.Imu_Calib_Init();
            IMU_State = IMUState.Calibing;

            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x03;
            
            Task.Run(() => UI_IMUStateChange());
            Thread.Sleep(3000);
            do
            {                
                Thread.Sleep(250);
                Imu_calib.Retry_Time++;
            }
            while (!Imu_calib.Calib_OK && Imu_calib.Retry_Time < 3);

            //上述通过 只是代表校准这个动作完成了
            if(Imu_calib.Acc_Ok && Imu_calib.Gyro_Ok)
            {
                MessageBox.Show("校准完成！");
            }
            else
            {
                //有元件出问题
                MessageBox.Show("校准失败！");
            }

            Work_State = WorkState.Idle;
            IMU_State = IMUState.Running;
            Task.Run(() => UI_IMUStateChange());
        }

        /// <summary>
        /// 检查字节对应位是否为1
        /// </summary>
        /// <param name="data">要检查的字节</param>
        /// <param name="b">第几位</param>
        /// <returns>true则为1 否则为false</returns>
        private bool Check_BitIsTrue(byte data, int b)
        {
            return ((data >> b) & 0x01) == 0x01;
        }

        /// <summary>
        /// 检查字对应位是否为1
        /// </summary>
        /// <param name="data">要检查的字节</param>
        /// <param name="b">第几位</param>
        /// <returns>true则为1 否则为false</returns>
        private bool Check_BitIsTrue(ushort data, int b)
        {
            return ((data >> b) & 0x01) == 0x01;
        }

        /// <summary>
        /// 检查字对应位是否为1
        /// </summary>
        /// <param name="data">要检查的字节</param>
        /// <param name="b">第几位</param>
        /// <returns>true则为1 否则为false</returns>
        private bool Check_BitIsTrue(uint data, int b)
        {
            return ((data >> b) & 0x01) == 0x01;
        }

        /// <summary>
        /// 写入imu的配置 不包括零偏信息
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void button_imu_writeconfig_Click(object sender, EventArgs e)
        {
            byte[] write_buff = new byte[ModbusRTU.RegNum_IMU_WriteConfig * 2];
            bool checkOk = true;
            do
            {
                //首先检查输入是否合理
                if (numericUpDown_outputrate.Value < 0 || numericUpDown_outputrate.Value > 65535)
                {
                    checkOk = false;
                    break;
                }
                if (comboBox_acc_fsr.SelectedIndex == -1 || comboBox_gyro_fsr.SelectedIndex == -1 
                    || comboBox_odr.SelectedIndex == -1)
                {
                    checkOk = false;
                    break;
                }

                /* 输出使能 */
                if (checkBox_ImuOutputEn.Checked)
                    write_buff[0] = 0x01;
                else
                    write_buff[0] = 0x00;

                /* 工作使能 安装方向 低4位有效 */
                if (checkBox_imu_en.Checked)
                    write_buff[1] = 0x01;
                else
                    write_buff[1] = 0x00;

                if(Imu_config.version < IMUConfig.IMU_RB_VERSION_V2)
                {
                    if (comboBox_IMU_Mount.SelectedIndex == 0)
                        write_buff[1] |= (0x01 << 2);
                    write_buff[23] = 0;
                }
                else
                {
                    write_buff[23] = (byte)comboBox_IMU_Mount.SelectedIndex;
                }

                /* 六轴输出频率 */
                write_buff[2] = (byte)((ushort)(numericUpDown_outputrate.Value) >> 8);
                write_buff[3] = (byte)((ushort)(numericUpDown_outputrate.Value) & 0x00FF);

                /* 六轴输出格式 */
                write_buff[4] = Get_IMU_OutputFormat();

                /* 采样频率 */
                if(Imu_config.version < IMUConfig.IMU_RB_VERSION_V2)
                {
                    if (comboBox_odr.SelectedIndex == 12)
                        write_buff[5] = 0x0F;
                    else
                        write_buff[5] = (byte)(comboBox_odr.SelectedIndex + 1);
                }
                else
                {
                    write_buff[5] = (byte)comboBox_odr.SelectedIndex;
                }
                
                Imu_config.Set_Odr(write_buff[5]);

                /* 加速度量程 */
                write_buff[6] = (byte)comboBox_acc_fsr.SelectedIndex;
                Imu_config.Set_Acc_fsr(write_buff[6]);

                /* 角速度量程 */
                write_buff[7] = (byte)comboBox_gyro_fsr.SelectedIndex;
                Imu_config.Set_Gyro_fsr(write_buff[7]);

                //零偏和版本号写入原来读取的参数
                for(int i = 0; i < 14; i++)
                {
                    write_buff[8 + i] = 0;
                }

                write_buff[22] = (byte)comboBox_Algo_select.SelectedIndex;
                
                /* 磁力计量程 */
                write_buff[24] = (byte)comboBox_magn_fsr.SelectedIndex;
                Imu_config.Set_Magn_fsr(write_buff[24]);
                /* 磁力计采样频率 */
                write_buff[25] = (byte)comboBox_magn_odr.SelectedIndex;
                Imu_config.Set_Magn_odr(write_buff[25]);

                /* 是否使用磁力计校准参数 */
                write_buff[26] = (byte)(Imu_config.Is_use_magncorrect ? 1 : 0);
                /* 是否使用uwb回传 */
                write_buff[27] = (byte)(checkBox_en_uwb.Checked ? 1 : 0);

                /* 磁力计校准部分参数 写入记录参数 */
                for (int i = 0; i < 3; i++)
                {
                    write_buff[28 + i * 2] = (byte)(Imu_config.Magn_bias[i] >> 8);
                    write_buff[29 + i * 2] = (byte)(Imu_config.Magn_bias[i] & 0x00FF);
                    write_buff[34 + i * 2] = (byte)(Imu_config.Magn_scale[i] >> 8);
                    write_buff[35 + i * 2] = (byte)(Imu_config.Magn_scale[i] & 0x00FF);
                }
 
                /* 磁力计算范围频率 */
                write_buff[40] = (byte)((ushort)(numericUpDown_magn_min.Value) >> 8);
                write_buff[41] = (byte)((ushort)(numericUpDown_magn_min.Value) & 0x00FF);
                write_buff[42] = (byte)((ushort)(numericUpDown_magn_max.Value) >> 8);
                write_buff[43] = (byte)((ushort)(numericUpDown_magn_max.Value) & 0x00FF);

            }
            while (false);

            if (!checkOk)
            {
                MessageBox.Show("请检查输入参数是否合理！");
                return;
            }
            else
            {
                ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_IMU;
                ModbusRTU.Instance.Modbus_com.FunctionCode = 0x10;
                ModbusRTU.Instance.Modbus_com.RegNum = ModbusRTU.RegNum_IMU_WriteConfig;
                byte[] send_byte = ModbusRTU.Instance.Modbus10Send(write_buff);
                if (send_byte != null)
                {
                    APP_Send_Data(send_byte, 0);
                    Work_State = WorkState.WriteIMUConfig;
                }
            }


        }

        /// <summary>
        /// 根据格式的选择生成对应的指令
        /// </summary>
        /// <returns>格式指令</returns>
        private byte Get_IMU_OutputFormat()
        {
            byte result = 0;

            if (checkBox_en_acc.Checked)
                result |= (1 << 0);
            if(checkBox_en_gyro.Checked)
                result |= (1 << 1);
            if(checkBox_en_euler.Checked)
                result |= (1 << 2);
            if(checkBox_en_temp.Checked)
                result |= (1 << 3);
            if(checkBox_en_q.Checked)
                result |= (1 << 4);
            if(checkBox_en_magn.Checked)
                result |= (1 << 5);

            return result;
        }

        /// <summary>
        /// 输出使能改变引起的ui改变
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void checkBox_ImuOutputEn_CheckedChanged(object sender, EventArgs e)
        {
            if(checkBox_ImuOutputEn.Checked)
            {
                checkBox_en_acc.Enabled = true;
                checkBox_en_gyro.Enabled = true;
                checkBox_en_euler.Enabled = true;
                checkBox_en_temp.Enabled = true;
                checkBox_en_q.Enabled = true;
                checkBox_en_acc.Checked = true;
                checkBox_en_gyro.Checked = true;
                checkBox_en_euler.Checked = true;
                checkBox_en_temp.Checked = true;
                checkBox_en_q.Checked = true;
                checkBox_en_magn.Checked = true;
                checkBox_en_uwb.Checked = true;
            }
            else
            {
                checkBox_en_acc.Enabled = false;
                checkBox_en_gyro.Enabled = false;
                checkBox_en_euler.Enabled = false;
                checkBox_en_temp.Enabled = false;
                checkBox_en_q.Enabled = false;
                checkBox_en_acc.Checked = false;
                checkBox_en_gyro.Checked = false;
                checkBox_en_euler.Checked = false;
                checkBox_en_temp.Checked = false;
                checkBox_en_q.Checked = false;
                checkBox_en_magn.Checked = false;
                checkBox_en_uwb.Checked = false;
            }
        }

        /// <summary>
        /// IMU工作使能引起的UI改变
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void checkBox_imu_en_CheckedChanged(object sender, EventArgs e)
        {
            if(checkBox_imu_en.Checked)
            {
                Panel_Output_En.Enabled = true;
                comboBox_acc_fsr.Enabled = true;
                comboBox_gyro_fsr.Enabled = true;
                comboBox_magn_fsr.Enabled = true;
                comboBox_magn_odr.Enabled = true;
                comboBox_odr.Enabled = true;
                comboBox_IMU_Mount.Enabled = true;
                comboBox_Algo_select.Enabled = true;
                numericUpDown_magn_min.Enabled = true;
                numericUpDown_magn_max.Enabled = true;
                numericUpDown_outputrate.Enabled = true;
            }
            else
            {
                Panel_Output_En.Enabled = false;
                comboBox_acc_fsr.Enabled = false;
                comboBox_gyro_fsr.Enabled = false;
                comboBox_magn_fsr.Enabled = false;
                comboBox_magn_odr.Enabled = false;
                comboBox_odr.Enabled = false;
                numericUpDown_outputrate.Enabled = false;
                comboBox_Algo_select.Enabled = false;
                numericUpDown_magn_min.Enabled = false;
                numericUpDown_magn_max.Enabled = false;
                comboBox_IMU_Mount.Enabled = false;
            }
        }

        /// <summary>
        /// 判断该模块是否IMU模块
        /// </summary>
        private void Imu_First_Read_Handler()
        {
            int timeout = 0;
            /* 尝试读取六轴部分 */
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x03;
            ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_IMU;
            ModbusRTU.Instance.Modbus_com.RegNum = ModbusRTU.RegNum_IMU_ReadConfig;
            byte[] send_byte = ModbusRTU.Instance.Modbus03Send();
            if (send_byte != null)
            {
                APP_Send_Data(send_byte, 0);
            }
            Work_State = WorkState.ReadIMUConfig;
            do
            {
                Thread.Sleep(50);
                timeout++;
            } while (Work_State != WorkState.Idle && timeout < 10);

            if (Work_State != WorkState.Idle) //本次读取失败            
                Work_State = WorkState.Idle;
            else           
                Task.Run(() => UI_IMUStateChange());
            
            
            return;
        }

        //磁力计校准
        private void button_magn_calib_Click(object sender, EventArgs e)
        {
            //指示单片机不使用校准后数据输出数据
            Is_Magn_correct_calib = false;
            byte[] send_data = new byte[2];
            send_data[0] = 0;
            send_data[1] = 0;
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x10;
            ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_IMU_Magn_correct;
            ModbusRTU.Instance.Modbus_com.RegNum = 1;
            byte[] send_byte = ModbusRTU.Instance.Modbus10Send(send_data);
            if(send_byte == null)
            {
                MessageBox.Show("指令出错！");
                return;
            }
            Work_State = WorkState.CalibMagn;
            int retry_times = 0;
            do
            {
                APP_Send_Data(send_byte, 0);
                Thread.Sleep(250);
            }
            while (!Is_Magn_correct_calib || retry_times > 5);

            if (!Is_Magn_correct_calib)
            {
                MessageBox.Show("进入校准模式失败！");
                return;
            }

            //指令成功后 打开新的界面并进行校准
            MagnCalibWindow w = new MagnCalibWindow(imudata);
            if(w.ShowDialog() == DialogResult.Yes)
            {
                //校准成功 写入到单片机并使能使用校准数据
                imudata.Has_Magn_Calib = true;
                send_data = new byte[14];
                ModbusRTU.Instance.Modbus_com.FunctionCode = 0x10;
                ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_IMU_Magn_correct;
                ModbusRTU.Instance.Modbus_com.RegNum = 7;
                send_data[0] = 1;
                send_data[1] = 0;
                for(int i = 0; i < 3; i++)
                {
                    //单位是uT 需要转换为G
                    short bias_lsb = Data_Real2Lsb(imudata.Magn_bias[i] / 100, Imu_config.Magn_fsr);
                    send_data[2 + i * 2] = (byte)(bias_lsb >> 8);
                    send_data[3 + i * 2] = (byte)(bias_lsb & 0x00FF);
                    Imu_config.Magn_bias[i] = bias_lsb;
                    //先放大1000倍

                    short scale_lsb = (short)(imudata.Magn_scale[i] * 1000);
                    send_data[8 + i * 2] = (byte)(scale_lsb >> 8);
                    send_data[9 + i * 2] = (byte)(scale_lsb & 0x00FF);
                    Imu_config.Magn_scale[i] = scale_lsb;
                }
                send_byte = ModbusRTU.Instance.Modbus10Send(send_data);
                if (send_byte == null)
                {
                    MessageBox.Show("指令出错！");
                    return;
                }
                Work_State = WorkState.CalibMagn_fin;
                APP_Send_Data(send_byte, 0);
            }
            else
            {
                //校准失败或没校准 重新使能使用校准数据
                send_data[0] = Imu_config.Is_use_magncorrect ? (byte)1 : (byte)0;
                send_data[1] = 0;
                ModbusRTU.Instance.Modbus_com.FunctionCode = 0x10;
                ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_IMU_Magn_correct;
                ModbusRTU.Instance.Modbus_com.RegNum = 1;
                send_byte = ModbusRTU.Instance.Modbus10Send(send_data);
                if (send_byte == null)
                {
                    MessageBox.Show("指令出错！");
                    return;
                }
                Work_State = WorkState.CalibMagn_fin;
                APP_Send_Data(send_byte, 0);
            }
        }

        private void Combo_pgrb_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (Combo_pgrb.SelectedIndex != -1)
            {
                Imu_display_id = Convert.ToByte(Combo_pgrb.Text.ToString());
            }

        }

        private void Btn_3d_imu_display_Click(object sender, EventArgs e)
        {
            //建立udp通信
            Imu_unity_commu.Start();

            if (!Is_open_unity)
            {
                //打开unity程序
                Process p = new Process();
                p.StartInfo.FileName = AppDomain.CurrentDomain.BaseDirectory + @"Apps\3DDisplay.exe";
                p.EnableRaisingEvents = true;
                p.Exited += P_Exited;
                p.Start();
                Is_open_unity = true;
            }
            
        }

        private void P_Exited(object sender, EventArgs e)
        {
            Is_open_unity = false;
        }

        private void Btn_StopUnityCommu_Click(object sender, EventArgs e)
        {
            Imu_unity_commu.Stop();
        }


        #endregion
        /****************************************************/


        /****************************************************/
        #region TCP窗口通讯
        /// <summary>
        /// 打开TCP窗口
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void ToolStripMenuItem_Tcp_Click(object sender, EventArgs e)
        {
            if(Connect_Mode == ConnectMode.Unknown)
            {
                Form_Tcp form_tcp = new Form_Tcp(Tcp_dataClient);
                if (form_tcp.ShowDialog(this) == DialogResult.OK)  //传入this作为打开的子窗体的父窗体 监听结束信息
                {
                    Notification connect_result = this.Tag as Notification;
                    if (connect_result.IsTcpConnect)
                    {
                        //连接完成
                        ToolStripMenuItem_Tcp.Text = "断开连接";
                        Connect_Mode = ConnectMode.TCP;
                        toolStripStatusLabel_state.Text = "软件状态：未连接设备";
                        toolStripStatusLabel_commu.Text = "TCP连接";
                        toolStripComboBox_com.Enabled = false;
                        toolStripComboBox_Rate.Enabled = false;
                        toolStripMenuItem_SB.Enabled = true;
                        toolStripComboBox_ID.Enabled = true;
                        ToolStripMenuItem_SCAN_ID.Enabled = true;                        
                    }
                    
                }
            }
            else if(Connect_Mode == ConnectMode.TCP)
            {
                if (Tcp_dataClient.IsConnect)
                    Tcp_dataClient.DisConnect(false);  //主动断开
                
                Connect_Mode = ConnectMode.Unknown;

                Work_State = WorkState.Idle;
                Connect_State = ConnectState.DisConnect;
                IMU_State = IMUState.NoConnect;
                Imu_config.Config_Init = false;
                Get_ModuleVersion = false;
                Task.Run(() => UI_ConnectChange());
                Task.Run(() => UI_IMUStateChange());
            }
        }
        #endregion
        /****************************************************/

        /****************************************************/
        #region 数据表分页显示
        //通道表1下一页
        private void button_GJ1_nextpage_Click(object sender, EventArgs e)
        {           
            Data_channel1.Now_page++;
            label_GJ1_nowpage.Text = Data_channel1.Now_page.ToString();
            Data_channel1.Refresh(DataTable_Trace1, dataGridView_GJ1);
            button_GJ1_nextpage.Enabled = !Data_channel1.Is_end;
            button_GJ1_frontpage.Enabled = !Data_channel1.Is_head;
        }


        //通道表1上一页
        private void button_GJ1_frontpage_Click(object sender, EventArgs e)
        {
            Data_channel1.Now_page--;
            label_GJ1_nowpage.Text = Data_channel1.Now_page.ToString();
            Data_channel1.Refresh(DataTable_Trace1, dataGridView_GJ1);
            button_GJ1_nextpage.Enabled = !Data_channel1.Is_end;
            button_GJ1_frontpage.Enabled = !Data_channel1.Is_head;
        }

        //通道表2上一页
        private void button_GJ2_frontpage_Click(object sender, EventArgs e)
        {
            Data_channel2.Now_page--;
            label_GJ2_nowpage.Text = Data_channel2.Now_page.ToString();
            Data_channel2.Refresh(DataTable_Trace2, dataGridView_GJ2);
            button_GJ2_nextpage.Enabled = !Data_channel2.Is_end;
            button_GJ2_frontpage.Enabled = !Data_channel2.Is_head;
        }

        //通道表2下一页
        private void button_GJ2_nextpage_Click(object sender, EventArgs e)
        {
            Data_channel2.Now_page++;
            label_GJ2_nowpage.Text = Data_channel2.Now_page.ToString();
            Data_channel2.Refresh(DataTable_Trace2, dataGridView_GJ2);
            button_GJ2_nextpage.Enabled = !Data_channel2.Is_end;
            button_GJ2_frontpage.Enabled = !Data_channel2.Is_head;
        }

        private void NumericUpDown_CH1_record_num_ValueChanged(object sender, EventArgs e)
        {
            GJ1_record_per_data = (int)NumericUpDown_CH1_record_num.Value;
            GJ1_now_record = 0; //清零当前记录
        }

        private void NumericUpDown_CH2_record_num_ValueChanged(object sender, EventArgs e)
        {
            GJ2_record_per_data = (int)NumericUpDown_CH2_record_num.Value;
            GJ2_now_record = 0; //清零当前记录
        }

        #endregion
        /****************************************************/


        /// <summary>
        /// 窗口大小变化 目前不用
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Main_Form_SizeChanged(object sender, EventArgs e)
        {
            //ResizeHelper.controlAutoSize(this);
        }

        private void numericUpDown_KAM_Q_ValueChanged(object sender, EventArgs e)
        {
            KALMAN_Q = (int)numericUpDown_KAM_Q.Value;
        }

        private void numericUpDown_KAM_R_ValueChanged(object sender, EventArgs e)
        {
            KALMAN_R = (int)numericUpDown_KAM_R.Value;
        }

        #region 三维显示
        /// <summary>
        /// 坐标轴线性变换
        /// </summary>
        /// <param name="data">要转换点</param>
        /// <param name="src_scale">被转换量程</param>
        /// <param name="src_min">被转换的最小值</param>
        /// <returns></returns>
        private float LinearChange(float data, float src_scale, float src_min)
        {
            return (data - src_min) * DrawConfig.DRAW_PLANE_SIZE / src_scale;
        }

        /// <summary>
        /// 实际坐标变换成画图坐标
        /// </summary>
        /// <param name="real_Point">实际坐标数组</param>
        /// <returns></returns>
        public float[] RealPoint2DrawPoint(float[] real_Point)
        {
            float[] Draw_point = new float[3];
            Draw_point[0] = LinearChange(real_Point[1], _DrawConfig.Y_config.Scale, _DrawConfig.Y_config.Min);
            Draw_point[1] = LinearChange(real_Point[2], _DrawConfig.Z_config.Scale, _DrawConfig.Z_config.Min);
            Draw_point[2] = LinearChange(real_Point[0], _DrawConfig.X_config.Scale, _DrawConfig.X_config.Min);
            return Draw_point;
        }

        /// <summary>
        /// 实际坐标变换成画图坐标
        /// </summary>
        /// <param name="real_x">实际x</param>
        /// <param name="real_y">实际y</param>
        /// <param name="real_z">实际z</param>
        /// <returns></returns>
        public float[] RealPoint2DrawPoint(float real_x, float real_y, float real_z)
        {
            float[] Draw_point = new float[3];
            Draw_point[0] = LinearChange(real_y, _DrawConfig.Y_config.Scale, _DrawConfig.Y_config.Min);
            Draw_point[1] = LinearChange(real_z, _DrawConfig.Z_config.Scale, _DrawConfig.Z_config.Min);
            Draw_point[2] = LinearChange(real_x, _DrawConfig.X_config.Scale, _DrawConfig.X_config.Min);
            return Draw_point;
        }

        /// <summary>
        /// 浮点数组转换为vector3
        /// </summary>
        /// <param name="point"></param>
        /// <returns></returns>
        public Vector3 Float2Vector3(float[] point)
        {
            return new Vector3(point[0], point[1], point[2]);
        }

        /// <summary>
        /// 生成顶点缓存
        /// </summary>
        /// <param name="src_List">源缓存列表</param>
        /// <param name="dst_vertices">生成的缓存</param>
        public void GetVertexF(List<DrawModel> src_List, ref float[] dst_vertices)
        {
            int idx = 0;
            dst_vertices = new float[src_List.Count * 6];
            foreach (DrawModel m in src_List)
            {
                m.GenVertices().CopyTo(dst_vertices, idx);
                idx += 6;
            }
        }

        private void glControl_Load(object sender, EventArgs e)
        {
            glControl.MouseWheel += GlControl_MouseWheel;

            float min, max, step;
            min = (float)numericUpDown_xMin.Value;
            max = (float)numericUpDown_xMax.Value;
            step = (float)numericUpDown_xStep.Value;
            _DrawConfig.Set_Xconfig(min, max, step);
            min = (float)numericUpDown_yMin.Value;
            max = (float)numericUpDown_yMax.Value;
            step = (float)numericUpDown_yStep.Value;
            _DrawConfig.Set_Yconfig(min, max, step);
            min = (float)numericUpDown_zMin.Value;
            max = (float)numericUpDown_zMax.Value;
            step = (float)numericUpDown_zStep.Value;
            _DrawConfig.Set_Zconfig(min, max, step);

            if (TK_tagTraceHelper != null)
                TK_tagTraceHelper.Dispose();
            int traceLen = (int)numericUpDown_TKTraceLen.Value;
            TK_tagTraceHelper = new DrawHelper(traceLen, TagList.Count);

            TK_Draw_Init();
            Camera_Reset();
        }
     
        /// <summary>
        /// 画坐标轴三平面 非旋转得到
        /// </summary>
        private void Axis_DrawPlane()
        {
            //先画初始的3个显示平面
            //zoy
            VerticesList.Add(new DrawModel(Color.White, 0.0f, 0.0f, 0.0f));
            VerticesList.Add(new DrawModel(Color.White, 0.0f, 0.0f, DrawConfig.DRAW_PLANE_SIZE));
            VerticesList.Add(new DrawModel(Color.White, 0.0f, DrawConfig.DRAW_PLANE_SIZE, DrawConfig.DRAW_PLANE_SIZE));
            VerticesList.Add(new DrawModel(Color.White, 0.0f, DrawConfig.DRAW_PLANE_SIZE, 0.0f));
            Axis_Plane_Num++;
            //zox
            VerticesList.Add(new DrawModel(Color.White, 0.0f, 0.0f, 0.0f));
            VerticesList.Add(new DrawModel(Color.White, DrawConfig.DRAW_PLANE_SIZE, 0.0f, 0.0f));
            VerticesList.Add(new DrawModel(Color.White, DrawConfig.DRAW_PLANE_SIZE, 0.0f, DrawConfig.DRAW_PLANE_SIZE));
            VerticesList.Add(new DrawModel(Color.White, 0.0f, 0.0f, DrawConfig.DRAW_PLANE_SIZE));
            Axis_Plane_Num++;
            //xoy
            VerticesList.Add(new DrawModel(Color.White, 0.0f, 0.0f, 0.0f));
            VerticesList.Add(new DrawModel(Color.White, DrawConfig.DRAW_PLANE_SIZE, 0.0f, 0.0f));
            VerticesList.Add(new DrawModel(Color.White, DrawConfig.DRAW_PLANE_SIZE, DrawConfig.DRAW_PLANE_SIZE, 0.0f));
            VerticesList.Add(new DrawModel(Color.White, 0.0f, DrawConfig.DRAW_PLANE_SIZE, 0.0f));
            Axis_Plane_Num++;
        }

        /// <summary>
        /// 画网格线 例如基准轴为x 伸展轴为y，那么将会根据步长画出在xoy平面上的横线
        /// </summary>
        /// <param name="base_axis">轴上的基点</param>
        /// <param name="towards_axis">向哪个轴伸展</param>
        /// <param name="unused_axis">没用到的轴</param>
        /// <param name="unused_min">没用到的轴的最小值</param>
        /// <param name="base_config">基准轴的配置</param>
        /// <param name="towards_config">伸展轴的配置</param>
        private void Axis_DrawLine(uint base_axis, uint towards_axis, uint unused_axis, float unused_min, DrawConfig.Confit_t base_config, DrawConfig.Confit_t towards_config)
        {
            if (base_axis >= 3 || towards_axis >= 3)
                return;
            uint line_num_perSize = (uint)(base_config.Scale / base_config.Step);
            float[] points = new float[3] { 0.0f, 0.0f, 0.0f };
            for (uint i = 0; i < line_num_perSize; i++)
            {
                points[base_axis] = i * base_config.Step + base_config.Min;
                points[unused_axis] = unused_min;
                points[towards_axis] = towards_config.Min;
                VerticesList.Add(new DrawModel(Color.Black, RealPoint2DrawPoint(points)));
                points[towards_axis] = towards_config.Max;
                VerticesList.Add(new DrawModel(Color.Black, RealPoint2DrawPoint(points)));
                Axis_LineNum++;
            }

        }

        /// <summary>
        /// 画基站模型（正方体） 基站大小由DrawConfig.DRAW_ANCHOR_SIZE决定
        /// </summary>
        /// <param name="x">基站位置x</param>
        /// <param name="y">基站坐标y</param>
        /// <param name="z">基站坐标z</param>
        private void Axis_DrawAnchor(float x, float y, float z)
        {
            float Anchor_size = DrawConfig.DRAW_ANCHOR_SIZE / 2;
            float x0 = x - Anchor_size, x1 = x + Anchor_size,
                y0 = y - Anchor_size, y1 = y + Anchor_size,
                z0 = z - Anchor_size, z1 = z + Anchor_size;

            Color Anchor_Color = Color.Orange;

            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x0, y0, z0)));
            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x0, y0, z1)));
            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x0, y1, z1)));
            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x0, y1, z0)));

            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x1, y0, z0)));
            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x1, y0, z1)));
            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x1, y1, z1)));
            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x1, y1, z0)));

            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x0, y0, z0)));
            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x1, y0, z0)));
            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x1, y0, z1)));
            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x0, y0, z1)));

            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x0, y1, z0)));
            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x1, y1, z0)));
            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x1, y1, z1)));
            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x0, y1, z1)));

            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x0, y0, z0)));
            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x1, y0, z0)));
            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x1, y1, z0)));
            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x0, y1, z0)));

            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x0, y0, z1)));
            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x1, y0, z1)));
            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x1, y1, z1)));
            VerticesList.Add(new DrawModel(Anchor_Color, RealPoint2DrawPoint(x0, y1, z1)));

        }

        private void TK_Draw_Init()
        {
            VerticesList.Clear();
            if (Vertices_Array != null)
                Array.Clear(Vertices_Array, 0, Vertices_Array.Length);
            /* 生成所有顶点 */
            //画三个平面
            Axis_DrawPlane();

            //画x轴点上的线
            Axis_DrawLine(DrawConfig.DRAW_LINE_X, DrawConfig.DRAW_LINE_Y, DrawConfig.DRAW_LINE_Z, _DrawConfig.Z_config.Min, _DrawConfig.X_config, _DrawConfig.Y_config);
            Axis_DrawLine(DrawConfig.DRAW_LINE_X, DrawConfig.DRAW_LINE_Z, DrawConfig.DRAW_LINE_Y, _DrawConfig.Y_config.Min, _DrawConfig.X_config, _DrawConfig.Z_config);

            //画y轴点上的线
            Axis_DrawLine(DrawConfig.DRAW_LINE_Y, DrawConfig.DRAW_LINE_X, DrawConfig.DRAW_LINE_Z, _DrawConfig.Z_config.Min, _DrawConfig.Y_config, _DrawConfig.X_config);
            Axis_DrawLine(DrawConfig.DRAW_LINE_Y, DrawConfig.DRAW_LINE_Z, DrawConfig.DRAW_LINE_X, _DrawConfig.X_config.Min, _DrawConfig.Y_config, _DrawConfig.Z_config);

            //画z轴点上的线
            Axis_DrawLine(DrawConfig.DRAW_LINE_Z, DrawConfig.DRAW_LINE_X, DrawConfig.DRAW_LINE_Y, _DrawConfig.Y_config.Min, _DrawConfig.Z_config, _DrawConfig.X_config);
            Axis_DrawLine(DrawConfig.DRAW_LINE_Z, DrawConfig.DRAW_LINE_Y, DrawConfig.DRAW_LINE_X, _DrawConfig.X_config.Min, _DrawConfig.Z_config, _DrawConfig.Y_config);

            //画xyz三轴原点线
            //x
            VerticesList.Add(new DrawModel(Color.Blue, RealPoint2DrawPoint(_DrawConfig.X_config.Min, _DrawConfig.Y_config.Min, _DrawConfig.Z_config.Min)));
            VerticesList.Add(new DrawModel(Color.Blue, RealPoint2DrawPoint(_DrawConfig.X_config.Max, _DrawConfig.Y_config.Min, _DrawConfig.Z_config.Min)));
            Axis_LineNum++;
            //y
            VerticesList.Add(new DrawModel(Color.Lime, RealPoint2DrawPoint(_DrawConfig.X_config.Min, _DrawConfig.Y_config.Min, _DrawConfig.Z_config.Min)));
            VerticesList.Add(new DrawModel(Color.Lime, RealPoint2DrawPoint(_DrawConfig.X_config.Min, _DrawConfig.Y_config.Max, _DrawConfig.Z_config.Min)));
            Axis_LineNum++;
            //z
            VerticesList.Add(new DrawModel(Color.Red, RealPoint2DrawPoint(_DrawConfig.X_config.Min, _DrawConfig.Y_config.Min, _DrawConfig.Z_config.Min)));
            VerticesList.Add(new DrawModel(Color.Red, RealPoint2DrawPoint(_DrawConfig.X_config.Min, _DrawConfig.Y_config.Min, _DrawConfig.Z_config.Max)));
            Axis_LineNum++;

            //画基站单体
            Axis_DrawAnchor(_DrawConfig.X_config.Min, _DrawConfig.Y_config.Min, _DrawConfig.Z_config.Min);

            //根据标签数量和轨迹长度改变标签顶点数量
            TK_pointStart_ptrIdx = VerticesList.Count * 6 * sizeof(float); //登记标签点在VBO内存指针位置 指向字节
            for(int i = 0; i < TagList.Count; i++)
            {
                if(i % 2 == 0) //偶数
                {
                    for (int j = 0; j < TK_tagTraceHelper.Max_HistoryLen; j++)
                        VerticesList.Add(new DrawModel(Color.BlueViolet, RealPoint2DrawPoint(_DrawConfig.X_config.Min, _DrawConfig.Y_config.Min, _DrawConfig.Z_config.Min)));
                }
                else
                {
                    for (int j = 0; j < TK_tagTraceHelper.Max_HistoryLen; j++)
                        VerticesList.Add(new DrawModel(Color.Yellow, RealPoint2DrawPoint(_DrawConfig.X_config.Min, _DrawConfig.Y_config.Min, _DrawConfig.Z_config.Min)));
                }
            }

            //生成并赋值到顶点缓存
            GetVertexF(VerticesList, ref Vertices_Array);

            GL.ClearColor(0.9f, 0.9f, 0.9f, 1.0f);  //背景色 稍微有点灰
            /*GL.Enable(EnableCap.DepthTest);*/       //如果使用深度测试 那么坐标平面上的坐标线会不清晰 原因不明
            GL.Enable(EnableCap.ProgramPointSize);  //允许修改point的大小
            Draw_VBO = GL.GenBuffer();              //生成VBO
            GL.BindBuffer(BufferTarget.ArrayBuffer, Draw_VBO);  //定义数据类型并绑定
            //申请内存 定义经常动态修改
            GL.BufferData(BufferTarget.ArrayBuffer, Vertices_Array.Length * sizeof(float), Vertices_Array, BufferUsageHint.DynamicDraw);

            Draw_VAO = GL.GenVertexArray();         //生成VAO
            GL.BindVertexArray(Draw_VAO);           //绑定VAO
            //VAO指向VBO
            /* 该VBO结构为 3个float代表的坐标 3个float代表的颜色
             * index:代表该VAO对应shader着色器的位置 0对应的是物体坐标 1对应物体颜色
             * stride：包含第一个到下一个该顶点的数量 这里是6个float
             * offset：从第一个开始的偏移量 指向颜色的部分需要偏移3个float
             */
            GL.VertexAttribPointer(0, 3, VertexAttribPointerType.Float, false, 6 * sizeof(float), 0);
            GL.EnableVertexAttribArray(0);
            GL.VertexAttribPointer(1, 3, VertexAttribPointerType.Float, false, 6 * sizeof(float), 3 * sizeof(float));
            GL.EnableVertexAttribArray(1);
            //登记着色器文件
            shader = new Shader("OpenTKHelper/Shaders/shader.vert", "OpenTKHelper/Shaders/shader.frag");
            shader.Use();
            
            //初始化完成 重绘
            glControl.Invalidate();
        }

        private void Camera_Reset()
        {
            //相机参数初始化 位置值为测试出来的
            User_Camera = new Camera(new Vector3(5.750f, 4.314f, 2.642f), glControl.Width / (float)glControl.Height);
            User_Camera.Yaw = -180f;
            User_Camera.Pitch = -30f;
            User_Camera.Fov = 100f;
        }

        private void TK_Draw_Dispose()
        {
            GL.DisableVertexAttribArray(0);
            GL.DisableVertexAttribArray(1);
            GL.DeleteBuffer(Draw_VBO);  //清除VBO
            GL.DeleteVertexArray(Draw_VAO);  //清除VAO
            shader.Dispose();

            Axis_Plane_Num = 0;  //清除记录的平面数量 如果不清除会导致画错
            Axis_LineNum = 0;   //清除记录的线条数量 如果不清除会导致画错

        }


        private void glControl_Paint(object sender, PaintEventArgs e)
        {
            Render();
        }

        /// <summary>
        /// 更改配置
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void button_TKConfig_Click(object sender, EventArgs e)
        {
            //根据设置的配置更改画面
            try
            {
                TK_Draw_Dispose();  //重置
                float min, max, step;
                min = (float)numericUpDown_xMin.Value;
                max = (float)numericUpDown_xMax.Value;
                step = (float)numericUpDown_xStep.Value;
                _DrawConfig.Set_Xconfig(min, max, step);
                min = (float)numericUpDown_yMin.Value;
                max = (float)numericUpDown_yMax.Value;
                step = (float)numericUpDown_yStep.Value;
                _DrawConfig.Set_Yconfig(min, max, step);
                min = (float)numericUpDown_zMin.Value;
                max = (float)numericUpDown_zMax.Value;
                step = (float)numericUpDown_zStep.Value;
                _DrawConfig.Set_Zconfig(min, max, step);
               
                if (TK_tagTraceHelper != null)
                    TK_tagTraceHelper.Dispose();
                int traceLen = (int)numericUpDown_TKTraceLen.Value;
                TK_tagTraceHelper = new DrawHelper(traceLen, TagList.Count);

                TK_Draw_Init();
            }
            catch
            {

            }
        }

        /// <summary>
        /// 保持/清除轨迹
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void button_TKTrace_Click(object sender, EventArgs e)
        {

            if (TK_tagTraceHelper != null)
                TK_tagTraceHelper.ClearAllHistory();
            else
            {
                int traceLen = (int)numericUpDown_TKTraceLen.Value;
                TK_tagTraceHelper = new DrawHelper(traceLen, TagList.Count);
            }

            if (!TK_HasTrace)
            {
                button_TKTrace.Text = "清除轨迹显示";
                TK_HasTrace = true;                               
            }
            else
            {
                button_TKTrace.Text = "保持轨迹显示";
                TK_HasTrace = false;
                TK_Draw_Dispose();  //重置
                TK_Draw_Init();
            }            
        }

        /// <summary>
        /// 渲染画面
        /// </summary>
        private void Render()
        {
            try
            {
                if(tabControl1.SelectedIndex != 2)
                {
                    return;
                }
                glControl.MakeCurrent();
                //GL.ClearColor(Color4.MidnightBlue);
                int draw_idx = 0, i;
                

                GL.ClearColor(0.9f, 0.9f, 0.9f, 1.0f);
                GL.Clear(ClearBufferMask.ColorBufferBit);

                GL.BindVertexArray(Draw_VAO);
                Matrix4 transform = Matrix4.Identity;
                shader.Use();
                shader.SetMatrix4("model", transform);
                shader.SetMatrix4("view", User_Camera.GetViewMatrix());
                shader.SetMatrix4("projection", User_Camera.GetProjectionMatrix());

                GL.DrawArrays(PrimitiveType.Quads, draw_idx, Axis_Plane_Num * 4);  //画坐标平面
                draw_idx += Axis_Plane_Num * 4;
                
                GL.LineWidth(1);
                GL.DrawArrays(PrimitiveType.Lines, draw_idx, (Axis_LineNum - 3) * 2);   //画网格线
                GL.LineWidth(3);
                GL.DrawArrays(PrimitiveType.Lines, draw_idx + (Axis_LineNum - 3) * 2, 3 * 2);   //画坐标轴三条线 加粗
                GL.LineWidth(1);
                draw_idx += Axis_LineNum * 2;

                //画基站
                for(i = 0; i < ANCHOR_MAX_COUNT; i++)
                {
                    if (!AnchorGroup[i].IsUse)
                        continue;
                    transform = Matrix4.CreateTranslation(Float2Vector3(RealPoint2DrawPoint((float)(AnchorGroup[i].x / 100.0f), (float)(AnchorGroup[i].y / 100.0f), (float)(AnchorGroup[i].z / 100.0f))));
                    shader.SetMatrix4("model", transform);
                    GL.DrawArrays(PrimitiveType.Quads, draw_idx, 24);
                }

                draw_idx += 24;

                if (!TK_HasTrace)
                {
                    //无轨迹显示

                    foreach(Tag t in TagList)
                    {
                        if (t == null)
                            continue;                      
                        transform = Matrix4.CreateTranslation(Float2Vector3(RealPoint2DrawPoint((float)(t.x / 100.0f), (float)(t.y / 100.0f), (float)(t.z / 100.0f))));
                        shader.SetMatrix4("model", transform);
                        if (t.Index % 2 == 0)
                            GL.DrawArrays(PrimitiveType.Points, draw_idx, 1);
                        else
                            GL.DrawArrays(PrimitiveType.Points, draw_idx + TK_tagTraceHelper.Max_HistoryLen + 1, 1);
                    }
                }
                else
                {
                    shader.SetMatrix4("model", Matrix4.Identity);
                    //轨迹显示
                    foreach (Tag t in TagList)
                    {
                        if (t == null)
                            continue;

                        /* 修改顶点坐标 */

                        //生成标签轨迹点
                        Color now_color = Color.BlueViolet;
                        if (t.Index % 2 != 0)
                            now_color = Color.Yellow;
                        List<DrawModel> ChangeList = new List<DrawModel>();
                        int history_len = TK_tagTraceHelper.GetHistoryLen(t.Index);
                        for (i = 0; i < history_len; i++)
                        {
                            ChangeList.Add(new DrawModel(now_color, TK_tagTraceHelper.GetPosition(t.Index, i)));
                        }
                        float[] change_array = new float[history_len];
                        GetVertexF(ChangeList, ref change_array);

                        //修改到VBO
                        int ptroffset = TK_pointStart_ptrIdx + t.Index * TK_tagTraceHelper.Max_HistoryLen * 6 * sizeof(float);
                        GL.BufferSubData(BufferTarget.ArrayBuffer, IntPtr.Add(IntPtr.Zero, ptroffset), sizeof(float) * 6 * history_len, change_array);

                        GL.LineWidth(7);
                        //画线
                        GL.DrawArrays(PrimitiveType.LineStrip, draw_idx, history_len);
                        draw_idx += TK_tagTraceHelper.Max_HistoryLen;     //已经提前开辟了轨迹的VBO区域 因此要画下一个坐标后更改索引               
                    }
                }
       
                glControl.SwapBuffers();

            }
            catch
            {

            }
            

        }

        private void GlControl_MouseWheel(object sender, MouseEventArgs e)
        {
            base.OnMouseWheel(e);
            User_Camera.Fov -= e.Delta / 100;
        }

        private void glControl_MouseMove(object sender, MouseEventArgs e)
        {
            if (Mouse_HasClick)
            {
                var deltaX = e.X - Origin_Pos.X;
                var deltaY = e.Y - Origin_Pos.Y;
                Origin_Pos = new Vector2(e.X, e.Y);

                // Apply the camera pitch and yaw (we clamp the pitch in the camera class)
                User_Camera.Yaw += deltaX * sensitivity;
                User_Camera.Pitch -= deltaY * sensitivity; // Reversed since y-coordinates range from bottom to top
                User_Camera.Position -= User_Camera.Right * deltaX * sensitivity * 0.05f;
                User_Camera.Position += User_Camera.Up * deltaY * sensitivity * 0.05f;               
            }
        }

        private void glControl_MouseUp(object sender, MouseEventArgs e)
        {
            Mouse_HasClick = false;
            var deltaX = e.X - Origin_Pos.X;
            var deltaY = e.Y - Origin_Pos.Y;
            Origin_Pos = new Vector2(e.X, e.Y);
          
            User_Camera.Yaw += deltaX * sensitivity;
            User_Camera.Pitch -= deltaY * sensitivity; // Reversed since y-coordinates range from bottom to top
            User_Camera.Position -= User_Camera.Right * deltaX * sensitivity * 0.05f;
            User_Camera.Position += User_Camera.Up * deltaY * sensitivity * 0.05f;           
        }

        private void glControl_MouseDown(object sender, MouseEventArgs e)
        {
            Mouse_HasClick = true;
            Origin_Pos = new Vector2(e.X, e.Y);
        }

        private void glControl_KeyPress(object sender, System.Windows.Forms.KeyPressEventArgs e)
        {
            if (e.KeyChar == 'W' || e.KeyChar == 'w')
            {
                User_Camera.Position += User_Camera.Front * 1.5f * 0.05f;
            }
            else if (e.KeyChar == 'S' || e.KeyChar == 's')
            {
                User_Camera.Position -= User_Camera.Front * 1.5f * 0.05f;
            }
            else if (e.KeyChar == 'A' || e.KeyChar == 'a')
            {
                User_Camera.Position -= User_Camera.Right * 1.5f * 0.05f;
            }
            else if (e.KeyChar == 'D' || e.KeyChar == 'd')
            {
                User_Camera.Position += User_Camera.Right * 1.5f * 0.05f;
            }
            if (e.KeyChar == 'Z' || e.KeyChar == 'z')
            {
                User_Camera.Position += User_Camera.Up * 1.5f * 0.05f; // Up
            }
            if (e.KeyChar == 'C' || e.KeyChar == 'c')
            {
                User_Camera.Position -= User_Camera.Up * 1.5f * 0.05f; // Down
            }
        }

        #endregion

        #region 基站测距分析
        /// <summary>
        /// 更改主基站定位上报输出内容
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void btn_Anal_Config_Click(object sender, EventArgs e)
        {
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x10;
            ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_MainAncOutputConfig;
            ModbusRTU.Instance.Modbus_com.RegNum = ModbusRTU.RegNum_MainAncOutputConfig;

            byte data = 0;
            if (checkBox_RtlsEn.Checked)
                data |= 1 << ANC_PROTOCAL_RTLS;
            if (checkBox_DistEn.Checked)
                data |= 1 << ANC_PROTOCAL_DIST;
            if (checkBox_rxDiagEn.Checked)
                data |= 1 << ANC_PROTOCAL_RXDIAG;
            if (checkBox_TsEn.Checked)
                data |= 1 << ANC_PROTOCAL_TIMESTAMP;

            Analyse_format = data;  //更改赋值
            DataTable_Analyze_Init();
            Data_analyze.Refresh_Itemsource(DataTable_Analyse, dataGridView_AncAnalys);
            byte[] buff = new byte[2] { 0, data };
            byte[] send_byte = ModbusRTU.Instance.Modbus10Send(buff);
            if (send_byte != null)
            {
                APP_Send_Data(send_byte, 0);               
                Work_State = WorkState.WriteOutputConfig;
            }
        }

        /// <summary>
        /// 开始记录内容
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void button_Anal_Start_Click(object sender, EventArgs e)
        {
            if (!Is_Analyse)
            {                
                button_Anal_Start.Text = "暂停记录";
                //数据表根据使能内容初始化
                Data_analyze.Refresh_Itemsource(DataTable_Analyse, dataGridView_AncAnalys);
                Is_Analyse = true;
                button_Anal_save.Enabled = false;
                button_Anal_clear.Enabled = false;
            }
            else
            {
                Is_Analyse = false;
                button_Anal_Start.Text = "开始记录";
                button_Anal_save.Enabled = true;
                button_Anal_clear.Enabled = true;
            }

        }

        /// <summary>
        /// 初始化分析数据表的列
        /// </summary>
        private void DataTable_Analyze_Init()
        {
            if (DataTable_Analyse != null)
                DataTable_Analyse.Dispose();
            DataTable_Analyse = new DataTable();
            DataTable_Analyse.Columns.Add("Time");
            if (Check_BitIsTrue((byte)Analyse_format, ANC_PROTOCAL_RTLS))
            {
                DataTable_Analyse.Columns.Add("cal_flag");
                DataTable_Analyse.Columns.Add("x");
                DataTable_Analyse.Columns.Add("y");
                DataTable_Analyse.Columns.Add("z");
            }
            if (Check_BitIsTrue((byte)Analyse_format, ANC_PROTOCAL_DIST))
            {
                DataTable_Analyse.Columns.Add("dist_flag");
                for (int i = 0; i < ANCHOR_MAX_COUNT; i++)
                {
                    string column_name = "dist_" + Encoding.ASCII.GetString(new byte[] { (byte)(0x61 + i) });
                    DataTable_Analyse.Columns.Add(column_name);
                }
            }
            if (Check_BitIsTrue((byte)Analyse_format, ANC_PROTOCAL_RXDIAG))
            {
                DataTable_Analyse.Columns.Add("max_noise");
                DataTable_Analyse.Columns.Add("std_noise");
                DataTable_Analyse.Columns.Add("fp_amp1");
                DataTable_Analyse.Columns.Add("fp_amp2");
                DataTable_Analyse.Columns.Add("fp_amp3");
                DataTable_Analyse.Columns.Add("max_grown_cir");
                DataTable_Analyse.Columns.Add("rx_preamble_count");
                DataTable_Analyse.Columns.Add("fp");
                DataTable_Analyse.Columns.Add("fp_power");
                DataTable_Analyse.Columns.Add("rx_power");
            }
            if (Check_BitIsTrue((byte)Analyse_format, ANC_PROTOCAL_TIMESTAMP))
            {
                DataTable_Analyse.Columns.Add("t1");
                DataTable_Analyse.Columns.Add("t2");
                DataTable_Analyse.Columns.Add("t3");
                DataTable_Analyse.Columns.Add("t4");
                DataTable_Analyse.Columns.Add("t5");
                DataTable_Analyse.Columns.Add("t6");
            }

            Analyze_index = 0;
            for (int i = 0; i < Data_analyze.Datatable_MaxLen; i++)
            {
                DataRow dr = DataTable_Analyse.NewRow();
                for(int j = 0; j < DataTable_Analyse.Columns.Count; j++)
                {
                    dr[j] = 0;
                }
                DataTable_Analyse.Rows.Add(dr);
            }

        }



        private void btn_Anal_lastpage_Click(object sender, EventArgs e)
        {
            Data_analyze.Now_page--;
            label_Anal_nowpage.Text = Data_analyze.Now_page.ToString();
            Data_analyze.Refresh_Itemsource(DataTable_Analyse, dataGridView_AncAnalys);
            button_Anal_nextpage.Enabled = !Data_analyze.Is_end;
            btn_Anal_lastpage.Enabled = !Data_analyze.Is_head;
        }

        private void button_Anal_nextpage_Click(object sender, EventArgs e)
        {
            Data_analyze.Now_page++;
            label_Anal_nowpage.Text = Data_analyze.Now_page.ToString();
            Data_analyze.Refresh_Itemsource(DataTable_Analyse, dataGridView_AncAnalys);
            button_Anal_nextpage.Enabled = !Data_analyze.Is_end;
            btn_Anal_lastpage.Enabled = !Data_analyze.Is_head;
        }

        //保存到excel输出
        private void button_Anal_save_Click(object sender, EventArgs e)
        {
            SaveFileDialog sd = new SaveFileDialog();
            sd.Title = "请选择导出位置";
            sd.Filter = "Excel文件| *.xls";
            if (sd.ShowDialog() == DialogResult.OK)
            {
                string filename = sd.FileName;
                if (!string.IsNullOrEmpty(filename))
                {
                    try
                    {
                        //创建Excel文件的对象
                        NPOI.HSSF.UserModel.HSSFWorkbook book = new NPOI.HSSF.UserModel.HSSFWorkbook();
                        //添加一个sheet
                        NPOI.SS.UserModel.ISheet sheet1 = book.CreateSheet("Sheet1");

                        //给sheet1添加第一行的头部标题
                        NPOI.SS.UserModel.IRow row1 = sheet1.CreateRow(0);

                        int i, j;

                        for (i = 0; i < DataTable_Analyse.Columns.Count; i++)
                        {
                            row1.CreateCell(i).SetCellValue(DataTable_Analyse.Columns[i].ToString());
                        }
                        
                        for (i = 0; i < DataTable_Analyse.Rows.Count; i++)
                        {
                            NPOI.SS.UserModel.IRow rowtemp = sheet1.CreateRow(i + 1);
                            for (j = 0; j < DataTable_Analyse.Columns.Count; j++)
                            {
                                if (j == 0)  //第一列是时间 字符串形式输出
                                    rowtemp.CreateCell(j).SetCellValue(DataTable_Analyse.Rows[i][j].ToString());
                                else  //其余列为数字输出
                                    rowtemp.CreateCell(j).SetCellValue(double.Parse(DataTable_Analyse.Rows[i][j].ToString()));
                            }
                        }

                        FileStream ms = File.OpenWrite(sd.FileName.ToString());
                        try
                        {
                            book.Write(ms);
                            ms.Seek(0, SeekOrigin.Begin);
                            MessageBox.Show("导出成功");
                        }
                        catch
                        {
                            MessageBox.Show("导出失败!");
                        }
                        finally
                        {
                            if (ms != null)
                            {
                                ms.Close();
                            }
                        }
                    }
                    catch
                    {

                    }
                }
            }
        }

        private void button_Anal_clear_Click(object sender, EventArgs e)
        {
            //Analyze_index = 0;
            //DataTable_Analyse.Clear();
            //DataTable_Analyse.Dispose();
            //dataGridView_AncAnalys.DataSource = null;
            DataTable_Analyze_Init();
            Data_analyze.Refresh_Itemsource(DataTable_Analyse, dataGridView_AncAnalys);
        }

        #endregion

        #region CIR分析
        private void Btn_Start_get_cir_Click(object sender, EventArgs e)
        {
            //根据要读取的地址和数量做规则检查
            ushort start_addr = (ushort)NumericUpDown_cir_start_addr.Value;
            ushort read_num = (ushort)NumericUpDown_cir_num.Value;

            if(start_addr + read_num > Cir_work_t.CIR_MAX_NUM)
            {
                MessageBox.Show("读取数量超出限制，请重新选择!");
                return;
            }
            if(Combo_cir_tagid.SelectedIndex == -1)
            {
                MessageBox.Show("请先选择要测试的标签!");
                return;
            }

            Work_State = WorkState.Cir_testing;
            Cir_work_instance.Init();
            Cir_work_instance.Cir_test_tagid = byte.Parse(Combo_cir_tagid.Text);
            Cir_work_instance.Cir_read_startaddr = start_addr;
            Cir_work_instance.Cir_read_num = read_num;

            //TODO:超过某个字节数据量应该要分包读取 这个后面再测

            Task t = new Task(() => Cir_get_data_Handler());
            t.Start();

        }

        private void Cir_get_data_Handler()
        {
            //发送单次测距自动输出指令
            ModbusRTU.Instance.Modbus_com.ModbusID = NOW_ID;
            ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_ModuleMode;
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x10;
            ModbusRTU.Instance.Modbus_com.RegNum = 1;

            byte[] temp = new byte[2];
            temp[0] = 0x00;
            temp[1] = 0x03;  //单次定位自动上报数据
            byte[] send_buff = ModbusRTU.Instance.Modbus10Send(temp);
            if (send_buff != null)
                APP_Send_Data(send_buff, 0);

            Cir_change_progress(0, 1);
            int timeout_flag = 50;
            while (true)
            {
                while (timeout_flag-- > 0 && Cir_work_instance.Flag == Cir_work_flag_t.wait_getdist)
                {
                    Thread.Sleep(100);
                }
                if (Cir_work_instance.Flag == Cir_work_flag_t.get_correctdist)
                {
                    break;
                }
                else if (Cir_work_instance.Flag == Cir_work_flag_t.get_otherdist)
                {
                    //获取到其它标签测距值 重新指令进行测距
                    APP_Send_Data(send_buff, 0);
                    Cir_work_instance.Flag = Cir_work_flag_t.wait_getdist;
                    timeout_flag = 50;
                }
                else if (timeout_flag <= 0)
                {
                    //测距超时
                    MessageBox.Show("[CIR]和标签测距超时!");
                    Work_State = WorkState.Idle;
                    return;
                }
                else
                {
                    //其它情况？
                    MessageBox.Show("[CIR]测试出错!");
                    Work_State = WorkState.Idle;
                    return;
                }
            }

            //测距完成 发送请求读取cir指令
            //MessageBox.Show("测距完成，开始请求cir数据");
            int ret = 0;
            Cir_work_instance.Cir_data_list.Clear();
            ret = Cir_get_cirdata(Cir_work_instance.Cir_read_startaddr, Cir_work_instance.Cir_read_num);
            if (ret == 0)
            {
                //读取失败
                Work_State = WorkState.Idle;
                return;
            }
            else if(ret == -1)
            {
                //读取拒绝 一次读取的数据量过大 将当前数据拆成几次读取
                //MessageBox.Show("[CIR]一次读取数据数量过大，采用分包读取，请等待读取完成");
                int retry_time = 0;
                int split_package = Cir_work_instance.Cir_read_num / Cir_work_t.CIR_SPILIT_READ_NUM;
                int last_num = Cir_work_instance.Cir_read_num % Cir_work_t.CIR_SPILIT_READ_NUM;
                if(last_num > 0)
                {
                    split_package++;
                }
                for(int i = 0; i < split_package; i++)
                {
                    int read_ret = 0;
                    do
                    {
                        int read_num_temp = Cir_work_t.CIR_SPILIT_READ_NUM;
                        if (i == split_package - 1 && last_num != 0)
                        {
                            read_num_temp = last_num;
                        }
                        read_ret = Cir_get_cirdata((ushort)(Cir_work_instance.Cir_read_startaddr + i * Cir_work_t.CIR_SPILIT_READ_NUM), (ushort)read_num_temp);
                        if(read_ret == 1)
                        {
                            retry_time = 0;
                            break;
                        }
                    }
                    while (retry_time++ < 3);
                    
                    if(read_ret < 0)
                    {
                        //读取失败
                        MessageBox.Show($"[CIR]分包读取第{i}包读取失败!");
                        Work_State = WorkState.Idle;
                        return;
                    }

                    Cir_change_progress(i, split_package);
                    Thread.Sleep(10);

                }
            }

            Cir_change_progress(1, 1);
            MessageBox.Show("[CIR]数据获取成功!");
            Work_State = WorkState.Idle;
            //所有cir数据获取完成 输出到表格中
            Cir_plot();

        }



        private void Cir_send_ask_command(ushort start_idx, ushort read_num)
        {
            byte[] data_buff = new byte[4];
            data_buff[0] = (byte)(start_idx >> 8);
            data_buff[1] = (byte)(start_idx & 0x00FF);
            data_buff[2] = (byte)(read_num >> 8);
            data_buff[3] = (byte)(read_num & 0x00FF);
            ModbusRTU.Instance.Modbus_com.ModbusID = NOW_ID;
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x41;
            byte[] send_buff = ModbusRTU.Instance.Modbus_Custom_Send(data_buff, data_buff.Length);
            if(send_buff != null)
            {
                APP_Send_Data(send_buff);
            }
        }

        private void Cir_send_get_cirdata_command(byte now_idx)
        {
            byte[] data_buff = new byte[2];
            data_buff[0] = 0xA0;
            data_buff[1] = now_idx;
            ModbusRTU.Instance.Modbus_com.ModbusID = NOW_ID;
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x42;
            byte[] send_buff = ModbusRTU.Instance.Modbus_Custom_Send(data_buff, data_buff.Length);
            if (send_buff != null)
            {
                APP_Send_Data(send_buff);
            }
        }

        private void Cir_send_cir_fin_command()
        {

            ModbusRTU.Instance.Modbus_com.ModbusID = NOW_ID;
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x42;
            byte[] send_buff = ModbusRTU.Instance.Modbus_Custom_Send(0xA1);
            if (send_buff != null)
            {
                APP_Send_Data(send_buff);
            }
        }

        private int Cir_get_cirdata(ushort start_idx, ushort read_num)
        {

            Cir_work_instance.Flag = Cir_work_flag_t.wait_readcir_response;
            Cir_send_ask_command(start_idx, read_num);
            int timeout_flag = 10;
            while (timeout_flag-- > 0 && Cir_work_instance.Flag == Cir_work_flag_t.wait_readcir_response)
            {
                Thread.Sleep(100);
            }
            if (Cir_work_instance.Flag != Cir_work_flag_t.get_readcir_response)
            {
                //MessageBox.Show("[CIR]获取请求cir数据回应失败!");
                return -2;
            }
            if (!Cir_work_instance.Is_get_readresp_ok)
            {
                //MessageBox.Show("[CIR]获取请求cir数据拒绝!");
                return -1;
            }

            //回应正常 读取具体cir数据
            
            Cir_work_instance.Now_cir_read_idx = 0;
            for (int i = 0; i < Cir_work_instance.Now_cir_totalcount; i++)
            {
                Cir_work_instance.Flag = Cir_work_flag_t.wait_cir_data;
                Cir_send_get_cirdata_command(Cir_work_instance.Now_cir_read_idx);
                timeout_flag = 10;
                while (timeout_flag-- > 0 && Cir_work_instance.Flag == Cir_work_flag_t.wait_cir_data)
                {
                    Thread.Sleep(100);
                }
                if (Cir_work_instance.Flag != Cir_work_flag_t.get_cir_data)
                {
                    //MessageBox.Show($"[CIR]获取第{Cir_work_instance.Now_cir_read_idx + 1}个cir包数据失败!");
                    return -3;
                }
                Cir_work_instance.Now_cir_read_idx++;
            }

            //所有的都获取完成 发送结束指令
            Cir_work_instance.Flag = Cir_work_flag_t.wait_cir_fin;
            Cir_send_cir_fin_command();
            timeout_flag = 10;
            while (timeout_flag-- > 0 && Cir_work_instance.Flag == Cir_work_flag_t.wait_cir_fin)
            {
                Thread.Sleep(100);
            }
            if (Cir_work_instance.Flag != Cir_work_flag_t.get_cir_fin)
            {
                //MessageBox.Show("[CIR]指令cir结束失败!");
                return -4;
            }
            return 1;
        }

        private void Cir_plot()
        {
            PlotHelper_Cir.ResetDisplay();
            PlotHelper_Cir.ClearPlot(0);

            PlotHelper_Cir.GetXAxis().Minimum = Cir_work_instance.Cir_read_startaddr;
            PlotHelper_Cir.GetXAxis().Maximum = Cir_work_instance.Cir_read_startaddr + Cir_work_instance.Cir_read_num;
            double max_value = 0;
            for (int i = 0; i < Cir_work_instance.Cir_read_num; i++)
            {
                double value = 0;
                if (Module_use_chip == Module_Chip_t.DW1000)
                {                   
                    short real = 0, imagine = 0;
                    real = (short)(Cir_work_instance.Cir_data_list[i * 4] | (Cir_work_instance.Cir_data_list[i * 4 + 1] << 8));
                    imagine = (short)(Cir_work_instance.Cir_data_list[i * 4 + 2] | (Cir_work_instance.Cir_data_list[i * 4 + 3] << 8));
                    value = Math.Sqrt(Math.Pow(real, 2) + Math.Pow(imagine, 2));                    
                }
                else
                {
                    int real = 0, imagine = 0;
                    real = (int)(Cir_work_instance.Cir_data_list[i * 6] | (Cir_work_instance.Cir_data_list[i * 6 + 1] << 8) | (Cir_work_instance.Cir_data_list[i * 6 + 2] << 16));
                    imagine = (int)(Cir_work_instance.Cir_data_list[i * 6 + 3] | (Cir_work_instance.Cir_data_list[i * 6 + 4] << 8) | (Cir_work_instance.Cir_data_list[i * 6 + 5] << 16));
                    if((real & 0x020000) > 0)
                    {
                        real = (int)(real | 0xFFFC0000);
                    }
                    if ((imagine & 0x020000) > 0)
                    {
                        imagine = (int)(imagine | 0xFFFC0000);
                    }

                    value = Math.Sqrt(Math.Pow(real, 2) + Math.Pow(imagine, 2));
                }

                PlotHelper_Cir.AddPoint(Cir_work_instance.Cir_read_startaddr + i, value, 0);
                if (max_value <= value)
                {
                    max_value = value;
                }
                //if(i + Cir_work_instance.Cir_read_startaddr == Rxdiag.firstPath)
                //{
                //    PlotHelper_Cir.AddPoint((int)Rxdiag.firstPath, 0, 1);
                //    PlotHelper_Cir.AddPoint((int)Rxdiag.firstPath, value, 1);
                //}
            }
            PlotHelper_Cir.GetYAxis().Maximum = max_value + 500;
            PlotHelper_Cir.RefreshPlot();
        }

        private void Btn_Cir_transpng_Click(object sender, EventArgs e)
        {
            SaveFileDialog sd = new SaveFileDialog();
            sd.Title = "请选择导出位置";
            sd.Filter = "png| *.png";
            if (sd.ShowDialog() == DialogResult.OK)
            {
                string filename = sd.FileName;
                if (!string.IsNullOrEmpty(filename))
                {
                    try
                    {
                        PngExporter p = new PngExporter()
                        {
                            Width = 680,
                            Height = 400
                        };
                        p.ExportToFile(PlotHelper_Cir.Plot, filename);
                        MessageBox.Show("导出图片成功!");
                    }
                    catch
                    {
                        MessageBox.Show("导出图片失败!");
                    }
                }
            }
        }

        private void Btn_cir_trans2excel_Click(object sender, EventArgs e)
        {
            SaveFileDialog sd = new SaveFileDialog();
            sd.Title = "请选择导出位置";
            sd.Filter = "Excel文件| *.xls";
            if (sd.ShowDialog() == DialogResult.OK)
            {
                string filename = sd.FileName;
                if (!string.IsNullOrEmpty(filename))
                {
                    try
                    {
                        //创建Excel文件的对象
                        NPOI.HSSF.UserModel.HSSFWorkbook book = new NPOI.HSSF.UserModel.HSSFWorkbook();
                        //添加一个sheet
                        NPOI.SS.UserModel.ISheet sheet1 = book.CreateSheet("Sheet1");

                        //给sheet1添加第一行的头部标题
                        NPOI.SS.UserModel.IRow row1 = sheet1.CreateRow(0);

                        row1.CreateCell(0).SetCellValue("Cir_idx");
                        row1.CreateCell(1).SetCellValue("Cir_value");

                        for (int i = 0; i < Cir_work_instance.Cir_read_num; i++)
                        {
                            NPOI.SS.UserModel.IRow rowtemp = sheet1.CreateRow(i + 1);
                            rowtemp.CreateCell(0).SetCellValue(Cir_work_instance.Cir_read_startaddr + i);
                            rowtemp.CreateCell(1).SetCellValue(PlotHelper_Cir.GetLine(0).Points[i].Y);
                        }

                        FileStream ms = File.OpenWrite(sd.FileName.ToString());
                        try
                        {
                            book.Write(ms);
                            ms.Seek(0, SeekOrigin.Begin);
                            MessageBox.Show("导出成功");
                        }
                        catch
                        {
                            MessageBox.Show("导出失败!");
                        }
                        finally
                        {
                            if (ms != null)
                            {
                                ms.Close();
                            }
                        }
                    }
                    catch
                    {

                    }
                }
            }
        }

        private void CheckBox_Cir_showgrid_CheckedChanged(object sender, EventArgs e)
        {
            if (CheckBox_Cir_showgrid.Checked)
            {
                PlotHelper_Cir.Show_GridLine();
            }
            else
            {
                PlotHelper_Cir.Clear_GridLine();
            }
            PlotHelper_Cir.RefreshPlot(false);
        }

        private void CheckBox_cir_showmarkup_CheckedChanged(object sender, EventArgs e)
        {
            if (CheckBox_cir_showmarkup.Checked)
            {
                PlotHelper_Cir.Show_Markup(0);
            }
            else
            {
                PlotHelper_Cir.Clear_Markup(0);
            }
            PlotHelper_Cir.RefreshPlot(false);
        }

        private void Cir_change_progress(int now_value, int max_value)
        {
            MethodInvoker mi = new MethodInvoker(() =>
            {
                int show_value = (int)((double)now_value / max_value * 100);
                ProgressBar_read_cir.Value = show_value;
                Text_cir_progress.Text = $"{show_value}%";
            });
            BeginInvoke(mi);
        }



        #endregion

        #region 远程配置
        private void Btn_rc_en_Click(object sender, EventArgs e)
        {
            if (Is_in_remotecfg_mode)
            {
                //退出配置模式

                //发送控制指令
                //发送命令
                ModbusRTU.Instance.Modbus_com.ModbusID = NOW_ID;
                ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_ModuleMode;
                ModbusRTU.Instance.Modbus_com.FunctionCode = 0x10;
                ModbusRTU.Instance.Modbus_com.RegNum = 1;

                byte[] temp = new byte[2];
                temp[0] = 0x00;
                temp[1] = 0x00;  //空闲
                byte[] send_buff = ModbusRTU.Instance.Modbus10Send(temp);
                if (send_buff != null)
                {
                    Work_State = WorkState.Out_Remote_cfg;
                    do
                    {
                        Thread.Sleep(100);
                        APP_Send_Data(send_buff, 0);
                    }
                    while (Work_State != WorkState.Idle);
                }
                Is_in_remotecfg_mode = false;
                Btn_rc_en.Text = "进入配置模式";
                GroupBox_rc_taglist.Enabled = false;
                Groupbox_rc_detail.Enabled = false;
                Remote_cfg_taglist.Clear();

            }
            else
            {
                if (Module_Mode != ModuleMode.main_anc)
                {
                    MessageBox.Show("只有主基站才可以使用该功能!");
                    return;
                }
                //发送控制指令
                //发送命令
                ModbusRTU.Instance.Modbus_com.ModbusID = NOW_ID;
                ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_ModuleMode;
                ModbusRTU.Instance.Modbus_com.FunctionCode = 0x10;
                ModbusRTU.Instance.Modbus_com.RegNum = 1;

                byte[] temp = new byte[2];
                temp[0] = 0x00;
                temp[1] = 10;  //配置模式
                byte[] send_buff = ModbusRTU.Instance.Modbus10Send(temp);
                if (send_buff != null)
                {
                    Work_State = WorkState.In_Remote_cfg;
                    do
                    {
                        Thread.Sleep(100);
                        APP_Send_Data(send_buff, 0);
                    }
                    while (Work_State != WorkState.Remote_cfg);
                }

                Btn_rc_en.Text = "退出配置模式";
                GroupBox_rc_taglist.Enabled = true;
                Groupbox_rc_detail.Enabled = true;
                Is_in_remotecfg_mode = true;
            }
        }

        private void DataGridView_tag_cfg_SelectionChanged(object sender, EventArgs e)
        {
            if (Remote_cfg_taglist.Count == 0)
            {
                return;
            }
            if (DataGridView_tag_cfg.SelectedCells.Count == 0)
            {
                return;
            }
            int row_idx = DataGridView_tag_cfg.SelectedCells[0].RowIndex;
            if (row_idx == -1)
            {
                return;
            }
            Remote_tag_cfg now_cfg = Remote_cfg_taglist[row_idx];
            Selected_cfg.ID = now_cfg.ID;
            Selected_cfg.TagVersion = now_cfg.TagVersion;
            Selected_cfg.Tag_Kind = now_cfg.Tag_Kind;
            Selected_cfg.Moving_freq = now_cfg.Moving_freq;
            Selected_cfg.Alarm_freq = now_cfg.Alarm_freq;
            Selected_cfg.Static_freq = now_cfg.Static_freq;
            Selected_cfg.Move_Pack = now_cfg.Move_Pack;
            Selected_cfg.Static_Pack = now_cfg.Static_Pack;
            Selected_cfg.Imu_en = now_cfg.Imu_en;
            Selected_cfg.Imu_sense = now_cfg.Imu_sense;
            Selected_cfg.RxAntDelay = now_cfg.RxAntDelay;
            Selected_cfg.Pg_id = now_cfg.Pg_id;
            Selected_cfg.PowerSet_EN = now_cfg.PowerSet_EN;
            Selected_cfg.Power_db = now_cfg.Power_db;
            Selected_cfg.Nosleep_freq = now_cfg.Nosleep_freq;
            Selected_cfg.Poweroff_en = now_cfg.Poweroff_en;
            Selected_cfg.PowerOnTime = now_cfg.PowerOnTime;
            Selected_cfg.Heart_Rate = now_cfg.Heart_Rate;
        }


        private void RadioButton_CheckedChanged(object sender, EventArgs e)
        {
            RadioButton rb = sender as RadioButton;
            if (rb.Checked)
            {
                if (rb.Name == "RadioButton_single")
                {
                    Is_single_cfg = true;
                }
                else
                {
                    Is_single_cfg = false;
                }
            }
        }

        private void Btn_send_cfg_Click(object sender, EventArgs e)
        {
            if (Selected_cfg == null)
            {
                MessageBox.Show("请先选中列表中一项!");
                return;
            }
            //发送配置指令
            ModbusRTU.Instance.Modbus_com.ModbusID = NOW_ID;
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x43;
            byte[] data_buff = new byte[28 + 14];
            data_buff[0] = 41;
            data_buff[1] = (byte)(Is_single_cfg ? 1 : 2);
            if (Is_single_cfg)
            {
                Array.Copy(strToHexByte(Selected_cfg.ID), 0, data_buff, 2, 6);
            }
            else
            {
                Array.Clear(data_buff, 2, 6);
            }
            data_buff[8] = (byte)(Selected_cfg.Static_freq >> 8);
            data_buff[9] = (byte)(Selected_cfg.Static_freq & 0x00FF);
            data_buff[10] = (byte)(Selected_cfg.Alarm_freq >> 8);
            data_buff[11] = (byte)(Selected_cfg.Alarm_freq & 0x00FF);
            data_buff[12] = (byte)(Selected_cfg.Moving_freq >> 8);
            data_buff[13] = (byte)(Selected_cfg.Moving_freq & 0x00FF);
            data_buff[14] = (byte)(Selected_cfg.Imu_en ? 0 : 1);
            data_buff[15] = Selected_cfg.Imu_sense;
            data_buff[16] = Selected_cfg.Move_Pack;
            data_buff[17] = Selected_cfg.Static_Pack;
            data_buff[18] = (byte)(Selected_cfg.RxAntDelay >> 8);
            data_buff[19] = (byte)(Selected_cfg.RxAntDelay & 0x00FF);
            data_buff[20] = (byte)(Selected_cfg.PowerSet_EN ? 1 : 0);
            data_buff[21] = Selected_cfg.Power_db;
            data_buff[22] = (byte)(Selected_cfg.Nosleep_freq >> 8);
            data_buff[23] = (byte)(Selected_cfg.Nosleep_freq & 0x00FF);
            data_buff[24] = (byte)Selected_cfg.PowerOnTime;
            data_buff[25] = (byte)Selected_cfg.Pg_id;
            data_buff[26] = (byte)(Selected_cfg.Poweroff_en ? 0 : 1);
            data_buff[27] = (byte)Selected_cfg.Heart_Rate;
            //将时间转换为字符串
            string timeString = DateTime.Now.ToString("yyyyMMddHHmmss");
            // 将字符串转换为ASCII字节数组
            byte[] asciiArray = Encoding.ASCII.GetBytes(timeString);
            Array.Copy(asciiArray, 0, data_buff, 28, asciiArray.Length);
            byte[] send_buff = ModbusRTU.Instance.Modbus_Custom_Send(data_buff, data_buff.Length);
            if (send_buff != null)
                APP_Send_Data(send_buff, 0);
            MessageBox.Show("写入完成!");
        }

        private void Checkbox_smartpwr_en_CheckedChanged(object sender, EventArgs e)
        {
            Combo_power_db.Enabled = Checkbox_smartpwr_en.Checked;
        }

        private void Checkbox_rc_imu_en_CheckedChanged(object sender, EventArgs e)
        {
            Combo_imu_sensitive.Enabled = Checkbox_rc_imu_en.Checked;
        }

        #endregion

        #region 自动标定
        private void Btn_AutoCalibPos_Click(object sender, EventArgs e)
        {
            //先等待进入标定模式
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x10;
            ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_AutoCalibConfig;
            ModbusRTU.Instance.Modbus_com.RegNum = ModbusRTU.RegNum_AutoCalibConfig;
            int retry_time = 5;
            byte[] temp = new byte[2];
            temp[0] = 0x01;
            temp[1] = 10;    //测距次数 默认10次
            byte[] send_buff = ModbusRTU.Instance.Modbus10Send(temp);
            if (send_buff == null)
            {
                MessageBox.Show("Modbus指令出错!");
                return;
            }
            Work_State = WorkState.IntoAutoCalibPos;
            do
            {
                Thread.Sleep(200);
                APP_Send_Data(send_buff, 0);
            }
            while (Work_State != WorkState.AutoCalibPos && retry_time-- > 0);

            if(Work_State != WorkState.AutoCalibPos)
            {
                MessageBox.Show("进入自动标定模式出错!");
                return;
            }

            AncAutoCalibPos_Window w = new AncAutoCalibPos_Window(AnchorList, APP_Send_Data);
            this.Send_CalibPos_Event += w.Data_Recv_Handler;
            if(w.ShowDialog() == DialogResult.OK)
            {
                //退出自动标定模式
                ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_AutoCalibConfig;
                ModbusRTU.Instance.Modbus_com.FunctionCode = 0x10;
                ModbusRTU.Instance.Modbus_com.RegNum = 1;

                temp = new byte[2];
                temp[0] = 0x00;
                temp[1] = 0x00;
                send_buff = ModbusRTU.Instance.Modbus10Send(temp);
                if (send_buff != null)
                {
                    Work_State = WorkState.OutAutoCalibPos;
                    do
                    {
                        Thread.Sleep(100);
                        APP_Send_Data(send_buff, 0);
                    }
                    while (Work_State != WorkState.Idle);
                    this.Send_CalibPos_Event -= w.Data_Recv_Handler;
                }
            }
        }
        #endregion

        #region 硬件测试
        private void ToolStripMenuItem_ContinuousFrame_Click(object sender, EventArgs e)
        {
            Hardware_Test_Mode = 0x00;
            ModbusRTU.Instance.Modbus_com.RegValue = (0x01 << 8 | 0x00);
            ModbusRTU.Instance.Modbus_com.ModbusID = NOW_ID;
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x06;
            ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_HardwareTest;
           
            byte[] buff = ModbusRTU.Instance.Modbus06Send();
            if (buff != null)
                APP_Send_Data(buff, 0);
            Work_State = WorkState.IntoHardwareTest_cfg;
        }

        private void ToolStripMenuItem_ContinuousWave_Click(object sender, EventArgs e)
        {
            Hardware_Test_Mode = 0x01;
            ModbusRTU.Instance.Modbus_com.RegValue = (0x01 << 8 | 0x01);
            ModbusRTU.Instance.Modbus_com.ModbusID = NOW_ID;
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x06;
            ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_HardwareTest;
           
            byte[] buff = ModbusRTU.Instance.Modbus06Send();
            if (buff != null)
                APP_Send_Data(buff, 0);
            Work_State = WorkState.IntoHardwareTest_cfg;
        }

        private void ToolStripMenuItem_Hardware_exit_Click(object sender, EventArgs e)
        {
            ModbusRTU.Instance.Modbus_com.RegValue = 0x0000;
            ModbusRTU.Instance.Modbus_com.ModbusID = NOW_ID;
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x06;
            ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_HardwareTest;

            byte[] buff = ModbusRTU.Instance.Modbus06Send();
            if (buff != null)
                APP_Send_Data(buff, 0);
            Work_State = WorkState.OutHardwareTest_cfg;
        }
        #endregion

        #region 写入频偏参数
        private void button_write_uwb_trim_Click(object sender, EventArgs e)
        {
            byte[] buff_temp = new byte[2];
            buff_temp[0] = (byte)(CheckBox_is_use_uwb_trim.Checked ? 1 : 0);
            buff_temp[1] = (byte)(numericUpDown_uwb_trim.Value);
            ModbusRTU.Instance.Modbus_com.RegValue = (ushort)(buff_temp[0] << 8 | buff_temp[1]);
            ModbusRTU.Instance.Modbus_com.ModbusID = NOW_ID;
            ModbusRTU.Instance.Modbus_com.FunctionCode = 0x06;
            ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_UWBTrimConfig;

            byte[] send_buff = ModbusRTU.Instance.Modbus06Send();
            if (send_buff != null)
                APP_Send_Data(send_buff, 0);
        }
        #endregion
    }
}
