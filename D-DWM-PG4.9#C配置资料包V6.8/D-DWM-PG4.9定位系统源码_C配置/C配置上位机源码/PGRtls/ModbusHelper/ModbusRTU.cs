using System;
using System.Collections.Generic;
using System.Dynamic;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using static PGRtls.ModbusHelper.ModbusRTUState;

namespace PGRtls.ModbusHelper
{
    public class ModbusRTU
    {
        public const byte RegNum_ReadConfig = 118;  //读取模块配置寄存器数量
        public const byte RegNum_WriteConfig = 111; //写入模块配置寄存器数量
        public const byte RegNum_IMU = 20;          //IMU寄存器数量 
        public const byte RegNum_IMU_ReadConfig = 22;  //IMU读取寄存器配置数量
        public const byte RegNum_IMU_WriteConfig = 22;  //IMU写入寄存器配置数量
        public const byte RegNum_IMU_WriteMagn_correct = 7; //写入磁力计校准参数寄存器数量
        public const byte RegNum_TagOutputConfig = 2;  //模块标签输出内容寄存器数量
        public const byte RegNum_MainAncOutputConfig = 1;  //模块主基站输出内容寄存器数量
        public const byte RegNum_AutoCalibConfig = 1;  //模块主基站测距使能寄存器数量
        //public const byte RegNum_Rtls = 44;         
        //public const byte RegNum_DataRecv = 14;

        public const byte Addr_ModuleMode = 59;     //模块定位工作寄存器地址
        public const byte Addr_IMU = 120;           //IMU寄存器起始地址
        public const byte Addr_IMU_Magn_correct = 133; //IMU寄存器起始地址
        public const byte Addr_TagOutputConfig = 112;  //模块标签输出内容寄存器地址
        public const byte Addr_MainAncOutputConfig = 114;  //模块主基站输出内容寄存器地址
        public const byte Addr_AutoCalibConfig = 115; //模块主基站测距使能寄存器地址
        public const byte Addr_AutoCalibPairConfig = 116; //模块主基站测距使能寄存器地址
        public const byte Addr_HardwareTest = 118; //模块硬件测试寄存器地址
        public const byte Addr_UWBTrimConfig = 117; //UWB频偏寄存器地址

        private readonly byte[] Table_crc_hi = new byte[] {
    0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 0x01, 0xC0,
    0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41,
    0x00, 0xC1, 0x81, 0x40, 0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0,
    0x80, 0x41, 0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40,
    0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1,
    0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 0x01, 0xC0, 0x80, 0x41,
    0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1,
    0x81, 0x40, 0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41,
    0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 0x01, 0xC0,
    0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 0x00, 0xC1, 0x81, 0x40,
    0x01, 0xC0, 0x80, 0x41, 0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1,
    0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40,
    0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 0x01, 0xC0,
    0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 0x00, 0xC1, 0x81, 0x40,
    0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0,
    0x80, 0x41, 0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40,
    0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 0x01, 0xC0,
    0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41,
    0x00, 0xC1, 0x81, 0x40, 0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0,
    0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41,
    0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0,
    0x80, 0x41, 0x00, 0xC1, 0x81, 0x40, 0x00, 0xC1, 0x81, 0x40,
    0x01, 0xC0, 0x80, 0x41, 0x01, 0xC0, 0x80, 0x41, 0x00, 0xC1,
    0x81, 0x40, 0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41,
    0x00, 0xC1, 0x81, 0x40, 0x01, 0xC0, 0x80, 0x41, 0x01, 0xC0,
    0x80, 0x41, 0x00, 0xC1, 0x81, 0x40
    };

