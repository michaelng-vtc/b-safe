using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PGRtls.Rtls
{
    public static class Filter
    {
        //卡尔曼滤波 基于下一时刻位置不变模型
        public static double[] Filter_Kalman(double data_now, double data_last, double p_last, double ProcessNiose_Q, double MeasureNoise_R)
        {
            double[] result = new double[2];
            double R = MeasureNoise_R;
            double Q = ProcessNiose_Q;
            double p_mid;
            double p_now;
            double kg;

            p_mid = p_last + Q;                                     //预测本次误差 
            kg = p_mid / (p_mid + R);                               //更新本次卡尔曼增益
            data_now = data_last + kg * (data_now - data_last);     //根据本次观测值预测本次输出
            p_now = (1 - kg) * p_mid;                               //更新误差
            p_last = p_now;                     
            result[0] = data_now;
            result[1] = p_last;
            return result;
        }

       
    }
}
