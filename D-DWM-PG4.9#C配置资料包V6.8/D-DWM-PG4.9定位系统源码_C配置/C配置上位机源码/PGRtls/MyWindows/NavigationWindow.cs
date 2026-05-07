using PGRtls.Model;
using PGRtls.Services;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using PGRtls.ATHelper;
using System.Threading;
using System.Drawing.Drawing2D;
using NPOI.SS.Formula.Functions;
using System.Windows.Navigation;

namespace PGRtls.MyWindows
{

    public partial class NavigationWindow : Form
    {
        List<Tag> Tag_All_list;         //当前所有用于定位的标签列表
        BindingList<Tag> Tag_navi_list;   //导航标签列表 由于实现OnpropertyChanged 需要为BindingList
        Action<byte[]> Senddata_Action = null;  //发送数据动作 由主界面注入
        Action CloseNavi_Action = null;         //关闭导航窗口动作  由主界面注入
        private readonly string[] Navi_status_str = new string[3] { "静止", "点动", "自动导航" };
        
        private Tag Now_selected_tag = null;

        private bool Has_Respond = false;

        private enum Mouse_pos_flag
        {
            No_work = 0,
            Selecting,
            Cature_pos
        }
        Mouse_pos_flag Mouse_getpos_flag = Mouse_pos_flag.No_work;


        private const byte COMMU_MARKCODE = 0xCB;
        private const byte FUNC_SET_STATUS = 0xA0;
        private const byte FUNC_GET_STATUS = 0xA1;
        private const byte FUNC_SET_CARSPEED = 0xA2;
        private const byte FUNC_GET_CARSPEED = 0xA3;

        private const byte FUNC_MANNUAL_MOVE = 0xB0;
        private const byte FUNC_AUTO_MOVE = 0xC0;
        private const byte FUNC_UPLOAD_ANGLE = 0xD0;

        private const byte TAG_STATUS_IDLE = 0;
        private const byte TAG_STATUS_MANNUAL = 1;
        private const byte TAG_STATUS_AUTO = 2;

        bool HasGetMessage = false;
        ushort Mannual_moveduetime = 50;

        private delegate void Text_Showstring_delegate(string s);
        private Text_Showstring_delegate Showstring_Delegate;
        public EventHandler OnStartSelectPoint_EventHandler { get; set; }
        private enum Sys_text_state_t
        {
            Sys_work = 0,
            Sys_searching,
            Sys_ChangingMode,
            Sys_Get_speed,
            Sys_Set_speed,
            Sys_MannualMoving,
            Sys_AutoMoving
        }

        Sys_text_state_t Sys_state = Sys_text_state_t.Sys_work;

        public NavigationWindow(List<Tag> Tag_tempList, Action<byte[]> main_send_action, Action Close_Action)
        {
            InitializeComponent();
            
            Tag_All_list = Tag_tempList;  
            Tag_navi_list = new BindingList<Tag>();
            Showstring_Delegate = new Text_Showstring_delegate(Show_String);

            foreach (Tag t in Tag_All_list)
            {
                if (t.IsNavi)
                {
                    Tag_navi_list.Add(t);
                }
            }

            //由主界面传入的发送方法
            if (main_send_action != null)
            {
                Senddata_Action = main_send_action;
            }

            //由主界面传入的关闭导航窗口标志
            if(Close_Action != null)
            {
                CloseNavi_Action = Close_Action;
            }

            DataGrid_Init();

        }

        private void Show_String(string s)
        {
            Text_status.Text = s;
        }

        private void Text_Status_Change(string str)
        {
            Text_status?.BeginInvoke(Showstring_Delegate, str);
            Thread.Sleep(50);
        } 

