using OpenTK;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PGRtls.OpenTKHelper
{
    public class DrawHelper
    {

        public struct History
        {
            public List<Vector3> positions { get; set; }

            public History(int max)
            {
                positions = new List<Vector3>(max);
            }
        }
       
        public List<History> History_List { get; set; }

        public int Max_HistoryLen { get; set; }
        public int PointStart_idx { get; set; }

        public DrawHelper(int maxlen, int tagNum)
        {
            History_List = new List<History>(maxlen);
            Max_HistoryLen = maxlen;
            for (int i = 0; i < tagNum; i++)
            {
                History_List.Add(new History(maxlen));
            }
        }

        /// <summary>
        /// 往轨迹列表里增加坐标点
        /// </summary>
        /// <param name="idx">标签索引 和标签列表相同</param>
        /// <param name="data">标签实际坐标</param>
        public void Add_HistoryPoint(int idx, Vector3 data)
        {
            History h = History_List[idx];
            if(h.positions.Count >= Max_HistoryLen)
                h.positions.RemoveAt(0);
            h.positions.Add(data);
        }

        public float[] GetPosition(int tag_idx, int history_idx)
        {
            Vector3 v = History_List[tag_idx].positions[history_idx];           
            return new float[] { v.X, v.Y, v.Z };
        }

        public int GetHistoryLen(int tag_idx)
        {
            return History_List[tag_idx].positions.Count;
        }

        /// <summary>
        /// 清除轨迹列表里所有标签点
        /// </summary>
        public void ClearAllHistory()
        {
            foreach(History h in History_List)
            {
                h.positions.Clear();
            }
        }

        public void Dispose()
        {
            History_List.Clear();
            
        }


    }
}
