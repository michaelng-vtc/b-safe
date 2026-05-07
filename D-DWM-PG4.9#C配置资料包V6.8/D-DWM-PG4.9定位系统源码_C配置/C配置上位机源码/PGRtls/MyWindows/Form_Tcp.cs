using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using PGRtls.Model;
using PGRtls.Tool;

namespace PGRtls.MyWindows
{
    public partial class Form_Tcp : Form
    {
        DataClient Client_instance;
        Notification user_notify = new Notification();
        UdpClient Udp_MJ_Client;
        UdpClient Udp_Wch_Client;
        WCHNetConHelper Wch_Helper = new WCHNetConHelper();
        //string Pc_ip = string.Empty;
        const string Udp_Send_str = "{\"Command\":\"config\"}";

        public Form_Tcp(DataClient client)
        {
            InitializeComponent();
            Client_instance = client;
            UDP_Init();
        }

        private void button_Tcp_Click(object sender, EventArgs e)
        {
            if (!Client_instance.IsConnect)
            {
                string ip_str = comboBox_ServerIp.Text;
                if (string.IsNullOrWhiteSpace(ip_str) && comboBox_ServerIp.SelectedIndex == -1)
                {
                    MessageBox.Show("请先搜索并选择IP！", "Warning", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    return;
                }
                
                string port_str = textBox_Port.Text;
                if (string.IsNullOrEmpty(ip_str) || string.IsNullOrEmpty(port_str))
                {
                    MessageBox.Show("请输入正确的ip和端口号！", "Warning", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    return;
                }
                if (Client_instance.Init(ip_str, int.Parse(port_str)))
                {
                    if (Client_instance.Connect2Server())
                    {
                        MessageBox.Show("连接成功！");
                        Callback2Main(true);
                    }
                    else
                    {
                        MessageBox.Show("连接失败！");
                    }
                }
            }                 
        }

        private void Callback2Main(bool Connected)
        {
            DialogResult = DialogResult.OK;
            Main_Form mainform = this.Owner as Main_Form;
            user_notify.IsTcpConnect = Connected;
            mainform.Tag = user_notify;
        }


        private void Form_Tcp_FormClosing(object sender, FormClosingEventArgs e)
        {
            if (Client_instance.IsConnect)
                Callback2Main(true);
            else
                Callback2Main(false);

            if (Udp_MJ_Client != null)
            {
                Udp_MJ_Client.Close();
                Udp_MJ_Client.Dispose();
            }

            if(Udp_Wch_Client != null)
            {
                Udp_Wch_Client.Close();
                Udp_Wch_Client.Dispose();
            }
        }

        private void button_Search_Click(object sender, EventArgs e)
        {
            try 
            {
                //POEV2.0前 采用鸣驹智能网络转串口 对应搜索
                IPEndPoint RemoteIep = new IPEndPoint(IPAddress.Broadcast, 5002);
                byte[] send_buff = Encoding.ASCII.GetBytes(Udp_Send_str);
                Udp_MJ_Client.Send(send_buff, send_buff.Length, RemoteIep);

                Thread.Sleep(250);

                //POEV3.0后 采用南京沁恒网络转串口 对应搜索
                RemoteIep.Port = 50000;
                send_buff = Wch_Helper.WCH_WriteSearchBuff();
                Udp_Wch_Client.Send(send_buff, send_buff.Length, RemoteIep);
            }
            catch(Exception ex)
            {
                MessageBox.Show(ex.Message);
                Udp_MJ_Client.Close();
                Udp_Wch_Client.Close();
            }
        }

        /// <summary>
        /// UDP参数初始化
        /// </summary>
        private void UDP_Init()
        {
            //Pc_ip = GetIp();
            //修改为本机任意ip作为监听
            IPEndPoint LocalIep = new IPEndPoint(IPAddress.Parse("0.0.0.0"), 5003);   //Pc_ip
            Udp_MJ_Client = new UdpClient(LocalIep);
            Udp_Wch_Client = new UdpClient(new IPEndPoint(IPAddress.Parse("0.0.0.0"), 60000));

            //打开接收
            Udp_MJ_RecvAsync();
            Udp_Wch_RecvAsync();
        }

        private async void Udp_MJ_RecvAsync()
        {
            try
            {
                UdpReceiveResult recv_result = await Udp_MJ_Client.ReceiveAsync();
                if (recv_result.Buffer.Length > 0)
                {
                    //简单处理判断
                    if (recv_result.Buffer[0] == '{' && recv_result.Buffer[recv_result.Buffer.Length - 1] == '}')
                    {
                        MethodInvoker mi = new MethodInvoker(() =>
                        {
                            string remoteip = recv_result.RemoteEndPoint.Address.ToString();
                            if (!comboBox_ServerIp.Items.Contains(remoteip))
                                comboBox_ServerIp.Items.Add(remoteip);
                            if (comboBox_ServerIp.SelectedIndex == -1)
                                comboBox_ServerIp.SelectedIndex = 0;
                        });
                        BeginInvoke(mi);
                    }
                    Udp_MJ_RecvAsync();  //重新打开接收
                }
            }
            catch
            {
                //可能已经断开
            }                       
        }

        private async void Udp_Wch_RecvAsync()
        {
            try
            {
                UdpReceiveResult recv_result = await Udp_Wch_Client.ReceiveAsync();
                if (recv_result.Buffer.Length > 0)
                {
                    if(Wch_Helper.WCH_CheckBuff(recv_result.Buffer,out string mac) == 1)
                    {
                        MethodInvoker mi = new MethodInvoker(() =>
                        {
                            string remoteip = recv_result.RemoteEndPoint.Address.ToString();
                            if (!comboBox_ServerIp.Items.Contains(remoteip))
                                comboBox_ServerIp.Items.Add(remoteip);
                            if (comboBox_ServerIp.SelectedIndex == -1)
                                comboBox_ServerIp.SelectedIndex = 0;
                        });
                        BeginInvoke(mi);
                    }
                    Udp_Wch_RecvAsync();  //重新打开接收
                }
            }
            catch
            {
                //可能已经断开
            }
        }

        private  List<string> ShowIP()
        {
            List<string> ipv4list = new List<string>();
            //ipv4地址也可能不止一个 
            foreach (string ip in GetLocalIpv4())
            {
                //Console.WriteLine(ip.ToString());
                ipv4list.Add(ip.ToString());
            }
            return ipv4list;
        }

        private string[] GetLocalIpv4()
        {
            //事先不知道ip的个数，数组长度未知，因此用StringCollection储存 
            IPAddress[] localIPs;
            localIPs = Dns.GetHostAddresses(Dns.GetHostName());
            StringCollection IpCollection = new StringCollection();
            foreach (IPAddress ip in localIPs)
            {
                //根据AddressFamily判断是否为ipv4,如果是InterNetWorkV6则为ipv6 
                if (ip.AddressFamily == AddressFamily.InterNetwork)
                    IpCollection.Add(ip.ToString());
            }
            string[] IpArray = new string[IpCollection.Count];
            IpCollection.CopyTo(IpArray, 0);
            return IpArray;
        }

        private string GetIp()
        {
            string ip = string.Empty;
            List<string> list = ShowIP();
            foreach (string str in list)
            {
                if (str.Contains("192.168."))
                {
                    ip = str;
                }
            }
            if (string.IsNullOrEmpty(ip) && list.Count > 0)  //不是C类局域网地址 可能是A或者B类
            {
                ip = list.First();
            }
            return ip;
        }

    }
}
