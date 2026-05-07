using NPOI.OpenXmlFormats.Dml;
using OxyPlot;
using PGRtls.Model;
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Linq;
using System.Security.Policy;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using Point = System.Drawing.Point;

namespace PGRtls.Tool
{
    public class GDI_DrawHelper
    {     
        /// <summary>
        /// 画图操作实例
        /// </summary>
        private Graphics Gph { get; set; }
        /// <summary>
        /// 画板
        /// </summary>
        private Bitmap Inner_Bitmap { get; set; }
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
        public int Draw_size_x { get; set; }
        /// <summary>
        /// 画板y方向大小
        /// </summary>
        public int Draw_size_y { get; set; }
        /// <summary>
        /// 显示字体
        /// </summary>
        private Font Tx_font = new Font("宋体", 10);
        /// <summary>
        /// 地图路径
        /// </summary>
        private string Map_Image_path { get; set; } = string.Empty;
        /// <summary>
        /// 地图图片
        /// </summary>
        private Image Map_Image { get; set; }
        /// <summary>
        /// 是否有地图
        /// </summary>
        public bool Has_Map { get; private set; } = false;
        /// <summary>
        /// 地图宽度
        /// </summary>
        public int Map_width { get; set; }
        /// <summary>
        /// 地图高度
        /// </summary>
        public int Map_height { get; set; }
        /// <summary>
        /// 地图原点x
        /// </summary>
        public int Map_origin_x { get; set; } = 50;
        /// <summary>
        /// 地图原点y
        /// </summary>
        public int Map_origin_y { get; set; } = 50;
        /// <summary>
        /// 鼠标记录上次位置
        /// </summary>
        public float[] Mouse_LastPoint { get; set; } = new float[2] { 0.0f, 0.0f };
        /// <summary>
        /// 是否有轨迹
        /// </summary>
        public bool Has_trace { get; set; }
        /// <summary>
        /// 轨迹点集合
        /// </summary>
        public List<GDI_TagRecord> TagRecord_List { get; set; } = new List<GDI_TagRecord>(1024);

        public GDI_DrawHelper()
        {

        }

        /// <summary>
        /// 初始化画图配置
        /// </summary>
        /// <param name="size_x">画板宽度</param>
        /// <param name="size_y">画板高度</param>
        public void Draw_config_Init(int size_x, int size_y)
        {
            Draw_size_x = size_x;
            Draw_size_y = size_y;
            Inner_Bitmap = new Bitmap(size_x, size_y);
            Gph = Graphics.FromImage(Inner_Bitmap);
        }

        /// <summary>
        /// 获取画板
        /// </summary>
        /// <returns></returns>
        public Bitmap Get_Bitmap()
        {
            return Inner_Bitmap;
        }

        /// <summary>
        /// 设置地图图片
        /// </summary>
        /// <param name="map_path">地图路径</param>
        /// <returns></returns>
        public bool Set_Map_Img(string map_path)
        {
            
            Has_Map = false;
            if (!string.IsNullOrWhiteSpace(map_path))
            {
                Map_Image_path = map_path;  //记录图片路径
                try
                {
                    Map_Image = Image.FromFile(Map_Image_path);  //从路径中获取地图
                    Has_Map = true;
                    return true;
                }
                catch
                {
                    return false;
                }               
            }
            return false;
        }

        /// <summary>
        /// 清除地图
        /// </summary>
        public void Clear_Map()
        {
            Has_Map = false;
            Map_Image_path = null;
            Map_Image?.Dispose();
        }

        /// <summary>
        /// 设置地图参数
        /// </summary>
        /// <param name="width">地图宽度</param>
        /// <param name="height">地图高度</param>
        /// <param name="x">地图原点x</param>
        /// <param name="y">地图原点y</param>
        public void Set_Map_Config(int width, int height, int x, int y)
        {
            Map_width = width;
            Map_height = height;
            Map_origin_x = x;
            Map_origin_y = y;
        }

        public string Get_Map_path()
        {
            return Map_Image_path;
        }

        /// <summary>
        /// 将实际坐标转换到画图坐标
        /// </summary>
        /// <param name="real_x"></param>
        /// <param name="real_y"></param>
        /// <returns></returns>
        public PointF Transform2DrawPointF(int real_x, int real_y)
        {
            return new PointF(
                real_x / Axis_multiple + Axis_origin_x,
                Draw_size_y - (real_y / Axis_multiple + Axis_origin_y)
                );
        }

