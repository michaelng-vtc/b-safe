using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maui_pg.Models
{
    public class DeviceCandidate
    {
        private Guid _Id;
        public Guid Id 
        {
            get
            {
                return _Id;
            }
            set
            {
                _Id = value;
                if (string.IsNullOrWhiteSpace(_Id.ToString()))
                {
                    return;
                }
                string[] s = _Id.ToString().Split('-');

                if (s.Length > 0)
                {
                    string showtemp = s[s.Length - 1];
                    string result = string.Empty;
                    for (int i = 0; i < showtemp.Length; i++)
                    {
                        if (i != 0 && i != showtemp.Length - 1 && i % 2 == 0)
                        {
                            result += ":";
                        }
                        result += showtemp[i];
                    }
                    result = result.ToUpper();
                    Show_ID = result;
                }
            }
        }

        public string Show_ID { get; set; }

        public string Name { get; internal set; }
        public int Rssi { get; set; }
    }
}
