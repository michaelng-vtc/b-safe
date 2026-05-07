using CommunityToolkit.Mvvm.Messaging.Messages;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maui_pg.Messages
{
    public class PanMoveArg
    {
        public double Pan_x { get; set; }
        public double Pan_y { get; set; }

        public PanMoveArg(double x, double y)
        {
            Pan_x = x;
            Pan_y = y;
        }
    }

    public class PanMoveMessage : ValueChangedMessage<PanMoveArg>
    {
        public PanMoveMessage(PanMoveArg value) : base(value)
        {
        }
    }
}
