using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PGRtls.OpenTKHelper
{
    public class DrawConfig
    {
        public const float DRAW_PLANE_SIZE = 6.0f;
        public const float DRAW_ANCHOR_SIZE = 0.1f;
        public const uint DRAW_LINE_X = 0;
        public const uint DRAW_LINE_Y = 1;
        public const uint DRAW_LINE_Z = 2;

        public struct Confit_t
        {
            public float Max { get; set; }
            public float Min { get; set; }
            public float Scale { get; set; }
            public float Step { get; set; }

            public Confit_t(float max, float min, float step)
            {
                Max = max;
                Min = min;
                Scale = max - min;
                Step = step;
            }
        }

        public Confit_t X_config { get; set; }

        public Confit_t Y_config { get; set; }

        public Confit_t Z_config { get; set; }

        public DrawConfig()
        {

        }

        public void Set_Xconfig(float min, float max, float step)
        {
            X_config = new Confit_t(max, min, step);
        }

        public void Set_Yconfig(float min, float max, float step)
        {
            Y_config = new Confit_t(max, min, step);
        }

        public void Set_Zconfig(float min, float max, float step)
        {
            Z_config = new Confit_t(max, min, step);
        }
    }
}
