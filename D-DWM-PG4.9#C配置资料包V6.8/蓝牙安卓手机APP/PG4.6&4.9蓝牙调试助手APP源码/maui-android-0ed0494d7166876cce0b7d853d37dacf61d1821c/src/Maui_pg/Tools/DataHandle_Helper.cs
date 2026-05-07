using Maui_pg.Models;
using Maui_pg.Shares;
using Maui_pg.Tools.ModbusHelper;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maui_pg.Tools
{
    public class DataHandle_Helper
    {

        #region 单例模式实例
        private static readonly object logLock = new object();

        private volatile static DataHandle_Helper _instance = null;
        public static DataHandle_Helper Instance
        {
            get
            {
                if (_instance == null)
                {
                    lock (logLock)
                    {
                        if (_instance == null)
                        {
                            _instance = new DataHandle_Helper();
                        }
                    }
                }
                return _instance;
            }
        }
        #endregion
        private DataHandle_Helper()
        {
            Task.Run(Data_RecvTask);
        }

        private AutoResetEvent RecvThread_Are = new AutoResetEvent(false);  //用于对接收处理线程的同步处理 

        private static readonly object Lock_recv_object = new object();

        private const int Recv_buffer_max = 20480;  //接收处理最大缓存数量
        private List<byte> Recv_buffer = new List<byte>(Recv_buffer_max);  //接收缓存区

        public event EventHandler<EventArgs> ReadConfig_Event;

        //用于读取标签输出的定位测距信息的数组
        //readonly string[] Tag_Dist_Resolve = new string[16] {"AnchorA",
        //                                                    "AnchorB" ,
        //                                                    "AnchorC" ,
        //                                                    "AnchorD" ,
        //                                                    "AnchorE" ,
        //                                                    "AnchorF" ,
        //                                                    "AnchorG" ,
        //                                                    "AnchorH",
        //                                                    "AnchorI" ,
        //                                                    "AnchorJ" ,
        //                                                    "AnchorK" ,
        //                                                    "AnchorL" ,
        //                                                    "AnchorM" ,
        //                                                    "AnchorN" ,
        //                                                    "AnchorO" ,
        //                                                    "AnchorP"
        //};

        //readonly char[] Tag_Rtls_Resolve = new char[3] { 'X', 'Y', 'Z' };

        public void Add_rx_data(byte[] data)
        {
            lock (Lock_recv_object)
            {
                if (Recv_buffer.Count > Recv_buffer_max)  //缓存超过字节数 先丢弃前面的字节           
                    Recv_buffer.RemoveRange(0, Recv_buffer_max);

                Recv_buffer.AddRange(data);  //存入缓存区
            }
            RecvThread_Are.Set();
        }

        private void Data_RecvTask()
        {
            while (true)
            {
                RecvThread_Are.WaitOne();
                if (Recv_buffer.Count >= 4)
                {
                    while (Recv_buffer.Count >= 4)
                    {
                        byte[] ReceiveByte = new byte[1];
                        int ReceieveByte_length = -1;
                        if (Recv_buffer[0] == Share_Data.Modbus_instance.ModbusID)
                        {
                            //接收到modbus数据
                            //判断是否Modbus功能码
                            if (Recv_buffer[1] == 0x03 || Recv_buffer[1] == 0x10 || Recv_buffer[1] == 0x06)
                            {
                                if (Recv_buffer[1] == 0x03)  //根据第三个字节来取缓存区的字节数
                                {
                                    int len = Recv_buffer[2];
                                    ReceieveByte_length = len + 5;
                                    if (ReceieveByte_length > Recv_buffer.Count)  //还没接收完全
                                        break;
                                    ReceiveByte = new byte[ReceieveByte_length];
                                }
                                if (Recv_buffer[1] == 0x10 || Recv_buffer[1] == 0x06)  //总数固定为8字节
                                {
                                    ReceieveByte_length = 8;
                                    if (ReceieveByte_length > Recv_buffer.Count)  //还没接收完全
                                        break;
                                    ReceiveByte = new byte[ReceieveByte_length];
                                }
                                Recv_buffer.CopyTo(0, ReceiveByte, 0, ReceieveByte_length);  //获取符合协议的帧数据以解析
                                Recv_buffer.RemoveRange(0, ReceieveByte_length);  //需要从缓存区中删除该数据
                                
                                switch (Share_Data.Modbus_instance.FunctionCode)
                                {
                                    case 0x03:  //目前只处理03码
                                        {
                                            ReceiveState state = ReceiveState.RecvOk;
                                            if (Share_Data.Work_State == WorkState.Idle || Share_Data.Work_State == WorkState.Rtlsing)
                                                state = ModbusRTU.Modbus03Recv(ReceiveByte, ReceieveByte_length, Share_Data.Modbus_instance, false);
                                            else
                                                state = ModbusRTU.Modbus03Recv(ReceiveByte, ReceieveByte_length, Share_Data.Modbus_instance, true);

                                            if (state == ReceiveState.RecvOk)
                                                Modbus03Recv(ReceiveByte, ReceieveByte_length);
                                            else  //协议判断不正确 继续接收下面的
                                                continue;
                                            break;
                                        }
                                    default:
                                        break;
                                }
                            }
                            else
                            {
                                //第一个是ID但跟着的不是功能码 
                                Recv_buffer.RemoveAt(0);
                            }
                        }
                        else
                        {
                            Recv_buffer.RemoveAt(0);
                        }

                        //由于蓝牙传输最大长度247 这里不对自由协议做处理
                        //if (!Is_Modbus)
                        //{
                        //    //不是Modbus协议 可能是自由协议                      
                        //    if ((Recv_buffer[0] == 'A' && Recv_buffer[1] == 'T') ||
                        //        (Recv_buffer[0] == 'O' && Recv_buffer[1] == 'K') ||
                        //        (Recv_buffer[0] == 'D' && Recv_buffer[1] == 'i') ||
                        //        (Recv_buffer[0] == 'R' && Recv_buffer[1] == 't'))
                        //    {
                        //        //符合需要的自由协议 找帧结尾有没有0D 0A
                        //        int idx_d, idx_a;
                        //        idx_d = Recv_buffer.IndexOf(0x0D);
                        //        idx_a = Recv_buffer.IndexOf(0x0A);
                        //        if (idx_d != -1 && idx_a != -1)
                        //        {
                        //            if (idx_a - idx_d == 1)
                        //            {
                        //                ReceieveByte_length = idx_a + 1;
                        //                ReceiveByte = new byte[ReceieveByte_length];
                        //                Recv_buffer.CopyTo(0, ReceiveByte, 0, ReceieveByte_length);  //获取符合协议的帧数据以解析
                        //                Recv_buffer.RemoveRange(0, ReceieveByte_length);  //需要从缓存区中删除该数据

                        //                if ((ReceiveByte[0] == 'D' && ReceiveByte[1] == 'i') ||
                        //                  (ReceiveByte[0] == 'R' && ReceiveByte[1] == 't'))
                        //                {
                        //                    //自由协议接收到标签定位数据
                        //                    Tag_RtlsDataRecv(ReceiveByte, 1);
                        //                }                  
                        //            }
                        //            else
                        //                break;
                        //        }
                        //        else
                        //            break;
                        //        //break;  //没读取到 先跳出循环等待下次的接收
                        //    }
                        //    else  //都不是 去除这个字节
                        //        Recv_buffer.RemoveAt(0);
                        //}

                    }
                }
            }
        }

        private void Modbus03Recv(byte[] temp, int length)
        {
            switch (Share_Data.Work_State)
            {
                case WorkState.ReadConfig:  //读取配置 目前只对标签做处理
                    {
                        Share_Data.Now_pg_device.Module_Mode = (ModuleMode)temp[10];
                        if(temp[10] == 0)  //标签模式
                        {
                            Share_Data.Now_pg_device.Module_id = temp[12];
                        }
                        Share_Data.TagList.Clear();
                        Share_Data.TagList.Add(new UWBTag()
                        {
                            Id = temp[12]
                        });
                        ReadConfig_Event?.Invoke(this, new EventArgs());
                        break;
                    }
                default:break;
            }
            if (temp[3] == 0xAC && temp[4] == 0xDA)  //标签上报位置信息 modbus格式
            {
                Tag_RtlsDataRecv(temp, 0);
            }
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
        private bool Check_BitIsTrue(uint data, int b)
        {
            return ((data >> b) & 0x01) == 0x01;
        }

        /// <summary>
        /// 标签接收到定位信息的处理
        /// </summary>
        /// <param name="RecvBuff">要解析的数据</param>
        /// <param name="mode">0 modbus模式 1字符</param>
        private void Tag_RtlsDataRecv(byte[] RecvBuff, int mode)
        {
            short[] last_xyz = new short[3];
            ushort[] last_dist = new ushort[Share_Data.ANCHOR_MAX_COUNT];
            bool[] ok_flags = new bool[Share_Data.ANCHOR_MAX_COUNT + 1];  //0 xyz成功标志 1-17 测距A-P基站成功标志 
            if (mode == 0) //modbus解析
            {

                int buff_idx = 7;
                int i;
                if (Check_BitIsTrue(RecvBuff[6], 0))
                {
                    //测距使能
                    ushort dist_flag = (ushort)(RecvBuff[buff_idx++] << 8 | RecvBuff[buff_idx++]);
                    for (i = 0; i < Share_Data.ANCHOR_MAX_COUNT; i++)
                    {
                        ok_flags[i + 1] = Check_BitIsTrue(dist_flag, i);
                        last_dist[i] = (ushort)(RecvBuff[buff_idx++] << 8 | RecvBuff[buff_idx++]);
                    }

                }
                if (Check_BitIsTrue(RecvBuff[6], 1))
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
            else  //ascii输出解析
            {
                /* 默认不选择通过ascii码输出 故不解析 */
                //string recv_str = string.Empty;
                //if (RecvBuff[0] == 'D' && RecvBuff[1] == 'i')
                //{
                //    //测距信息解析
                //    recv_str = Encoding.ASCII.GetString(RecvBuff);
                //    if (!string.IsNullOrEmpty(recv_str))
                //        Tag_DistRead(recv_str, ref last_dist);
                //}
                //else if (RecvBuff[0] == 'R' && RecvBuff[1] == 't')
                //{
                //    //定位信息解析
                //    recv_str = Encoding.ASCII.GetString(RecvBuff);
                //    if (!string.IsNullOrEmpty(recv_str))
                //        Tag_RtlsRead(recv_str, ref last_xyz);
                //}
            }

            //赋值
            if(Share_Data.Try_FindTag(Share_Data.Now_pg_device.Module_id, out UWBTag t))
            {
                if (ok_flags[0])
                {
                    t.X = last_xyz[0];
                    t.Y = last_xyz[1];
                    t.Z = last_xyz[2];
                }
            }
        }

        /// <summary>
        /// 判断字符串形式的测距信息
        /// </summary>
        /// <param name="str">标签测距字符串</param>
        /// <param name="dist">返回距离保存数组</param>
        //private void Tag_DistRead(string str, ref ushort[] dist)
        //{
        //    int anc_idx = 0;
        //    int anc_next_idx = 1;
        //    int cm_idx = 0;
        //    try
        //    {
        //        for (int i = 0; i < Share_Data.ANCHOR_MAX_COUNT; i++)
        //        {
        //            if (i != Share_Data.ANCHOR_MAX_COUNT - 1)
        //            {
        //                anc_idx = str.IndexOf(Tag_Dist_Resolve[i]);
        //                anc_next_idx = str.IndexOf(Tag_Dist_Resolve[i + 1]);
        //                if (anc_next_idx == -1)
        //                {
        //                    //未找到后续的 可能是DS模式下只输出与A基站的测距值
        //                    cm_idx = str.LastIndexOf("cm");
        //                    string str_temp = str.Substring(anc_idx, cm_idx - anc_idx);
        //                    if (string.IsNullOrEmpty(str_temp))
        //                        return;
        //                    string value_temp = str_temp.Substring(8, str_temp.Length - 8 - 1);

        //                    if (!string.IsNullOrEmpty(value_temp))
        //                    {
        //                        dist[i] = Convert.ToUInt16(value_temp);
        //                        break;
        //                    }
        //                }
        //                else
        //                {
        //                    string str_temp = str.Substring(anc_idx, anc_next_idx - anc_idx);
        //                    if (string.IsNullOrEmpty(str_temp))
        //                        return;
        //                    cm_idx = str_temp.IndexOf("cm");
        //                    if (cm_idx > 0)
        //                    {
        //                        string value_temp = str_temp.Substring(8, cm_idx - 8 - 1);

        //                        if (!string.IsNullOrEmpty(value_temp))
        //                            dist[i] = Convert.ToUInt16(value_temp);
        //                        else
        //                            return;
        //                    }
        //                }

        //            }
        //            else
        //            {
        //                anc_idx = str.IndexOf(Tag_Dist_Resolve[i]);
        //                cm_idx = str.LastIndexOf("cm");
        //                string str_temp = str.Substring(anc_idx, cm_idx - anc_idx);
        //                if (string.IsNullOrEmpty(str_temp))
        //                    return;
        //                string value_temp = str_temp.Substring(8, str_temp.Length - 8 - 1);

        //                if (!string.IsNullOrEmpty(value_temp))
        //                    dist[i] = Convert.ToUInt16(value_temp);
        //                else
        //                    return;
        //            }
        //        }
        //    }
        //    catch (Exception ex)
        //    {
        //        return;
        //    }

        //}

        ///// <summary>
        ///// 判断字符串形式的定位信息
        ///// </summary>
        ///// <param name="str">标签定位字符串</param>
        ///// <param name="rtls">返回定位信息保存数组</param>
        //private void Tag_RtlsRead(string str, ref short[] rtls)
        //{
        //    int now_idx = 0;
        //    int next_idx = 1;
        //    int cm_idx = 0;
        //    try
        //    {
        //        for (int i = 0; i < 3; i++)
        //        {
        //            if (i != 2)
        //            {
        //                now_idx = str.IndexOf(Tag_Rtls_Resolve[i]);
        //                next_idx = str.IndexOf(Tag_Rtls_Resolve[i + 1]);
        //                if (next_idx == -1)
        //                {
        //                    //未找到后续的 可能是输出二维坐标只有x和y
        //                    cm_idx = str.LastIndexOf("cm");
        //                    string str_temp = str.Substring(now_idx, cm_idx - now_idx);
        //                    if (string.IsNullOrEmpty(str_temp))
        //                        return;
        //                    string value_temp = str_temp.Substring(4, str_temp.Length - 4 - 1);
        //                    if (!string.IsNullOrEmpty(value_temp))
        //                    {
        //                        rtls[i] = Convert.ToInt16(value_temp);
        //                        break;
        //                    }
        //                }
        //                else
        //                {
        //                    string str_temp = str.Substring(now_idx, next_idx - now_idx);
        //                    if (string.IsNullOrEmpty(str_temp))
        //                        return;
        //                    cm_idx = str_temp.IndexOf("cm");
        //                    if (cm_idx > 0)
        //                    {
        //                        string value_temp = str_temp.Substring(4, cm_idx - 4 - 1);
        //                        if (!string.IsNullOrEmpty(value_temp))
        //                            rtls[i] = Convert.ToInt16(value_temp);
        //                        else
        //                            return;
        //                    }
        //                }

        //            }
        //            else
        //            {
        //                now_idx = str.IndexOf(Tag_Rtls_Resolve[i]);
        //                if (now_idx == -1)
        //                {
        //                    //没找到 只有xy
        //                    return;
        //                }
        //                cm_idx = str.LastIndexOf("cm");
        //                string str_temp = str.Substring(now_idx, cm_idx - now_idx);
        //                if (string.IsNullOrEmpty(str_temp))
        //                    return;
        //                string value_temp = str_temp.Substring(4, str_temp.Length - 4 - 1);
        //                if (!string.IsNullOrEmpty(value_temp))
        //                    rtls[i] = Convert.ToInt16(value_temp);
        //                else
        //                    return;
        //            }
        //        }
        //    }
        //    catch (Exception ex)
        //    {
        //        return;
        //    }

        //}

    }
}
