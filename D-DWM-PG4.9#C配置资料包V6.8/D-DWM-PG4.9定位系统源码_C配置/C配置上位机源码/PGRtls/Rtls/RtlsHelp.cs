using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using PGRtls.Model;
using MathNet.Numerics.LinearAlgebra.Double;

namespace PGRtls.Rtls
{
    public static class RtlsHelp
    {
        private const int TAYLOR_MAXTIME = 5; //最大收敛5次
        private const double TAYLOR_THRESH_2D = 5;  //二维收敛阈值
        private const double TAYLOR_THRESH_3D = 10;   //三维收敛阈值
        private const double MASS_THRESH = 15;  //质心筛选阈值

        /// <summary>
        /// 计算结果结构
        /// </summary>
        private struct Cal_Result
        {
           public double x;   //计算结果x
           public double y;   //计算结果y
           public double z;   //计算结果z

            public Cal_Result(double cal_x, double cal_y)
            {
                x = cal_x;
                y = cal_y;
                z = 0;
            }
           public Cal_Result(double cal_x, double cal_y, double cal_z)
            {
                x = cal_x;
                y = cal_y;
                z = cal_z;
            }
        }

        private static float Triangle_scale = 1.1f;    //基站筛选过程使用的比例参数

        #region 计算相关函数
        /// <summary>
        /// 计算平面两点距离
        /// </summary>
        /// <param name="x1"></param>
        /// <param name="y1"></param>
        /// <param name="x2"></param>
        /// <param name="y2"></param>
        /// <returns>距离</returns>
        public static double Rtls_Cal_Dist(double x1, double y1, double x2, double y2)
        {
            return Math.Sqrt(Math.Pow(x1 - x2, 2) + Math.Pow(y1 - y2, 2));
        }

        /// <summary>
        /// 计算立体两点距离
        /// </summary>
        /// <param name="x1"></param>
        /// <param name="y1"></param>
        /// <param name="z1"></param>
        /// <param name="x2"></param>
        /// <param name="y2"></param>
        /// <param name="z2"></param>
        /// <returns>距离</returns>
        public static double Rtls_Cal_Dist(double x1, double y1,double z1, double x2, double y2, double z2)
        {
            return Math.Sqrt(Math.Pow(x1 - x2, 2) + Math.Pow(y1 - y2, 2) + Math.Pow(z1 - z2, 2));
        }

        /// <summary>
        /// 判断三个基站是否为符合集合解算规则
        /// </summary>
        /// <param name="anc1"></param>
        /// <param name="anc2"></param>
        /// <param name="anc3"></param>
        /// <returns>true：符合几何解算</returns>
        private static bool Rtls_Judge_ThreeAncsTriangle(Anchor anc1,Anchor anc2,Anchor anc3)
        {
            double Dist_12, Dist_13, Dist_23;
            Dist_12 = Rtls_Cal_Dist(anc1.x, anc1.y, anc2.x, anc2.y);//1、2基站距离	
            Dist_13 = Rtls_Cal_Dist(anc1.x, anc1.y, anc3.x, anc3.y);//1、3基站距离
            Dist_23 = Rtls_Cal_Dist(anc2.x, anc2.y, anc3.x, anc3.y);//2、3基站距离
            if ((Dist_12 + Dist_13) > (Dist_23 * Triangle_scale) && (Dist_12 + Dist_23) > (Dist_13 * Triangle_scale) && (Dist_13 + Dist_23) > (Dist_12 * Triangle_scale))
                return true;
            else
                return false;
        }

        /// <summary>
        /// 判断两两个圆是否相交
        /// </summary>
        /// <param name="r1">圆1半径</param>
        /// <param name="r2">圆2半径</param>
        /// <param name="d">两圆圆心距</param>
        /// <returns>true 相交</returns>
        private static bool Rtls_Judge_CircleIntersection(double r1, double r2, double d)
        {           
            if (r1 + r2 < d)  //相交
            {
                //r1 *= 1.05;
                //r2 *= 1.05;
                //if (r1 + r2 < d)
                    return false;
            }
            if (Math.Abs(r1 - r2) > d) //相离
            {
                //if (r1 > r2)
                //    r2 *= 1.05;
                //else
                //    r1 *= 1.05;
                //if (Math.Abs(r1 - r2) > d)
                    return false ;
            }
            return true ;
        }

        /// <summary>
        ///  判断两条直线是否相交
        /// </summary>
        /// <param name="anc1">基站1</param>
        /// <param name="anc2">基站2</param>
        /// <param name="anc3">基站3</param>
        /// <param name="anc4">基站4</param>
        /// <returns>true：相交</returns>
        private static bool Rtls_Judge_LineIntersect(Anchor anc1, Anchor anc2, Anchor anc3, Anchor anc4)
        {
            //直线L1：(x1,y1)与(x2,y2)所成直线
            //直线L2：(x3,y3)与(x4,y4)所成直线
            double k1, k2;
            //判断是否有竖直的直线
            if (anc1.x == anc2.x || anc3.x == anc4.x)
            {
                //两条都是垂直线
                if (anc1.x == anc2.x && anc3.x == anc4.x)
                    return false;
                else  //其中一条是		
                    return true;
            }
            else
            {
                //计算两直线斜率
                k1 = (anc1.y - anc2.y) / (anc1.x - anc2.x);
                k2 = (anc3.y - anc4.y) / (anc3.x - anc4.x);
                if (k1 * k2 < 0)
                    return true;
                else
                    return false;
            }
        }

