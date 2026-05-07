using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PGRtls.Model
{
    public class WCHConfig
    {
        /// <summary>
        /// 是否需要重新获取配置标志 true需要 false不需要
        /// </summary>
        public bool Need_Reload { get; set; }
        public bool Config_OK { get; set; }

        public string MacAddr { get; set; }

        public string Ip { get; set; }
        public string Netmask { get; set; }
        public string Gateway { get; set; }
        public int Port { get; set; }

        public byte[] MacAddr_b { get; set; }
        public byte[] Ip_b { get; set; }
        public byte[] Netmask_b { get; set; }
        public byte[] Gateway_b { get; set; }

        public int Baudrate { get; set; }

        public byte[] Commu_buff { get; set; }

        /// <summary>
        /// 将数组内容转化成ip类型 带.的字符
        /// </summary>
        /// <param name="buff"></param>
        /// <returns></returns>
        public string ConvetNetConfig_fromBuff(byte[] buff)
        {
            string temp = string.Empty;
            for (int i = 0; i < 4; i++)
            {
                temp += buff[i].ToString();
                if (i != 3)
                    temp += ".";
            }
            return temp;
        }

        public byte[] ConvertBuff_fromNetconfig(string config)
        {
            byte[] temp = new byte[4];
            string[] s = config.Split('.');
            if (s.Length == 4)
            {
                for (int i = 0; i < 4; i++)
                    temp[i] = Convert.ToByte(s[i]);
            }
            return temp;
        }

        /// <summary>
        /// 将ip_b转到IP
        /// </summary>
        public void ConvertIP()
        {
            Ip = ConvetNetConfig_fromBuff(Ip_b);
        }

        /// <summary>
        /// 将buff转到netmask
        /// </summary>
        public void ConvertNetmask()
        {
            Netmask = ConvetNetConfig_fromBuff(Netmask_b);
        }

        /// <summary>
        /// 将buff转到gateway
        /// </summary>
        public void ConvertGateWay()
        {
            Gateway = ConvetNetConfig_fromBuff(Gateway_b);
        }


        public void ConvetMac_fromBuff()
        {
            string mac_temp = string.Empty;
            for (int i = 0; i < 6; i++)
            {
                mac_temp += MacAddr_b[i].ToString("X2");
                if (i != 5)
                    mac_temp += ".";
            }
            MacAddr = mac_temp;
        }

        public void ConvertBuff_toMac()
        {
            string[] s = MacAddr.Split(':');
            if (s.Length == 6)
            {
                for (int i = 0; i < 6; i++)
                {
                    MacAddr_b[i] = Convert.ToByte(s[i], 16);
                }
            }
        }

        public WCHConfig(string mac, string ip)
        {
            MacAddr = mac;

            Ip = ip;

            MacAddr_b = new byte[6];
            ConvertBuff_toMac();
            Ip_b = new byte[4];
            Netmask_b = new byte[4];
            Gateway_b = new byte[4];
            Commu_buff = new byte[255];
            Need_Reload = true;
            Config_OK = false;

            Baudrate = 0;
        }

    }
}
