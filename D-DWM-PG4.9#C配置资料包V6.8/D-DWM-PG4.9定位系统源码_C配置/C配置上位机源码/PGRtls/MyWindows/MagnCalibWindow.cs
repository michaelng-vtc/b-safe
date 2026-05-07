using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using MathNet.Numerics.LinearAlgebra.Double;
using PGRtls.Model;

namespace PGRtls.MyWindows
{
    public partial class MagnCalibWindow : Form
    {
        #region 变量
        IMUData Imu_instance = null;
        bool Is_calibing = false;
        bool Is_calib_fin = false;
        bool Is_calib_success = false;
        private List<double> Magn_x_data = new List<double>(2000);
        private List<double> Magn_y_data = new List<double>(2000);
        private List<double> Magn_z_data = new List<double>(2000);
        double[] Magn_cal_axis_len = new double[3];
        private delegate void TextBox_Showstring_delegate(string s);
        private TextBox_Showstring_delegate Showstring_Delegate;
        #endregion

        public MagnCalibWindow(IMUData imu_data)
        {
            InitializeComponent();
            Imu_instance = imu_data;
            Showstring_Delegate = new TextBox_Showstring_delegate(Show_string);
            Show_bias_scale();
        }

        private void Show_bias_scale()
        {
            Text_bias_x.Text = Imu_instance.Magn_bias[0].ToString("N3");
            Text_bias_y.Text = Imu_instance.Magn_bias[1].ToString("N3");
            Text_bias_z.Text = Imu_instance.Magn_bias[2].ToString("N3");
            Text_scale_x.Text = Imu_instance.Magn_scale[0].ToString("N3");
            Text_scale_y.Text = Imu_instance.Magn_scale[1].ToString("N3");
            Text_scale_z.Text = Imu_instance.Magn_scale[2].ToString("N3");          
        }


        private void MagnCalibWindow_Load(object sender, EventArgs e)
        {
            //数据绑定
            Text_magnx.DataBindings.Add("Text", Imu_instance, "Magn_x");
            Text_magny.DataBindings.Add("Text", Imu_instance, "Magn_y");
            Text_magnz.DataBindings.Add("Text", Imu_instance, "Magn_z");
        }

        private void Show_string(string s)
        {
            DateTime now_time = DateTime.Now;
            string time_str = $"[{now_time.ToString("yyyy/MM/dd HH:mm:sss")}]\r\n";
            Text_log.AppendText(time_str);
            Text_log.AppendText(s + "\r\n");
        }

        private void Tx_showLog(string s)
        {
            Text_log.BeginInvoke(Showstring_Delegate, s);
        }

        

        private void Btn_Calib_Click(object sender, EventArgs e)
        {
            if (!Is_calibing)
            {
                Tx_showLog("开始记录！");
                Magn_x_data.Clear();
                Magn_y_data.Clear();
                Magn_z_data.Clear();
                Is_calibing = true;
                Is_calib_fin = false;
                Btn_Calib.Text = "停止记录";
                Task.Run(() => Magn_calib_Handler());
            }
            else
            {
                Is_calibing = false;
                Is_calib_fin = true;
                Tx_showLog("停止校准！");
                Btn_Calib.Text = "开始记录";
            }
        }

        private void Magn_calib_Handler()
        {
            while (!Is_calib_fin)
            {
                if (Imu_instance.Is_get_newdata)
                {
                    Imu_instance.Is_get_newdata = false;
                    //保存数据
                    Magn_x_data.Add(Imu_instance.Magn_x);
                    Magn_y_data.Add(Imu_instance.Magn_y);
                    Magn_z_data.Add(Imu_instance.Magn_z);
                }
            }
            //校准完成
            Tx_showLog($"获得数据数量:{Magn_x_data.Count}");

            //运行算法
            Is_calib_success = Ellipse_Fit();          

            Tx_showLog("拟合完成");

            MethodInvoker mi = new MethodInvoker(() =>
            {
                Show_bias_scale();
            });
            BeginInvoke(mi);
            
            Tx_showLog($"椭圆原点-> x:{Imu_instance.Magn_bias[0]},y:{Imu_instance.Magn_bias[1]},z:{Imu_instance.Magn_bias[2]}");
            Tx_showLog($"椭圆轴长-> x:{Magn_cal_axis_len[0]},y:{Magn_cal_axis_len[1]},z:{Magn_cal_axis_len[2]}");
        }

        private double Math_squre(double d)
        {
            return Math.Pow(d, 2);
        }

        private bool Ellipse_Fit()
        {
            //整合数据
            try
            {
                DenseMatrix K = new DenseMatrix(Magn_x_data.Count, 6);
                DenseMatrix X = new DenseMatrix(6, 1);
                DenseMatrix Y = new DenseMatrix(Magn_x_data.Count, 1);
                for (int i = 0; i < Magn_x_data.Count; i++)
                {
                    K[i, 0] = Math_squre(Magn_y_data[i]);
                    K[i, 1] = Math_squre(Magn_z_data[i]);
                    K[i, 2] = Magn_x_data[i];
                    K[i, 3] = Magn_y_data[i];
                    K[i, 4] = Magn_z_data[i];
                    K[i, 5] = 1;

                    Y[i, 0] = - Math_squre(Magn_x_data[i]);
                }
                //最小二乘法
                DenseMatrix KT = (DenseMatrix)K.Transpose();
                DenseMatrix KTK = KT * K;
                if(KTK.Determinant() == 0)
                {
                    return false;
                }
                X = (DenseMatrix)KTK.Inverse() * KT * Y;
                Imu_instance.Magn_bias[0] = -X[2, 0] / 2;
                Imu_instance.Magn_bias[1] = -X[3, 0] / (2 * X[0, 0]);
                Imu_instance.Magn_bias[2] = -X[4, 0] / (2 * X[1, 0]);
                Magn_cal_axis_len[0] = Math.Sqrt(Math_squre(Imu_instance.Magn_bias[0]) + X[0, 0] * Math_squre(Imu_instance.Magn_bias[1]) +
                    X[1, 0] * Math_squre(Imu_instance.Magn_bias[2]) - X[5, 0]);
                Magn_cal_axis_len[1] = Math.Sqrt(Math_squre(Magn_cal_axis_len[0]) / X[0, 0]);
                Magn_cal_axis_len[2] = Math.Sqrt(Math_squre(Magn_cal_axis_len[0]) / X[1, 0]);

                //算出各轴对于x轴的比例
                Imu_instance.Magn_scale[0] = 1;
                Imu_instance.Magn_scale[1] = Magn_cal_axis_len[0] / Magn_cal_axis_len[1];
                Imu_instance.Magn_scale[2] = Magn_cal_axis_len[0] / Magn_cal_axis_len[2];
            }
            catch
            {
                return false;
            }
            return true;
        }

        private void MagnCalibWindow_FormClosing(object sender, FormClosingEventArgs e)
        {
            this.DialogResult = Is_calib_success ? DialogResult.Yes : DialogResult.No;
        }
    }
}
