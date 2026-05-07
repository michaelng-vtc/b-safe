using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace PGRtls.Model
{
    internal class Remote_tag_cfg : INotifyPropertyChanged
    {
        private SynchronizationContext syncContext;

        public static byte[] PowerHex = new byte[] {
            0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5,
            0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5,
            0x80, 0x81, 0x82, 0x83, 0x84, 0x85,
            0x60, 0x61, 0x62, 0x63, 0x64, 0x65,
            0x40, 0x41, 0x42, 0x43, 0x44, 0x45,
            0x20, 0x21, 0x22, 0x23, 0x24, 0x25,
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05,
            0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B,
            0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11,
            0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
            0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D,
            0x1E, 0x1F
        };

        private int PowerDb2Value(byte powerDb)
        {
            int g = 1;  //若失败则返回最小功率
            for (int i = 0; i < PowerHex.Length; i++)
            {
                if (powerDb == PowerHex[i])
                {
                    g = i;
                    break;
                }
            }
            return g;
        }

        private byte PowerValue2Db(float power_value)
        {
            int idx = (int)(power_value / 0.5f);
            if(idx >= 0 && idx <= 67)
            {
                return PowerHex[idx];
            }
            return 0;
        }


        private string _ID;
        public string ID
        {
            get
            {
                return _ID;
            }
            set
            {
                _ID = value;
                OnPropertyChanged("ID");
            }
        }

        private int _Frame;
        public int Frame
        {
            get
            {
                return _Frame;
            }
            set
            {
                _Frame = value;
                OnPropertyChanged("Frame");
            }
        }


        private byte _Pg_id;
        public byte Pg_id
        {
            get
            {
                return _Pg_id;
            }
            set
            {
                _Pg_id = value;
                OnPropertyChanged("Pg_id");
            }
        }


        private ushort _Static_freq;
        public ushort Static_freq
        {
            get
            {
                return _Static_freq;
            }
            set
            {
                _Static_freq = value;
                OnPropertyChanged("Static_freq");
            }
        }


        private ushort _Alarm_freq;
        public ushort Alarm_freq
        {
            get
            {
                return _Alarm_freq;
            }
            set
            {
                _Alarm_freq = value;
                OnPropertyChanged("Alarm_freq");
            }
        }


        private ushort _Moving_freq;
        public ushort Moving_freq
        {
            get
            {
                return _Moving_freq;
            }
            set
            {
                _Moving_freq = value;
                OnPropertyChanged("Moving_freq");
            }
        }

        private bool _Imu_en;

        public bool Imu_en
        {
            get { return _Imu_en; }
            set
            {
                _Imu_en = value;
                Imu_en_str = value ? "是" : "否";
            }
        }


        private string _Imu_en_str;
        public string Imu_en_str
        {
            get
            {
                return _Imu_en_str;
            }
            set
            {
                _Imu_en_str = value;
                OnPropertyChanged("Imu_en_str");
            }
        }

        private byte _Imu_sense;

        public byte Imu_sense
        {
            get { return _Imu_sense; }
            set
            {
                _Imu_sense = value;
                if (_Imu_sense == 2)
                {
                    Imu_sense_str = "低";
                }
                else if (_Imu_sense == 1)
                {
                    Imu_sense_str = "中";
                }
                else if (_Imu_sense == 0)
                {
                    Imu_sense_str = "高";
                }
            }
        }


        private string _Imu_sense_str;
        public string Imu_sense_str
        {
            get
            {
                return _Imu_sense_str;
            }
            set
            {
                _Imu_sense_str = value;
                OnPropertyChanged("Imu_sense_str");
            }
        }

        /* 动态发包次数 */
        private byte _Move_Pack;
        public byte Move_Pack
        {
            get
            {
                return _Move_Pack;
            }
            set
            {
                _Move_Pack = value;
                OnPropertyChanged("Move_Pack");
            }
        }

        /* 静止发包次数 */
        private byte _Static_Pack;
        public byte Static_Pack
        {
            get
            {
                return _Static_Pack;
            }
            set
            {
                _Static_Pack = value;
                OnPropertyChanged("Static_Pack");
            }
        }

        /* 接收天线延时 */
        private ushort _RxAntDelay;
        public ushort RxAntDelay
        {
            get
            {
                return _RxAntDelay;
            }
            set
            {
                _RxAntDelay = value;
                OnPropertyChanged("RxAntDelay");
            }
        }

        /* 标签种类 */
        private byte _Tag_Kind;
        public byte Tag_Kind
        {
            get
            {
                return _Tag_Kind;
            }
            set
            {
                _Tag_Kind = value;
                OnPropertyChanged("Tag_Kind");
                switch (_Tag_Kind)
                {
                    case 0:
                        TagKind_Show = "工牌";
                        break;
                    case 1:
                        TagKind_Show = "A款手环";
                        break;
                    case 2:
                        TagKind_Show = "资产K";
                        break;
                    case 3:
                        TagKind_Show = "资产B";
                        break;
                    case 9:
                        TagKind_Show = "C款手环";
                        break;
                    case 10:
                        TagKind_Show = "D款手环";
                        break;
                }
            }
        }

        private string _TagKind_Show;
        public string TagKind_Show
        {
            get
            {
                return _TagKind_Show;
            }
            set
            {
                _TagKind_Show = value;
                OnPropertyChanged("TagKind_Show");
            }
        }

        /* 标签版本 */
        private ushort _TagVersion;
        public ushort TagVersion
        {
            get
            {
                return _TagVersion;
            }
            set
            {
                _TagVersion = value;
                OnPropertyChanged("TagVersion");
                byte a = (byte)((_TagVersion >> 8) & 0x00FF);
                byte b = (byte)(_TagVersion & 0x00FF);
                TagVer_Show = a.ToString() + "." + b.ToString();
            }
        }

        private string _TagVer_Show;
        public string TagVer_Show
        {
            get
            {
                return _TagVer_Show;
            }
            set
            {
                _TagVer_Show = value;
                OnPropertyChanged("TagVer_Show");
            }
        }

        /* Smart Power*/
        bool _PowerSet_EN;
        public bool PowerSet_EN
        {
            get
            {
                return _PowerSet_EN;
            }
            set
            {
                _PowerSet_EN = value;
                OnPropertyChanged("PowerSet_EN");
                if (_PowerSet_EN)
                    PowerSet_Show = "是";
                else
                    PowerSet_Show = "否";
            }
        }
        string _PowerSet_Show;
        public string PowerSet_Show
        {
            get
            {
                return _PowerSet_Show;
            }
            set
            {
                _PowerSet_Show = value;
                OnPropertyChanged("PowerSet_Show");
            }
        }

        /* 功率 */
        private byte _Power_db;
        public byte Power_db
        {
            get
            {
                return _Power_db;
            }
            set
            {
                if(_Power_db != value)
                {
                    _Power_db = value;
                    OnPropertyChanged("Power_db");
                    int power_index = PowerDb2Value(_Power_db);
                    Power_Show = (float)0.5f * power_index;
                }
            }
        }

        private float _Power_Show;
        public float Power_Show
        {
            get
            {
                return _Power_Show;
            }
            set
            {
                if(_Power_Show != value)
                {
                    _Power_Show = value;
                    Power_db = PowerValue2Db(_Power_Show);
                    OnPropertyChanged("Power_Show");
                }
            }
        }

        /* 不休眠发包频率 */
        private int _Nosleep_freq;
        public int Nosleep_freq
        {
            get
            {
                return _Nosleep_freq;
            }
            set
            {
                _Nosleep_freq = value;
                OnPropertyChanged("Nosleep_freq");
            }
        }


        private bool _Poweroff_en;
        public bool Poweroff_en
        {
            get
            {
                return _Poweroff_en;
            }
            set
            {
                _Poweroff_en = value;
                OnPropertyChanged("Poweroff_en");
                if (_Poweroff_en)
                    Poweroff_en_Show = "是";
                else
                    Poweroff_en_Show = "否";
            }
        }

        private string _Poweroff_en_Show;
        public string Poweroff_en_Show
        {
            get
            {
                return _Poweroff_en_Show;
            }
            set
            {
                _Poweroff_en_Show = value;
                OnPropertyChanged("Poweroff_en_Show");
            }
        }

        private int _PowerOnTime;
        public int PowerOnTime
        {
            get
            {
                return _PowerOnTime;
            }
            set
            {
                _PowerOnTime = value;
                OnPropertyChanged("PowerOnTime");
            }
        }
        private int _Heart_Rate;
        public int Heart_Rate
        {
            get
            {
                return _Heart_Rate;
            }
            set
            {
                _Heart_Rate = value;
                OnPropertyChanged("Heart_Rate");
            }
        }
        public Remote_tag_cfg()
        {
            syncContext = SynchronizationContext.Current;
        }

        public Remote_tag_cfg(string id)
        {
            syncContext = SynchronizationContext.Current;
            ID = id;
        }

        public event PropertyChangedEventHandler PropertyChanged;
        protected internal virtual void OnPropertyChanged(string propertyName)
        {
            var handler = PropertyChanged;
            if (handler != null)
            {
                if (syncContext != null)
                    syncContext.Post(_ => handler(this, new PropertyChangedEventArgs(propertyName)), null);
                else
                    handler(this, new PropertyChangedEventArgs(propertyName));
            }
        }
    }
}
