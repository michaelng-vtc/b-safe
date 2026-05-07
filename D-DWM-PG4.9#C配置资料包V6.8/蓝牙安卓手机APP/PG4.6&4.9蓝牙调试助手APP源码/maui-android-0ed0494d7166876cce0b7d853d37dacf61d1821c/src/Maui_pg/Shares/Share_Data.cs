using Maui_pg.Models;
using Maui_pg.Tools.ModbusHelper;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maui_pg.Shares
{
    public class Share_Data
    {
        public static Modbus Modbus_instance { get; set; } = new Modbus(1);

        public static WorkState Work_State { get; set; } = WorkState.Idle;

        public const int ANCHOR_MAX_COUNT = 16;

        public static Device_pg Now_pg_device { get; set; } = new Device_pg();
        public static List<UWBTag> TagList { get; set; } = new List<UWBTag>();
        public static List<UWBAnchor> AncList { get; set; } = new List<UWBAnchor>();

        public static bool Try_FindTag(byte id, out UWBTag t)
        {
            for (int i = 0; i < TagList.Count; i++)
            {
                if (TagList[i].Id == id)
                {
                    t = TagList[i];
                    return true;
                }
            }
            t = new UWBTag();
            return false;
        }

    }
}
