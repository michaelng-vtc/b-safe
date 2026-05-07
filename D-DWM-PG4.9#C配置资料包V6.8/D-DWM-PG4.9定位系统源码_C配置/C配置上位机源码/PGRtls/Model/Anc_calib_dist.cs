using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PGRtls.Model
{
    public class Anc_calib_dist
    {
        public string Initial_id { get; set; } = string.Empty;
        public string Passive_id { get; set; } = string.Empty;
        public int Dist { get; set; }
        public bool Twr_success { get; set; }
        public int Error_timeout { get; set; }
        public Anc_calib_dist() { }
    }
}
