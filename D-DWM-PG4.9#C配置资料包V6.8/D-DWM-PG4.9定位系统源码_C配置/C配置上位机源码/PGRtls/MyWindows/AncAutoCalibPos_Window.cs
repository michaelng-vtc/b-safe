using PGRtls.ModbusHelper;
using PGRtls.Model;
using PGRtls.Rtls;
using PGRtls.Services;
using PGRtls.Tool;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace PGRtls.MyWindows
{
    public partial class AncAutoCalibPos_Window : Form
    {
        Action<byte[]> Senddata_Action = null;  //发送数据动作 由主界面注入
        BindingList<Anchor> Anchor_calib_list = new BindingList<Anchor>();
        BindingList<Anchor> Before_Anchor_list = new BindingList<Anchor>();
        Action<string> Show_txt_action = null;
        List<Anc_calib_dist> Calib_twr_list = new List<Anc_calib_dist>();
        List<Calib_anc> Calib_anc_list = new List<Calib_anc>();
        GDI_DrawHelper Draw_Helper = new GDI_DrawHelper();

        bool Has_AskDist_reply = false;
        bool Is_AutoCalib_working = false;
        bool Has_Reply_result = false;
        int AutoCalib_Flag = 0;

        int Now_Calib_time = 1;
        int Now_Calib_idx = 0;
        Dictionary<string, byte> Anc_id_dictionary = new Dictionary<string, byte>()
        {
            ["A基站"] = 0xFF,
            ["B基站"] = 0xF0,
            ["C基站"] = 0xF1,
            ["D基站"] = 0xF2,
            ["E基站"] = 0xF3,
            ["F基站"] = 0xF4,
            ["G基站"] = 0xF5,
            ["H基站"] = 0xF6,
            ["I基站"] = 0xF7,
            ["J基站"] = 0xF8,
            ["K基站"] = 0xF9,
            ["L基站"] = 0xFA,
            ["M基站"] = 0xFB,
            ["N基站"] = 0xFC,
            ["O基站"] = 0xFD,
            ["P基站"] = 0xFE,
        };

        enum Cal_orientation_t
        {
            Not_set = -1,
            Clockwise,
            CounterClockwise
        }

        enum Cal_axis_t
        {
            Not_set = -1,
            Axis_x_positive,
            Axis_x_nagative,
            Axis_y_positive,
            Axis_y_nagative,
        }

        string Cal_Origin_anc_id = string.Empty;
        string Cal_Mark_anc_id = string.Empty;
        Cal_orientation_t Cal_orient = Cal_orientation_t.Not_set;
        Cal_axis_t Cal_axis = Cal_axis_t.Not_set;


        public AncAutoCalibPos_Window()
        {
            InitializeComponent();
        }

        public AncAutoCalibPos_Window(BindingList<Anchor> anchorlist, Action<byte[]> main_send_action )
        {
            InitializeComponent();
            if(main_send_action != null)
            {
                Senddata_Action = main_send_action;
            }
            
            Show_txt_action = Show_log_txt;

            Before_Anchor_list = anchorlist;
            Anchor_calib_list.Clear();
            foreach (Anchor anc in anchorlist)
            {
                Anchor_calib_list.Add(new Anchor()
                {
                    Id = anc.Id,
                    IsUse = anc.IsUse,
                    x = anc.x,
                    y = anc.y
                });
            }

            DataGrid_Init();
        }

        private void DataGrid_Init()
        {
            /* 基站列表数据绑定 */
            //dataGridView_BS_SET.DataBindings.Add()
            DataGridView_Anc.AutoGenerateColumns = false;
            Column_select.DataPropertyName = "IsUse";
            Column_ID.DataPropertyName = "Id";
            Column_X.DataPropertyName = "x";
            Column_y.DataPropertyName = "y";
            DataGridView_Anc.DataSource = Anchor_calib_list;
        }

        private void Show_log_txt(string s)
        {
            Tb_log.Text += $"{DateTime.Now:yyyy/MM/dd HH:mm:ss fff}: {s}\r\n";
        }

        private void Add_log_txt(string s)
        {
            Tb_log?.BeginInvoke(Show_txt_action, s);           
        }


        public void Commu_send_data(byte[] data )
        {
            Senddata_Action?.Invoke(data);
        }

        /// <summary>
        /// 获取自动标定相关数据处理 之前已经判断了modbus的crc部分 这里不用再判断了
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        public void Data_Recv_Handler(object sender, CommuDataReceiveEventArg e)
        {
            byte[] recv_buff = e.Recv_buff;
            int len = e.Recv_len;
            if(recv_buff == null)
            {
                return;
            }
            if(len == 8 && recv_buff[1] == 0x10)  //收到指令发起测距的回应
            {
                Has_AskDist_reply = true;
                ModbusRTU.Instance.Modbus_com.FunctionCode = 0x03;  //立刻更改当前读取的modbus功能码 否则无法成功接收后面的测距结果
            }
            else if (recv_buff[1] == 0x03)  //收到回应测距结果
            {
                Has_Reply_result = true;
                Anc_calib_dist now_pair = Calib_twr_list[Now_Calib_idx];
                now_pair.Twr_success = recv_buff[6] == 1;
                if (now_pair.Twr_success)
                {
                    now_pair.Dist = recv_buff[9] << 8 | recv_buff[10];
                }
                else
                {
                    now_pair.Dist = -1;
                }
            }
        }

        private void AncAutoCalibPos_Window_Load(object sender, EventArgs e)
        {
            Combo_OriginAnc.Items.Clear();
            foreach(Anchor anc in Anchor_calib_list)
            {
                if (anc.IsUse)
                {
                    Combo_OriginAnc.Items.Add(anc);
                }                
            }
            Combo_OriginAnc.DisplayMember = "Id";
            Combo_MarkAnc.Items.Clear();

            //画图初始化
            Draw_Helper = new GDI_DrawHelper();

            Draw_Helper.Draw_config_Init(PictureBox_draw.Width, PictureBox_draw.Height);
            Draw_Helper.Draw_Clear();

            //显示在pictureBox1控件中
            this.PictureBox_draw.Image = Draw_Helper.Get_Bitmap();

        }

        private void Btn_Reset_Click(object sender, EventArgs e)
        {
            Anchor_calib_list.Clear();
            foreach (Anchor anc in Before_Anchor_list)
            {
                Anchor_calib_list.Add(new Anchor()
                {
                    Id = anc.Id,
                    IsUse = anc.IsUse,
                    x = anc.x,
                    y = anc.y
                });
            }
        }

        private void Btn_Start_Click(object sender, EventArgs e)
        {
            Is_AutoCalib_working = false;
            /* 1. 根据基站列表中的选择生成要自动标定的基站列表 */
            List<string> anc_cal_id_list = Anchor_calib_list.Where(a => a.IsUse == true).Select(a => a.Id).ToList();
            Calib_anc_list.Clear();
            
            if (string.IsNullOrWhiteSpace(Cal_Origin_anc_id) || string.IsNullOrWhiteSpace(Cal_Mark_anc_id)
                || Cal_orient == Cal_orientation_t.Not_set || Cal_axis == Cal_axis_t.Not_set)
            {
                MessageBox.Show("未选择正确计算参数，无法自动标定!");
                return;
            }

            /* 2. 根据要标定的基站生成总体要测距的数量和顺序 */
            int anc_count = anc_cal_id_list.Count;
            if(anc_count < 2)
            {
                MessageBox.Show("基站选择数量太少，无法自动标定!");
                return;
            }
            int dist_total = anc_count * (anc_count - 1) / 2;
            Calib_twr_list.Clear();
            int i = 0, j = 0;
            for (i = 0; i < anc_count - 1; i++)
            {
                Calib_anc_list.Add(new Calib_anc()
                {
                    Id = anc_cal_id_list[i]
                });
                for (j = i + 1; j < anc_count; j++)
                {
                    Calib_twr_list.Add(new Anc_calib_dist()
                    {
                        Initial_id = anc_cal_id_list[i],
                        Passive_id = anc_cal_id_list[j],
                        Dist = -1,
                        Twr_success = false
                    });
                }
            }
            //再加上最后一个
            Calib_anc_list.Add(new Calib_anc()
            {
                Id = anc_cal_id_list[anc_count - 1]
            });

            if (dist_total != Calib_twr_list.Count)
            {
                MessageBox.Show("基站组合有问题！");
                return;
            }

            /* 3. 启动后台线程开始不断指令基站相互测距并计算基站坐标 */
            Btn_Start.Enabled = false;
            Is_AutoCalib_working = true;
            Draw_timer.Enabled = true;
            AutoCalib_Flag = 0;
            Now_Calib_time = 1;
            foreach(Anchor anc in Anchor_calib_list)
            {
                anc.x = 0;
                anc.y = 0;
                anc.z = 0;
            }
            Thread calib_thread = new Thread(Calib_twr_Task);
            calib_thread.IsBackground = true;
            calib_thread.Start();
            Add_log_txt("/-------- 开始自动标定 --------/");
        }


        private void Calib_twr_Task()
        {
            Anc_calib_dist now_pair = new Anc_calib_dist();
            while (Is_AutoCalib_working)
            {
                if(AutoCalib_Flag == 0)
                {              
                    AutoCalib_Flag = 1;
                    Now_Calib_idx = 0;
                    Add_log_txt($"**** 第{Now_Calib_time}次自动标定 ****");
                }

                if(AutoCalib_Flag == 1)
                {
                    now_pair = Calib_twr_list[Now_Calib_idx];
                    ModbusRTU.Instance.Modbus_com.FunctionCode = 0x10;
                    ModbusRTU.Instance.Modbus_com.Addr = ModbusRTU.Addr_AutoCalibPairConfig;
                    ModbusRTU.Instance.Modbus_com.RegNum = 1;
                    byte[] send_data = new byte[2];
                    send_data[0] = Anc_id_dictionary[now_pair.Initial_id];
                    send_data[1] = Anc_id_dictionary[now_pair.Passive_id];
                    byte[] send_buff = ModbusRTU.Instance.Modbus10Send(send_data);
                    if(send_buff == null)
                    {
                        Add_log_txt($"Error!:{now_pair.Initial_id} : {now_pair.Passive_id}");
                        AutoCalib_Flag = 4;
                    }
                    now_pair.Error_timeout = 0;
                    Senddata_Action?.Invoke(send_buff);
                    Has_AskDist_reply = false;
                    Has_Reply_result = false;
                    AutoCalib_Flag = 2;
                }

                if (AutoCalib_Flag == 2)  //等待命令指令回复
                {
                    if (!Has_AskDist_reply && now_pair.Error_timeout++ < 10)
                    {
                        Thread.Sleep(100);

                    }
                    else if(Has_AskDist_reply)
                    {
                        
                        now_pair.Error_timeout = 0;
                        AutoCalib_Flag = 3;
                    }
                    else  //超时没有回应 目前处理只是跳过
                    {
                        Add_log_txt($"reply timeout!:{now_pair.Initial_id} : {now_pair.Passive_id}");
                        AutoCalib_Flag = 4;
                    }
                }

                if (AutoCalib_Flag == 3)  //等待结果回传
                {
                    if (!Has_Reply_result && now_pair.Error_timeout++ < 10)
                    {
                        Thread.Sleep(100);

                    }
                    else if (Has_Reply_result)
                    {
                        now_pair.Error_timeout = 0;
                        Add_log_txt($"Result:{now_pair.Initial_id} -> {now_pair.Passive_id}: ok:{(now_pair.Twr_success ? "yes" : "no")} dist: {now_pair.Dist}");
                        AutoCalib_Flag = 4;
                    }
                    else  //超时没有回应 目前处理只是跳过
                    {
                        Add_log_txt($"result timeout!:{now_pair.Initial_id} : {now_pair.Passive_id}");
                        AutoCalib_Flag = 4;
                    }
                }

                if (AutoCalib_Flag == 4)  //获取结果完成 定位计算或者重新指令测距
                {
                    
                    if (Now_Calib_idx < Calib_twr_list.Count - 1)
                    {
                        Now_Calib_idx++;
                        AutoCalib_Flag = 1;
                    }
                    else
                    {
                        //做完一轮了
                        Add_log_txt($"**** 第{Now_Calib_time++}次自动标定完成 ****");
                        Now_Calib_idx = 0;
                        //计算坐标
                        Auto_Calib_CalPos();
                        AutoCalib_Flag = 0;
                        Thread.Sleep(200);
                    }
                }

            }
        }

        private void Tb_log_TextChanged(object sender, EventArgs e)
        {
            if(Tb_log.Text.Length > 10000)
            {
                Tb_log.Text = string.Empty;
            }
            Tb_log.SelectionStart = Tb_log.Text.Length;
            Tb_log.ScrollToCaret();
        }

        private void Btn_Stop_Click(object sender, EventArgs e)
        {
            Is_AutoCalib_working = false;
            Draw_timer.Enabled = false;
            Btn_Start.Enabled = true;
            Add_log_txt("/-------- 结束自动标定 --------/");
        }

        private void Btn_Comfirm_Click(object sender, EventArgs e)
        {
            //确定更改后 位置为整数
            foreach (Anchor anc in Before_Anchor_list)
            {
                if(Try_GetAnc(anc.Id,out Anchor anc_calib))
                {
                    anc.x = (int)anc_calib.x;
                    anc.y = (int)anc_calib.y;
                    anc.IsUse = anc_calib.IsUse;
                }
            }
        }

        private void Combo_OriginAnc_DropDown(object sender, EventArgs e)
        {
            Combo_OriginAnc.Items.Clear();
            foreach (Anchor anc in Anchor_calib_list)
            {
                if (anc.IsUse)
                {
                    Combo_OriginAnc.Items.Add(anc);
                }
            }
            Combo_OriginAnc.DisplayMember = "Id";
        }

        private void Combo_MarkAnc_DropDown(object sender, EventArgs e)
        {
            Combo_MarkAnc.Items.Clear();
            foreach (Anchor anc in Anchor_calib_list)
            {
                if (anc.IsUse && !string.IsNullOrWhiteSpace(Cal_Origin_anc_id) && anc.Id != Cal_Origin_anc_id)
                {
                    Combo_MarkAnc.Items.Add(anc);
                }
            }
            Combo_MarkAnc.DisplayMember = "Id";
        }

        private void Combo_OriginAnc_SelectedIndexChanged(object sender, EventArgs e)
        {
            Anchor selected_anc =  Combo_OriginAnc.SelectedItem as Anchor;
            Cal_Origin_anc_id = selected_anc.Id;
            Combo_MarkAnc.Items.Clear();
            Combo_MarkAnc.SelectedIndex = -1;
            foreach (Anchor anc in Anchor_calib_list)
            {
                if (anc.IsUse && anc != selected_anc)
                {
                    Combo_MarkAnc.Items.Add(anc);
                }
            }
            Combo_MarkAnc.DisplayMember = "Id";
        }

        private void Combo_MarkAnc_SelectedIndexChanged(object sender, EventArgs e)
        {
            if(Combo_MarkAnc.SelectedIndex != -1)
            {
                Cal_Mark_anc_id = (Combo_MarkAnc.SelectedItem as Anchor)?.Id;
            }
            else
            {
                Cal_Mark_anc_id = string.Empty;
            }
            
        }

        private void Combo_ScaleOption_SelectedIndexChanged(object sender, EventArgs e)
        {
            Cal_orient = (Cal_orientation_t)Combo_ScaleOption.SelectedIndex;
        }

        private void Combo_MarkAxis_SelectedIndexChanged(object sender, EventArgs e)
        {
            Cal_axis = (Cal_axis_t)Combo_MarkAxis.SelectedIndex;
        }

        private void Auto_Calib_CalPos()
        {
            //先清空上次的结果
            foreach(Calib_anc anc in Calib_anc_list)
            {
                anc.First_ok = false;
                anc.Second_ok = false;
                anc.Final_ok = false;
            }
            /* 1. 根据两个选定基站和选项第一次计算其他基站坐标 */
            Calib_anc origin_anc = Calib_anc_list.Find(a => a.Id == Cal_Origin_anc_id);
            Calib_anc mark_anc = Calib_anc_list.Find(a => a.Id == Cal_Mark_anc_id);
            if(string.IsNullOrWhiteSpace(origin_anc.Id) || string.IsNullOrWhiteSpace(mark_anc.Id))
            {
                Add_log_txt("计算位置出错:原点或辅助基站出错!");
                return;
            }
            //先算出辅助基站坐标
            if(TryGet_calanc_dist(origin_anc.Id,mark_anc.Id,out double origin_mark_dist))
            {
                //根据所在坐标系写入坐标
                switch (Cal_axis)
                {
                    case Cal_axis_t.Axis_x_positive:
                        {
                            mark_anc.First_x = origin_mark_dist;
                            mark_anc.First_y = 0;
                            break;
                        }
                    case Cal_axis_t.Axis_x_nagative:
                        {
                            mark_anc.First_x = -origin_mark_dist;
                            mark_anc.First_y = 0;
                            break;
                        }
                    case Cal_axis_t.Axis_y_positive:
                        {
                            mark_anc.First_x = 0;
                            mark_anc.First_y = origin_mark_dist;
                            break;
                        }
                    case Cal_axis_t.Axis_y_nagative:
                        {
                            mark_anc.First_x = 0;
                            mark_anc.First_y = -origin_mark_dist;
                            break;
                        }
                    default:break;
                }
                mark_anc.First_ok = true;
            }
            else
            {
                Add_log_txt("计算位置出错:无法计算出辅助基站位置，后续无法计算!");
                return;
            }
            origin_anc.First_x = 0;
            origin_anc.First_y = 0;
            origin_anc.First_ok = true;
            //开始后续计算
            foreach (Calib_anc cal_anc in Calib_anc_list)
            {
                if(cal_anc == origin_anc || cal_anc == mark_anc)
                {
                    continue;
                }
                if(!TryGet_calanc_dist(origin_anc.Id, cal_anc.Id, out double origin_dist))
                {
                    cal_anc.First_ok = false;
                    continue;
                }
                if (!TryGet_calanc_dist(mark_anc.Id, cal_anc.Id, out double mark_dist))
                {
                    cal_anc.First_ok = false;
                    continue;
                }
                //可以获取两个基站距离 计算坐标
                double[] cal_result = RtlsHelp.Rtls_CalIntersection(origin_anc.First_x, origin_anc.First_y, origin_dist,
                                                                    mark_anc.First_x, mark_anc.First_y, mark_dist, (int)Cal_orient);
                if(cal_result == null)
                {
                    //计算失败
                    cal_anc.First_ok = false;
                }
                else
                {
                    if( !double.IsNaN(cal_result[0]) &&  !double.IsNaN(cal_result[1]))
                    {
                        cal_anc.First_ok = true;
                        cal_anc.First_x = cal_result[0];
                        cal_anc.First_y = cal_result[1];
                    }
                    else
                    {
                        cal_anc.First_ok = false;
                    }
                }
            }
            /* 2. 通过基站坐标再次进行计算第二次坐标 */
            List<Calib_anc> Second_calib_list = new List<Calib_anc>(Calib_anc_list.Count - 1);
            double[] second_result = new double[2];
            double[] final_xy = new double[2];
            foreach (Calib_anc cal_anc in Calib_anc_list)
            {             
                if (cal_anc == origin_anc)
                {
                    if (!Try_GetAnc(cal_anc.Id, out Anchor bind_origin_anc))  //应该不会找不到
                    {
                        continue;
                    }
                    bind_origin_anc.x = 0;
                    bind_origin_anc.y = 0;
                    continue;
                }
                Second_calib_list.Clear();

                //找其他基站对这个基站的距离
                for (int i = 0; i < Calib_anc_list.Count; i++)
                {
                    Calib_anc now_anc = Calib_anc_list[i];
                    if(now_anc == cal_anc)
                    {
                        continue;
                    }
                    if (!now_anc.First_ok)
                    {
                        continue;
                    }
                    if(!TryGet_calanc_dist(now_anc.Id,cal_anc.Id,out double dist))
                    {
                        continue;
                    }
                    now_anc.Dist_Now = (uint)dist;
                    Second_calib_list.Add(now_anc);
                }

                if(Second_calib_list.Count >= 3)
                {
                    if (RtlsHelp.Rtls_Cal_Pos2D_LeastSquare(Second_calib_list, out second_result))
                    {
                        if (!double.IsNaN(second_result[0]) && !double.IsNaN(second_result[1]))
                        {
                            cal_anc.Second_ok = true;
                            cal_anc.Second_x = second_result[0];
                            cal_anc.Second_y = second_result[1];
                        }
                        else
                        {
                            cal_anc.Second_ok = false;
                        }
                    }
                    else
                    {
                        cal_anc.Second_ok = false;
                    }
                }
                else
                {
                    cal_anc.Second_ok = false;
                }

                /* 3. 两次坐标取平均（目前 可考虑更好的处理） */

                if(cal_anc.First_ok && cal_anc.Second_ok)
                {
                    final_xy[0] = (cal_anc.First_x + cal_anc.Second_x) / 2;
                    final_xy[1] = (cal_anc.First_y + cal_anc.Second_y) / 2;
                }
                else if (cal_anc.First_ok)
                {
                    final_xy[0] = cal_anc.First_x;
                    final_xy[1] = cal_anc.First_y;
                }
                else if (cal_anc.Second_ok)
                {
                    final_xy[0] = cal_anc.Second_x;
                    final_xy[1] = cal_anc.Second_y;
                }
                else
                {
                    final_xy[0] = 0;
                    final_xy[1] = 0;
                }
                cal_anc.Final_ok = cal_anc.First_ok | cal_anc.Second_ok;

                if (!Try_GetAnc(cal_anc.Id, out Anchor bind_anc))  //应该不会找不到
                {
                    continue;
                }

                double alpha = 0.5;
                //与上一次的结果做低通滤波
                if (cal_anc.Final_ok)
                {
                    bind_anc.x = bind_anc.x * alpha + final_xy[0] * (1 - alpha);
                    bind_anc.y = bind_anc.y * alpha + final_xy[1] * (1 - alpha);
                }
            }

        }

        private bool TryGet_calanc_dist(string anc1, string anc2, out double dist)
        {
            dist = -1;
            foreach(Anc_calib_dist ret in  Calib_twr_list)
            {
                if(ret.Initial_id == anc1 && ret.Passive_id == anc2
                    ||
                   ret.Initial_id == anc2 && ret.Passive_id == anc1)
                {
                    if (ret.Twr_success)
                    {
                        dist = ret.Dist;
                        return true;
                    }
                    else
                    {
                        return false;
                    }
                }
            }
            return false;
        }

        private bool Try_GetAnc(string id, out Anchor anc)
        {
            for (int i = 0; i < Anchor_calib_list.Count; i++)
            {
                if (Anchor_calib_list[i].Id == id)
                {
                    anc = Anchor_calib_list[i];
                    return true;
                }
            }
            anc = new Anchor();
            return false;
        }

        private void Draw_timer_Tick(object sender, EventArgs e)
        {
            //画图
            if (Is_AutoCalib_working)
            {
                Draw_Helper.Draw_Clear();

                //画坐标轴 
                Draw_Helper.Draw_Axis();

                //画基站
                for (int i = 0; i < Anchor_calib_list.Count; i++)  //画基站
                {
                    Anchor a = Anchor_calib_list[i];
                    if (a.IsUse)
                    {
                        Draw_Helper.Draw_Anchor((int)a.x, (int)a.y, (char)(0x41 + i) + "基站", 40);
                    }
                }
                PictureBox_draw.Image = Draw_Helper.Get_Bitmap();
            }
        }

        private void PictureBox_draw_MouseMove(object sender, MouseEventArgs e)
        {
            if (MouseButtons.Left == e.Button)//按下左键
            {
                Draw_Helper.Mouse_MoveHandler(e.X, e.Y);
            }
            Draw_Helper.Mouse_LastPoint[0] = e.X;
            Draw_Helper.Mouse_LastPoint[1] = e.Y;
        }

        public void PictureBox_draw_MouseWheel(object sender, MouseEventArgs e)
        {
            if (e.Delta > 0)
            {
                if (Draw_Helper.Axis_multiple <= 0.01)
                    Draw_Helper.Axis_multiple = (float)0.01;
                else
                    Draw_Helper.Axis_multiple -= (float)0.01;
            }
            else
            {
                if (Draw_Helper.Axis_multiple >= 100)
                    Draw_Helper.Axis_multiple += (float)0.01;
                else
                    Draw_Helper.Axis_multiple += (float)0.01;
            }
        }

        private void AncAutoCalibPos_Window_FormClosing(object sender, FormClosingEventArgs e)
        {
            Is_AutoCalib_working = false;
            Draw_timer.Enabled = false;
            this.DialogResult = DialogResult.OK;
        }
    }
}
