using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maui_pg.Shares
{
    public enum WorkState
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
        WriteOutputConfig   //写入标签输出定位信息的配置
    }
}
