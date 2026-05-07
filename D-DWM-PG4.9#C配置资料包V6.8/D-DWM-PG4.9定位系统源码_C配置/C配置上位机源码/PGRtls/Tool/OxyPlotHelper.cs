using OxyPlot;
using OxyPlot.Axes;
using OxyPlot.Series;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Shapes;

namespace PGRtls.Tool
{
    public class OxyPlotHelper
    {
        public PlotModel Plot { get; set; }

        public int Line_Num { get; set; }

        public int Point_ShowMaxNum { get; set; }

        public struct Line_config_t
        {
            public OxyColor LineColors { get; set; }

            public string LineTitle { get; set; }

            public bool Is_show_markup { get; set; }
        }

        public List<Line_config_t> Line_config_List { get; set; }

        public string Plot_Title { get; set; }

        /// <summary>
        /// 实例初始化
        /// </summary>
        /// <param name="pTitle">图表标题</param>
        /// <param name="line_num">线系列数量</param>
        /// <param name="max_num">线系列点最大数量 该参数越大会导致画图滞后越严重</param>
        public OxyPlotHelper(string pTitle, int line_num, int max_num)
        {
            Line_Num = line_num;
            Plot_Title = pTitle;
            Point_ShowMaxNum = max_num;
            Line_config_List = new List<Line_config_t>(line_num);

            Plot = new PlotModel()
            {
                Background = OxyColors.White,
                Title = Plot_Title,
                TitleFontSize = 12,
                TitlePadding = 0,               
            };

        }

        /// <summary>
        /// 初始化坐标轴 x轴为时间轴 y轴为距离轴
        /// </summary>
        public void InitAxes(bool is_dist_plot = true)
        {
            if (is_dist_plot)
            {
                DateTimeAxis datetimeaxis = new DateTimeAxis
                {
                    Position = AxisPosition.Bottom,
                    StringFormat = "HH:mm:ss",
                    Title = "时间",
                    MaximumRange = 0.000025

                };
                Plot.Axes.Add(datetimeaxis);

                LinearAxis vertical_axis = new LinearAxis
                {
                    Position = AxisPosition.Left,
                    Maximum = 5,
                    Minimum = 0,
                    MaximumPadding = 0.1,
                    MinimumPadding = 0.1,
                    Title = "距离(m)",
                };
                Plot.Axes.Add(vertical_axis);
            }
            else
            {
                LinearAxis horizon_axis = new LinearAxis
                {
                    Position = AxisPosition.Bottom,
                    Maximum = 1016,
                    Minimum = 0,
                    Title = "cir_idx",
                };
                Plot.Axes.Add(horizon_axis);
                LinearAxis vertical_axis = new LinearAxis
                {
                    Position = AxisPosition.Left,
                    Maximum = 10000,
                    Minimum = 0,
                    Title = "cir",
                };
                Plot.Axes.Add(vertical_axis);
            }

           
        }

        /// <summary>
        /// 添加新图表线的系列配置
        /// </summary>
        /// <param name="color">线颜色</param>
        /// <param name="title">线名称</param>
        public void AddLineConfig(OxyColor color, string title, bool is_show_markup = false)
        {
            Line_config_List.Add(new Line_config_t()
            {
                LineColors = color,
                LineTitle = title,
                Is_show_markup = is_show_markup
            });

        }

        /// <summary>
        /// 画图示例初始化线系列
        /// </summary>
        public void InitLines()
        {
            foreach (Line_config_t config in Line_config_List)
            {
                LineSeries line = new LineSeries()
                {
                    Title = config.LineTitle,
                    Color = config.LineColors,
                    StrokeThickness = 1,
                    
                    //InterpolationAlgorithm = InterpolationAlgorithms.CanonicalSpline  //平滑曲线 会变慢
                };
                if (config.Is_show_markup)
                {
                    line.MarkerType = MarkerType.Circle;
                    line.MarkerStrokeThickness = 2;
                }
                Plot.Series.Add(line);
            }
        }

