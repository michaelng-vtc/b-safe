using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PGRtls.ATHelper
{
    public static class AT
    {
        public const int AT_DATA_SENDLEN_MAX = 80;
        //接收信息判断状态指示
        public enum ATRecvState
        {
            Nothing,       //无事发生
            Good,          //OK
            Error          //错误 指令输入有误
        }

        /// <summary>
        /// AT指令接收判断
        /// </summary>
        /// <param name="buff"></param>
        /// <returns></returns>
        public static ATRecvState AT_Recv(byte[] buff)
        {
            string Recv_str = Encoding.UTF8.GetString(buff);
            Recv_str = Recv_str.Replace("\0","");
            if (Recv_str == "OK\r\n")
                return ATRecvState.Good;
            else if (Recv_str == "ERROR\r\n")
                return ATRecvState.Error;
            return ATRecvState.Nothing;
        }

        /// <summary>
        /// AT指令发送配置串口输出模式
        /// </summary>
        /// <param name="Print_En">串口输出使能</param>
        /// <param name="Print_Mode">串口输出模式</param>
        /// <returns>UTF8 转换的字节数组</returns>
        public static byte[] AT_PrintMode_Write(bool Print_En, int Print_Mode)
        {            
            StringBuilder sb = new StringBuilder();
            sb.Append("AT+PrintMode=");
            if (Print_En)
                sb.Append("1,");
            else
                sb.Append("0,");
            sb.Append(Print_Mode.ToString());
            sb.Append("\r\n");
            byte[] send_buff = Encoding.UTF8.GetBytes(sb.ToString());
            return send_buff;
        }

        /// <summary>
        /// AT指令发送数据透传信息
        /// </summary>
        /// <param name="data_to_send">要发送的字符串</param>
        /// <param name="recv_id">要发送的ID</param>
        /// <returns>UTF8 转换的字节数组</returns>
        public static byte[] AT_DataSend_Write(string data_to_send,string recv_id)
        {
            string change = "\"";
            StringBuilder sb = new StringBuilder();
            sb.Append("AT+DataSend=");
            sb.Append(change);
            sb.Append(data_to_send);
            sb.Append(change);
            sb.Append(",");

            sb.Append(change);
            sb.Append(recv_id);
            sb.Append(change);
            sb.Append("\r\n");
            string str_send = sb.ToString();
            byte[] send_buff = Encoding.UTF8.GetBytes(str_send);
            return send_buff;
        }


        public static byte[] AT_DataSend_Write(byte[] data_to_send, string recv_id)
        {
            string header = "AT+DataSend=\"";
            string end = $"\",\"{recv_id}\"\r\n";
            byte[] header_b = Encoding.UTF8.GetBytes(header);
            byte[] end_b = Encoding.UTF8.GetBytes(end);
            if(header_b != null && end_b != null)
            {
                byte[] result = new byte[header_b.Length + end_b.Length + AT_DATA_SENDLEN_MAX];
                Array.Copy(header_b, 0, result, 0, header_b.Length);
                Array.Copy(data_to_send, 0, result, header_b.Length, AT_DATA_SENDLEN_MAX);
                Array.Copy(end_b, 0, result, header_b.Length + AT_DATA_SENDLEN_MAX, end_b.Length);
                return result;
            }
            return null;
        }

    }
}