        /// <summary>
        /// 更改系统状态指示
        /// </summary>
        private void Status_Change()
        {
            switch (Sys_state)
            {
                case Sys_text_state_t.Sys_work:
                    {
                        Text_Status_Change("系统运行中...");
                        break;
                    }
                case Sys_text_state_t.Sys_searching:
                    {
                        Text_Status_Change("搜索IP中...");
                        break;
                    }
                case Sys_text_state_t.Sys_ChangingMode:
                    {
                        Text_Status_Change("更改模式中...");
                        break;
                    }
                case Sys_text_state_t.Sys_Get_speed:
                    {
                        Text_Status_Change("获取速度中...");
                        break;
                    }
                case Sys_text_state_t.Sys_Set_speed:
                    {
                        Text_Status_Change("设置速度中...");
                        break;
                    }
                case Sys_text_state_t.Sys_AutoMoving:
                    {
                        Text_Status_Change("自动导航选取点中...");
                        break;
                    }
                default:break;
            }
        }

        private void DataGrid_Init()
        {
            DataGridView_Tag.AutoGenerateColumns = false;
            Column_ID.DataPropertyName = "Id";
            Column_x.DataPropertyName = "x";
            Column_y.DataPropertyName = "y";
            Column_z.DataPropertyName = "z";
            Column_status.DataPropertyName = "Navi_status_str";
            Column_angle.DataPropertyName = "Navi_angle";
            Column_magn.DataPropertyName = "Magn_tesla";
            DataGridView_Tag.DataSource = Tag_navi_list;
        }

        /// <summary>
        /// 从主界面中获取串口透传信息事件
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        internal void GetMessageFromMain(object sender, EventArgs e)
        {
            HasGetMessage = true;
            MessageReceiveEventArg arg = e as MessageReceiveEventArg;
            byte[] recv_buff = new byte[arg.Receive_data.Length];
            Array.Copy(arg.Receive_data, recv_buff, recv_buff.Length);
            //Task.Run(() => MessageReceive_Handler(arg.TagID, recv_buff));
            MessageReceive_Handler(arg.TagID, recv_buff);
        }

        internal void GetSelectPointFromMain(object sender, SelectPointEventArg e)
        {
            if (e.Capture_pos)
            {
                //获取目的坐标成功
                Change_tag_Automove((short)e.X, (short)e.Y);
                MethodInvoker mi = new MethodInvoker(() =>
                {
                    numericUpDown_dest_x.Value = (decimal)e.X;
                    numericUpDown_dest_y.Value = (decimal)e.Y;
                });
                Invoke(mi);
                Sys_state = Sys_text_state_t.Sys_work;
                Status_Change();
            }
            
        }

        /// <summary>
        /// 获取串口透传数据的处理
        /// </summary>
        /// <param name="id">透传标签id</param>
        /// <param name="buff">透传标签内容</param>
        private void MessageReceive_Handler(byte id, byte[] buff)
        {
            if (HasGetMessage)
            {
                HasGetMessage = false;
                //根据接收到数据解析
                //MessageBox.Show("ok");
                if (buff[0] != COMMU_MARKCODE)
                    return;
                switch (buff[1])
                {
                    case FUNC_GET_STATUS:  //获取当前小车状态
                        {
                            if (!Model.Tag.TryGetTag(Tag_navi_list, id, out Tag t)) 
                            {
                                //之前没添加过
                                if (Model.Tag.TryGetTag(Tag_All_list, id, out t))
                                {
                                    
                                    MethodInvoker mi = new MethodInvoker(() => 
                                    {                                      
                                        Tag_navi_list.Add(t);
                                        t.IsNavi = true;                                        
                                    });
                                    Invoke(mi);  //这里选择同步执行 否则会出现多个相同id添加到列表
                                    
                                }
                            }
                            t.Navi_status_idx = buff[2];
                            break;
                        }
                    case FUNC_GET_CARSPEED:  //设置车辆速度挡位
                        {                           
                            if (Now_selected_tag != null)
                            {
                                Now_selected_tag.Car_speed = buff[2];
                                Has_Respond = true;
                                MethodInvoker mi = new MethodInvoker(() =>
                                {
                                    comboBox_ChangeSpeed.Text = buff[2].ToString();
                                });
                                Invoke(mi);  //这里选择同步执行 否则会出现多个相同id添加到列表
                            }
                            break;
                        }
                    case FUNC_SET_STATUS:    //设置小车状态
                    case FUNC_SET_CARSPEED:  //设置小车速度挡位
                    case FUNC_MANNUAL_MOVE:  //点动模式指令响应
                    case FUNC_AUTO_MOVE:     //自动模式指令响应
                        {
                            Has_Respond = true;
                            break;
                        }
                    case FUNC_UPLOAD_ANGLE:  //小车主动上传角度和磁场信息
                        {
                            if(Now_selected_tag != null)
                            {                                
                                ushort angle = (ushort)(buff[2] << 8 | buff[3]);
                                ushort magn_h = (ushort)(buff[4] << 8 | buff[5]);
                                Now_selected_tag.Navi_angle = angle;
                                Now_selected_tag.Magn_tesla = magn_h;
                            }
                            break;
                        }
                    default:break;
                }
            }
        }

