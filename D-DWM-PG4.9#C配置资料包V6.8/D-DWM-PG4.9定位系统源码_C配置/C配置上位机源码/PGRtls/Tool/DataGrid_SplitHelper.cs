using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace PGRtls.Tool
{
    public class DataGrid_SplitHelper
    {
        public bool Is_head { get; private set; }

        public bool Is_end { get; private set; }

        private int _Now_page;
        public int Now_page
        {
            get => _Now_page;
            set
            {
                _Now_page = value;
                if (_Now_page == 1)
                    Is_head = true;
                else
                    Is_head = false;
                if (_Now_page == All_page)
                    Is_end = true;
                else
                    Is_end = false;     
            }
        }

        public int All_page { get; set; }

        public int Page_size { get; set; }

        public int Datatable_MaxLen { get; set; }

        /// <summary>
        /// 根据当前页更新数据表数据
        /// </summary>
        /// <param name="source_dt">数据源</param>
        /// <param name="dgv">要显示的数据表</param>
        public void Refresh(DataTable source_dt, DataGridView dgv)
        {
            if (source_dt == null)
                return;

            int beginRecord, endRecord, i;
            DataTable dataTemp;
                         
            dataTemp = source_dt.Clone();
            beginRecord = Page_size * (Now_page - 1);
            //表格数据到达最后一页但数量不够总数显示
            if (beginRecord + Page_size > Datatable_MaxLen)                
                endRecord = Datatable_MaxLen;                
            else
                endRecord = beginRecord + Page_size;

            for (i = beginRecord; i < endRecord; i++)                
                dataTemp.ImportRow(source_dt.Rows[i]);
                
            dgv.Rows.Clear();
            for (i = 0; i < Page_size; i++)            
                dgv.Rows.Add(dataTemp.Rows[i].ItemArray);
        }

        public void Refresh_Itemsource(DataTable source_dt, DataGridView dgv)
        {
            if (source_dt == null)
                return;
            if (source_dt.Rows.Count == 0)
                return;

            int beginRecord, endRecord, i;
            DataTable dataTemp;

            dataTemp = source_dt.Clone();

            beginRecord = Page_size * (Now_page - 1);
            //表格数据到达最后一页但数量不够总数显示
            if (beginRecord + Page_size > Datatable_MaxLen)
                endRecord = Datatable_MaxLen;
            else
                endRecord = beginRecord + Page_size;

            for (i = beginRecord; i < endRecord; i++)
                dataTemp.ImportRow(source_dt.Rows[i]);

            dgv.DataSource = null;
            dgv.DataSource = dataTemp;
        }


        public DataGrid_SplitHelper(int max_len, int pagesize)
        {
            Now_page = 1;
            Page_size = pagesize;
            Datatable_MaxLen = max_len;
            All_page = Datatable_MaxLen / Page_size;
            if (Datatable_MaxLen % Page_size != 0)
                All_page++;
        }


    }
}
