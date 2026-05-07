using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PGRtls.Services
{
    /// <summary>
    /// 导航事件参数 传递id和接收数据
    /// </summary>
    public class MessageReceiveEventArg : EventArgs
    {
        public byte TagID { get; set; }
        public byte[] Receive_data { get; set; }

        public MessageReceiveEventArg(byte id, byte[] buff)
        {
            TagID = id;
            Receive_data = new byte[buff.Length];
            Array.Copy(buff, Receive_data, Receive_data.Length);
        }
    }
}
