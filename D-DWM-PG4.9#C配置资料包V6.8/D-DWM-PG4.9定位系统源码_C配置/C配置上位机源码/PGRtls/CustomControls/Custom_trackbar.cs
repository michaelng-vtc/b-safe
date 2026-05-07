using OpenTK.Input;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using MouseEventArgs = System.Windows.Forms.MouseEventArgs;

namespace PGRtls.CustomControls
{
    /// <summary>
    /// 事件数据
    /// </summary>
    public class C_Trackbar_EventArgs : EventArgs
    {
        /// <summary>
        /// 事件数据
        /// </summary>
        /// <param name="value">值</param>
        public C_Trackbar_EventArgs(object value)
        {
            Value = value;
        }
        /// <summary>
        /// 值
        /// </summary>
        public object Value { get; set; }
    }

    /// <summary>
    /// 方向
    /// </summary>
    public enum C_Trackbar_Orientation
    {
        /// <summary>
        /// 水平方向（从左到右）
        /// </summary>
        Horizontal_LR,
        /// <summary>
        /// 水平方向（从右到左）
        /// </summary>
        Horizontal_RL,
        /// <summary>
        /// 垂直方向（从上到上）
        /// </summary>
        Vertical_BT,
        /// <summary>
        /// 垂直方向（从上到下）
        /// </summary>
        Vertical_TB
    }

    /// <summary>
    /// 鼠标状态
    /// </summary>
    public enum C_Trackbar_MouseStatus
    {
        /// <summary>
        /// 鼠标进入
        /// </summary>
        Enter,
        /// <summary>
        /// 鼠标离开
        /// </summary>
        Leave,
        /// <summary>
        /// 鼠标按下
        /// </summary>
        Down,
        /// <summary>
        /// 鼠标按下释放
        /// </summary>
        Up
    }

