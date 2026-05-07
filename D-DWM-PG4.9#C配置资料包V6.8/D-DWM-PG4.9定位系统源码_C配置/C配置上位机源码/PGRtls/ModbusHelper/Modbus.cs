using System;
using System.Collections.Generic;
using System.Text;

namespace PGRtls.ModbusHelper
{
    public class Modbus
    {
        //ModbusID
        public byte ModbusID { get; set; }
        //Modbus功能码
        public byte FunctionCode { get; set; }
        //Modbus寄存器地址
        public ushort Addr { get; set; }
        //Modbus寄存器数量
        public ushort RegNum { get; set; }
        //Modbus寄存器值 06码会用到
        public ushort RegValue { get; set; }

        /// <summary>
        /// Modbus类实例初始化
        /// </summary>
        /// <param name="ID">ModbusID</param>
        /// <param name="Func">Modbus功能码</param>
        /// <param name="addr">Modbus寄存器地址</param>
        /// <param name="regNum">Modbus寄存器数量</param>
        public Modbus(byte ID, byte Func, ushort addr, ushort regNum)
        {
            ModbusID = ID;
            FunctionCode = Func;
            Addr = addr;
            RegNum = regNum;
        }
    }
}