        /* Table of CRC values for low-order byte */
        private readonly byte[] Table_crc_lo = new byte[]{
    0x00, 0xC0, 0xC1, 0x01, 0xC3, 0x03, 0x02, 0xC2, 0xC6, 0x06,
    0x07, 0xC7, 0x05, 0xC5, 0xC4, 0x04, 0xCC, 0x0C, 0x0D, 0xCD,
    0x0F, 0xCF, 0xCE, 0x0E, 0x0A, 0xCA, 0xCB, 0x0B, 0xC9, 0x09,
    0x08, 0xC8, 0xD8, 0x18, 0x19, 0xD9, 0x1B, 0xDB, 0xDA, 0x1A,
    0x1E, 0xDE, 0xDF, 0x1F, 0xDD, 0x1D, 0x1C, 0xDC, 0x14, 0xD4,
    0xD5, 0x15, 0xD7, 0x17, 0x16, 0xD6, 0xD2, 0x12, 0x13, 0xD3,
    0x11, 0xD1, 0xD0, 0x10, 0xF0, 0x30, 0x31, 0xF1, 0x33, 0xF3,
    0xF2, 0x32, 0x36, 0xF6, 0xF7, 0x37, 0xF5, 0x35, 0x34, 0xF4,
    0x3C, 0xFC, 0xFD, 0x3D, 0xFF, 0x3F, 0x3E, 0xFE, 0xFA, 0x3A,
    0x3B, 0xFB, 0x39, 0xF9, 0xF8, 0x38, 0x28, 0xE8, 0xE9, 0x29,
    0xEB, 0x2B, 0x2A, 0xEA, 0xEE, 0x2E, 0x2F, 0xEF, 0x2D, 0xED,
    0xEC, 0x2C, 0xE4, 0x24, 0x25, 0xE5, 0x27, 0xE7, 0xE6, 0x26,
    0x22, 0xE2, 0xE3, 0x23, 0xE1, 0x21, 0x20, 0xE0, 0xA0, 0x60,
    0x61, 0xA1, 0x63, 0xA3, 0xA2, 0x62, 0x66, 0xA6, 0xA7, 0x67,
    0xA5, 0x65, 0x64, 0xA4, 0x6C, 0xAC, 0xAD, 0x6D, 0xAF, 0x6F,
    0x6E, 0xAE, 0xAA, 0x6A, 0x6B, 0xAB, 0x69, 0xA9, 0xA8, 0x68,
    0x78, 0xB8, 0xB9, 0x79, 0xBB, 0x7B, 0x7A, 0xBA, 0xBE, 0x7E,
    0x7F, 0xBF, 0x7D, 0xBD, 0xBC, 0x7C, 0xB4, 0x74, 0x75, 0xB5,
    0x77, 0xB7, 0xB6, 0x76, 0x72, 0xB2, 0xB3, 0x73, 0xB1, 0x71,
    0x70, 0xB0, 0x50, 0x90, 0x91, 0x51, 0x93, 0x53, 0x52, 0x92,
    0x96, 0x56, 0x57, 0x97, 0x55, 0x95, 0x94, 0x54, 0x9C, 0x5C,
    0x5D, 0x9D, 0x5F, 0x9F, 0x9E, 0x5E, 0x5A, 0x9A, 0x9B, 0x5B,
    0x99, 0x59, 0x58, 0x98, 0x88, 0x48, 0x49, 0x89, 0x4B, 0x8B,
    0x8A, 0x4A, 0x4E, 0x8E, 0x8F, 0x4F, 0x8D, 0x4D, 0x4C, 0x8C,
    0x44, 0x84, 0x85, 0x45, 0x87, 0x47, 0x46, 0x86, 0x82, 0x42,
    0x43, 0x83, 0x41, 0x81, 0x80, 0x40
    };

        public Modbus Modbus_com { get; set; } = new Modbus(1, 3, 0, 0);

        #region 单例模式实例
        private static readonly object logLock = new object();

        private volatile static ModbusRTU _instance = null;
        public static ModbusRTU Instance
        {
            get
            {
                if (_instance == null)
                {
                    lock (logLock)
                    {
                        if (_instance == null)
                        {
                            _instance = new ModbusRTU();
                        }
                    }
                }
                return _instance;
            }
        }
        #endregion


        //#region ModbusHelper
        //private static ModbusRTU _modbusHelper;
      
        //private ModbusRTU()  { }

        //public static ModbusRTU ModubsHelper
        //{
        //    get
        //    {
        //        if(_modbusHelper == null)
        //        {
        //            _modbusHelper = new ModbusRTU();
        //        }
        //        return _modbusHelper;
        //    }
        //}
        //#endregion


