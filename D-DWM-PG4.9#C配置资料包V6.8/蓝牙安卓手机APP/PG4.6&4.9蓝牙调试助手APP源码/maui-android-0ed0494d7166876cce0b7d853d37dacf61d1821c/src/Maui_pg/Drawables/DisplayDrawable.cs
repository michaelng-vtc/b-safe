using CommunityToolkit.Mvvm.Messaging;
using Maui_pg.Messages;
using Maui_pg.Models;
using Maui_pg.Shares;
using Microsoft.Maui.Graphics;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maui_pg.Drawables
{
    internal class DisplayDrawable : IDrawable
    {

        /// <summary>
        /// 基站坐标轴原点x
        /// </summary>
        public int Axis_origin_x { get; set; } = 50;
        /// <summary>
        /// 基站坐标轴原点y
        /// </summary>
        public int Axis_origin_y { get; set; } = 50;
        /// <summary>
        /// 基站坐标系数据对应画图显示的比例
        /// </summary>
        public float Axis_multiple { get; set; } = 3.0f;
        /// <summary>
        /// 画板x方向大小
        /// </summary>
        public double Draw_size_x { get; set; }
        /// <summary>
        /// 画板y方向大小
        /// </summary>
        public double Draw_size_y { get; set; }

        public bool Has_Init { get; set; } = false;

        private const int Max_tag_trace_len = 50;
        private readonly int Anc_size = 20;
        private readonly int Tag_size = 10;
        //private List<Point> Draw_point_anc_list = new List<Point>(16);

        private List<Point> Draw_point_tag_list = new List<Point>(Max_tag_trace_len);

        public DisplayDrawable()
        {
            //接收到屏幕手势平移信息
            WeakReferenceMessenger.Default.Register<PanMoveMessage>(this, (r, m) =>
            {
                Axis_origin_x += (int)m.Value.Pan_x / 10;  //除以10是为了减少移动漂移
                Axis_origin_y -= (int)m.Value.Pan_y / 10;  //除以10是为了减少移动漂移
            });
        }
        
        public void Render(bool has_trace, float draw_scale)
        {
            int i = 0;
            if (!has_trace)
            {
                Draw_point_tag_list.Clear();
            }
            //Draw_point_anc_list.Clear();
            //for (i = 0; i < Share_Data.AncList.Count; i++)
            //{
            //    Draw_point_anc_list.Add(new Point()
            //    {
            //        X = Share_Data.AncList[i].X,
            //        Y = Share_Data.AncList[i].Y
            //    });
            //}
            for (i = 0; i < Share_Data.TagList.Count; i++)
            {
                if(Draw_point_tag_list.Count + 1 > Max_tag_trace_len)  //只有1个标签的简单实现
                {
                    Draw_point_tag_list.RemoveAt(0);
                }
                Draw_point_tag_list.Add(new Point()
                {
                    X = Share_Data.TagList[i].X,
                    Y = Share_Data.TagList[i].Y
                });
            }
            if(Axis_multiple != draw_scale)
            {
                Axis_multiple = draw_scale;
            }
        }

        public void Init(double x, double y)
        {
            if(x== -1 && y== -1 && !Has_Init)
            {
                return;
            }
            Draw_size_x = x;
            Draw_size_y = y;
            Has_Init = true;
        }

        ///// <summary>
        ///// 将实际坐标转换到画图坐标
        ///// </summary>
        ///// <param name="real_x"></param>
        ///// <param name="real_y"></param>
        ///// <returns></returns>
        //public PointF Transform2DrawPointF(int real_x, int real_y)
        //{
        //    return new PointF(
        //        real_x / Axis_multiple + Axis_origin_x,
        //        Draw_size_y - (real_y / Axis_multiple + Axis_origin_y)
        //        );
        //}

        /// <summary>
        /// 将实际坐标转换到画图坐标
        /// </summary>
        /// <param name="real_x"></param>
        /// <param name="real_y"></param>
        /// <returns></returns>
        public Point Transform2DrawPoint(int real_x, int real_y)
        {
            return new Point(
                real_x / Axis_multiple + Axis_origin_x,
                Draw_size_y - (real_y / Axis_multiple + Axis_origin_y)
                );
        }

        /// <summary>
        /// 将画图坐标转换到实际坐标
        /// </summary>
        /// <param name="draw_x"></param>
        /// <param name="draw_y"></param>
        /// <returns></returns>
        public Point Transform2RealPoint(int draw_x, int draw_y)
        {
            return new Point(
                ((draw_x - Axis_origin_x) * Axis_multiple),
                ((Draw_size_y - draw_y - Axis_origin_y) * Axis_multiple)
                );
        }

        public void Draw(ICanvas canvas, RectF dirtyRect)
        {
            int i = 0;

            canvas.StrokeColor = Colors.Red;
            canvas.FillColor = Colors.Red;
            for (i = 0; i < Share_Data.AncList.Count; i++)
            {
                UWBAnchor anc = Share_Data.AncList[i];
                if(anc == null) 
                { 
                    continue; 
                }
                Point draw_point = Transform2DrawPoint(anc.X, anc.Y);
                draw_point.X -= Anc_size / 2;
                draw_point.Y -= Anc_size / 2;
                canvas.DrawRectangle((float)draw_point.X, (float)draw_point.Y, Anc_size, Anc_size);
                canvas.FillRectangle((float)draw_point.X, (float)draw_point.Y, Anc_size, Anc_size);
                canvas.DrawString(anc.ID, (float)draw_point.X + 10, (float)draw_point.Y + Anc_size + 10, HorizontalAlignment.Center);
            }

            canvas.StrokeColor = Colors.Blue;
            canvas.FillColor = Colors.Blue;
            for (i = 0; i < Draw_point_tag_list.Count; i++)
            {
                Point origin_point = Draw_point_tag_list[i];
                Point draw_point = Transform2DrawPoint((int)origin_point.X, (int)origin_point.Y);
                draw_point.X -= Tag_size / 2;
                draw_point.Y -= Tag_size / 2;
                canvas.DrawEllipse((float)draw_point.X, (float)draw_point.Y, Tag_size, Tag_size);               
                canvas.FillEllipse((float)draw_point.X, (float)draw_point.Y, Tag_size, Tag_size);
            }
            
        }
    }
}