        /// <summary>
        /// 搜索标签按钮点击动作
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Btn_Search_naviTag_Click(object sender, EventArgs e)
        {
            Sys_state = Sys_text_state_t.Sys_searching;
            Status_Change();

            byte[] data_buff = new byte[AT.AT_DATA_SENDLEN_MAX];
            data_buff[0] = COMMU_MARKCODE;
            data_buff[1] = FUNC_GET_STATUS;
            foreach(Tag t in Tag_All_list)
            {
                byte[] send_buff = AT.AT_DataSend_Write(data_buff, t.Id.ToString());
                if (send_buff != null)
                {
                    int send_time = 5;
                    do
                    {
                        Senddata_Action?.Invoke(send_buff);
                        Thread.Sleep(50);
                    }
                    while (send_time-- > 0);

                }
            }
            Sys_state = Sys_text_state_t.Sys_work;
            Status_Change();

        }

        /// <summary>
        /// 关闭导航窗口动作
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void NavigationWindow_FormClosing(object sender, FormClosingEventArgs e)
        {
            CloseNavi_Action?.Invoke();
        }

        /// <summary>
        /// 标签列表点击动作
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void DataGridView_Tag_SelectionChanged(object sender, EventArgs e)
        {
            if (DataGridView_Tag.SelectedRows.Count == 0)
                return;
            int tag_id = int.Parse(DataGridView_Tag.SelectedRows[0].Cells[0].Value.ToString());
            Text_Tag_id.Text = tag_id.ToString();
            if (Model.Tag.TryGetTag(Tag_navi_list, tag_id, out Tag t))
            {
                Now_selected_tag = t;
                MethodInvoker mi = new MethodInvoker(() =>
                {
                    Combo_ControlMode.SelectedIndex = Now_selected_tag.Navi_status_idx;
                });
                BeginInvoke(mi);
                
            }
        }

        /// <summary>
        /// 更改控制模式动作
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Combo_ControlMode_SelectedIndexChanged(object sender, EventArgs e)
        {
            //if(Now_selected_tag.Navi_status_idx != Combo_ControlMode.SelectedIndex)
            //{
            //    Change_tag_Navistatus((byte)Combo_ControlMode.SelectedIndex);
            //    UI_Change(Combo_ControlMode.SelectedIndex);
            //}
            Sys_state = Sys_text_state_t.Sys_ChangingMode;
            Status_Change();
            Change_tag_Navistatus((byte)Combo_ControlMode.SelectedIndex);
            UI_Change(Combo_ControlMode.SelectedIndex);
            Sys_state = Sys_text_state_t.Sys_work;
            Status_Change();
        }

        /// <summary>
        /// 根据不同的控制模式 ui显示不同
        /// </summary>
        /// <param name="state"></param>
        private void UI_Change(int state)
        {          
            switch (state)
            {
                case 0:
                    {
                        groupBox_mannual.Enabled = false;
                        groupBox_auto.Enabled = false;
                        break;
                    }
                case 1:
                    {
                        groupBox_mannual.Enabled = true;
                        groupBox_auto.Enabled = false;
                        break;
                    }
                case 2:
                    {
                        groupBox_mannual.Enabled = false;
                        groupBox_auto.Enabled = true;
                        break;
                    }
                default: break;
            }                        
        }

