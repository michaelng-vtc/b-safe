using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maui_pg.Models
{
    //模块功能
    public enum ModuleMode
    {
        tag,
        sub_anc,
        main_anc
    }

    public class Device_pg
    {
        public ModuleMode Module_Mode { get; set; } = ModuleMode.tag;

        public byte Module_id { get; set; }

        public List<UWBAnchor> AnchorList { get; set; } = new List<UWBAnchor>();

    }
}