        /// <summary>
        /// CRC校验
        /// </summary>
        /// <param name="buffer">输入要校验的数组</param>
        /// <param name="buffer_length">输入数组的长度</param>
        /// <returns></returns>
        private ushort Crc16(byte[] buffer, int buffer_length)
        {
            byte crc_hi = 0xFF; /* high CRC byte initialized */
            byte crc_lo = 0xFF; /* low CRC byte initialized */
            int t;
            /* pass through message buffer */
            for (int i = 0; i < buffer_length; i++)
            {
                t = crc_hi ^ buffer[i]; /* calculate the CRC  */
                crc_hi = (byte)(crc_lo ^ Table_crc_hi[t]);
                crc_lo = Table_crc_lo[t];
            }
            return (ushort)(crc_hi << 8 | crc_lo);
        }

        /// <summary>
        /// 发送03码数据
        /// </summary>
        /// <param name="modbus"></param>
        /// <returns>符合03码协议完整数组</returns>
        public byte[] Modbus03Send()
        {
            if (Modbus_com != null)
            {
                byte[] buff = new byte[8];
                int send_length = 0;
                buff[send_length++] = Modbus_com.ModbusID;
                buff[send_length++] = 0x03;
                buff[send_length++] = (byte)(Modbus_com.Addr >> 8);
                buff[send_length++] = (byte)(Modbus_com.Addr & 0x00FF);
                buff[send_length++] = (byte)(Modbus_com.RegNum >> 8);
                buff[send_length++] = (byte)(Modbus_com.RegNum & 0x00FF);
                ushort crc = Crc16(buff, send_length);
                buff[send_length++] = (byte)(crc >> 8);
                buff[send_length++] = (byte)(crc & 0x00FF);
                return buff;
            }
            else
                return null;
        }

        /// <summary>
        /// 发送10码
        /// </summary>
        /// <param name="modbus"></param>
        /// <param name="write_buff">要写入寄存器值</param>
        /// <returns>符合10码协议完整数组</returns>
        public byte[] Modbus10Send(byte[] write_buff)
        {
            if (write_buff == null)
                return null;
            byte[] buff = new byte[Modbus_com.RegNum * 2 + 9];
            int send_length = 0;
            buff[send_length++] = Modbus_com.ModbusID;
            buff[send_length++] = 0x10;
            buff[send_length++] = (byte)(Modbus_com.Addr >> 8);
            buff[send_length++] = (byte)(Modbus_com.Addr & 0x00FF);
            buff[send_length++] = (byte)(Modbus_com.RegNum >> 8);
            buff[send_length++] = (byte)(Modbus_com.RegNum & 0x00FF);
            buff[send_length++] = (byte)(Modbus_com.RegNum * 2);
            for(int i = 0; i < Modbus_com.RegNum * 2; i++)
            {
                buff[send_length++] = write_buff[i];
            }
            ushort crc = Crc16(buff, send_length);
            buff[send_length++] = (byte)(crc >> 8);
            buff[send_length++] = (byte)(crc & 0x00FF);
            return buff;
        }