    [DefaultEvent("CValueChanged")]
    public partial class Custom_trackbar : Control
    {
        public Custom_trackbar()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint, true);
            SetStyle(ControlStyles.OptimizedDoubleBuffer, true);
            CreateControl();
            //InitializeComponent();
        }

        #region 属性

        private Color _BarColor = Color.FromArgb(238, 238, 238);//灰色
        /// <summary>
        /// 背景条颜色
        /// </summary>
        [Category("CustomCfg"), Description("背景条颜色")]
        public Color C_BarColor
        {
            get { return _BarColor; }
            set
            {
                _BarColor = value;
                Invalidate();
            }
        }

        private Color _SliderColor = Color.FromArgb(50, 108, 246);//蓝色
        /// <summary>
        /// 滑块颜色
        /// </summary>
        [Category("CustomCfg"), Description("滑块颜色")]
        public Color C_SliderColor
        {
            get { return _SliderColor; }
            set
            {
                _SliderColor = value;
                Invalidate();
            }
        }

        private bool _IsRound = true;
        /// <summary>
        /// 是否是圆角<para>默认：是</para>
        /// </summary>
        [Category("CustomCfg"), Description("是否是圆角\r\n默认：是")]
        public bool C_IsRound
        {
            get { return _IsRound; }
            set
            {
                _IsRound = value;
                Invalidate();
            }
        }

        private int _Minimum = 0;
        /// <summary>
        /// 最小值<para>范围：大于等于0</para>
        /// </summary>
        [Category("CustomCfg"), Description("最小值<para>范围：大于等于0</para>")]
        public int C_Minimum
        {
            get { return _Minimum; }
            set
            {
                _Minimum = value;
                if (_Minimum >= _Maximum) _Minimum = _Maximum - 1;
                if (_Minimum < 0) _Minimum = 0;
                Invalidate();
            }
        }

        private int _Maximum = 100;
        /// <summary>
        /// 最大值
        /// </summary>
        [Category("CustomCfg"), Description("最大值")]
        public int C_Maximum
        {
            get { return _Maximum; }
            set
            {
                _Maximum = value;
                if (_Maximum <= _Minimum) _Maximum = _Minimum + 1;
                Invalidate();
            }
        }

        private int _Value = 0;
        /// <summary>
        /// 当前值
        /// </summary>
        [Category("CustomCfg"), Description("当前值")]
        public int C_Value
        {
            get { return _Value; }
            set
            {
                _Value = value;
                if (_Value < _Minimum) _Value = _Minimum;
                if (_Value > _Maximum) _Value = _Maximum;
                Invalidate();
                CValueChanged?.Invoke(this, new C_Trackbar_EventArgs(_Value));
            }
        }

        private C_Trackbar_Orientation _Orientation = C_Trackbar_Orientation.Horizontal_LR;
        /// <summary>
        /// 方向<para>默认：水平，从左到右</para>
        /// </summary>
        [Category("CustomCfg"), Description("方向\r\n默认：水平，从左到右")]
        public C_Trackbar_Orientation C_Orientation
        {
            get { return _Orientation; }
            set
            {
                C_Trackbar_Orientation old = _Orientation;
                _Orientation = value;
                if ((old == C_Trackbar_Orientation.Horizontal_LR || old == C_Trackbar_Orientation.Horizontal_RL) && (_Orientation == C_Trackbar_Orientation.Vertical_BT || _Orientation == C_Trackbar_Orientation.Vertical_TB))
                {
                    Size = new Size(Size.Height, Size.Width);
                }

                if ((_Orientation == C_Trackbar_Orientation.Horizontal_LR || _Orientation == C_Trackbar_Orientation.Horizontal_RL) && (old == C_Trackbar_Orientation.Vertical_BT || old == C_Trackbar_Orientation.Vertical_TB))
                {
                    Size = new Size(Size.Height, Size.Width);
                }
                Invalidate();
            }
        }

        private int _BarSize = 10;
        /// <summary>
        /// 滑条高度（水平）/宽度（垂直）
        /// </summary>
        [Category("CustomCfg"), Description(" 滑条高度（水平）/宽度（垂直）")]
        public int C_BarSize
        {
            get { return _BarSize; }
            set
            {
                _BarSize = value;
                if (_BarSize < 1) _BarSize = 1;
                if (_Orientation == C_Trackbar_Orientation.Horizontal_LR || _Orientation == C_Trackbar_Orientation.Horizontal_RL)
                {
                    Size = new Size(Width, _BarSize);
                }
                else
                {
                    Size = new Size(_BarSize, Height);
                }
            }
        }

        private C_Trackbar_MouseStatus mouseStatus = C_Trackbar_MouseStatus.Leave;
        private PointF mousePoint = Point.Empty;

        #endregion

        #region 
        /// <summary>
        /// 委托
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        public delegate void CValueChangedEventHandler(object sender, C_Trackbar_EventArgs e);
        /// <summary>
        /// 值发生改变时引发的事件
        /// </summary>
        public event CValueChangedEventHandler CValueChanged;
        #endregion

        #region
        private void pValueToPoint()
        {
            float fCapHalfWidth = 0;
            float fCapWidth = 0;
            if (_IsRound)
            {
                fCapWidth = _BarSize;
                fCapHalfWidth = _BarSize / 2.0f;
            }

            float fRatio = Convert.ToSingle(_Value - _Minimum) / (_Maximum - _Minimum);
            if (_Orientation == C_Trackbar_Orientation.Horizontal_LR)
            {
                float fPointValue = fRatio * (Width - fCapWidth) + fCapHalfWidth;
                mousePoint = new PointF(fPointValue, fCapHalfWidth);
            }
            else if (_Orientation == C_Trackbar_Orientation.Horizontal_RL)
            {
                float fPointValue = Width - fCapHalfWidth - fRatio * (Width - fCapWidth);
                mousePoint = new PointF(fPointValue, fCapHalfWidth);
            }
            else if (_Orientation == C_Trackbar_Orientation.Vertical_TB)
            {
                float fPointValue = fRatio * (Height - fCapWidth) + fCapHalfWidth;
                mousePoint = new PointF(fCapHalfWidth, fPointValue);
            }
            else
            {
                float fPointValue = Height - fCapHalfWidth - fRatio * (Height - fCapWidth);
                mousePoint = new PointF(fCapHalfWidth, fPointValue);
            }

        }

        private void pPointToValue()
        {
            float fCapHalfWidth = 0;
            float fCapWidth = 0;
            if (_IsRound)
            {
                fCapWidth = _BarSize;
                fCapHalfWidth = _BarSize / 2.0f;
            }

            if (_Orientation == C_Trackbar_Orientation.Horizontal_LR)
            {
                float fRatio = Convert.ToSingle(mousePoint.X - fCapHalfWidth) / (Width - fCapWidth);
                _Value = Convert.ToInt32(fRatio * (_Maximum - _Minimum) + _Minimum);
            }
            else if (_Orientation == C_Trackbar_Orientation.Horizontal_RL)
            {
                float fRatio = Convert.ToSingle(Width - mousePoint.X - fCapHalfWidth) / (Width - fCapWidth);
                _Value = Convert.ToInt32(fRatio * (_Maximum - _Minimum) + _Minimum);
            }
            else if (_Orientation == C_Trackbar_Orientation.Vertical_TB)
            {
                float fRatio = Convert.ToSingle(mousePoint.Y - fCapHalfWidth) / (Height - fCapWidth);
                _Value = Convert.ToInt32(fRatio * (_Maximum - _Minimum) + _Minimum);
            }
            else
            {
                float fRatio = Convert.ToSingle(Height - mousePoint.Y - fCapHalfWidth) / (Height - fCapWidth);
                _Value = Convert.ToInt32(fRatio * (_Maximum - _Minimum) + _Minimum);
            }
            if (_Value < _Minimum) _Value = _Minimum;
            if (_Value > _Maximum) _Value = _Maximum;
            CValueChanged?.Invoke(this, new C_Trackbar_EventArgs(_Value));

        }

        #endregion


        protected override void SetBoundsCore(int x, int y, int width, int height, BoundsSpecified specified)
        {
            int iHeight = _BarSize;
            if (_Orientation == C_Trackbar_Orientation.Horizontal_LR || _Orientation == C_Trackbar_Orientation.Horizontal_RL)
            {
                base.SetBoundsCore(x, y, width, iHeight, specified);
            }
            else
            {
                base.SetBoundsCore(x, y, iHeight, height, specified);
            }
        }
        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            pValueToPoint();
            e.Graphics.SmoothingMode = SmoothingMode.HighQuality;

            Pen penBarBack = new Pen(_BarColor, _BarSize);
            Pen penBarFore = new Pen(_SliderColor, _BarSize);

            float fCapHalfWidth = 0;
            float fCapWidth = 0;
            if (_IsRound)
            {
                fCapWidth = _BarSize;
                fCapHalfWidth = _BarSize / 2.0f;
                penBarBack.StartCap = LineCap.Round;
                penBarBack.EndCap = LineCap.Round;

                penBarFore.StartCap = LineCap.Round;
                penBarFore.EndCap = LineCap.Round;
            }

            float fPointValue = 0;
            if (_Orientation == C_Trackbar_Orientation.Horizontal_LR || _Orientation == C_Trackbar_Orientation.Horizontal_RL)
            {
                e.Graphics.DrawLine(penBarBack, fCapHalfWidth, Height / 2f, Width - fCapHalfWidth, Height / 2f);

                fPointValue = mousePoint.X;
                if (fPointValue < fCapHalfWidth) fPointValue = fCapHalfWidth;
                if (fPointValue > Width - fCapHalfWidth) fPointValue = Width - fCapHalfWidth;
            }
            else
            {
                e.Graphics.DrawLine(penBarBack, Width / 2f, fCapHalfWidth, Width / 2f, Height - fCapHalfWidth);

                fPointValue = mousePoint.Y;
                if (fPointValue < fCapHalfWidth) fPointValue = fCapHalfWidth;
                if (fPointValue > Height - fCapHalfWidth) fPointValue = Height - fCapHalfWidth;
            }


            if (_Orientation == C_Trackbar_Orientation.Horizontal_LR)
            {
                e.Graphics.DrawLine(penBarFore, fCapHalfWidth, Height / 2f, fPointValue, Height / 2f);
            }
            else if (_Orientation == C_Trackbar_Orientation.Horizontal_RL)
            {
                e.Graphics.DrawLine(penBarFore, fPointValue, Height / 2f, Width - fCapHalfWidth, Height / 2f);
            }
            else if (_Orientation == C_Trackbar_Orientation.Vertical_TB)
            {
                e.Graphics.DrawLine(penBarFore, Width / 2f, fCapHalfWidth, Width / 2f, fPointValue);
            }
            else
            {
                e.Graphics.DrawLine(penBarFore, Width / 2f, fPointValue, Width / 2f, Height - fCapHalfWidth);
            }
        }
        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            mouseStatus = C_Trackbar_MouseStatus.Down;
            mousePoint = e.Location;
            pPointToValue();
            Invalidate();
        }
        protected override void OnMouseMove(MouseEventArgs e)
        {
            base.OnMouseMove(e);
            if (mouseStatus == C_Trackbar_MouseStatus.Down)
            {
                mousePoint = e.Location;
                pPointToValue();
                Invalidate();
            }
        }
        protected override void OnMouseUp(MouseEventArgs e)
        {
            base.OnMouseUp(e);
            mouseStatus = C_Trackbar_MouseStatus.Up;
        }
        protected override void OnMouseEnter(EventArgs e)
        {
            base.OnMouseEnter(e);
            mouseStatus = C_Trackbar_MouseStatus.Enter;
        }
        protected override void OnMouseLeave(EventArgs e)
        {
            base.OnMouseLeave(e);
            mouseStatus = C_Trackbar_MouseStatus.Leave;
        }
    }
}
