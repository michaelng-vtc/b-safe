using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PGRtls.Model
{
    public class IMUConfig
    {
        public readonly ushort Bias_gyro_fsr = 256;
        public readonly ushort Bias_acc_fsr = 4;
        //磁力计转换系数 前面一个是根据手册里面计算的量程转换1.092267 后面是1G = 100uT 
        public readonly double Magn_fsr_scale = 109.2267; 

        public const int IMU_RB_VERSION_V2 = 20;

        public int version { get; set; }
        public bool Config_Init { get; set; }
        public double Gyro_fsr { get;private set; }
        public ushort Acc_fsr { get; private set; }
        public double Odr { get; private set; }

        public double Magn_fsr { get; private set; }
        public double Magn_odr { get; private set; }

        public bool Is_use_magncorrect { get; set; }
        public bool Is_use_uwbtrans { get; set; }

        public ushort Magn_algo_min { get; set; }
        public ushort Magn_algo_max { get; set; }

        public short[] Magn_bias { get; set; }
        public short[] Magn_scale { get; set; }

        #region RBV1配置
        public readonly string[] RBV1_config_acc_fsr = new string[4]
        {
            "±2", "±4", "±8", "±16"
        };

        public readonly string[] RBV1_config_gyro_fsr = new string[8]
        {
            "±15.2", "±31.2", "±62.5", "±125",
            "±250", "±500", "±1000", "±2000"
        };

        public readonly string[] RBV1_config_odr = new string[12]
        {
            "32K","16K","8K","4K","2K","1K",
            "200","100","50","25","12.5","500"
        };
        #endregion

        #region RBV2配置
        public readonly string[] RBV2_config_acc_fsr = new string[4]
        {
            "±2", "±4", "±8", "±16"
        };

        public readonly string[] RBV2_config_gyro_fsr = new string[8]
        {
            "±16", "±32", "±64", "±128",
            "±256", "±512", "±1024", "±2048"
        };

        public readonly string[] RBV2_config_odr = new string[9]
        {
            "7520","3760","1880","940","470","235",
            "117.5","58.75","29.375"
        };
        #endregion


        public IMUConfig()
        {
            Gyro_fsr = 0;
            Acc_fsr = 0;
            Magn_fsr = 0;
            Magn_odr = 0;
            Odr = 0;
            Magn_bias = new short[3];
            Magn_scale = new short[3];
            Is_use_magncorrect = false;
            Config_Init = false;
            Magn_algo_min = 20;
            Magn_algo_max = 70;
        }

        /// <summary>
        /// 设置加速度量程(RBV1和V2相同)
        /// </summary>
        /// <param name="index">加速度实际数值对应idx</param>
        public void Set_Acc_fsr(int index)
        {
            switch (index)
            {
                case 0:
                    {
                        Acc_fsr = 2;
                        break;
                    }
                case 1:
                    {
                        Acc_fsr = 4;
                        break;
                    }
                case 2:
                    {
                        Acc_fsr = 8;
                        break;
                    }
                case 3:
                    {
                        Acc_fsr = 16;
                        break;
                    }
                default:
                    {
                        Acc_fsr = 0;
                        break;
                    }
            }
        }

        /// <summary>
        /// 设置陀螺仪量程
        /// </summary>
        /// <param name="index">陀螺仪实际数值对应idx</param>
        public void Set_Gyro_fsr(int index)
        {
            if(version < IMU_RB_VERSION_V2)  //RBV1
            {
                switch (index)
                {
                    case 0:
                        {
                            Gyro_fsr = 15.2;
                            break;
                        }
                    case 1:
                        {
                            Gyro_fsr = 31.2;
                            break;
                        }
                    case 2:
                        {
                            Gyro_fsr = 62.5;
                            break;
                        }
                    case 3:
                        {
                            Gyro_fsr = 125;
                            break;
                        }
                    case 4:
                        {
                            Gyro_fsr = 250;
                            break;
                        }
                    case 5:
                        {
                            Gyro_fsr = 500;
                            break;
                        }
                    case 6:
                        {
                            Gyro_fsr = 1000;
                            break;
                        }
                    case 7:
                        {
                            Gyro_fsr = 2000;
                            break;
                        }
                    default:
                        {
                            Gyro_fsr = 0;
                            break;
                        }
                }
            }
            else
            {
                switch (index)
                {
                    case 0:
                        {
                            Gyro_fsr = 16;
                            break;
                        }
                    case 1:
                        {
                            Gyro_fsr = 32;
                            break;
                        }
                    case 2:
                        {
                            Gyro_fsr = 64;
                            break;
                        }
                    case 3:
                        {
                            Gyro_fsr = 128;
                            break;
                        }
                    case 4:
                        {
                            Gyro_fsr = 256;
                            break;
                        }
                    case 5:
                        {
                            Gyro_fsr = 512;
                            break;
                        }
                    case 6:
                        {
                            Gyro_fsr = 1024;
                            break;
                        }
                    case 7:
                        {
                            Gyro_fsr = 2048;
                            break;
                        }
                    default:
                        {
                            Gyro_fsr = 0;
                            break;
                        }
                }
            }
        }

        /// <summary>
        /// 设置采样频率 单位Hz
        /// </summary>
        /// <param name="index">采样频率实际数值对应idx</param>
        public void Set_Odr(int index)
        {
            if(version < IMU_RB_VERSION_V2)
            {
                switch (index)
                {
                    case 1:
                        {
                            Odr = 32000;
                            break;
                        }
                    case 2:
                        {
                            Odr = 16000;
                            break;
                        }
                    case 3:
                        {
                            Odr = 8000;
                            break;
                        }
                    case 4:
                        {
                            Odr = 4000;
                            break;
                        }
                    case 5:
                        {
                            Odr = 2000;
                            break;
                        }
                    case 6:
                        {
                            Odr = 1000;
                            break;
                        }
                    case 7:
                        {
                            Odr = 200;
                            break;
                        }
                    case 8:
                        {
                            Odr = 100;
                            break;
                        }
                    case 9:
                        {
                            Odr = 50;
                            break;
                        }
                    case 10:
                        {
                            Odr = 25;
                            break;
                        }
                    case 11:
                        {
                            Odr = 12.5;
                            break;
                        }
                    case 15:
                        {
                            Odr = 500;
                            break;
                        }
                    default:
                        {
                            Odr = 0;
                            break;
                        }
                }
            }
            else
            {
                switch (index)
                {
                    case 0:
                        {
                            Odr = 7520;
                            break;
                        }
                    case 1:
                        {
                            Odr = 3760;
                            break;
                        }
                    case 2:
                        {
                            Odr = 1880;
                            break;
                        }
                    case 3:
                        {
                            Odr = 940;
                            break;
                        }
                    case 4:
                        {
                            Odr = 470;
                            break;
                        }
                    case 5:
                        {
                            Odr = 235;
                            break;
                        }
                    case 6:
                        {
                            Odr = 117.5;
                            break;
                        }
                    case 7:
                        {
                            Odr = 58.75;
                            break;
                        }
                    case 8:
                        {
                            Odr = 29.375;
                            break;
                        }                   
                    default:
                        {
                            Odr = 0;
                            break;
                        }
                }
            }
            
        }

        /// <summary>
        /// 设置磁力计量程
        /// </summary>
        /// <param name="index"></param>
        public void Set_Magn_fsr(int index, bool Check_version = true)
        {
            if(Check_version && version < IMU_RB_VERSION_V2)
            {
                return;
            }
            switch (index)
            {
                case 0:
                    {
                        Magn_fsr = 30;
                        break;
                    }
                case 1:
                    {
                        Magn_fsr = 12;
                        break;
                    }
                case 2:
                    {
                        Magn_fsr = 8;
                        break;
                    }
                case 3:
                    {
                        Magn_fsr = 2;
                        break;
                    }
                default:break;
            }
        }

        /// <summary>
        /// 设置磁力计的采样频率
        /// </summary>
        /// <param name="index"></param>
        public void Set_Magn_odr(int index)
        {
            if (version < IMU_RB_VERSION_V2)
            {
                return;
            }
            switch (index)
            {
                case 0:
                    {
                        Magn_odr = 10;
                        break;
                    }
                case 1:
                    {
                        Magn_odr = 50;
                        break;
                    }
                case 2:
                    {
                        Magn_odr = 100;
                        break;
                    }
                case 3:
                    {
                        Magn_odr = 200;
                        break;
                    }
                default: break;
            }
        }

        /// <summary>
        /// 获取imu芯片温度
        /// </summary>
        /// <param name="temp_H"></param>
        /// <param name="temp_L"></param>
        /// <returns></returns>
        public double Imu_GetTemperature(byte temp_H, byte temp_L)
        {
            ushort raw_temperature;
            raw_temperature = (ushort)(temp_H << 8 | temp_L);
            if (version < IMU_RB_VERSION_V2)
            {                
                return Math.Round((double)raw_temperature / 132.48 + 25, 3);  
            }
            else
            {
                return (double)raw_temperature / 256;
            }       
        }
    }
}