        /// <summary>
        /// 泰勒级数收敛
        /// </summary>
        /// <param name="Cal_Anc">用于计算的基站列表</param>
        /// <param name="origin_point">初始坐标点</param>
        /// <param name="Is2D">true则二维模型 否则三维</param>
        /// <param name="diff">计算得出的误差</param>
        /// <returns>true则计算成功 否则失败</returns>
        private static bool Rtls_TaylorUpdate(List<Anchor> Cal_Anc, double[] origin_point, bool Is2D, out double[] diff)
        {
            int Cal_order = Is2D == true ? 2 : 3;
            diff = new double[Cal_order];
            int row = Cal_Anc.Count, i;
            if (origin_point.Length != Cal_order)
                return false;
            try
            {
                DenseMatrix A = new DenseMatrix(row, Cal_order);
                DenseMatrix B = new DenseMatrix(row, 1);
                for (i = 0; i < row; i++)
                {
                    Anchor cal_anc = Cal_Anc[i];
                    if (Is2D)
                    {
                        //二维
                        double dist = Rtls_Cal_Dist(cal_anc.x, cal_anc.y, origin_point[0], origin_point[1]);
                        A[i, 0] = (origin_point[0] - cal_anc.x) / dist;
                        A[i, 1] = (origin_point[1] - cal_anc.y) / dist;
                        B[i, 0] = cal_anc.Dist_Now - dist;
                    }
                    else
                    {
                        //三维
                        double dist = Rtls_Cal_Dist(cal_anc.x, cal_anc.y, cal_anc.z, origin_point[0], origin_point[1], origin_point[3]);
                        A[i, 0] = (origin_point[0] - cal_anc.x) / dist;
                        A[i, 1] = (origin_point[1] - cal_anc.y) / dist;
                        A[i, 2] = (origin_point[2] - cal_anc.z) / dist;
                        B[i, 0] = cal_anc.Dist_Now - dist;
                    }
                }
                //求解
                DenseMatrix ATA = new DenseMatrix(Cal_order, Cal_order);
                ATA = (DenseMatrix)A.Transpose() * A;
                if (ATA.Determinant() == 0)  //奇异矩阵
                    return false;
                DenseMatrix X = (DenseMatrix)ATA.Inverse() * (DenseMatrix)A.Transpose() * B;
                for (i = 0; i < Cal_order; i++)
                    diff[i] = X[i, 0];

            }
            catch
            {
                return false;
            }


            return true;


        }

        #endregion

        #region 二维计算

        /// <summary>
        /// 快速排序 对象为基站类型 排序标准为测距 由小到大排序
        /// </summary>
        /// <param name="sort_data"></param>
        /// <param name="left_idx"></param>
        /// <param name="right_idx"></param>
        private static void Quick_sortAnc(ref List<Anchor> sort_data, int left_idx, int right_idx)
        {
            if (left_idx >= right_idx)
                return;
            
            int i = left_idx, j = right_idx;
            uint base_data = sort_data[left_idx].Dist_Now;
            Anchor temp = sort_data[left_idx];
            while (i < j)
            {
                //从右侧查找小于base的元素
                while (i < j && sort_data[j].Dist_Now >= base_data)
                    j--;
                //找到了
                if (i < j)
                {
                    //将base和右边找到的值交换
                    sort_data[i] = sort_data[j];
                    i++;  //i+1是为了后面开始的从左边找比base大的值
                }
                //从左侧查找大于base的元素
                while (i < j && i < right_idx && sort_data[i].Dist_Now <= base_data)
                    i++;
                //找到了
                if (i < j)
                {
                    //将base和左边找到的值交换
                    sort_data[j] = sort_data[i];
                    j--;  //j-1是为了后面开始的从右边找比base小的值
                }
            }
            //i=j了 这一次找完 将base填到中间
            sort_data[i] = temp;
            if (i != 0)
                Quick_sortAnc(ref sort_data, left_idx, i - 1);  //左侧递归
            if (i != right_idx)
                Quick_sortAnc(ref sort_data, i + 1, right_idx); //右侧递归
        }

        private static double[] Cal_masscenter(List<Cal_Result> points)
        {
            double[] mass_result = new double[2] { 0, 0};
            if (points.Count > 0)
            {
                foreach (Cal_Result cr in points)
                {
                    mass_result[0] += cr.x;
                    mass_result[1] += cr.y;
                }
                mass_result[0] /= points.Count;
                mass_result[1] /= points.Count;                
            }
            return mass_result;
        }

        private static void CenterMass_Select(ref List<Cal_Result> results, out double[] result_mass)
        {
            result_mass = new double[2];
            int i = 0, len = results.Count, max_idx = 0;
            if(len == 1)
            {
                result_mass[0] = results[0].x;
                result_mass[1] = results[0].y;
                return;
            }
            double temp_dist = 0, max_dist = 0;
            
            double[] first_mass = Cal_masscenter(results);
            //找出离质心最远的坐标点
            for (i = 0; i < len; i++)
            {
                temp_dist = Rtls_Cal_Dist(first_mass[0], first_mass[1], results[i].x, results[i].y);
                if (max_dist < temp_dist)
                {
                    max_dist = temp_dist;
                    max_idx = i;
                }
            }
            //将这个坐标点排除后再计算一次质心
            results.RemoveAt(max_idx);
            len = results.Count;
            double[] second_mass = Cal_masscenter(results);
            if (Rtls_Cal_Dist(first_mass[0], first_mass[1], second_mass[0], second_mass[1]) < MASS_THRESH)
            {
                //如果排除了那个最远点后计算的质心和第一次做的质心相差小于设定的阈值则输出第一次质心
                result_mass[0] = first_mass[0];
                result_mass[1] = first_mass[1];
            }
            else
            {
                if (len == 1)  //如果仅剩1个点了 两次取平均输出
                {
                    result_mass[0] = (first_mass[0] + second_mass[0]) / 2;
                    result_mass[1] = (first_mass[1] + second_mass[1]) / 2;
                }
                else  //递归
                    CenterMass_Select(ref results, out result_mass);
            }
        }



