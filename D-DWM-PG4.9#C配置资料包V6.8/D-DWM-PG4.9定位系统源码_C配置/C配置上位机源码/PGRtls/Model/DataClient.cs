using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using PGRtls.Log;

namespace PGRtls.Model
{
    public class DataClient
    {
        public int TCP_port { get;private set; }
        public string TCP_ip { get; set; }
        public IPEndPoint Remote_Endpoint { get; private set; }
        public TcpClient Tcp_client { get; set; }
        public NetworkStream Net_stream { get; set; }
        public bool IsConnect { get; set; }
        public Thread Recv_Thread { get;private set; }
        private IAsyncResult AsyncTcpRead;
        public Action<byte[],int> Recv_Callback { get;private set; }
        public Action Disconnect_Callback { get; private set; }

        private byte[] Recv_Buff;
        public int Recv_Buff_MaxLen { get;private set; }
        public int Recv_Len { get; private set; }


        public DataClient(int max_len)
        {
            Recv_Buff_MaxLen = max_len;
            Recv_Buff = new byte[Recv_Buff_MaxLen];
            Recv_Len = 0;
            IsConnect = false;
        }

        /// <summary>
        /// Tcp Ip和端口号和接收处理初始化
        /// </summary>
        /// <param name="ip">要连接服务端IP</param>
        /// <param name="port">要连接服务端端口号</param>
        /// <returns>true则初始化成功</returns>
        public bool Init(string ip,int port)
        {
            if(string.IsNullOrEmpty(ip) || port <= 0 || IsConnect)
            {
                return false;
            }
            TCP_ip = ip;
            TCP_port = port;
            Remote_Endpoint = new IPEndPoint(IPAddress.Parse(TCP_ip), TCP_port);         
            return true;
        }

        /// <summary>
        /// 设置接收处理方法 在连接前要设置 否则连接后接收不到数据
        /// </summary>
        /// <param name="Recv_action">接收的方法</param>
        public void Set_RecvCallback(Action<byte[], int> Recv_action)
        {
            Recv_Callback = Recv_action;
        }

        /// <summary>
        /// 设置断开处理方法 检测到断开连接后会自动调用
        /// </summary>
        /// <param name="Dis_action"></param>
        public void Set_DisconnCallback(Action Dis_action)
        {
            Disconnect_Callback = Dis_action;
        }

        /// <summary>
        /// 连接到对应服务端
        /// </summary>
        /// <returns>true则代表连接成功</returns>
        public bool Connect2Server()
        {
            if (IsConnect)
                return false;
            Tcp_client = new TcpClient();
            if (Remote_Endpoint != null)
                Tcp_client.Connect(Remote_Endpoint);
            Thread.Sleep(250);
            if (Tcp_client != null && Tcp_client.Connected)  //连接成功
            {
                Net_stream = Tcp_client.GetStream();
                IsConnect = true;
                AsyncRead();  //打开接收
                Thread check_thread = new Thread(Check_Alive);
                check_thread.IsBackground = true;
                check_thread.Priority = ThreadPriority.Lowest;
                check_thread.Start();
                return true;
            }
            else
                return false;
        }

        /// <summary>
        /// 开启异步的读取
        /// </summary>
        public void AsyncRead()
        {
            try
            {
                Array.Clear(Recv_Buff, 0, Recv_Buff_MaxLen);
                AsyncTcpRead = Net_stream.BeginRead(Recv_Buff, 0, Recv_Buff_MaxLen, EndRecv, Tcp_client);
            }
            catch(Exception ex)
            {
                MessageBox.Show(ex.Message);
                //出错 认为断开
                DisConnect(false); 
            }
        }

        /// <summary>
        /// 接收到数据的处理
        /// </summary>
        /// <param name="asyncResult"></param>
        private void EndRecv(IAsyncResult asyncResult)
        {
            try
            {
                int len = Net_stream.EndRead(asyncResult);
                if(len > 0)
                {
                    Recv_Len = len;
                    //byte[] buff = new byte[Recv_Len];
                    //Array.Copy(Recv_Buff, 0, buff, 0, Recv_Len);
                    
                    if (Recv_Callback != null)
                    {                       
                        Recv_Callback.Invoke(Recv_Buff, Recv_Len);
                        
                    }
                    AsyncRead(); // 重新打开接收

                }
                else
                {
                    MessageBox.Show("接收数据长度0，tcp断开");
                    //认为断开
                    DisConnect(false);
                }
            }
            catch
            {
                //出错 认为断开
                DisConnect(false);
            }            
        }

        /// <summary>
        /// 同步发送
        /// </summary>
        /// <param name="send_buff"></param>
        public void Send(byte[] send_buff)
        {
            try
            {
                if (IsConnect)
                    Tcp_client.Client.Send(send_buff);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message);
                //出错 认为断开
                DisConnect(false);
            }
        }

        /// <summary>
        /// 同步发送
        /// </summary>
        /// <param name="send_buff">发送数据</param>
        /// <param name="len">发送长度</param>
        /// <param name="offset">发送偏移</param>
        public void Send(byte[] send_buff, int len, int offset)
        {
            try
            {
                if (IsConnect)
                    Tcp_client.Client.Send(send_buff, offset, len, SocketFlags.None);
            }
            catch(Exception ex)
            {
                MessageBox.Show(ex.Message);
                //出错 认为断开
                DisConnect(false);
            }
        }

        private void Check_Alive()
        {
            try
            {
                while (IsConnect)
                {
                    Thread.Sleep(1000);
                    Ping ping = new Ping();
                    PingReply pingReply = ping.Send(TCP_ip, 100);
                    if (pingReply.Status != IPStatus.Success)
                    {
                        DisConnect(true);
                    }                       
                }
            }
            catch
            {
                return;
            }
            
        }

        /// <summary>
        /// 断开连接 分为主动和被动断开
        /// </summary>
        /// <param name="Ispassive">true则被动断开</param>
        public void DisConnect(bool Ispassive)
        {
            if (!AsyncTcpRead.IsCompleted)
            {
                AsyncTcpRead.AsyncWaitHandle.Close();
            }

            if (Net_stream != null)
            {
                Net_stream.Close();
                Net_stream.Dispose();
            }
            
            if (Tcp_client != null)
            {
                Tcp_client.Close();
                Tcp_client.Dispose();
            }

            IsConnect = false;

            if (Ispassive && Disconnect_Callback != null)
                Disconnect_Callback.Invoke();

            //if (Disconnect_Callback != null)
            //    Disconnect_Callback.Invoke();
        }
    }
}