        /// <summary>
        /// 停止运动
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Btn_Stop_Click(object sender, EventArgs e)
        {
            Sys_state = Sys_text_state_t.Sys_ChangingMode;
            Status_Change();
            Change_tag_Navistatus(TAG_STATUS_IDLE);
            UI_Change(TAG_STATUS_IDLE);
            Combo_ControlMode.SelectedIndex = 0;
            Sys_state = Sys_text_state_t.Sys_work;
            Status_Change();
        }

        /// <summary>
        /// 周期判断指令发送有无回复 如果没有则周期重发
        /// 重发次数大于设定值，跳出并指示失败
        /// </summary>
        /// <param name="send_buff"></param>
        /// <param name="timeout"></param>
        /// <returns></returns>
        private bool Check_car_respond(byte[] send_buff, int timeout)
        {
            if (send_buff != null)
            {
                Has_Respond = false;
                while (!Has_Respond && timeout-- > 0)
                {
                    Senddata_Action?.Invoke(send_buff);
                    Thread.Sleep(100);
                }
                return Has_Respond;
            }
            return false;
        }

        /// <summary>
        /// 获得车速度挡位
        /// </summary>
        private void Get_car_speed()
        {
            if (Now_selected_tag != null)
            {
                byte[] data_buff = new byte[AT.AT_DATA_SENDLEN_MAX];
                data_buff[0] = COMMU_MARKCODE;
                data_buff[1] = FUNC_GET_CARSPEED;
                byte[] send_buff = AT.AT_DataSend_Write(data_buff, Now_selected_tag.Id.ToString());
                if(!Check_car_respond(send_buff, 20))
                {
                    MessageBox.Show("指令失败!");
                }
            }
        }

        /// <summary>
        /// 设置车速度挡位
        /// </summary>
        /// <param name="car_speed"></param>
        private void Set_car_speed(byte car_speed)
        {
            if (Now_selected_tag != null)
            {
                byte[] data_buff = new byte[AT.AT_DATA_SENDLEN_MAX];
                data_buff[0] = COMMU_MARKCODE;
                data_buff[1] = FUNC_SET_CARSPEED;
                data_buff[2] = car_speed;
                byte[] send_buff = AT.AT_DataSend_Write(data_buff, Now_selected_tag.Id.ToString());
                Check_car_respond(send_buff, 20);
            }
        }

        /// <summary>
        /// 发送指令更改运动状态 需等待直到接收到回应指令
        /// </summary>
        /// <param name="status"></param>
        private void Change_tag_Navistatus(byte status)
        {
            if (Now_selected_tag != null)
            {
                byte[] data_buff = new byte[AT.AT_DATA_SENDLEN_MAX];
                data_buff[0] = COMMU_MARKCODE;
                data_buff[1] = FUNC_SET_STATUS;
                data_buff[2] = status;
                byte[] send_buff = AT.AT_DataSend_Write(data_buff, Now_selected_tag.Id.ToString());
                if (!Check_car_respond(send_buff, 30))
                {
                    MessageBox.Show("指令失败!");
                }
                else
                {
                    Now_selected_tag.Navi_status_idx = status;
                }
            }
        }

        /// <summary>
        /// 更改点动模式运动状态
        /// </summary>
        /// <param name="move">运动指令</param>
        /// <param name="duetime">持续时间 单位ms</param>
        private void Change_tag_Mannualmove(byte move, ushort duetime)
        {
            if (Now_selected_tag != null)
            {
                byte[] data_buff = new byte[AT.AT_DATA_SENDLEN_MAX];
                data_buff[0] = COMMU_MARKCODE;
                data_buff[1] = FUNC_MANNUAL_MOVE;
                data_buff[2] = move;
                data_buff[3] = (byte)(duetime >> 8);
                data_buff[4] = (byte)(duetime & 0x00FF);
                byte[] send_buff = AT.AT_DataSend_Write(data_buff, Now_selected_tag.Id.ToString());
                if (!Check_car_respond(send_buff, 20))
                {
                    MessageBox.Show("指令失败!");
                }
            }
        }