        /// <summary>
        /// 二维计算处理
        /// </summary>
        /// <param name="AncList">计算基站列表</param>
        /// <param name="t">本次计算标签</param>
        /// <param name="point_xy">输出的定位解算坐标</param>
        /// <returns>true：本次计算成功</returns>
        public static bool Rtls_2D_Handler(Anchor[] AncList , Tag t, out double[] point_xy)    //三个基站解算二维坐标                      
        {
            int i,j,k;
            List<Cal_Result> Cal_ResultList = new List<Cal_Result>();
            point_xy = new double[2] { 0, 0};
            List<Anchor> Cal_AncList = new List<Anchor>();
            
            for (i = 0; i < AncList.Length; i++)
            {
                //将测距值给到基站
                AncList[i].Dist_Now = t.Dist[i];
                //取得要用于计算的基站
                if (AncList[i].IsUse && t.Dist_Success[i])
                    Cal_AncList.Add(AncList[i]);
            }

            int Cal_Anc_Num = Cal_AncList.Count;

            if (Cal_Anc_Num < 3)    //少于3个基站，无法定位                           
                return false;
            else if(Cal_Anc_Num > 6)
            {
                Quick_sortAnc(ref Cal_AncList, 0, Cal_Anc_Num - 1);
                //排序后只要前六个
                Cal_AncList.RemoveRange(6, Cal_Anc_Num - 6);
                Cal_Anc_Num = 6;
            }
            bool[] Cal_anc_errors = new bool[Cal_Anc_Num];
            //分组每3个进行判断解算坐标
            for (i = 0; i < Cal_Anc_Num - 2; i++)
            {
                for (j = i + 1; j < Cal_Anc_Num - 1; j++)
                {
                    for (k = j + 1; k < Cal_Anc_Num; k++)
                    {
                        Anchor anc1 = Cal_AncList[i];
                        Anchor anc2 = Cal_AncList[j];
                        Anchor anc3 = Cal_AncList[k];
                        if (Rtls_Judge_2D(anc1, anc2, anc3))
                        {
                            double[] result = new double[2];
                            //旧解算方法 直接矩阵解算
                            //if(Rtls_Cal_Pos2D(anc1.x,anc1.y,anc1.Dist_Now,anc2.x,anc2.y,anc2.Dist_Now,anc3.x,anc3.y,anc3.Dist_Now,out result))                            
                            //    Cal_ResultList.Add(new Cal_Result(result[0], result[1]));
                            //新解算方法 三角全质心算法
                            if (Rtls_Cal_Pos2D_Allmass(anc1, anc2, anc3, out result))
                            {
                                Cal_ResultList.Add(new Cal_Result(result[0], result[1]));
                                Cal_anc_errors[i] = true;
                                Cal_anc_errors[j] = true;
                                Cal_anc_errors[k] = true;
                            }
                                
                        }
                    }
                }
            }
            double[] points_result = new double[2] { 0,0};
            //数据结果汇总 目前只是取平均 可以尝试加权等方式来增加鲁棒性
            //if (Cal_ResultList.Count > 0)
            //{
            //    foreach(Cal_Result cr in Cal_ResultList)
            //    {
            //        points_result[0] += cr.x;
            //        points_result[1] += cr.y;
            //    }
            //    points_result[0] /= Cal_ResultList.Count;
            //    points_result[1] /= Cal_ResultList.Count;
            //    //t.CalSuccess = true;
            //    //return true;
            //}
            //else
            //    return false;

            //数据结果汇总 质心筛选
            if (Cal_ResultList.Count > 0)
                CenterMass_Select(ref Cal_ResultList, out points_result);
            else
                return false;


            //先保存未收敛前的值
            //如果后续泰勒收敛失败 输出第一次解析解
            point_xy[0] = points_result[0];
            point_xy[1] = points_result[1];
            t.CalSuccess = true;

            //筛选是否有未参与第一次定位的基站 如果有 则剔除不做后面的泰勒收敛
            int cal_num_temp = Cal_Anc_Num;
            for (i = Cal_Anc_Num - 1; i >= 0; i--)
            {
                if (Cal_anc_errors[i] == false)
                {
                    Cal_AncList.RemoveAt(i);
                    cal_num_temp--;
                }
            }
            Cal_Anc_Num = cal_num_temp;

            //根据初始值，使用泰勒级数收敛
            int Taylor_time = 0;
            bool Taylor_ok = true;
            do
            {
                if (Rtls_TaylorUpdate(Cal_AncList, points_result, true, out double[] result))
                {
                    points_result[0] += result[0];
                    points_result[1] += result[1];
                    if (Math.Abs(result[0]) + Math.Abs(result[1]) < TAYLOR_THRESH_2D)
                        break;                   
                }
                else
                {
                    Taylor_ok = false;
                    break;
                }
            } while (Taylor_time++ < TAYLOR_MAXTIME);

            if(Taylor_ok) //泰勒收敛成功
            {             
                point_xy[0] = points_result[0];
                point_xy[1] = points_result[1];                
            }

            return true;

        }

        /// <summary>
        /// 二维筛选基站
        /// </summary>
        /// <param name="anc1"></param>
        /// <param name="anc2"></param>
        /// <param name="anc3"></param>
        /// <returns>true：该组三个基站可以解算坐标</returns>
        private static bool Rtls_Judge_2D(Anchor anc1, Anchor anc2, Anchor anc3)
        {
            //两圆相交情况
            if (Rtls_Judge_ThreeAncsTriangle(anc1, anc2, anc3))
            {
                //找到最大边长
                double Dist_12, Dist_13, Dist_23;
                Dist_12 = Rtls_Cal_Dist(anc1.x, anc1.y, anc2.x, anc2.y);//1、2基站距离	
                Dist_13 = Rtls_Cal_Dist(anc1.x, anc1.y, anc3.x, anc3.y);//1、3基站距离
                Dist_23 = Rtls_Cal_Dist(anc2.x, anc2.y, anc3.x, anc3.y);//2、3基站距离
                double max_dist = Dist_12;
                if (max_dist < Dist_13)
                    max_dist = Dist_13;
                if (max_dist < Dist_23)
                    max_dist = Dist_23;
                //判断基站对应的测距值是否都大于了最大的边长
                //max_dist *= 1.2;
                if (max_dist < anc1.Dist_Now && max_dist < anc2.Dist_Now && max_dist < anc3.Dist_Now)
                    return false;
                //判断三个圆每两两之间是否相交
                if (Rtls_Judge_CircleIntersection(anc1.Dist_Now, anc2.Dist_Now, Dist_12)
                    && Rtls_Judge_CircleIntersection(anc1.Dist_Now, anc3.Dist_Now, Dist_13)
                    && Rtls_Judge_CircleIntersection(anc2.Dist_Now, anc3.Dist_Now, Dist_23))
                    return true;
                else
                    return false;
            }
            else
                return false;
        }