        /// <summary>
        /// 将实际坐标转换到画图坐标
        /// </summary>
        /// <param name="real_x"></param>
        /// <param name="real_y"></param>
        /// <returns></returns>
        public Point Transform2DrawPoint(int real_x, int real_y)
        {
            return new Point(
                (int)(real_x / Axis_multiple + Axis_origin_x),
                (int)(Draw_size_y - (real_y / Axis_multiple + Axis_origin_y))
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
                (int)((draw_x - Axis_origin_x) * Axis_multiple ),
                (int)((Draw_size_y - draw_y - Axis_origin_y) * Axis_multiple)
                );
        }

        /// <summary>
        /// 清除画板
        /// </summary>
        public void Draw_Clear()
        {
            Gph?.Clear(Color.White);
        }

        /// <summary>
        /// 画上地图
        /// </summary>
        public void Draw_Map()
        {
            Gph?.DrawImage(Map_Image, Map_origin_x, Map_origin_y, Map_width, Map_height);
        }

        /// <summary>
        /// 画基站
        /// </summary>
        /// <param name="x">基站实际坐标x</param>
        /// <param name="y">基站实际坐标y</param>
        /// <param name="anc_str">该基站显示名称</param>
        /// <param name="size">基站大小</param>
        public void Draw_Anchor(int x, int y, string anc_str, int size)
        {
            Point draw_point = Transform2DrawPoint(x, y);
            Rectangle anc_rect = new Rectangle(draw_point.X - size / 2, draw_point.Y - size / 2, size, size);         
            Image Anchor = Properties.Resources.anchor;
            Gph?.DrawImage(Anchor, anc_rect);            
            Gph?.DrawString(anc_str, Tx_font, Brushes.Black, draw_point.X - size / 2 + 5, draw_point.Y + size / 2);
        }

        /// <summary>
        /// 画基站测距圆及文字
        /// </summary>
        /// <param name="x">测距圆所在基站实际x坐标</param>
        /// <param name="y">测距圆所在基站实际y坐标</param>
        /// <param name="dist">测距值</param>
        public void Draw_DistCircle(int x, int y, int dist)
        {
            PointF draw_point = Transform2DrawPointF(x - dist, y + dist);
            Gph?.DrawEllipse(Pens.Red, draw_point.X, draw_point.Y, dist * 2 / Axis_multiple, dist * 2 / Axis_multiple);
            PointF str_point = Transform2DrawPointF(x, y);
            Gph?.DrawString($"Dist={dist}cm", Tx_font, Brushes.Red, str_point.X + 15, str_point.Y - 25);
        }

        /// <summary>
        /// 变更轨迹画图状态
        /// </summary>
        /// <param name="trace_en"></param>
        public void Change_Trace_Status(bool trace_en)
        {
            Has_trace = trace_en;
            TagRecord_List.Clear();
        }

        /// <summary>
        /// 画标签
        /// </summary>
        /// <param name="color">标签颜色</param>
        /// <param name="x">标签实际坐标x</param>
        /// <param name="y">标签实际坐标y</param>
        /// <param name="size">标签大小</param>
        /// <param name="need_add">是否需要加入到轨迹集合中（默认不加）</param>
        public void Draw_Tag(Color color, int x, int y, int size, bool need_add = false)
        {
            Brush draw_brush = new SolidBrush(color);
            Point draw_point = Transform2DrawPoint(x, y);
            int draw_x = draw_point.X - size / 2;
            int draw_y = draw_point.Y - size / 2;

            Gph?.DrawEllipse(new Pen(draw_brush), draw_x, draw_y, size, size);
            Gph?.FillEllipse(draw_brush, draw_x, draw_y, size, size);
            if (need_add)
            {
                TagRecord_List.Add(new GDI_TagRecord()
                {
                    Color_brush = color,
                    X = x,
                    Y = y,
                    Size = size
                });
            }
        }

        /// <summary>
        /// 画选中导航目的点坐标文字
        /// </summary>
        /// <param name="x">鼠标实际坐标x</param>
        /// <param name="y">鼠标实际坐标y</param>
        public void Draw_cursor_tx(int x, int y)
        {
            Point tx_point = Transform2RealPoint((int)x, (int)y);
            string tx = $"{tx_point.X},{tx_point.Y}";
            Gph?.DrawString(tx, Tx_font, Brushes.Black, x, y);
        }

