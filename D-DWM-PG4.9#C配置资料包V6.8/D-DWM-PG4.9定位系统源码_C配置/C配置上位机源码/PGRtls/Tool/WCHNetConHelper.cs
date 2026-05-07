using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using PGRtls.Model;

namespace PGRtls.Tool
{
    public class WCHNetConHelper
    {
        public const byte NET_MODULE_CMD_SET = 0x01;
        public const byte NET_MODULE_CMD_GET = 0x02;
        public const byte NET_MODULE_CMD_RESET = 0x03;
        public const byte NET_MODULE_CMD_SEARCH = 0x04;

        public const byte NET_MODULE_ACK_SET = 0x81;
        public const byte NET_MODULE_ACK_GET = 0x82;
        public const byte NET_MODULE_ACK_RESEST = 0x83;
        public const byte NET_MODULE_ACK_SEARCH = 0x84;

        private const int HEADER_PACKET_LEN = 30;
        private const int DATA_PACKET_REAL_LEN = 204;
        private const int DATA_PACKET_LEN = 255;
        private const int PACKET_LEN = HEADER_PACKET_LEN + DATA_PACKET_LEN;

        private const int PACKET_CMD_IDX = 16;
        private const int PACKET_MAC_IDX = 17;
        private const int PACKET_DATALEN_IDX = 29;
        private const int PACKET_DATA_START_IDX = 30;

        public const int DATA_IP_IDX = 32;
        public const int DATA_GATEWAY_IDX = 36;
        public const int DATA_NETMASK_IDX = 40;
        public const int DATA_DHCP_IDX = 44;
        public const int DATA_MODE_IDX = 141;
        public const int DATA_LOCALPORT_RAND_IDX = 142;
        public const int DATA_LOCALPORT_IDX = 143;  //端口号低位在前 长度为2
        public const int DATA_BAUDRATE_IDX = 151;  //串口波特率 低位在前 长度4

        private const string CH9120_CFG_FLAG = "CH9120_CFG_FLAG\0";
        private byte[] Cfg_flag_b { get; set; }

        public byte Send_Command { get; set; }
        public byte Recv_Command { get; set; }
        //public string Now_mac { get; set; }
        public byte[] Data_Buff { get; set; }
        public int Now_datalen { get; private set; }

        public WCHNetConHelper()
        {
            Cfg_flag_b = Encoding.ASCII.GetBytes(CH9120_CFG_FLAG);
            Data_Buff = new byte[DATA_PACKET_LEN];
        }
        /// <summary>
        /// 检查是否符合WCH协议
        /// </summary>
        /// <param name="buff">接收到的数据字节数组</param>
        /// <returns>1 符合协议且取出Data -1 帧头错误 -2长度不够 </returns>
        public int WCH_CheckBuff(byte[] buff, out string mac_now)
        {
            int Data_len = 0;
            mac_now = string.Empty;
            if (buff.Length > 16)
            {
                byte[] cfg_b = new byte[16];
                Array.Copy(buff, cfg_b, 16);
                string cfg_flag = Encoding.ASCII.GetString(cfg_b);
                if (cfg_flag != CH9120_CFG_FLAG)
                    return -1;
            }
            else
                return -2;
            if (buff.Length >= HEADER_PACKET_LEN)  //网络帧头接收完了
            {
                //指令头正确
                Recv_Command = buff[PACKET_CMD_IDX];
                mac_now = string.Empty;
                for (int i = 0; i < 6; i++)
                {
                    mac_now += buff[PACKET_MAC_IDX + i].ToString("X2");
                    if (i != 5)
                        mac_now += ":";
                }
                Data_len = buff[PACKET_DATALEN_IDX];
            }
            else
                return -2;
            if (Data_len + HEADER_PACKET_LEN <= buff.Length)
            {
                if (Data_len > 0)
                {
                    Data_Buff = new byte[Data_len];
                    Array.Copy(buff, PACKET_DATA_START_IDX, Data_Buff, 0, Data_len);
                    Now_datalen = Data_len;
                }
                return 1;
            }
            else
                return -2;

        }

        /// <summary>
        /// 准备发送搜索基站的指令
        /// </summary>
        /// <returns></returns>
        public byte[] WCH_WriteSearchBuff()
        {
            byte[] send_buff = new byte[PACKET_LEN];
            Send_Command = NET_MODULE_CMD_SEARCH;
            Array.Copy(Cfg_flag_b, send_buff, Cfg_flag_b.Length);
            send_buff[PACKET_CMD_IDX] = NET_MODULE_CMD_SEARCH;
            for (int i = 17; i < PACKET_LEN; i++)
                send_buff[i] = 0;
            return send_buff;
        }

    }
}