        /// <summary>
        /// 二维计算坐标 ---直接矩阵解算
        /// </summary>
        /// <param name="x1"></param>
        /// <param name="y1"></param>
        /// <param name="r1"></param>
        /// <param name="x2"></param>
        /// <param name="y2"></param>
        /// <param name="r2"></param>
        /// <param name="x3"></param>
        /// <param name="y3"></param>
        /// <param name="r3"></param>
        /// <param name="result">解算出来的定位坐标</param>
        /// <returns>true:解算成功</returns>
        public static bool Rtls_Cal_Pos2D(double x1, double y1, double r1,
                                    double x2, double y2, double r2,
                                    double x3, double y3, double r3, out double[] result)
        {
            double[,] A = new double[2, 2];
            double[,] B = new double[2, 2];
            double[] C = new double[2];
            result = new double[2];
            A[0, 0] = 2 * (x1 - x2); A[0, 1] = 2 * (y1 - y2);
            A[1, 0] = 2 * (x1 - x3); A[1, 1] = 2 * (y1 - y3);

            double det = 0;
            det = A[0, 0] * A[1, 1] - A[1, 0] * A[0, 1];

            if (det != 0)
            {
                B[0, 0] = A[1, 1] / det;
                B[0, 1] = -A[0, 1] / det;


                B[1, 0] = -A[1, 0] / det;
                B[1, 1] = A[0, 0] / det;

                C[0] = r2 * r2 - r1 * r1 - x2 * x2 + x1 * x1 - y2 * y2 + y1 * y1;
                C[1] = r3 * r3 - r1 * r1 - x3 * x3 + x1 * x1 - y3 * y3 + y1 * y1;

                result[0] = B[0, 0] * C[0] + B[0, 1] * C[1];
                result[1] = B[1, 0] * C[0] + B[1, 1] * C[1];
                return true;
            }
            else
            {
                result[0] = 0;
                result[1] = 0;
                return false;
            }
        }

        /// <summary>
        /// 二维计算坐标 三角全质心算法
        /// </summary>
        /// <param name="a1">基站1</param>
        /// <param name="a2">基站2</param>
        /// <param name="a3">基站3</param>
        /// <param name="result">计算坐标结果</param>
        /// <returns>true则计算成功 否则失败</returns>
        private static bool Rtls_Cal_Pos2D_Allmass(Anchor a1, Anchor a2, Anchor a3, out double[] result)
        {
            result = new double[2];
            try
            {
                DenseMatrix A = new DenseMatrix(3, 3);
                A[0, 0] = -2 * a1.x; A[0, 1] = -2 * a1.y; A[0, 2] = 1;
                A[1, 0] = -2 * a2.x; A[1, 1] = -2 * a2.y; A[1, 2] = 1;
                A[2, 0] = -2 * a3.x; A[2, 1] = -2 * a3.y; A[2, 2] = 1;
                DenseMatrix B = new DenseMatrix(3, 1);
                B[0, 0] = Math.Pow(a1.Dist_Now, 2) - Math.Pow(a1.x, 2) - Math.Pow(a1.y, 2);
                B[1, 0] = Math.Pow(a2.Dist_Now, 2) - Math.Pow(a2.x, 2) - Math.Pow(a2.y, 2);
                B[2, 0] = Math.Pow(a3.Dist_Now, 2) - Math.Pow(a3.x, 2) - Math.Pow(a3.y, 2);

                //求解
                DenseMatrix ATA = new DenseMatrix(3, 3);
                ATA = (DenseMatrix)A.Transpose() * A;
                if (ATA.Determinant() == 0)  //奇异矩阵
                    return false;
                DenseMatrix X = (DenseMatrix)ATA.Inverse() * (DenseMatrix)A.Transpose() * B;
                result[0] = X[0, 0];
                result[1] = X[1, 0];
            }
            catch(Exception ex)
            {
                Console.WriteLine(ex.Message);
                return false;
            }
            return true;
        }

        #endregion

        #region 三维解算

        public static ushort Rtls_3D_Getmaxdist(List<Anchor> cal_anc_list)
        {
            double dist_temp = 0, dist_max = 0; ;
            for (int i = 0; i < cal_anc_list.Count; i++)
            {
                for (int j = i + 1; j < cal_anc_list.Count; j++)
                {
                    dist_temp = Rtls_Cal_Dist(cal_anc_list[i].x, cal_anc_list[i].y, cal_anc_list[i].z,
                                                cal_anc_list[j].x, cal_anc_list[j].y, cal_anc_list[j].z);
                    if(dist_temp > dist_max)
                    {
                        dist_max = dist_temp;
                    }
                }
            }
            return (ushort)dist_max;
        }


