using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PGRtls.Services
{
    public class SelectPointEventArg : EventArgs
    {
        public int X { get; set; }
        public int Y { get; set; }
        public bool Capture_pos { get; set; }

        public SelectPointEventArg(int x, int y, bool capture)
        {
            X = x;
            Y = y;
            Capture_pos = capture;
        }
    }
}
