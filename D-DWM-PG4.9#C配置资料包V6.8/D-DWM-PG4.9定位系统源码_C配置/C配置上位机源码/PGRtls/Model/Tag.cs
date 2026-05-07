using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.ComponentModel;

namespace PGRtls.Model
{
    public class Tag : INotifyPropertyChanged
    {
        //标签本次x坐标
        private double _x;
        public double x
        {
            get
            {
                return _x;
            }
            set
            {
                if (_x == value)
                {
                   return;
                }                    
                _x = value;
                OnPropertyChanged("x");
            }
        }

        //标签本次y坐标
        private double _y;
        public double y
        {
            get
            {
                return _y;
            }
            set
            {
                if (_y == value)
                {
                   return;
                }
                _y = value;                
                OnPropertyChanged("y");
            }
        }

        //标签本次z坐标
        private double _z;
        public double z
        {
            get
            {
                return _z;
            }
            set
            {
                if (_z == value)
                {
                   return;
                }
                _z = value;
                OnPropertyChanged("z");
            }
        }

        //标签导航状态
        private int _Navi_status_idx;
        public int Navi_status_idx
        {
            get
            {
                return _Navi_status_idx;
            }
            set
            {
                if(_Navi_status_idx != value)
                {
                    _Navi_status_idx = value;
                    switch (value)
                    {
                        case 0:
                            {
                                Navi_status_str = "静止";
                                break;
                            }
                        case 1:
                            {
                                Navi_status_str = "点动";
                                break;
                            }
                        case 2:
                            {
                                Navi_status_str = "自动导航";
                                break;
                            }
                        default:break;
                    }
                }
            }
        }


        private string _Navi_status_str;
        public string Navi_status_str
        {
            get
            {
                return _Navi_status_str;
            }
            set
            {
                if (_Navi_status_str == value)
                {
                    return;
                }
                _Navi_status_str = value;
                OnPropertyChanged("Navi_status_str");
            }
        }

        //导航角度
        private int _Navi_angle;
        public int Navi_angle
        {
            get => _Navi_angle;
            set
            {
                if (_Navi_angle == value)
                {
                    return;
                }
                _Navi_angle = value;
                OnPropertyChanged("Navi_angle");
            }
        }

        private double _Magn_tesla;
        public double Magn_tesla
        {
            get => _Magn_tesla;
            set
            {
                if (_Magn_tesla == value)
                {
                    return;
                }
                _Magn_tesla = value;
                OnPropertyChanged("Magn_tesla");
            }
        }

        public int Car_speed { get; set; }

        //标签自身ID
        public int Id { get; set; }

        //标签本次定位是否解算成功
        public bool CalSuccess { get; set; }

        //标签本次与其它基站测距值
        public uint[] Dist { get; set; }

        //标签本次与其它基站测距成功指示
        public bool[] Dist_Success { get; set; }

        //标签1s前x坐标
        public double Last_x_1s { get; set; }

        //标签1s前y坐标
        public double Last_y_1s { get; set; }

        //标签1s前z坐标
        public double Last_z_1s { get; set; }

        public int TagNotFound_time { get; set; }

        //标签上次x坐标
        public double Last_x { get; set; }

        //标签上次y坐标
        public double Last_y { get; set; }

        //标签上次z坐标
        public double Last_z { get; set; }

        //标签上次卡尔曼滤波x的P值
        public double P_last_x { get; set; }

        //标签上次卡尔曼滤波y的P值
        public double P_last_y { get; set; }

        //标签上次卡尔曼滤波z的P值
        public double P_last_z { get; set; }

        //标签在列表中的位置
        public int Index { get; set; }

        //手环工牌标签的电量显示
        public byte Qc { get; set; }

        //手环工牌标签报警提示
        public bool IsAlarm { get; set; }

        //手环工牌标签报警显示
        public int Alarm_count { get; set; }
        //手环标签的心率值
        public byte Heart { get; set; }
        //手环标签的血氧值
        public byte Blood { get; set; }

        public bool IsNavi { get; set; }


        //速度
        public double Velocity { get; set; }

        public DateTime LastRecord_time { get; set; }

        public struct Rx_diag_t
        {
            public ushort Max_noise { get; set; }
            public ushort Std_noise { get; set; }
            public ushort Fp_amp1 { get; set; }
            public ushort Fp_amp2 { get; set; }
            public ushort Fp_amp3 { get; set; }
            public ushort Max_growthCIR { get; set; }
            public ushort Rx_preambleCount { get; set; }
            public ushort Fp { get; set; }
            public double Fp_power { get; set; }
            public double Rx_power { get; set; }

            public byte DGC_dbg { get; set; }
        }
        public Rx_diag_t Rx_diag;

        public event PropertyChangedEventHandler PropertyChanged;
        protected internal virtual void OnPropertyChanged(string propertyName)
        {
            var handler = PropertyChanged;
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }


        public uint[] Time_ts { get; set; }


        public Tag(int id)
        {
            x = 0;
            y = 0;
            z = 0;
            Id = id;
            Index = 0;
            CalSuccess = false;
            Dist = new uint[16];
            Dist_Success = new bool[16];
            Time_ts = new uint[6];
            Rx_diag = new Rx_diag_t();
            IsNavi = false;
            Navi_status_idx = -1;
        }

        public Tag(int id, int idx)
        {
            x = 0;
            y = 0;
            z = 0;
            Id = id;
            Index = idx;
            CalSuccess = false;
            Dist = new uint[16];
            Dist_Success = new bool[16];
            Time_ts = new uint[6];
            Rx_diag = new Rx_diag_t();
            IsNavi = false;
            Navi_status_idx = -1;
        }

        public void Cal_Velocity(double now_x, double now_y, double now_z)
        {
            Velocity = Rtls.RtlsHelp.Rtls_Cal_Dist(Last_x_1s, Last_y_1s, Last_z_1s, now_x, now_y, now_z);
            Velocity = Math.Round(Velocity, 2);
            Last_x_1s = now_x;
            Last_y_1s = now_y;
            Last_z_1s = now_z;
        }

        public static bool TryGetTag(List<Tag> list, int id ,out Tag t)
        {
            for(int i = 0; i < list.Count; i++)
            {
                if(list[i].Id == id)
                {
                    t = list[i];
                    return true;
                }
            }
            t = new Tag(id);
            return false;
        }

        public static bool TryGetTag(BindingList<Tag> list, int id, out Tag t)
        {
            for (int i = 0; i < list.Count; i++)
            {
                if (list[i].Id == id)
                {
                    t = list[i];
                    return true;
                }
            }
            t = new Tag(id);
            return false;
        }
    }
}