        /// <summary>
        /// 三维计算处理
        /// </summary>
        /// <param name="AncList">参与计算基站列表</param>
        /// <param name="t">本次解算的标签</param>
        /// <param name="point_xyz"></param>
        /// <returns></returns>
        public static bool Rtls_3D_Handler(Anchor[] AncList, Tag t, out double[] point_xyz)  //四个基站解算标签三维坐标
        {
            int i;
            List<Cal_Result> Cal_ResultList = new List<Cal_Result>();
            point_xyz = new double[3] { 0, 0, 0 };
            double[] Point_temp = new double[3];
            List<Anchor> Cal_AncList = new List<Anchor>();

            for (i = 0; i < AncList.Length; i++)
            {
                //将测距值给到基站
                AncList[i].Dist_Now = t.Dist[i];
                //取得要用于计算的基站
                if (AncList[i].IsUse && t.Dist_Success[i])
                    Cal_AncList.Add(AncList[i]);
            }

            int Cal_Anc_Num = Cal_AncList.Count;

            if (Cal_Anc_Num < 4)    //少于4个基站，无法定位                           
                return false;

            //检查有无异常距离
            int max_anc_dist = Rtls_3D_Getmaxdist(Cal_AncList) * 2;
            for (i = Cal_AncList.Count - 1; i >= 0; i--)
            {
                if (Cal_AncList[i].Dist_Now > max_anc_dist)
                {
                    Cal_AncList.RemoveAt(i);
                }
            }

            if(Rtls_Cal_Pos3D_LeastSquare(Cal_AncList,out double[] result))
            {
                int Taylor_time = 0;
                bool Taylor_ok = true;
                //先记录当前结果
                Point_temp[0] = result[0];
                Point_temp[1] = result[1];
                Point_temp[2] = result[2];

                do
                {
                    if (Rtls_TaylorUpdate(Cal_AncList, result, false, out double[] diff))
                    {
                        result[0] += diff[0];
                        result[1] += diff[1];
                        result[2] += diff[2];
                        if(Math.Abs(diff[0]) + Math.Abs(diff[1]) + Math.Abs(diff[2]) < TAYLOR_THRESH_3D)
                        {
                            Taylor_ok = true;
                            break;
                        }
                    }
                    else
                    {
                        Taylor_ok = false;
                        break;
                    }
                } while (Taylor_time++ < TAYLOR_MAXTIME);

                if (Taylor_ok)
                {
                    point_xyz[0] = result[0];
                    point_xyz[1] = result[1];
                    point_xyz[2] = result[2];                   
                }
                else
                {
                    point_xyz[0] = Point_temp[0];
                    point_xyz[1] = Point_temp[1];
                    point_xyz[2] = Point_temp[2];
                }
                t.CalSuccess = true;
                return true;
            }
            else
            {
                t.CalSuccess = false;
                return false;
            }

            //分组每4个进行判断解算坐标
            //for (i = 0; i < Cal_Anc_Num - 3; i++)
            //{
            //    for (j = i + 1; j < Cal_Anc_Num - 2; j++)
            //    {
            //        for (k = j + 1; k < Cal_Anc_Num - 1; k++)
            //        {
            //            for (e = k + 1; e < Cal_Anc_Num; e++)
            //            {
            //                Anchor anc1 = Cal_AncList[i];
            //                Anchor anc2 = Cal_AncList[j];
            //                Anchor anc3 = Cal_AncList[k];
            //                Anchor anc4 = Cal_AncList[e];
            //                if (Rtls_Judge_3D(anc1, anc2, anc3,anc4))
            //                {
            //                    double[] result = new double[3];
            //                    if (Rtls_Cal_Pos3D(anc1.x, anc1.y, anc1.z, anc1.Dist_Now, anc2.x, anc2.y, anc2.z, anc2.Dist_Now,
            //                                       anc3.x, anc3.y, anc3.z, anc3.Dist_Now, anc4.x, anc4.y, anc4.z, anc4.Dist_Now ,out result))
            //                        Cal_ResultList.Add(new Cal_Result(result[0], result[1],result[2]));
            //                }
            //            }                        
            //        }
            //    }
            //}

            //数据结果汇总 目前只是取平均 可以尝试加权等方式来增加鲁棒性
            //if (Cal_ResultList.Count > 0)
            //{
            //    foreach (Cal_Result cr in Cal_ResultList)
            //    {
            //        point_xyz[0] += cr.x;
            //        point_xyz[1] += cr.y;
            //        point_xyz[2] += cr.z;
            //    }
            //    point_xyz[0] /= Cal_ResultList.Count;
            //    point_xyz[1] /= Cal_ResultList.Count;
            //    point_xyz[2] /= Cal_ResultList.Count;
            //    t.CalSuccess = true;
            //    return true;
            //}
            //else
            //    return false;
        }

        /// <summary>
        /// 三维坐标筛选基站
        /// </summary>
        /// <param name="anc1"></param>
        /// <param name="anc2"></param>
        /// <param name="anc3"></param>
        /// <param name="anc4"></param>
        /// <returns>true 该组四个基站可以解算坐标</returns>
        public static bool Rtls_Judge_3D(Anchor anc1, Anchor anc2, Anchor anc3, Anchor anc4)
        {
            int i;
            //判断水平坐标下的三个基站能否形成良好的三角形
            if (Rtls_Judge_ThreeAncsTriangle(anc1, anc2, anc3) && Rtls_Judge_ThreeAncsTriangle(anc1, anc2, anc4)
                && Rtls_Judge_ThreeAncsTriangle(anc1, anc3, anc4) && Rtls_Judge_ThreeAncsTriangle(anc2, anc3, anc4))
            {
                //判断立体情况下测距值有没有超过形成的四边形区域
                double[] dist_all_3D = new double[6];
                dist_all_3D[0] = Rtls_Cal_Dist(anc1.x, anc1.y, anc1.z, anc2.x, anc2.y, anc2.z);//1、2基站距离
                dist_all_3D[1] = Rtls_Cal_Dist(anc1.x, anc1.y, anc1.z, anc3.x, anc3.y, anc3.z);//1、3基站距离
                dist_all_3D[2] = Rtls_Cal_Dist(anc1.x, anc1.y, anc1.z, anc4.x, anc4.y, anc4.z);//1、4基站距离
                dist_all_3D[3] = Rtls_Cal_Dist(anc2.x, anc2.y, anc2.z, anc3.x, anc3.y, anc3.z);//2、3基站距离
                dist_all_3D[4] = Rtls_Cal_Dist(anc2.x, anc2.y, anc2.z, anc4.x, anc4.y, anc4.z);//2、4基站距离
                dist_all_3D[5] = Rtls_Cal_Dist(anc3.x, anc3.y, anc3.z, anc4.x, anc4.y, anc4.z);//3、4基站距离
                double max_dist = dist_all_3D[0];
                for (i = 1; i < 6; i++)
                {
                    if (max_dist < dist_all_3D[i])
                        max_dist = dist_all_3D[i];
                }
                //判断基站对应的测距值是否大于了最大的对角线 大于则认为标签在基站包围面外面
                if (anc1.Dist_Now > max_dist && anc2.Dist_Now > max_dist && anc3.Dist_Now > max_dist && anc4.Dist_Now > max_dist)
                    return false;
                else
                {
                    List<Anchor> temp_AncList = new List<Anchor>();
                    temp_AncList.Add(anc1);
                    temp_AncList.Add(anc2);
                    temp_AncList.Add(anc3);
                    temp_AncList.Add(anc4);
                    //由高到低的z轴排序基站
                    for (i = 0; i < temp_AncList.Count - 1; i++)
                    {
                        for(int j = i; j < temp_AncList.Count; j++)
                        {
                            if (temp_AncList[i].z < temp_AncList[j].z)
                            {
                                Anchor temp = temp_AncList[i];
                                temp_AncList[i] = temp_AncList[j];
                                temp_AncList[j] = temp;
                            }
                        }
                    }
                    //取次高减次低要大于100以上才可以满足高度差条件
                    if (temp_AncList[1].z - temp_AncList[2].z < 100)
                        return false;
                    // 计算两高基站和两低基站所成直线的斜率 判断是否两条直线相交

                    if (Rtls_Judge_LineIntersect(temp_AncList[0],temp_AncList[1],temp_AncList[2],temp_AncList[3]))
                        return true;
                    else
                        return false;
                }
            }
            else
                return false;
        }