        /// <summary>
        /// 发送06码
        /// </summary>
        /// <returns>符合06码协议完整数组</returns>
        public byte[] Modbus06Send()
        {
            byte[] buff = new byte[8];
            int send_length = 0;
            buff[send_length++] = Modbus_com.ModbusID;
            buff[send_length++] = 0x06;
            buff[send_length++] = (byte)(Modbus_com.Addr >> 8);
            buff[send_length++] = (byte)(Modbus_com.Addr & 0x00FF);
            buff[send_length++] = (byte)(Modbus_com.RegValue >> 8);
            buff[send_length++] = (byte)(Modbus_com.RegValue & 0x00FF);

            ushort crc = Crc16(buff, send_length);
            buff[send_length++] = (byte)(crc >> 8);
            buff[send_length++] = (byte)(crc & 0x00FF);
            return buff;
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="data_buff"></param>
        /// <returns></returns>
        public byte[] Modbus_Custom_Send(byte[] data_buff, int data_len)
        {
            byte[] buff = new byte[data_len + 4];
            int send_length = 0;
            buff[send_length++] = Modbus_com.ModbusID;
            buff[send_length++] = Modbus_com.FunctionCode;
            for (int i = 0; i < data_len; i++)
            {
                buff[send_length++] = data_buff[i];
            }
            ushort crc = Crc16(buff, send_length);
            buff[send_length++] = (byte)(crc >> 8);
            buff[send_length++] = (byte)(crc & 0x00FF);
            return buff;
        }
        public byte[] Modbus_Custom_Send(byte data)
        {
            byte[] buff = new byte[5];
            int send_length = 0;
            buff[send_length++] = Modbus_com.ModbusID;
            buff[send_length++] = Modbus_com.FunctionCode;
            buff[send_length++] = data;
            ushort crc = Crc16(buff, send_length);
            buff[send_length++] = (byte)(crc >> 8);
            buff[send_length++] = (byte)(crc & 0x00FF);
            return buff;
        }

        /// <summary>
        /// 03码接收
        /// </summary>
        /// <param name="buff">获取到的字节数组</param>
        /// <param name="length">数组长度</param>
        /// <param name="modbus"></param>
        /// <returns>该数据modbus协议情况</returns>
        public ReceiveState Modbus03Recv(byte[] buff , int length, bool CheckRegNum)
        {
            ushort crc = Crc16(buff, length - 2);
            if (crc != ((buff[length - 2] << 8) | buff[length - 1]))
                return ReceiveState.crcError;
            if (buff[0] != Modbus_com.ModbusID)
                return ReceiveState.IDError;
            if (buff[1] != Modbus_com.FunctionCode)
                return ReceiveState.FunctionCodeError;
            if (CheckRegNum)
            {
                if (buff[2] != Modbus_com.RegNum * 2)
                    return ReceiveState.RegNumError;
            }
            
            return ReceiveState.RecvOk;
        }

        /// <summary>
        /// 10码接收
        /// </summary>
        /// <param name="buff">获取到的字节数组</param>
        /// <param name="length">数组长度</param>
        /// <returns>该数据modbus协议情况</returns>
        public ReceiveState Modbus10Recv(byte[] buff, int length, bool CheckRegNum)
        {
            ushort crc = Crc16(buff, length - 2);
            if (crc != ((buff[length - 2] << 8) | buff[length - 1]))
                return ReceiveState.crcError;
            if (buff[0] != Modbus_com.ModbusID)
                return ReceiveState.IDError;
            if (buff[1] != Modbus_com.FunctionCode)
                return ReceiveState.FunctionCodeError;
            ushort addr = (ushort)((buff[2] << 8) | buff[3]);
            if (addr != Modbus_com.Addr)
                return ReceiveState.AddrError;
            ushort regnum = (ushort)((buff[4] << 8) | buff[5]);
            if (CheckRegNum)
            {
                if (regnum != Modbus_com.RegNum)
                    return ReceiveState.RegNumError;
            }
                
            return ReceiveState.RecvOk;
        }

        /// <summary>
        /// 06码接收
        /// </summary>
        /// <param name="buff">获取到的字节数组</param>
        /// <param name="length">数组长度</param>
        /// <returns>该数据modbus协议情况</returns>
        public ReceiveState Modbus06Recv(byte[] buff, int length)
        {
            ushort crc = Crc16(buff, length - 2);
            if (crc != ((buff[length - 2] << 8) | buff[length - 1]))
                return ReceiveState.crcError;
            if (buff[0] != Modbus_com.ModbusID)
                return ReceiveState.IDError;
            if (buff[1] != Modbus_com.FunctionCode)
                return ReceiveState.FunctionCodeError;
            ushort addr = (ushort)((buff[2] << 8) | buff[3]);
            if (addr != Modbus_com.Addr)
                return ReceiveState.AddrError;
            ushort regvalue = (ushort)((buff[4] << 8) | buff[5]);
            if (regvalue != Modbus_com.RegValue)
                return ReceiveState.RegValueError;
            return ReceiveState.RecvOk;
        }

        /// <summary>
        /// Modbus协议自定义协议解析 只需要判断id、功能码和crc是否正确
        /// </summary>
        /// <param name="buff"></param>
        /// <param name="length"></param>
        /// <returns></returns>
        public ReceiveState Modbus_Custom_Recv(byte[] buff, int length)
        {
            ushort crc = Crc16(buff, length - 2);
            if (crc != ((buff[length - 2] << 8) | buff[length - 1]))
                return ReceiveState.crcError;
            if (buff[0] != Modbus_com.ModbusID)
                return ReceiveState.IDError;
            if (buff[1] != Modbus_com.FunctionCode)
                return ReceiveState.FunctionCodeError;
            return ReceiveState.RecvOk;
        }



    }
}
