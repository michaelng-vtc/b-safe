using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace PGRtls.Model
{
    internal class IMU_Remote_commu
    {
        public UdpClient Commu_instance { get; set; }
        //private JsonWriterOptions json_writer_option = new JsonWriterOptions()
        //{
        //    Indented = true
        //};
        private IPEndPoint RemoteEndpoint = new IPEndPoint(IPAddress.Loopback, 8888);

        public bool Is_start_send { get; set; } = false;

        public IMU_Remote_commu()
        {
            

        }

        public void Start()
        {
            if (Is_start_send)
            {
                return;
            }
            Commu_instance = new UdpClient(0);  //只发送不接收 所以打开任意一个空闲端口
            Is_start_send = true;
        }

        public void Stop()
        {
            if(Commu_instance != null)
            {
                Commu_instance.Close();
                Commu_instance.Dispose();
            }
            Is_start_send = false;
        }



        public void Send2Unity(double eular_x, double eular_y, double eular_z)
        {
            byte[] send_buff = new byte[9];
            send_buff[0] = 0xEC;
            send_buff[1] = 0x08;
            send_buff[2] = 0xAC;
            send_buff[3] = (byte)((short)eular_x >> 8);
            send_buff[4] = (byte)((short)eular_x & 0x00FF);
            send_buff[5] = (byte)((short)eular_y >> 8);
            send_buff[6] = (byte)((short)eular_y & 0x00FF);
            send_buff[7] = (byte)((short)eular_z >> 8);
            send_buff[8] = (byte)((short)eular_z & 0x00FF);
            Commu_instance.Send(send_buff, send_buff.Length, RemoteEndpoint);

        }

    }
}