        /// <summary>
        /// 三维坐标计算算法 ---直接矩阵解算
        /// </summary>
        /// <param name="x1"></param>
        /// <param name="y1"></param>
        /// <param name="z1"></param>
        /// <param name="r1"></param>
        /// <param name="x2"></param>
        /// <param name="y2"></param>
        /// <param name="z2"></param>
        /// <param name="r2"></param>
        /// <param name="x3"></param>
        /// <param name="y3"></param>
        /// <param name="z3"></param>
        /// <param name="r3"></param>
        /// <param name="x4"></param>
        /// <param name="y4"></param>
        /// <param name="z4"></param>
        /// <param name="r4"></param>
        /// <param name="Point_xyz">计算出的标签坐标</param>
        /// <returns>true:解算成功</returns>
        private static bool Get_three_BS_Out_XYZ(double x1, double y1, double z1, double r1,
                                      double x2, double y2, double z2, double r2,
                                      double x3, double y3, double z3, double r3,
                                      double x4, double y4, double z4, double r4,out double[] Point_xyz)//三维坐标求解
        {
            double[,] A = new double[3, 3];
            double[,] B = new double[3, 3];
            double[] C = new double[3];
            Point_xyz = new double[3];
            A[0, 0] = 2 * (x1 - x2); A[0, 1] = 2 * (y1 - y2); A[0, 2] = 2 * (z1 - z2);
            A[1, 0] = 2 * (x1 - x3); A[1, 1] = 2 * (y1 - y3); A[1, 2] = 2 * (z1 - z3);
            A[2, 0] = 2 * (x1 - x4); A[2, 1] = 2 * (y1 - y4); A[2, 2] = 2 * (z1 - z4);
            //B = Inverse(A);

            double det = 0;    //determinant
            det =
                 A[0, 0] * A[1, 1] * A[2, 2] + A[0, 1] * A[1, 2] * A[2, 0] + A[0, 2] * A[1, 0] * A[2, 1] - A[2, 0] * A[1, 1] * A[0, 2] - A[1, 0] * A[0, 1] * A[2, 2] - A[0, 0] * A[2, 1] * A[1, 2];

            if (det != 0)
            {
                B[0, 0] = (A[1, 1] * A[2, 2] - A[1, 2] * A[2, 1]) / det;
                B[0, 1] = -(A[0, 1] * A[2, 2] - A[0, 2] * A[2, 1]) / det;
                B[0, 2] = (A[0, 1] * A[1, 2] - A[0, 2] * A[1, 1]) / det;

                B[1, 0] = -(A[1, 0] * A[2, 2] - A[1, 2] * A[2, 0]) / det;
                B[1, 1] = (A[0, 0] * A[2, 2] - A[0, 2] * A[2, 0]) / det;
                B[1, 2] = -(A[0, 0] * A[1, 2] - A[0, 2] * A[1, 0]) / det;

                B[2, 0] = (A[1, 0] * A[2, 1] - A[1, 1] * A[2, 0]) / det;
                B[2, 1] = -(A[0, 0] * A[2, 1] - A[0, 1] * A[2, 0]) / det;
                B[2, 2] = (A[0, 0] * A[1, 1] - A[0, 1] * A[1, 0]) / det;


                C[0] = r2 * r2 - r1 * r1 - x2 * x2 + x1 * x1 - y2 * y2 + y1 * y1 - z2 * z2 + z1 * z1;
                C[1] = r3 * r3 - r1 * r1 - x3 * x3 + x1 * x1 - y3 * y3 + y1 * y1 - z3 * z3 + z1 * z1;
                C[2] = r4 * r4 - r1 * r1 - x4 * x4 + x1 * x1 - y4 * y4 + y1 * y1 - z4 * z4 + z1 * z1;
                Point_xyz[0] = B[0, 0] * C[0] + B[0, 1] * C[1] + B[0, 2] * C[2];
                Point_xyz[1] = B[1, 0] * C[0] + B[1, 1] * C[1] + B[1, 2] * C[2];
                Point_xyz[2] = B[2, 0] * C[0] + B[2, 1] * C[1] + B[2, 2] * C[2];
                return true;
            }
            else
            {
                Point_xyz[0] = 0;
                Point_xyz[1] = 0;
                Point_xyz[2] = 0;
                return false;
            }
        }
        /****************************************************/

