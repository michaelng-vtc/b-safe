using System;
using System.Collections.Generic;
using System.Text;

namespace PGRtls.ModbusHelper
{
    public class ModbusRTUState
    {
        /// <summary>
        /// modbus接收状态指示
        /// </summary>
        public enum ReceiveState
        {
            crcError = 0,               //crc校验错误     
            IDError ,                   //modbusID错误
            FunctionCodeError,          //modbus功能码错误
            AddrError,                  //modbus寄存器地址错误
            RegNumError,                //modbus寄存器数量错误
            RegValueError,              //modbus寄存器值错误
            RecvOk                      //没问题
        }
    }
}
