using NPOI.SS.Formula.Functions;
using OxyPlot;
using PGRtls.Model;
using PGRtls.Services;
using PGRtls.Tool;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Diagnostics;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace PGRtls.MyWindows
{
    public partial class TagHistoryWindow : Form
    {

        GDI_DrawHelper Draw_Helper = new GDI_DrawHelper();
        DataTable History_datatable = new DataTable();
        List<Anchor> Uwb_anc_List = new List<Anchor>(16);
        bool Is_replaying = false;
        public int Now_replay_idx { get; set; }
        public int Now_replay_count { get; set; }
        int Tag_size = 8;
        bool Can_show = false;
        bool Is_Draw_refresh = false;
        //DataTable_Trace1 = new DataTable();
        //DataTable_Trace1.Columns.Add("Time", typeof(string));
        //    DataTable_Trace1.Columns.Add("x", typeof(string));
        //    DataTable_Trace1.Columns.Add("y", typeof(string));
        //    DataTable_Trace1.Columns.Add("z", typeof(string));
        //    DataTable_Trace1.Columns.Add("A", typeof(string));
        //    DataTable_Trace1.Columns.Add("B", typeof(string));
        //    DataTable_Trace1.Columns.Add("C", typeof(string));
        //    DataTable_Trace1.Columns.Add("D", typeof(string));
        //    DataTable_Trace1.Columns.Add("E", typeof(string));
        //    DataTable_Trace1.Columns.Add("F", typeof(string));
        //    DataTable_Trace1.Columns.Add("G", typeof(string));
        //    DataTable_Trace1.Columns.Add("H", typeof(string));
        //    DataTable_Trace1.Columns.Add("I", typeof(string));
        //    DataTable_Trace1.Columns.Add("J", typeof(string));
        //    DataTable_Trace1.Columns.Add("K", typeof(string));
        //    DataTable_Trace1.Columns.Add("L", typeof(string));
        //    DataTable_Trace1.Columns.Add("M", typeof(string));
        //    DataTable_Trace1.Columns.Add("N", typeof(string));
        //    DataTable_Trace1.Columns.Add("O", typeof(string));
        //    DataTable_Trace1.Columns.Add("P", typeof(string));
        //    DataTable_Trace1.Columns.Add("Flag", typeof(string));
        //    DataTable_Trace1.Columns.Add("Velocity", typeof(string));

        public TagHistoryWindow(DataTable dt, GDI_DrawHelper now_draw_cfg, List<Anchor> anc_list)
        {
            InitializeComponent();


            //假数据测试
            //for (int i = 0; i < 50; i++)
            //{
            //    DataRow r = dt.NewRow();
            //    r["x"] = 10 * i;
            //    r["y"] = 10 * i;
            //    r["Time"] = DateTime.Now.ToString();
            //    History_datatable.Rows.Add(r.ItemArray);
            //    Thread.Sleep(50);
            //}
            Can_show = TagHistory_dt_Init(dt);
            TagHistory_replay_Init();

            Draw_Helper = new GDI_DrawHelper();
            
            Draw_Helper.Axis_multiple = now_draw_cfg.Axis_multiple;
            Draw_Helper.Axis_origin_x = now_draw_cfg.Axis_origin_x;
            Draw_Helper.Axis_origin_y = now_draw_cfg.Axis_origin_y;
            Draw_Helper.Has_trace = true;
            if (now_draw_cfg.Has_Map)
            {              
                Draw_Helper.Set_Map_Config(now_draw_cfg.Map_width, now_draw_cfg.Map_height, now_draw_cfg.Map_origin_x, now_draw_cfg.Map_origin_y);
                Draw_Helper.Set_Map_Img(now_draw_cfg.Get_Map_path());
            }

            Uwb_anc_List = new List<Anchor>(16);
            foreach (Anchor anc in anc_list)
            {
                Uwb_anc_List.Add(new Anchor()
                {
                    Id = anc.Id,
                    IsUse = anc.IsUse,
                    x = anc.x,
                    y = anc.y
                });
            }
        }

        private bool TagHistory_dt_Init(DataTable dt)
        {
            History_datatable = dt.Clone();
            for (int i = 0; i < dt.Rows.Count; i++)
            {
                //如果没有数值则不加入
                if (dt.Rows[i]["Time"].ToString() == "0")
                {
                    continue;
                }
                History_datatable.ImportRow(dt.Rows[i]);
            }

            if(History_datatable.Rows.Count == 0)
            {
                MessageBox.Show("当前通道没有轨迹数据!将关闭该页面!");
                return false;
            }

            //根据时间重新排列数据
            History_datatable.DefaultView.Sort = "Time";
            History_datatable = History_datatable.DefaultView.ToTable();
            return true;
        }

        private void TagHistory_replay_Init()
        {
            Now_replay_count = History_datatable.Rows.Count;    
            if(Now_replay_count == 0)
            {
                return;
            }
            Now_replay_idx = 0;
            Text_time_now.Text = History_datatable.Rows[0]["Time"].ToString();
            Text_time_total.Text = History_datatable.Rows[Now_replay_count - 1]["Time"].ToString();
            Is_replaying = false;
            //Draw_timer.Enabled = false;
            custom_trackbar1.C_Maximum = Now_replay_count - 1;
            custom_trackbar1.C_Value = Now_replay_idx;
        }

        private void TagHistory_display_change()
        {
            custom_trackbar1.C_Value = Now_replay_idx;
            Text_time_now.Text = History_datatable.Rows[Now_replay_idx]["Time"].ToString();
        }


        private void TagHistoryWindow_Load(object sender, EventArgs e)
        {
            if (!Can_show)
            {
                this.Close();
            }
            Draw_Helper.Draw_config_Init(PictureBox_draw.Width, PictureBox_draw.Height);
            Draw_Helper.Draw_Clear();
            //显示在pictureBox1控件中
            this.PictureBox_draw.Image = Draw_Helper.Get_Bitmap();
            Draw_timer.Enabled = true;
        }

        private bool Check_bit(uint data, int bit)
        {
            return ((data >> bit) & 0x01) == 0x01;
        }


        private void Draw_timer_Tick(object sender, EventArgs e)
        {
            if (Is_Draw_refresh)
            {
                TagHistory_replay_Init();
                Draw_Helper.Draw_Clear();
                Is_Draw_refresh = false;
                Is_replaying = false;
                PictureBox_draw.Image = Draw_Helper.Get_Bitmap();
                return;
            }

            if (!Is_replaying)
            {
                return;
            }


            //画图
            Draw_Helper.Draw_Clear();

            if(CheckBox_map.Checked && Draw_Helper.Has_Map)
            {
                Draw_Helper.Draw_Map();
            }

            if (checkBox_axis.Checked)
            {
                //画坐标轴 
                Draw_Helper.Draw_Axis();
            }

            if (checkBox_name.Checked)
            {
                //画基站
                for (int i = 0; i < Uwb_anc_List.Count; i++)  //画基站
                {
                    Anchor a = Uwb_anc_List[i];
                    if (a.IsUse)
                    {
                        Draw_Helper.Draw_Anchor((int)a.x, (int)a.y, (char)(0x41 + i) + "基站", 40);
                    }
                }
            }

            //画标签 由头到现在的点画一次就是轨迹
            DataRow dr = null;
            int x = 0, y = 0;
            for (int i = 0;i < Now_replay_idx; i++)
            {
                dr = History_datatable.Rows[i];
                x = int.Parse(dr["x"].ToString());
                y = int.Parse(dr["y"].ToString());
                Draw_Helper.Draw_Tag(Color.Blue, x, y, Tag_size, false);
            }

            TagHistory_display_change();
            Now_replay_idx++;
            if (Now_replay_idx < Now_replay_count)
            {
                dr = History_datatable.Rows[Now_replay_idx];
                TagHistory_display_change();
                Now_replay_idx++;

            }
            else
            {
                Is_replaying = false;
            }


            if (checkBox_taginfo.Checked == true) //画标签坐标
            {
                string show_str = $"({x}cm,{y}cm) {dr["Velocity"]} cm/s";
                Draw_Helper.Draw_Tag_tx(show_str, x, y);
            }

            if (checkBox_draw_distcircle.Checked == true)  //画标签测距圆
            {
                ushort dis_buff;
                uint flag = uint.Parse(dr["Flag"].ToString());
                for (int i = 0; i < Uwb_anc_List.Count; i++)
                {
                    if (!Uwb_anc_List[i].IsUse)
                        continue;
                    if(!Check_bit(flag, i))  //本次该基站测距失败
                    {
                        continue;
                    }
                    dis_buff = Convert.ToUInt16(dr[i + 4]);
                    Draw_Helper.Draw_DistCircle((int)Uwb_anc_List[i].x, (int)Uwb_anc_List[i].y, dis_buff);
                }
            }

            PictureBox_draw.Image = Draw_Helper.Get_Bitmap();
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

        private void numericUpDown_TagSize_ValueChanged(object sender, EventArgs e)
        {
            Tag_size = (int)numericUpDown_TagSize.Value;
        }

        private void Btn_start_Click(object sender, EventArgs e)
        {
            Is_replaying = true;
            //Draw_timer.Enabled = true;
            Text_status.Text = "回放中...";
        }

        private void Btn_pause_Click(object sender, EventArgs e)
        {
            Is_replaying = false;
            //Draw_timer.Enabled = false;
            Text_status.Text = "暂停...";
        }

        private void Btn_stop_Click(object sender, EventArgs e)
        {
            Is_replaying = false;
            Is_Draw_refresh = true;
            Text_status.Text = "空闲中...";


        }

        private void custom_trackbar1_CValueChanged(object sender, CustomControls.C_Trackbar_EventArgs e)
        {
            Now_replay_idx = (int)custom_trackbar1.C_Value;
           
        }
    }
}