        /// <summary>
        /// 三维坐标计算算法 ---最小二乘法解算（不加权）
        /// </summary>
        /// <param name="x1"></param>
        /// <param name="y1"></param>
        /// <param name="z1"></param>
        /// <param name="r1"></param>
        /// <param name="x2"></param>
        /// <param name="y2"></param>
        /// <param name="z2"></param>
        /// <param name="r2"></param>
        /// <param name="x3"></param>
        /// <param name="y3"></param>
        /// <param name="z3"></param>
        /// <param name="r3"></param>
        /// <param name="x4"></param>
        /// <param name="y4"></param>
        /// <param name="z4"></param>
        /// <param name="r4"></param>
        /// <param name="Point_xyz">计算出的标签坐标</param>
        /// <returns>true:解算成功</returns>
        private static bool Rtls_Cal_Pos3D(double x1, double y1, double z1, double r1,
                                         double x2, double y2, double z2, double r2,
                                         double x3, double y3, double z3, double r3,
                                         double x4, double y4, double z4, double r4,out double[] Point_xyz)//三维坐标求解
        {
            int i, j;
            double[,] A = new double[3, 3];   //以3*3的二维数组A存储矩阵A的数据
            double[,] AT = new double[3, 3];
            double[,] ATA = new double[3, 3];
            double[,] H = new double[3, 3];
            double[,] B = new double[3, 3];
            double[] C = new double[3];
            Point_xyz = new double[3];

            A[0,0] = 2 * (x1 - x2); A[0,1] = 2 * (y1 - y2); A[0,2] = 2 * (z1 - z2);
            A[1,0] = 2 * (x1 - x3); A[1,1] = 2 * (y1 - y3); A[1,2] = 2 * (z1 - z3);
            A[2,0] = 2 * (x1 - x4); A[2,1] = 2 * (y1 - y4); A[2,2] = 2 * (z1 - z4);

            //求A的转置矩阵
            for (i = 0; i < 3; i++)
            {
                for (j = 0; j < 3; j++)
                {
                    AT[i,j] = A[j,i];
                }
            }

            //求AT*A
            for (i = 0; i < 3; i++)
            {
                for (j = 0; j < 3; j++)
                {
                    ATA[i,j] = AT[i,0] * A[0,j] + AT[i,1] * A[1,j] + AT[i,2] * A[2,j];
                }
            }


            //求矩阵ATA的行列式的值
            double det = ATA[0,0] * ATA[1,1] * ATA[2,2] + ATA[0,1] * ATA[1,2] * ATA[2,0] + ATA[0,2] * ATA[1,0] * ATA[2,1]
                       - ATA[2,0] * ATA[1,1] * ATA[0,2] - ATA[1,0] * ATA[0,1] * ATA[2,2] - ATA[0,0] * ATA[2,1] * ATA[1,2];

            if (det != 0)  //只有在矩阵A的行列式不为0时，矩阵A才存在逆矩阵，3*3的二维数组B即为ATA的逆矩阵
            {
                B[0,0] = (ATA[1,1] * ATA[2,2] - ATA[1,2] * ATA[2,1]) / det;
                B[0,1] = -(ATA[0,1] * ATA[2,2] - ATA[0,2] * ATA[2,1]) / det;
                B[0,2] = (ATA[0,1] * ATA[1,2] - ATA[0,2] * ATA[1,1]) / det;

                B[1,0] = -(ATA[1,0] * ATA[2,2] - ATA[1,2] * ATA[2,0]) / det;
                B[1,1] = (ATA[0,0] * ATA[2,2] - ATA[0,2] * ATA[2,0]) / det;
                B[1,2] = -(ATA[0,0] * ATA[1,2] - ATA[0,2] * ATA[1,0]) / det;

                B[2,0] = (ATA[1,0] * ATA[2,1] - ATA[1,1] * ATA[2,0]) / det;
                B[2,1] = -(ATA[0,0] * ATA[2,1] - ATA[0,1] * ATA[2,0]) / det;
                B[2,2] = (ATA[0,0] * ATA[1,1] - ATA[0,1] * ATA[1,0]) / det;


                //求B*AT
                for (i = 0; i < 3; i++)
                {
                    for (j = 0; j < 3; j++)
                    {
                        H[i,j] = B[i,0] * AT[0,j] + B[i,1] * AT[1,j] + B[i,2] * AT[2,j];
                    }
                }
                //数组C为公式H*X=C中的矩阵C
                C[0] = r2 * r2 - r1 * r1 - x2 * x2 + x1 * x1 - y2 * y2 + y1 * y1 - z2 * z2 + z1 * z1;
                C[1] = r3 * r3 - r1 * r1 - x3 * x3 + x1 * x1 - y3 * y3 + y1 * y1 - z3 * z3 + z1 * z1;
                C[2] = r4 * r4 - r1 * r1 - x4 * x4 + x1 * x1 - y4 * y4 + y1 * y1 - z4 * z4 + z1 * z1;

                //将矩阵A的逆矩阵左乘矩阵C得到标签x,y,z的值
                Point_xyz[0] = H[0,0] * C[0] + H[0,1] * C[1] + H[0,2] * C[2];
                Point_xyz[1] = H[1,0] * C[0] + H[1,1] * C[1] + H[1,2] * C[2];
                Point_xyz[2] = H[2,0] * C[0] + H[2,1] * C[1] + H[2,2] * C[2];
                return true;
            }
            else
            {
                Point_xyz[0] = 0;
                Point_xyz[1] = 0;
                Point_xyz[2] = 0;
                return false;
            }          
        }

