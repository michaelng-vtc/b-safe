using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maui_pg.Uuids
{
    public class Pg_Service_Uuids
    {
        public static Guid Pg_Nordic_uart_service_uuid { get; private set; } = new Guid("6e400001-b5a3-f393-e0a9-e50e24dcca9e");
        public static Guid Pg_Nordic_uart_service_rx_character_uuid { get; private set; } = new Guid("6e400002-b5a3-f393-e0a9-e50e24dcca9e");
        public static Guid Pg_Nordic_uart_service_tx_character_uuid { get; private set; } = new Guid("6e400003-b5a3-f393-e0a9-e50e24dcca9e");
    }
}
