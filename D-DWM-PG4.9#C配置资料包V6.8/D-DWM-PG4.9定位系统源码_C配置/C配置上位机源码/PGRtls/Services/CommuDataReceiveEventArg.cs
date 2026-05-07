using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PGRtls.Services
{
    public class CommuDataReceiveEventArg : EventArgs
    {
        public byte[] Recv_buff { get; set; }
        public int Recv_len { get; set; }

        public CommuDataReceiveEventArg(byte[] recv_buff, int recv_len)
        {            
            Recv_len = recv_len;
            Recv_buff = new byte[recv_len];
            Array.Copy(recv_buff, Recv_buff, recv_len);
        }
    }
}