        /// <summary>
        /// 三维坐标计算算法 最小二乘法
        /// </summary>
        /// <param name="Ancs">计算基站列表</param>
        /// <param name="Point_xyz">计算得出坐标</param>
        /// <returns></returns>
        private static bool Rtls_Cal_Pos3D_LeastSquare(List<Anchor> Ancs, out double[] Point_xyz)
        {
            Point_xyz = new double[3];
            try
            {
                int row = Ancs.Count - 1, i;                
                DenseMatrix A = new DenseMatrix(row, 3);
                DenseMatrix B = new DenseMatrix(row, 1);
                Anchor a0 = Ancs[0];
                for (i = 0; i < row; i++)
                {
                    A[i, 0] = (a0.x - Ancs[i + 1].x) * 2;
                    A[i, 1] = (a0.y - Ancs[i + 1].y) * 2;
                    A[i, 2] = (a0.z - Ancs[i + 1].z) * 2;
                    B[i, 0] = Math.Pow(a0.x, 2) + Math.Pow(a0.y, 2) + Math.Pow(a0.z, 2) - Math.Pow(a0.Dist_Now, 2);
                    B[i, 0] += Math.Pow(Ancs[i + 1].Dist_Now, 2) - Math.Pow(Ancs[i + 1].x, 2) - Math.Pow(Ancs[i + 1].y, 2) - Math.Pow(Ancs[i + 1].z, 2);
                }
                DenseMatrix AT = (DenseMatrix)A.Transpose();
                DenseMatrix ATA = AT * A;
                if (ATA.Determinant() == 0)
                    return false;
                DenseMatrix X = (DenseMatrix)ATA.Inverse() * AT * B;
                Point_xyz[0] = X[0, 0];
                Point_xyz[1] = X[1, 0];
                Point_xyz[2] = X[2, 0];
            }
            catch
            {
                return false;
            }
            return true;


        }
        #endregion

        #region 基站自动标定算法
        /// <summary>
        /// 两测距圆计算标签坐标 需要提前表明是顺时针还是逆时针方向的标签
        /// </summary>
        /// <param name="x1"></param>
        /// <param name="y1"></param>
        /// <param name="r1"></param>
        /// <param name="x2"></param>
        /// <param name="y2"></param>
        /// <param name="r2"></param>
        /// <param name="opt"></param>
        /// <returns></returns>
        public static double[] Rtls_CalIntersection(double x1, double y1, double r1, double x2, double y2, double r2, int opt)
        {
            double[] result = new double[3] { 0, 0, 0 };
            double d12 = Rtls_Cal_Dist(x1, y1, x2, y2);

            if (Rtls_Judge_CircleIntersection(r1, r2, d12) == false)
            {
                return null;
            }

            /* 1. 先算出更靠左边的点 如果垂直则更下面的点*/
            double x_start, y_start, x_end, y_end, r_start, r_end, theta;
            if (x1 == x2)
            {
                //垂直
                x_start = x_end = x1;
                if (y1 > y2)
                {
                    y_start = y2;
                    y_end = y1;
                    r_start = r2;
                    r_end = r1;
                }
                else
                {
                    y_start = y1;
                    y_end = y2;
                    r_start = r1;
                    r_end = r2;
                }
                theta = Math.PI / 2;
            }
            else
            {
                if (x1 > x2)
                {
                    x_start = x2;
                    y_start = y2;
                    r_start = r2;
                    x_end = x1;
                    y_end = y1;
                    r_end = r1;
                }
                else
                {
                    x_start = x1;
                    y_start = y1;
                    r_start = r1;
                    x_end = x2;
                    y_end = y2;
                    r_end = r2;
                }
                theta = Math.Atan2(y_end - y_start, x_end - x_start);
                if (double.IsNaN(theta))
                {
                    return null;
                }
            }

            /* 2. 算出圆心距和两圆交点的角度 */
            
            double roll = Math.Acos((Math.Pow(r_start, 2) + Math.Pow(d12, 2) - Math.Pow(r_end, 2)) / (2 * r_start * d12));
            if (double.IsNaN(roll))
            {
                return null;
            }
            if (opt == 1)
            {
                //逆时针
                result[0] = x_start + Math.Cos(theta + roll) * r_start;
                result[1] = y_start + Math.Sin(theta + roll) * r_start;
            }
            else
            {
                //顺时针
                result[0] = x_start + Math.Cos(theta - roll) * r_start;
                result[1] = y_start + Math.Sin(theta - roll) * r_start;
            }
            return result;
        }

        /// <summary>
        /// 三维坐标计算算法 最小二乘法
        /// </summary>
        /// <param name="Ancs">计算基站列表</param>
        /// <param name="Point_xyz">计算得出坐标</param>
        /// <returns></returns>
        public static bool Rtls_Cal_Pos2D_LeastSquare(List<Calib_anc> Ancs, out double[] Point_xyz)
        {
            Point_xyz = new double[2];
            try
            {
                int row = Ancs.Count - 1, i;
                DenseMatrix A = new DenseMatrix(row, 2);
                DenseMatrix B = new DenseMatrix(row, 1);
                Calib_anc a0 = Ancs[0];
                for (i = 0; i < row; i++)
                {
                    A[i, 0] = (a0.First_x - Ancs[i + 1].First_x) * 2;
                    A[i, 1] = (a0.First_y - Ancs[i + 1].First_y) * 2;
                    B[i, 0] = Math.Pow(a0.First_x, 2) + Math.Pow(a0.First_y, 2) - Math.Pow(a0.Dist_Now, 2);
                    B[i, 0] += Math.Pow(Ancs[i + 1].Dist_Now, 2) - Math.Pow(Ancs[i + 1].First_x, 2) - Math.Pow(Ancs[i + 1].First_y, 2);
                }
                DenseMatrix AT = (DenseMatrix)A.Transpose();
                DenseMatrix ATA = AT * A;
                if (ATA.Determinant() == 0)
                    return false;
                DenseMatrix X = (DenseMatrix)ATA.Inverse() * AT * B;
                Point_xyz[0] = X[0, 0];
                Point_xyz[1] = X[1, 0];
            }
            catch
            {
                return false;
            }
            return true;

        }

        #endregion

    }
}