        /// <summary>
        /// 画标签文字
        /// </summary>
        /// <param name="tx">要显示的文字</param>
        /// <param name="x">标签实际坐标x</param>
        /// <param name="y">标签实际坐标y</param>
        public void Draw_Tag_tx(string tx, int x, int y)
        {
            Gph?.DrawString(tx, Tx_font, Brushes.Black, Transform2DrawPointF(x + 30, y + 50));
        }

        /// <summary>
        /// 画导航标签图标
        /// </summary>
        /// <param name="x">导航标签实际x</param>
        /// <param name="y">导航标签实际y</param>
        /// <param name="size">标签大小</param>
        /// <param name="angle">标签角度</param>
        public void Draw_Navi_tag(int x, int y, int size, int angle) 
        {
            Point draw_point = Transform2DrawPoint(x, y);
            Rectangle tag_rect = new Rectangle(draw_point.X - size / 2, draw_point.Y - size / 2, size, size);
            Bitmap tag_rotate = Rotate_bitmap(Properties.Resources.Car_green, angle);
            Gph?.DrawImage(tag_rotate, tag_rect);          
        }

        /// <summary>
        /// 旋转图片
        /// </summary>
        /// <param name="b">要旋转的图片</param>
        /// <param name="angle">角度</param>
        /// <returns>旋转后的图片</returns>
        private Bitmap Rotate_bitmap(Bitmap b, int angle)
        {
            angle = angle % 360;
            //弧度转换
            double radian = angle * Math.PI / 180.0;
            double cos = Math.Cos(radian);
            double sin = Math.Sin(radian);
            //原图的宽和高
            int w = b.Width;
            int h = b.Height;
            int W = (int)(Math.Max(Math.Abs(w * cos - h * sin), Math.Abs(w * cos + h * sin)));
            int H = (int)(Math.Max(Math.Abs(w * sin - h * cos), Math.Abs(w * sin + h * cos)));
            //目标位图
            Bitmap dsImage = new Bitmap(W, H);
            Graphics g = Graphics.FromImage(dsImage);
            g.InterpolationMode = InterpolationMode.Bilinear;
            g.SmoothingMode = SmoothingMode.HighQuality;
            //计算偏移量
            Point Offset = new Point((W - w) / 2, (H - h) / 2);
            //构造图像显示区域：让图像的中心与窗口的中心点一致
            Rectangle rect = new Rectangle(Offset.X, Offset.Y, w, h);
            Point center = new Point(rect.X + rect.Width / 2, rect.Y + rect.Height / 2);
            g.TranslateTransform(center.X, center.Y);
            g.RotateTransform(360 - angle);
            //恢复图像在水平和垂直方向的平移
            g.TranslateTransform(-center.X, -center.Y);
            g.DrawImage(b, rect);
            //重至绘图的所有变换
            g.ResetTransform();
            g.Save();
            g.Dispose();
            return dsImage;
        }

        /// <summary>
        /// 画目的点图片
        /// </summary>
        /// <param name="x">目的点实际x</param>
        /// <param name="y">目的点实际y</param>
        /// <param name="size">目的点大小</param>
        public void Draw_Target_Image(int x, int y, int size)
        {
            Point draw_point = Transform2DrawPoint(x, y);
            Rectangle draw_rect = new Rectangle(draw_point.X - size / 2, draw_point.Y - size / 2, size, size);          
            Gph?.DrawImage(Properties.Resources.Target, draw_rect);
        }

        /// <summary>
        /// 画标签轨迹集合中的内容（画轨迹）
        /// </summary>
        public void Draw_TagRecord()
        {
            foreach(GDI_TagRecord tr in TagRecord_List)
            {
                Draw_Tag(tr.Color_brush, tr.X, tr.Y, tr.Size);
            }
        }