        /// <summary>
        /// 获取线系列
        /// </summary>
        /// <param name="idx"></param>
        /// <returns></returns>
        public LineSeries GetLine(int idx)
        {
            return Plot.Series[idx] as LineSeries;
        }

        /// <summary>
        /// 获取x轴
        /// </summary>
        /// <returns></returns>
        public LinearAxis GetXAxis()
        {
            return Plot.DefaultXAxis as LinearAxis;
        }

        /// <summary>
        /// 获取y轴
        /// </summary>
        /// <returns></returns>
        public LinearAxis GetYAxis()
        {
            return Plot.DefaultYAxis as LinearAxis;
        }

        public void Show_GridLine()
        {
            LinearAxis x_axis = GetXAxis();
            x_axis.MajorGridlineStyle = LineStyle.Solid;
            x_axis.MinorGridlineStyle = LineStyle.Solid;
            LinearAxis y_axis = GetYAxis();
            y_axis.MajorGridlineStyle = LineStyle.Solid;
            y_axis.MinorGridlineStyle = LineStyle.Solid;
        }

        public void Clear_GridLine()
        {
            LinearAxis x_axis = GetXAxis();
            x_axis.MajorGridlineStyle = LineStyle.None;
            x_axis.MinorGridlineStyle = LineStyle.None;
            LinearAxis y_axis = GetYAxis();
            y_axis.MajorGridlineStyle = LineStyle.None;
            y_axis.MinorGridlineStyle = LineStyle.None;

        }

        public void Show_Markup(int line_idx)
        {
            LineSeries l = GetLine(line_idx);
            l.MarkerType = MarkerType.Circle;
            l.MarkerStrokeThickness = 2;
        }

        public void Clear_Markup(int line_idx)
        {
            LineSeries l = GetLine(line_idx);
            l.MarkerType = MarkerType.None;

        }

        /// <summary>
        /// 对应线系列添加新点 会根据设定的最大值删除点
        /// </summary>
        /// <param name="time"></param>
        /// <param name="y_value"></param>
        /// <param name="idx"></param>
        public void AddPoint(DateTime time, double y_value, int idx)
        {
            LineSeries line = GetLine(idx);
            if (line != null)
            {
                if (line.Points.Count > Point_ShowMaxNum)
                    line.Points.RemoveAt(0);
                line.Points.Add(DateTimeAxis.CreateDataPoint(time, y_value));

            }
        }

        public void AddPoint(int x_value, double y_value, int idx)
        {
            LineSeries line = GetLine(idx);
            if (line != null)
            {
                if (line.Points.Count > Point_ShowMaxNum)
                    line.Points.RemoveAt(0);
                line.Points.Add(new DataPoint(x_value, y_value));
                
            }
        }

        public void ClearPlot(int idx)
        {
            LineSeries line = GetLine(idx);
            if (line != null)
            {
                line.Points.Clear();
            }
            Plot.InvalidatePlot(true);
        }

        /// <summary>
        /// 图表刷新
        /// </summary>
        public void RefreshPlot(bool is_data_update = true)
        {
            Plot.InvalidatePlot(is_data_update);
        }

        /// <summary>
        /// 图表重置移动 缩放后的情况
        /// </summary>
        public void ResetDisplay()
        {
            //DateTimeAxis x_axis = Plot.Axes[0] as DateTimeAxis;
            //if (x_axis != null)
            //    x_axis.Reset();
            Plot.Axes[0].Reset();
            Plot.Axes[1].Reset();
            //LinearAxis y_axis = Plot.Axes[1] as LinearAxis;
            //if (y_axis != null)
            //    y_axis.Reset();
        }

        /// <summary>
        /// 设置y轴最大值
        /// </summary>
        /// <param name="max"></param>
        public void Set_YAxis_Max(double max)
        {
            LinearAxis y_axis = GetYAxis();
            if (y_axis != null)            
                y_axis.Maximum = max;            
        }


    }
}
