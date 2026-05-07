using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PGRtls.OpenTKHelper
{
    public class DrawModel
    {
        private Color _pColor;
        public Color pColor
        {
            get
            {
                return _pColor;
            }
            set
            {
                _pColor = value;
                fColor = Convert2Float(_pColor);
            }
        }


        private float[] _fColor = new float[3];
        public float[] fColor
        {
            get
            {
                return _fColor;
            }
            private set
            {
                _fColor = value;
            }
        }

        public float[] Convert2Float(Color c)
        {
            float[] RGB_f = new float[3];
            RGB_f[0] = c.R / 255.0f;
            RGB_f[1] = c.G / 255.0f;
            RGB_f[2] = c.B / 255.0f;
            return RGB_f;
        }

        public float[] Pos { get; set; }

        public void SetPos(float x, float y, float z)
        {
            Pos[0] = x;
            Pos[1] = y;
            Pos[2] = z;
        }

        public void SetPos(float[] pos)
        {
            pos.CopyTo(Pos, 0);
        }

        /// <summary>
        /// 生成模型对应顶点 顶点类型float，格式：x y z R G B 
        /// </summary>
        /// <returns></returns>
        public float[] GenVertices()
        {
            float[] result = new float[6];
            Pos.CopyTo(result, 0);
            fColor.CopyTo(result, 3);
            return result;
        }

        public DrawModel()
        {
            Pos = new float[3];
            fColor = new float[3];
        }

        public DrawModel(Color c)
        {
            Pos = new float[3];
            fColor = new float[3];
            pColor = c;
        }

        public DrawModel(Color c, float[] pos)
        {
            Pos = new float[3];
            fColor = new float[3];
            pColor = c;
            SetPos(pos);
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="c">颜色</param>
        /// <param name="x">画面显示坐标x</param>
        /// <param name="y">画面显示坐标y</param>
        /// <param name="z">画面显示坐标z</param>
        public DrawModel(Color c, float x, float y, float z)
        {
            Pos = new float[3];
            fColor = new float[3];
            pColor = c;
            SetPos(x, y, z);
        }
    }
}