        /// <summary>
        /// 画坐标轴
        /// </summary>
        public void Draw_Axis()
        {
            PointF cPt;
            PointF[] xPt = new PointF[3]{
                 new   PointF(Axis_origin_x,0),
                 new   PointF(Axis_origin_x-8,15),
                 new   PointF(Axis_origin_x+8,15)};//X轴三角形    
            PointF[] yPt = new PointF[3]{
                 new   PointF(Draw_size_x,Draw_size_y - Axis_origin_y),
                 new   PointF(Draw_size_x-15,Draw_size_y - (Axis_origin_y-8)),
                 new   PointF(Draw_size_x-15,Draw_size_y - (Axis_origin_y+8))};//Y轴三角形    
            
            Gph?.DrawPolygon(Pens.Black, xPt);//X轴三角形 
            Gph?.FillPolygon(Brushes.Black, xPt);
            Gph?.DrawPolygon(Pens.Black, yPt);//Y轴三角形   
            Gph?.FillPolygon(Brushes.Black, yPt);

            Gph?.DrawLine(Pens.Black, Axis_origin_x, Draw_size_y - (Axis_origin_y - 20), Axis_origin_x, 0);  //画y轴
            Gph?.DrawLine(Pens.Black, Axis_origin_x - 20, Draw_size_y - Axis_origin_y, Draw_size_x, Draw_size_y - Axis_origin_y);  //画X轴
            {
                cPt = new PointF(Axis_origin_x - 20, Draw_size_y - (Axis_origin_y - 5));
                Gph.DrawString("0m", Tx_font, Brushes.Black, cPt);
            }

            int zb_num;
            int i;

            /* 画X轴刻点 */
            zb_num = (Int16)((Draw_size_x - Axis_origin_x) / 100);
            if (((Draw_size_x - Axis_origin_x) % 100) == 0) 
                zb_num--;
            for (i = 0; i < zb_num; i++)
            {
                float mm;
                cPt = new PointF(Axis_origin_x + (i + 1) * 100 - 10, Draw_size_y - (Axis_origin_y - 10));//中心点 
                Gph?.DrawLine(Pens.Black, Axis_origin_x + (i + 1) * 100, Draw_size_y - Axis_origin_y, Axis_origin_x + (i + 1) * 100, Draw_size_y - (Axis_origin_y + 10));  //画x轴
                mm = ((i + 1) * (Axis_multiple));
                Gph?.DrawString(mm.ToString("f2") + "m", Tx_font, Brushes.Black, cPt);


            }
            
            /* 画Y轴刻点 */
            zb_num = (Int16)((Draw_size_y - Axis_origin_y) / 100);
            if (((Draw_size_y - Axis_origin_y) % 100) == 0) 
                zb_num--;
            for (i = 0; i < zb_num; i++)
            {
                float mm;
                cPt = new PointF(Axis_origin_x - 40, Draw_size_y - (Axis_origin_y + (i + 1) * 100 + 7));//中心点 
                Gph?.DrawLine(Pens.Black, Axis_origin_x, Draw_size_y - (Axis_origin_y + (i + 1) * 100), Axis_origin_x + 10, Draw_size_y - (Axis_origin_y + (i + 1) * 100));  //画y轴
                mm = ((i + 1) * (Axis_multiple));
                Gph?.DrawString(mm.ToString("f2") + "m", Tx_font, Brushes.Black, cPt);
            }           
        }

        /// <summary>
        /// 鼠标移动处理
        /// </summary>
        /// <param name="now_x">实际x坐标</param>
        /// <param name="now_y">实际y坐标</param>
        public void Mouse_MoveHandler(int now_x, int now_y)
        {
            float dx, dy;
            dx = Mouse_LastPoint[0] - now_x;
            dy = Mouse_LastPoint[1] - now_y;

            if ((0.0f != dx) || (0.0f != dy))
            {
                Axis_origin_x -= (int)(dx);

                if (Axis_origin_x >= Draw_size_x)
                    Axis_origin_x = (short)Draw_size_x;
                if (Axis_origin_x <= 0)
                    Axis_origin_x = 0;

                //numericUpDown_origin_X
                Axis_origin_y += (int)(dy);
                if (Axis_origin_y >= Draw_size_y)
                    Axis_origin_y = Draw_size_y;
                if (Axis_origin_y <= 0)
                    Axis_origin_y = 0;
            }
            //Mouse_LastPoint[0] = now_x;
            //Mouse_LastPoint[1] = now_y;
        }

    }

    public class GDI_TagRecord
    {
        /// <summary>
        /// 标签颜色
        /// </summary>
        public Color Color_brush { get; set; }
        /// <summary>
        /// 标签x坐标（实际坐标）
        /// </summary>
        public int X { get; set; }
        /// <summary>
        /// 标签y坐标（实际坐标）
        /// </summary>
        public int Y { get; set; }
        /// <summary>
        /// 标签大小
        /// </summary>
        public int Size { get; set; }
    }

}