        /// <summary>
        /// 指定自动导航目的地址
        /// </summary>
        /// <param name="pos_x">目的坐标x</param>
        /// <param name="pos_y">目的坐标y</param>
        private void Change_tag_Automove(short pos_x, short pos_y)
        {
            if (Now_selected_tag != null)
            {
                byte[] data_buff = new byte[AT.AT_DATA_SENDLEN_MAX];
                data_buff[0] = COMMU_MARKCODE;
                data_buff[1] = FUNC_AUTO_MOVE;
                data_buff[2] = (byte)(pos_x >> 8);
                data_buff[3] = (byte)(pos_x & 0x00FF);
                data_buff[4] = (byte)(pos_y >> 8);
                data_buff[5] = (byte)(pos_y & 0x00FF);
                byte[] send_buff = AT.AT_DataSend_Write(data_buff, Now_selected_tag.Id.ToString());
                if (!Check_car_respond(send_buff, 30))
                {
                    MessageBox.Show("指令失败!");
                }
            }
        }

        
        /// <summary>
        /// 点动控制中不同方向按钮按下动作
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Btn_Mannualmove_Click(object sender, EventArgs e)
        {
            Button b = sender as Button;
            if (b == null)
            {
                MessageBox.Show("error!");
            }
            byte Move_action = 0;
            switch (b.Name)
            {
                case "Btn_Front_left":
                    {
                        Move_action = 1;
                        break;
                    }
                case "Btn_Front_Right":
                    {
                        Move_action = 2;
                        break;
                    }
                case "Btn_Front":
                    {
                        Move_action = 0;
                        break;
                    }
                case "Btn_Back_Left":
                    {
                        Move_action = 4;
                        break;
                    }
                case "Btn_Back_Right":
                    {
                        Move_action = 5;
                        break;
                    }
                case "Btn_Back":
                    {
                        Move_action = 3;
                        break;
                    }
                default:break;
            }
            Change_tag_Mannualmove(Move_action, Mannual_moveduetime);
        }

        /// <summary>
        /// 点动控制持续时间修改
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void numericUpDown_moveduetime_ValueChanged(object sender, EventArgs e)
        {
            Mannual_moveduetime = (ushort)numericUpDown_moveduetime.Value;
        }

        /// <summary>
        /// 自动导航 根据输入坐标点移动
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Btn_StartMove_Click(object sender, EventArgs e)
        {
            short pos_x, pos_y;
            pos_x = (short)numericUpDown_dest_x.Value;
            pos_y = (short)numericUpDown_dest_y.Value;
            Change_tag_Automove(pos_x, pos_y);
        }

        /// <summary>
        /// 更改速度挡位
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Btn_changespeed_Click(object sender, EventArgs e)
        {
            if (comboBox_ChangeSpeed.SelectedIndex != -1)
            {
                Sys_state = Sys_text_state_t.Sys_Set_speed;
                Status_Change();
                Set_car_speed(byte.Parse(comboBox_ChangeSpeed.Text));
                Sys_state = Sys_text_state_t.Sys_work;
                Status_Change();
            }
        }

        /// <summary>
        /// 按下选中导航目的点
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Btn_cursorSelect_Click(object sender, EventArgs e)
        {
            //通知主界面开始选中目的点
            OnStartSelectPoint_EventHandler?.Invoke(this, new EventArgs());
        }

        /// <summary>
        /// 获取速度挡位
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Btn_GetSpeed_Click(object sender, EventArgs e)
        {
            Sys_state = Sys_text_state_t.Sys_Get_speed;
            Status_Change();
            Get_car_speed();
            Sys_state = Sys_text_state_t.Sys_work;
            Status_Change();
        }


    }

}
