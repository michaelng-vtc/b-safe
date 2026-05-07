using SQLite;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maui_pg.Models
{
    public class UWBAnchor
    {
        [PrimaryKey, AutoIncrement]
        public int ID_Index { get; set; }
        public short X { get; set; }
        public short Y { get; set; }
        public string ID { get; set; } = string.Empty;

    }
}
