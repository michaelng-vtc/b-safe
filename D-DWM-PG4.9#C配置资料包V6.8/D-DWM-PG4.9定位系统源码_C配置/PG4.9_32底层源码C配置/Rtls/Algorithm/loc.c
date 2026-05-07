#include "math.h"
#include "loc.h"
#include "arm_math.h"
#include "Array.h"

#define MASS_THRESH 15.0f
#define TAYLOR_2D_THRESH 5.0f
#define TAYLOR_3D_THRESH 5.0f

uint8_t Cal_2D_AllCenterMass(float* Anc_A,float* Anc_B,float* Anc_C, float* Cal_result);

/// <summary>
float Triangle_scale=1.1;    //基站筛选过程使用的比例参数

/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 判断两个圆是否相交
 *
 * input parameters
 * @param r1 圆1半径
 * @param r2 圆2半径 
 * @param d  两圆圆心距
 * output parameters
 * 1代表两圆相交 0则不相交
 */
uint8_t Judge_CircleIntersection(double r1, double r2, double d)
{
	 if(r1 + r2 < d) //可能相离 稍微增大看能否满足
	 {
		r1 *= 1.05;
		r2 *= 1.05;
		if (r1 + r2 < d)
			return 0;
	 }
	 if(fabs(r1 - r2) > d) //再判断是否内含
	 {
		 if(r1 > r2)
			 r2*=1.05;
		 else
			 r1*=1.05;
		 if(fabs(r1 - r2) > d)
			return 0;
	 }
	 return 1;
}


/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 计算两点的二维平面的欧式距离
 *
 * input parameters
 * @param x1 y1 点1的二维坐标
 * @param x2 y2 点2的二维坐标
 * output parameters
 * 两点欧式距离
 */
double Cal_Dist(double x1, double y1, double x2, double y2)
{
	return sqrt(pow((x1-x2),2)+pow((y1-y2),2));
}


/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 计算两点的三维平面的欧式距离
 *
 * input parameters
 * @param x1 y1 z1 点1的三维坐标
 * @param x2 y2 z2 点2的三维坐标
 * output parameters
 * 两点欧式距离
 */
double Cal_Dist_3D(double x1, double y1, double z1, double x2, double y2, double z2)
{
	return sqrt(pow((x1-x2),2)+pow((y1-y2),2)+pow((z1-z2),2));
}


/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 根据数组内对应元素的快速排序（具体原理见百度）
 *
 * input parameters
 * @param (*sort_data)[2] 需要排序的n*2数组 
           要比较的是[][0]的元素大小，最终得到[][0]从小到大排序的数组
 * @param left_idx  从左边开始的索引
 * @param right_idx 从右边开始的索引
 * output parameters  none 
 */
void Quick_Sort_withdata(uint16_t (*sort_data)[2], uint16_t left_idx, uint16_t right_idx)
{
	if(left_idx >= right_idx)
		return;
	
	uint16_t i = left_idx, j = right_idx;
	uint16_t base = sort_data[left_idx][0];
	uint16_t base_temp = sort_data[left_idx][1];
	while(i < j)
	{
		//从右侧查找小于base的元素
		while(i < j && sort_data[j][0] >= base)
			j--;
		//找到了
		if(i < j)
		{
			//将base和右边找到的值交换
			sort_data[i][0] = sort_data[j][0];
			sort_data[i][1] = sort_data[j][1];
			i++;  //i+1是为了后面开始的从左边找比base大的值
		}
		//从左侧查找大于base的元素
		while(i < j && i < right_idx && sort_data[i][0] <= base)  
			i++;
		//找到了
		if(i < j)
		{
			//将base和左边找到的值交换
			sort_data[j][0] = sort_data[i][0];
			sort_data[j][1] = sort_data[i][1];
			j--;  //j-1是为了后面开始的从右边找比base小的值
		}		
	}
	//i=j了 这一次找完 将base填到中间
	sort_data[i][0] = base;
	sort_data[i][1] = base_temp;
	if(i != 0)
		Quick_Sort_withdata(sort_data,left_idx,i - 1);  //左侧递归
	if(i != right_idx)
		Quick_Sort_withdata(sort_data,i + 1,right_idx); //右侧递归
}



/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 判断该三个基站是否适合进行二维解算 
 *        判断是不是有效三角形，筛选排除无效三角形，以便保证良好的数据
 * input parameters
 * @param *anc1 参与解算的基站1坐标数组
 * @param *anc2 参与解算的基站2坐标数组
 * @param *anc3 参与解算的基站3坐标数组
 * output parameters 
   1可用于解算 0不可用
 */
uint8_t Judge_2D (float *anc1,float *anc2, float *anc3)//
{
	float Dist_12,Dist_13,Dist_23;	
	float x1 = anc1[0];
	float y1 = anc1[1];
	float r1 = anc1[2];
	float x2 = anc2[0];
	float y2 = anc2[1];
	float r2 = anc2[2];
	float x3 = anc3[0];
	float y3 = anc3[1];
	float r3 = anc3[2];
	Dist_12=sqrt(pow((x1-x2),2)+pow((y1-y2),2));//1、2基站距离	
	Dist_13=sqrt(pow((x1-x3),2)+pow((y1-y3),2));//1、3基站距离
	Dist_23=sqrt(pow((x2-x3),2)+pow((y2-y3),2));//2、3基站距离
	 
	 //两圆相交情况
	 if((Dist_12+Dist_13)>(Dist_23*Triangle_scale) && (Dist_12+Dist_23)>(Dist_13*Triangle_scale)  &&  (Dist_13+Dist_23)>(Dist_12*Triangle_scale))
	 {
		 //找到最大边长
		 float max_dist = Dist_12;
		 if (max_dist < Dist_13)
					max_dist = Dist_13;
		 if (max_dist < Dist_23)
					max_dist = Dist_23;
		 //判断基站对应的测距值是否都大于了最大的边长
		 //max_dist *= 1.2;
		 if (max_dist < r1 && max_dist < r2 && max_dist < r3)
			  return 0;
		 if(Judge_CircleIntersection(r1,r2,Dist_12) && Judge_CircleIntersection(r1,r3,Dist_13) && Judge_CircleIntersection(r2,r3,Dist_23))
			 return 1;
		 else
			 return 0;
	 }	 
	 else 
		 return 0;
				 
}	

	
/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 判断该四个基站是否适合进行三维解算（5.0版本更新后不使用）
 *        判断是不是有效三角形，筛选排除无效三角形，以便保证良好的数据
 * input parameters
 * @param x1 y1 z1 点1的三维坐标 r1点1本次测距距离
 * @param x2 y2 z2 点2的三维坐标 r2点2本次测距距离
 * @param x3 y3 z3 点3的三维坐标 r3点3本次测距距离
 * @param x4 y4 z4 点4的三维坐标 r4点4本次测距距离
 * output parameters 
   1可用于解算 0不可用
 */
uint8_t Judge_3D (float x1, float y1,float z1, float r1, 
						 float x2, float y2, float z2, float r2, 
			       float x3, float y3, float z3, float r3,
						 float x4, float y4, float z4, float r4 ) 
{
	float dist_all_2D[6];
	float dist_all_3D[6];
	uint8_t i;
	float max_dist;

	//判断基站的水平坐标是否能每三个组成一个三角形
	dist_all_2D[0] = Cal_Dist(x1,y1,x2,y2);//1、2基站距离
	dist_all_2D[1] = Cal_Dist(x1,y1,x3,y3);//1、3基站距离
	dist_all_2D[2] = Cal_Dist(x1,y1,x4,y4);//1、4基站距离
	dist_all_2D[3] = Cal_Dist(x2,y2,x3,y3);//2、3基站距离
	dist_all_2D[4] = Cal_Dist(x2,y2,x4,y4);//2、4基站距离
	dist_all_2D[5] = Cal_Dist(x3,y3,x4,y4);//3、4基站距离

	if(!(dist_all_2D[0]+dist_all_2D[1] > dist_all_2D[3]*Triangle_scale)    //1 2 3基站判断
			&& !(dist_all_2D[0]+dist_all_2D[3] > dist_all_2D[1]*Triangle_scale) 
			&& !(dist_all_2D[1]+dist_all_2D[3] > dist_all_2D[0]*Triangle_scale))
		return 0;

	if(!(dist_all_2D[0]+dist_all_2D[2] > dist_all_2D[4]*Triangle_scale)   //1 2 4基站判断
			&& !(dist_all_2D[0]+dist_all_2D[4] > dist_all_2D[2]*Triangle_scale) 
			&& !(dist_all_2D[2]+dist_all_2D[4] > dist_all_2D[0]*Triangle_scale))
		return 0;	
	
	if(!(dist_all_2D[1]+dist_all_2D[2] > dist_all_2D[5]*Triangle_scale)   //1 3 4基站判断
			&& !(dist_all_2D[1]+dist_all_2D[5] > dist_all_2D[2]*Triangle_scale) 
			&& !(dist_all_2D[2]+dist_all_2D[5] > dist_all_2D[1]*Triangle_scale))
		return 0;	
	
	if(!(dist_all_2D[3]+dist_all_2D[4] > dist_all_2D[5]*Triangle_scale)   // 2 3 4基站判断
			&& !(dist_all_2D[3]+dist_all_2D[5] > dist_all_2D[4]*Triangle_scale) 
			&& !(dist_all_2D[4]+dist_all_2D[5] > dist_all_2D[3]*Triangle_scale))
		return 0;	
	

	//判断基站立体坐标下 通过测距值判断标签点是否在这四个基站内部
	dist_all_3D[0] = Cal_Dist_3D(x1,y1,z1,x2,y2,z2);//1、2基站距离
	dist_all_3D[1] = Cal_Dist_3D(x1,y1,z1,x3,y3,z3);//1、3基站距离
	dist_all_3D[2] = Cal_Dist_3D(x1,y1,z1,x4,y4,z4);//1、4基站距离
	dist_all_3D[3] = Cal_Dist_3D(x2,y2,z2,x3,y3,z3);//2、3基站距离
	dist_all_3D[4] = Cal_Dist_3D(x2,y2,z2,x4,y4,z4);//2、4基站距离
	dist_all_3D[5] = Cal_Dist_3D(x3,y3,z3,x4,y4,z4);//3、4基站距离
	
	//找到最大的对角线值
	max_dist = dist_all_3D[0];
	for(i=1;i<6;i++)
	{
		if(max_dist < dist_all_3D[i])
			max_dist = dist_all_3D[i];
	}
	
	//判断基站对应的测距值是否大于了最大的对角线 大于则认为标签在基站包围面外面
	if(r1 > max_dist && r2 > max_dist && r3 > max_dist && r4 > max_dist)
		return 0;
	else
		return 1;
}					


/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 判断两条直线水平面上是否相交（5.0版本更新后不用）
 * input parameters
 * @param x1 y1  点1的二维坐标
 * @param x2 y2  点2的二维坐标
 * @param x3 y3  点3的二维坐标
 * @param x4 y4  点4的二维坐标
 * output parameters 
   1代表相交 0不相交
 */
uint8_t Rtls_Judge_LineIntersect(double x1, double y1, double x2, double y2, double x3, double y3 , double x4, double y4)
{
	//直线L1：(x1,y1)与(x2,y2)所成直线
	//直线L2：(x3,y3)与(x4,y4)所成直线
	double k1,k2;
	//判断是否有竖直的直线
	if(x1 == x2 || x3 == x4)
	{
		//两条都是垂直线
		if(x1 == x2 && x3 == x4)
			return 0;
		else  //其中一条是		
			return 1;				
	}
	else
	{
		//计算两直线斜率
		k1 = (y1 - y2) / (x1 - x2);
		k2 = (y3 - y4) / (x3 - x4);
		if(k1 * k2 < 0)
			return 1;
		else
			return 0;

	}		
}


/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 判断该四个基站是否适合进行三维解算（5.0版本更新后不用）
 *        在Judge_3D的基础上再判断四个基站是否两高两低对角摆放        
 * input parameters
 * @param *anc0 参与解算的基站0坐标数组
 * @param *anc1 参与解算的基站1坐标数组
 * @param *anc2 参与解算的基站2坐标数组
 * @param *anc3 参与解算的基站3坐标数组
 * output parameters 
   1可用于解算 0不可
 */
uint8_t Judge_3D_New(float *anc0,float *anc1, float *anc2, float *anc3)
{
//	uint8_t flag = 0;
	uint8_t i,j;

	float ancs[4][3];
	float x0 = anc0[0];
	float y0 = anc0[1];
	float z0 = anc0[2];
	float r0 = anc0[3];
	float x1 = anc1[0];
	float y1 = anc1[1];
	float z1 = anc1[2];
	float r1 = anc1[3];
	float x2 = anc2[0];
	float y2 = anc2[1];
	float z2 = anc2[2];	
	float r2 = anc2[3];
	float x3 = anc3[0];
	float y3 = anc3[1];
	float z3 = anc3[2];	
	float r3 = anc3[3];
  
	ancs[0][0] = x0;
	ancs[0][1] = y0;
	ancs[0][2] = z0;
	ancs[1][0] = x1;
	ancs[1][1] = y1;
	ancs[1][2] = z1;
	ancs[2][0] = x2;
	ancs[2][1] = y2;
	ancs[2][2] = z2;
	ancs[3][0] = x3;
	ancs[3][1] = y3;
	ancs[3][2] = z3;
	
	if(Judge_3D(x0, y0, z0, r0, x1, y1, z1, r1, x2, y2, z2, r2, x3, y3, z3, r3))
	{
		//根据高度从高到低排序四个基站
		float sort_z[4] = {0};
		float temp;
//		double k = 0;
		uint8_t temp_index;
		uint8_t sort_index[4] = {0,1,2,3};
		sort_z[0]=z0;
		sort_z[1]=z1;
		sort_z[2]=z2;
		sort_z[3]=z3;
		
		
		for(i=0;i<3;i++)
		{
			for(j=i+1;j<4;j++)
			{
				if(sort_z[i]<sort_z[j])
				{
					temp = sort_z[i];
					sort_z[i] = sort_z[j];
					sort_z[j] = temp;
					temp_index = sort_index[i];
					sort_index[i] = sort_index[j];
					sort_index[j] = temp_index;
				}
			}
		}
		
		//取次高减次低要大于100以上才可以满足高度差条件
		if(sort_z[1] - sort_z[2] < 100)
			return 0;
		
		//计算两高基站和两低基站所成直线的斜率 判断是否两条直线相交
		if(Rtls_Judge_LineIntersect(ancs[sort_index[0]][0],ancs[sort_index[0]][1],ancs[sort_index[1]][0],ancs[sort_index[1]][1],
			 ancs[sort_index[2]][0],ancs[sort_index[2]][1],ancs[sort_index[3]][0],ancs[sort_index[3]][1]))
			return 1;	
		else
			return 0;
	}	
  return 0;	
}



/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 二维解算坐标 采用全质心算法
 *  公式为AX=B => X = (AT * A)^-1 * AT * B
 *     -             -       -        -       -                    -
 *     | -2xa -2ya 1  |      |    x    |      | da^2 - xa^2 - ya^2  |
 * A = | -2xb -2yb 1  |  X = |    y    |  B = | db^2 - xb^2 - yb^2  |
 *     | -2xc -2yc 1  |      | x^2+y^2 |      | dc^2 - xc^2 - yc^2  |
 *     -             -       -        -       -                     -
 * input parameters
 * @param Anc_A  参与解算的基站A坐标数组
 * @param Anc_B  参与解算的基站B坐标数组
 * @param Anc_C  参与解算的基站C坐标数组
 * @param *Cal_result  计算结果坐标
 * output parameters 
   1代表计算成功 0失败
 */
uint8_t Cal_2D_AllCenterMass(float* Anc_A,float* Anc_B,float* Anc_C, float* Cal_result)
{
	uint8_t cal_ok = 1;
	arm_matrix_instance_f32 A_mat;
	arm_matrix_instance_f32 X_mat;
	arm_matrix_instance_f32 B_mat;
	arm_matrix_instance_f32 AT_mat;
	arm_matrix_instance_f32 ATA_mat;
	arm_matrix_instance_f32 ATA_inv_mat;
	arm_matrix_instance_f32 cal_mat;
	arm_status status = ARM_MATH_SUCCESS;
	//由于已经固定了矩阵大小和阶数 不需要变更矩阵行列数
	float32_t A_data[9] =
  {
		-2 * Anc_A[0],-2 * Anc_A[1], 1,
		-2 * Anc_B[0],-2 * Anc_B[1], 1,
		-2 * Anc_C[0],-2 * Anc_C[1], 1,
	};
	float32_t B_data[3] =
	{
		Anc_A[2] * Anc_A[2] - Anc_A[0] * Anc_A[0] - Anc_A[1] * Anc_A[1],
		Anc_B[2] * Anc_B[2] - Anc_B[0] * Anc_B[0] - Anc_B[1] * Anc_B[1],
		Anc_C[2] * Anc_C[2] - Anc_C[0] * Anc_C[0] - Anc_C[1] * Anc_C[1],
	};
	float32_t AT_data[9] ={0};
	float32_t ATA_data[9] ={0};
	float32_t ATA_inv_data[9] ={0};
	float32_t cal_data[9] ={0};
	float32_t X_data[3] ={0};
	
	arm_mat_init_f32(&A_mat, 3, 3, (float32_t *)A_data);
	arm_mat_init_f32(&AT_mat, 3, 3, (float32_t *)AT_data);
	arm_mat_init_f32(&ATA_mat, 3, 3, (float32_t *)ATA_data);
	arm_mat_init_f32(&ATA_inv_mat, 3, 3, (float32_t *)ATA_inv_data);
	arm_mat_init_f32(&cal_mat, 3, 3, (float32_t *)cal_data);
	arm_mat_init_f32(&B_mat, 3, 1 ,(float32_t *)B_data);
	arm_mat_init_f32(&X_mat, 3, 1 ,(float32_t *)X_data);
	
	do
	{
		status = arm_mat_trans_f32(&A_mat,&AT_mat);
		if(status != ARM_MATH_SUCCESS)
		{
			cal_ok = 0;
			break;
		}
		status = arm_mat_mult_f32(&AT_mat,&A_mat,&ATA_mat);
		if(status != ARM_MATH_SUCCESS)
		{
			cal_ok = 0;
			break;
		}
		status = arm_mat_inverse_f32(&ATA_mat,&ATA_inv_mat);
		if(status != ARM_MATH_SUCCESS)
		{
			cal_ok = 0;
			break;
		}
		status = arm_mat_mult_f32(&ATA_inv_mat,&AT_mat,&cal_mat);
		if(status != ARM_MATH_SUCCESS)
		{
			cal_ok = 0;
			break;
		}
		status = arm_mat_mult_f32(&cal_mat,&B_mat,&X_mat);
		if(status != ARM_MATH_SUCCESS)
		{
			cal_ok = 0;
			break;
		}
	}
	while(0);
	
	if(cal_ok)
	{
		Cal_result[0] = X_mat.pData[0];
		Cal_result[1] = X_mat.pData[1];	
		return 1;
	}	
	else
	{
		Cal_result[0] = 0;
		Cal_result[1] = 0;	
		return 0;
	}	
}


/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 计算点集合的质心      
 * input parameters
 * @param (*points)[2] 二维点集合
 * @param len 二维点数量
 * @param *result 计算得出这些点的质心
 * output parameters 
 * none
 */
void Cal_massCenter(float (*points)[2], uint8_t len, float* result)
{
	uint8_t i;
	float mass[2] = {0.0f};
	for(i=0;i<len;i++)
	{
		mass[0] += points[i][0];
		mass[1] += points[i][1];
	}
	mass[0] /= len;
	mass[1] /= len;
	result[0] = mass[0];
	result[1] = mass[1];
}


/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 质心筛选算法 得到多个坐标点中用作泰勒收敛的初值      
 * input parameters
 * @param (*points)[2] 二维点集合
 * @param *result 计算得出这些点的质心
 * output parameters 
 * none
 */
void CenterMass_Select(float (*points)[2], uint8_t len, float* result)
{	
	uint8_t i = 0, max_idx = 0;
	float temp_dist, max_dist = 0;	
	float first_mass[2] = {0.0f}, new_mass[2] = {0.0f}, temp[2] = {0.0f};
	Cal_massCenter(points,len,first_mass);
	//找出离质心最远的坐标点
	for(i=0;i < len;i++)
	{
		temp_dist = Cal_Dist(first_mass[0],first_mass[1],points[i][0],points[i][1]);
		if(max_dist < temp_dist)
		{
			max_dist = temp_dist;
			max_idx = i;
		}
	}
	//将这个坐标点排除后再计算一次质心
	if(max_idx != len - 1)
	{
		temp[0] = points[max_idx][0];
		temp[1] = points[max_idx][1];
		for(i=max_idx;i<len-1;i++)
		{
			points[i][0] = points[i+1][0];
			points[i][1] = points[i+1][1];
		}
		points[len - 1][0] = temp[0];
		points[len - 1][1] = temp[1];
	}
	
	len--;
	Cal_massCenter(points,len,new_mass);
	if(Cal_Dist(first_mass[0],first_mass[1],new_mass[0],new_mass[1]) < MASS_THRESH)
	{
		//如果排除了那个最远点后计算的质心和第一次做的质心相差小于设定的阈值则输出第一次质心
		result[0] = first_mass[0];
		result[1] = first_mass[1];
	}
	else
	{
		if(len == 1)  //如果仅剩1个点了 两次取平均输出
		{
			result[0] = (first_mass[0] + new_mass[0]) / 2;
		  result[1] = (first_mass[1] + new_mass[1]) / 2;
		}
		else  //递归
		  CenterMass_Select(points,len,result);
	}
		
}


/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 二维下泰勒收敛算法（具体原理见百度）
 * 通过计算得到的坐标初值(x0,y0)，测得实际第k个基站到标签距离为d(k),而由标签估算到第k个基站距离为g(k)= sqrt((x0 - xk)^2 + (y0 - yk)^2)
 * 那么满足d(k) - g(k) = Error(k)
 * 需要令Error最小，可以估计迭代值(x',y'),对g(k)进行一阶泰勒展开则有
 *  公式为AX=B => X = (AT * A)^-1 * AT * B
 *     -                               -       -    -        -             -
 *     | (x0 - x1)/g(1) (y0 - y1)/g(1) |       | x' |        | d(1) - g(1) |
 * A = |       ...           ...       |   X = |    |    B = |     ...     |
 *     | (x0 - xk)/g(k) (y0 - yk)/g(k) |       | y' |        | d(k) - g(k) |
 *     -                               -       -    -        -             -
 * input parameters
 * @param (*Ancs)[3]  参与解算的所有基站坐标+距离数组 数组内容 x y dist
 * @param cal_num  参与解算的基站数量
 * @param x0 y0    计算的坐标初值
 * @param *Cal_result  计算结果坐标
 * output parameters 
   1代表计算成功 -1失败
 */
int8_t Cal_Taylor_2D(float (*Ancs)[3],const uint16_t cal_num, float x0, float y0, float *Cal_result)
{
	uint16_t i;
	uint8_t cal_ok = 0;
	float a1,a2,dist;
	arm_matrix_instance_f32 A_mat;
	arm_matrix_instance_f32 X_mat;
	arm_matrix_instance_f32 B_mat;
	arm_matrix_instance_f32 AT_mat;
	arm_matrix_instance_f32 ATA_mat;
	arm_matrix_instance_f32 ATA_inv_mat;
	arm_matrix_instance_f32 cal_mat;
	arm_status status = ARM_MATH_SUCCESS;
	
	Array_t A_data = Array_create(cal_num * 2);
	Array_t B_data = Array_create(cal_num);
	Array_t AT_data = Array_create(2 * cal_num);
	Array_t ATA_data = Array_create(2 * 2);
	Array_t ATA_inv_data = Array_create(2 * 2);
	Array_t cal_data = Array_create(2 * cal_num );
	float32_t X_data[2] ={0};
	
	//各数组赋值
	for(i=0;i<cal_num;i++)
	{
		dist = Cal_Dist(x0,y0,Ancs[i][0],Ancs[i][1]);
		a1 = x0 - Ancs[i][0];
		a2 = y0 - Ancs[i][1];
		Array_set(&A_data,i*2,a1 / dist);
		Array_set(&A_data,i*2+1,a2 / dist);
		Array_set(&B_data,i,Ancs[i][2] - dist);
	}
	memset(AT_data.array,0,AT_data.size);
	memset(ATA_data.array,0,ATA_data.size);
	memset(ATA_inv_data.array,0,ATA_inv_data.size);
	memset(cal_data.array,0,cal_data.size);
	
	//矩阵初始化
	arm_mat_init_f32(&A_mat, cal_num, 2, (float32_t *)A_data.array);
	arm_mat_init_f32(&AT_mat, 2, cal_num, (float32_t *)AT_data.array);
	arm_mat_init_f32(&ATA_mat, 2, 2, (float32_t *)ATA_data.array);
	arm_mat_init_f32(&ATA_inv_mat, 2, 2, (float32_t *)ATA_inv_data.array);
	arm_mat_init_f32(&cal_mat, 2, cal_num, (float32_t *)cal_data.array);
	arm_mat_init_f32(&B_mat, cal_num, 1 ,(float32_t *)B_data.array);
	arm_mat_init_f32(&X_mat, 2, 1 ,(float32_t *)X_data);
	
	do
	{
		status = arm_mat_trans_f32(&A_mat,&AT_mat);
		if(status != ARM_MATH_SUCCESS)	
		{
			cal_ok = 0;
			break;	
		}	
		status = arm_mat_mult_f32(&AT_mat,&A_mat,&ATA_mat);
		if(status != ARM_MATH_SUCCESS)
		{
			cal_ok = 0;
			break;	
		}		
		status = arm_mat_inverse_f32(&ATA_mat,&ATA_inv_mat);
		if(status != ARM_MATH_SUCCESS)
		{
			cal_ok = 0;
			break;	
		}		
		status = arm_mat_mult_f32(&ATA_inv_mat,&AT_mat,&cal_mat);
		if(status != ARM_MATH_SUCCESS)
		{
			cal_ok = 0;
			break;	
		}		
		status = arm_mat_mult_f32(&cal_mat,&B_mat,&X_mat);
		if(status != ARM_MATH_SUCCESS)
		{
			cal_ok = 0;
			break;	
		}
		cal_ok = 1;		
	}
	while(0);
		
	Array_free(&A_data);
	Array_free(&AT_data);
	Array_free(&ATA_data);
	Array_free(&ATA_inv_data);
	Array_free(&cal_data);
	Array_free(&B_data);

	if(cal_ok == 1)
	{
		Cal_result[0]=X_mat.pData[0];
		Cal_result[1]=X_mat.pData[1];
		return 1;
	}
	else
	{
		Cal_result[0]=0;
		Cal_result[1]=0;
		return -1;
	}
	
	
}



/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 三维解算坐标 最小二乘法解算
 *  公式为AX=B => X = (AT * A)^-1 * AT * B
 *     -                                  -      -   -      -                                                        -
 *     | 2(x0 - x1) 2(y0 - y1) 2(z0 - z1) |      | x |      | x0^2 + y0^2 + z0^2 - d0^2 - x1^2 - y1^2 - z1^2 + d1^2  |
 * A = |     ...        ...        ...    |  X = | y |  B = |                         ...                            |
 *     | 2(x0 - xk) 2(y0 - yk) 2(z0 - zk) |      | z |      | x0^2 + y0^2 + z0^2 - d0^2 - xk^2 - yk^2 - zk^2 + dk^2  |
 *     -                                  -      -   -      -                                                        -
 * input parameters
 * @param (*Ancs)[4]  参与解算的所有基站坐标+距离数组 数组内容 x y z dist
 * @param cal_num  参与解算的基站数量
 * @param *Cal_result  计算结果坐标
 * output parameters 
   1代表计算成功 0失败
 */
uint8_t Cal_3D_LeastSquare(const float (*Ancs)[4],const uint8_t cal_num, float* Cal_result)
{
	uint16_t i;
	uint8_t cal_ok = 0;
	float a1,a2,a3,r1;
	uint8_t n = cal_num -1;
	arm_matrix_instance_f32 A_mat;
	arm_matrix_instance_f32 X_mat;
	arm_matrix_instance_f32 B_mat;
	arm_matrix_instance_f32 AT_mat;
	arm_matrix_instance_f32 ATA_mat;
	arm_matrix_instance_f32 ATA_inv_mat;
	arm_matrix_instance_f32 cal_mat;
	arm_status status = ARM_MATH_SUCCESS;
	
	Array_t A_data = Array_create(n * 3);  
	Array_t B_data = Array_create(n);
	Array_t AT_data = Array_create(3 * n);
	Array_t ATA_data = Array_create(3 * 3);
	Array_t ATA_inv_data = Array_create(3 * 3);
	Array_t cal_data = Array_create(3 * n );
	float32_t X_data[3] ={0};
	
	r1 = powf(Ancs[0][0],2) + powf(Ancs[0][1],2) + powf(Ancs[0][2],2) - powf(Ancs[0][3],2);
	//各数组赋值
	for(i=1;i<cal_num;i++)
	{
		a1 = Ancs[0][0] - Ancs[i][0];
		a2 = Ancs[0][1] - Ancs[i][1];
		a3 = Ancs[0][2] - Ancs[i][2];
		
		Array_set(&A_data,(i-1)* 3, a1 * 2);
		Array_set(&A_data,(i-1)* 3 + 1, a2 * 2);
		Array_set(&A_data,(i-1)* 3 + 2, a3 * 2);
		Array_set(&B_data,i-1,r1 - powf(Ancs[i][0],2) - powf(Ancs[i][1],2) - powf(Ancs[i][2],2) + powf(Ancs[i][3],2));
	}
	memset(AT_data.array,0,AT_data.size);
	memset(ATA_data.array,0,ATA_data.size);
	memset(ATA_inv_data.array,0,ATA_inv_data.size);
	memset(cal_data.array,0,cal_data.size);
	
	//矩阵初始化
	arm_mat_init_f32(&A_mat, n, 3, (float32_t *)A_data.array);
	arm_mat_init_f32(&AT_mat, 3, n, (float32_t *)AT_data.array);
	arm_mat_init_f32(&ATA_mat, 3, 3, (float32_t *)ATA_data.array);
	arm_mat_init_f32(&ATA_inv_mat, 3, 3, (float32_t *)ATA_inv_data.array);
	arm_mat_init_f32(&cal_mat, 3, n, (float32_t *)cal_data.array);
	arm_mat_init_f32(&B_mat, n, 1 ,(float32_t *)B_data.array);
	arm_mat_init_f32(&X_mat, 3, 1 ,(float32_t *)X_data);
	
	do
	{
		status = arm_mat_trans_f32(&A_mat,&AT_mat);
		if(status != ARM_MATH_SUCCESS)	
		{
			cal_ok = 0;
			break;	
		}	
		status = arm_mat_mult_f32(&AT_mat,&A_mat,&ATA_mat);
		if(status != ARM_MATH_SUCCESS)
		{
			cal_ok = 0;
			break;	
		}		
		status = arm_mat_inverse_f32(&ATA_mat,&ATA_inv_mat);
		if(status != ARM_MATH_SUCCESS)
		{
			cal_ok = 0;
			break;	
		}		
		status = arm_mat_mult_f32(&ATA_inv_mat,&AT_mat,&cal_mat);
		if(status != ARM_MATH_SUCCESS)
		{
			cal_ok = 0;
			break;	
		}		
		status = arm_mat_mult_f32(&cal_mat,&B_mat,&X_mat);
		if(status != ARM_MATH_SUCCESS)
		{
			cal_ok = 0;
			break;	
		}
		cal_ok = 1;		
	}
	while(0);
	
	//一定要释放内存否则堆溢出
	Array_free(&A_data);
	Array_free(&AT_data);
	Array_free(&ATA_data);
	Array_free(&ATA_inv_data);
	Array_free(&cal_data);
	Array_free(&B_data);

	if(cal_ok == 1)
	{
		Cal_result[0]=X_mat.pData[0];
		Cal_result[1]=X_mat.pData[1];
		Cal_result[2]=X_mat.pData[2];
		return 1;
	}
	else
	{
		Cal_result[0]=0;
		Cal_result[1]=0;
		Cal_result[2]=0;
		return 0;
	}
}



/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 三维下泰勒收敛算法（具体原理见百度）
 * 通过计算得到的坐标初值(x0,y0,z0)，测得实际第k个基站到标签距离为d(k),而由标签估算到第k个基站距离为g(k)= sqrt((x0 - xk)^2 + (y0 - yk)^2 + (z0 - zk)^2)
 * 那么满足d(k) - g(k) = Error(k)
 * 需要令Error最小，可以估计迭代值(x',y',z'),对g(k)进行一阶泰勒展开则有
 *  公式为AX=B => X = (AT * A)^-1 * AT * B
 *     -                                              -       -    -        -             -
 *     | (x0 - x1)/g(1) (y0 - y1)/g(1) (z0 - z1)/g(1) |       | x' |        | d(1) - g(1) |
 * A = |       ...           ...             ...      |   X = | y' |    B = |     ...     |
 *     | (x0 - xk)/g(k) (y0 - yk)/g(k) (z0 - zk)/g(k) |       | z' |        | d(k) - g(k) |
 *     -                                              -       -    -        -             -
 * input parameters
 * @param (*Ancs)[4]  参与解算的所有基站坐标+距离数组 数组内容 x y z dist
 * @param cal_num  参与解算的基站数量
 * @param x0 y0 z0   计算的坐标初值
 * @param *Cal_result  计算结果坐标
 * output parameters 
   1代表计算成功 -1失败
 */
int8_t Cal_Taylor_3D(const float (*Ancs)[4],const uint16_t cal_num, float x0, float y0, float z0, float *Cal_result)
{
	uint16_t i;
	uint8_t cal_ok = 0;
	float a1,a2,a3,dist;
	arm_matrix_instance_f32 A_mat;
	arm_matrix_instance_f32 X_mat;
	arm_matrix_instance_f32 B_mat;
	arm_matrix_instance_f32 AT_mat;
	arm_matrix_instance_f32 ATA_mat;
	arm_matrix_instance_f32 ATA_inv_mat;
	arm_matrix_instance_f32 cal_mat;
	arm_status status = ARM_MATH_SUCCESS;
	
	Array_t A_data = Array_create(cal_num * 3);
	Array_t B_data = Array_create(cal_num);
	Array_t AT_data = Array_create(3 * cal_num);
	Array_t ATA_data = Array_create(3 * 3);
	Array_t ATA_inv_data = Array_create(3 * 3);
	Array_t cal_data = Array_create(3 * cal_num );
	float32_t X_data[3] ={0};
	
	//各数组赋值
	for(i=0;i<cal_num;i++)
	{
		dist = Cal_Dist_3D(x0,y0,z0,Ancs[i][0],Ancs[i][1],Ancs[i][2]);
		a1 = x0 - Ancs[i][0];
		a2 = y0 - Ancs[i][1];
		a3 = z0 - Ancs[i][2];
		
		Array_set(&A_data,i*3,a1 / dist);
		Array_set(&A_data,i*3+1,a2 / dist);
		Array_set(&A_data,i*3+2,a3 / dist);
		Array_set(&B_data,i,Ancs[i][3] - dist);
	}
	memset(AT_data.array,0,AT_data.size);
	memset(ATA_data.array,0,ATA_data.size);
	memset(ATA_inv_data.array,0,ATA_inv_data.size);
	memset(cal_data.array,0,cal_data.size);
	
	//矩阵初始化
	arm_mat_init_f32(&A_mat, cal_num, 3, (float32_t *)A_data.array);
	arm_mat_init_f32(&AT_mat, 3, cal_num, (float32_t *)AT_data.array);
	arm_mat_init_f32(&ATA_mat, 3, 3, (float32_t *)ATA_data.array);
	arm_mat_init_f32(&ATA_inv_mat, 3, 3, (float32_t *)ATA_inv_data.array);
	arm_mat_init_f32(&cal_mat, 3, cal_num, (float32_t *)cal_data.array);
	arm_mat_init_f32(&B_mat, cal_num, 1 ,(float32_t *)B_data.array);
	arm_mat_init_f32(&X_mat, 3, 1 ,(float32_t *)X_data);
	
	do
	{
		status = arm_mat_trans_f32(&A_mat,&AT_mat);
		if(status != ARM_MATH_SUCCESS)	
		{
			cal_ok = 0;
			break;	
		}	
		status = arm_mat_mult_f32(&AT_mat,&A_mat,&ATA_mat);
		if(status != ARM_MATH_SUCCESS)
		{
			cal_ok = 0;
			break;	
		}		
		status = arm_mat_inverse_f32(&ATA_mat,&ATA_inv_mat);
		if(status != ARM_MATH_SUCCESS)
		{
			cal_ok = 0;
			break;	
		}		
		status = arm_mat_mult_f32(&ATA_inv_mat,&AT_mat,&cal_mat);
		if(status != ARM_MATH_SUCCESS)
		{
			cal_ok = 0;
			break;	
		}		
		status = arm_mat_mult_f32(&cal_mat,&B_mat,&X_mat);
		if(status != ARM_MATH_SUCCESS)
		{
			cal_ok = 0;
			break;	
		}
    cal_ok = 1;		
	}
	while(0);
		
	//一定要释放内存否则堆溢出
	Array_free(&A_data);
	Array_free(&AT_data);
	Array_free(&ATA_data);
	Array_free(&ATA_inv_data);
	Array_free(&cal_data);
	Array_free(&B_data);

	if(cal_ok == 1)
	{
		Cal_result[0]=X_mat.pData[0];
		Cal_result[1]=X_mat.pData[1];
		Cal_result[2]=X_mat.pData[2];
		return 1;
	}
	else
	{
		Cal_result[0]=0;
		Cal_result[1]=0;
		Cal_result[2]=0;
		return -1;
	}
	
}




/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 二维解算坐标逻辑
 *                
 * input parameters
 * @param *anc_list 解算基站列表
 * @param *point_out 解算得出标签坐标
 * output parameters 
   1解算成功 0解算失败
 */				
uint8_t Rtls_Cal_2D(Anchor_t *anc_list ,uint32_t Calculate_FLAG, float *point_out)
{
	float point_buf[20][2];  //每三个基站循环定位得到的坐标数据缓存，6取3的组合数量为20
	float point_temp[2] = {0,0};
	float BS_buf_EN [16][3];  //实际使能且测距成功的基站的数据
	uint16_t sort_bs[16][2];
	float x=0,y=0;
	float taylor_result[2] = {0.0f};
	int8_t taylor_time = 5, taylor_ok = -1;
			
	uint8_t BS_EN_num = 0;   //使能且测距成功的基站数量计数
	uint8_t i = 0, num = 0;
	uint8_t E = 0, R = 0, T = 0;
	    
			//赋值到排序数组中
	for(i = 0;i < ANCHOR_LIST_COUNT;i++)
	{
		Anchor_t *a = &anc_list[i];
		if((Calculate_FLAG>>i)&0x01)
		{
			sort_bs[BS_EN_num][0] = a->dist;
			sort_bs[BS_EN_num][1] = i;
			BS_EN_num++;
		}					
	}
			
	if (BS_EN_num < 3)    //少于3个基站，无法定位                           
		return 0;
	else   
	{
		if(BS_EN_num > 6)  //大于6个,根据测距距离大小 排除最大的 排除直到只有6个基站参与解算
		{
			Quick_Sort_withdata(sort_bs,0,BS_EN_num - 1);  //快速从小到大排序
			BS_EN_num = 6;  //只要前六个
			for(i=0;i<BS_EN_num;i++)
			{
				uint16_t anc_idx = sort_bs[i][1];
				BS_buf_EN[i][0] = anc_list[anc_idx].x;
				BS_buf_EN[i][1] = anc_list[anc_idx].y;
				BS_buf_EN[i][2] = anc_list[anc_idx].dist;
			}
		}
		else
		{
			//少于6个直接赋值
			for(i=0;i<BS_EN_num;i++)
			{
				 uint16_t anc_idx = sort_bs[i][1];
				 BS_buf_EN[i][0] = anc_list[anc_idx].x;
				 BS_buf_EN[i][1] = anc_list[anc_idx].y;
				 BS_buf_EN[i][2] = anc_list[anc_idx].dist;
			}
		}					 
	}
             
	for (E = 0; E < (BS_EN_num - 2); E++)  //将所有使能的基站每三个分组进行循环定位
	{
		for (R = E + 1; R < (BS_EN_num - 1); R++)
		{
			for (T = R + 1; T < BS_EN_num; T++)
			{
				uint8_t flag=0;		
				//								 ERROR_FLAG=0;                     //计算耗时，需要归零一下错误标志位，相当于喂狗	 									
				flag=Judge_2D(BS_buf_EN[E], BS_buf_EN[R],BS_buf_EN[T]);
				if(flag == 1)
				{
					uint8_t calsuccess = 0;
					calsuccess = Cal_2D_AllCenterMass(BS_buf_EN[E], BS_buf_EN[R], BS_buf_EN[T], point_temp);
					if(calsuccess == 1)  //计算成功坐标存入数组
					{
						point_buf[num][0] = point_temp[0];
						point_buf[num][1] = point_temp[1];
						num++;    
					}

				}
			}
		}
	}
				
	 point_out[0] = 0.0;
	 point_out[1] = 0.0;
				 
	 //质心筛选
	 if(num > 1)
	 {
		CenterMass_Select(point_buf,num,point_out);
	 }
	 else if(num == 1)
	 {
		point_out[0] = point_buf[0][0];
		point_out[1] = point_buf[0][1]; 
	 }
	 else
		return 0;
			 
//			 for (i = 0; i < num; i++)  //将所有计算得到的数据相加存入point_out
//			 {
//					 point_out[0] += point_buf[i][0];
//					 point_out[1] += point_buf[i][1];
//			 }
//			 if (num != 0)       //取平均值输出坐标数据
//			 {
//					point_out[0] = point_out[0] / num;
//					point_out[1] = point_out[1] / num;
////				 return 1;
//			 }
			 
			 
	x = point_out[0];
	y = point_out[1];
			 
	//Taylor收敛
	taylor_time = 5;
	do
	{
		if(Cal_Taylor_2D(BS_buf_EN,BS_EN_num,x,y,taylor_result) != -1)
		{
			if(fabs(taylor_result[0]) + fabs(taylor_result[1]) < TAYLOR_2D_THRESH)
			{
//				point_out[0] = x + taylor_result[0];
//				point_out[1] = y + taylor_result[1];
				taylor_ok = 1;
				break;
			}
			else
			{
				x += taylor_result[0];
				y += taylor_result[1];
			}						 
		 }
		 else
		 {
			 break;
		 }
	}
	while(taylor_time-- > 0);

	if(taylor_ok == 1)  //收敛成功 如果失败 则输出收敛前的值
	{
		point_out[0] = x + taylor_result[0];
		point_out[1] = y + taylor_result[1];
	}
	return 1;
			 
//	if(taylor_time <= 0)
//	{
//		point_out[0] = x + taylor_result[0];
//		point_out[1] = y + taylor_result[1];
//		return 1;
//	}
//	else
//	{
//		//taylor收敛失败 输出第一次计算出来的值
//		return 1;
//	}
			 			
}	


/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 三维解算坐标逻辑
 *                
 * input parameters
 * @param *anc_list 解算基站列表
 * @param *point_out 解算得出标签坐标
 * output parameters 
   1解算成功 0解算失败
 */				
uint8_t Rtls_Cal_3D(Anchor_t *anc_list ,uint32_t Calculate_FLAG ,float *point_out)
{
//			double point_buf[70][3];  //每四个基站循环定位得到的坐标数据缓存，8取4的组合数量为70,速度大小于89会出问题
	float BS_buf_EN [16][4];  //实际使能且测距成的基站的数据
	uint8_t BS_EN_num = 0;   //使能且测距成功的基站数量计数
	float point_temp[3] = {0.0f}, taylor_result[3] = {0.0f};
	uint16_t sort_bs[16][2];
	int8_t taylor_time = 0, taylor_ok = -1;
	float x = 0,y = 0,z = 0;
			
	int i = 0;
//      int E = 0, R = 0, T = 0, K = 0;
	     
	point_out[0] = 0.0f;
	point_out[1] = 0.0f;
	point_out[2] = 0.0f;
			
	//赋值到排序数组中
	for(i = 0;i < ANCHOR_LIST_COUNT;i++)
	{
		Anchor_t *a = &anc_list[i];
		if((Calculate_FLAG>>i)&0x01)
		{
			sort_bs[BS_EN_num][0] = a->dist;
			sort_bs[BS_EN_num][1] = i;
			BS_EN_num++;
		}					
	  }
			
			
//	for(i = 0;i < ANCHOR_LIST_COUNT;i++)
//	{
//		Anchor *a = &anc_list[i];
//		if((Calculate_FLAG>>i) & 0x01)
//		{
//			BS_buf_EN[BS_EN_num][0] = a->x;
//			BS_buf_EN[BS_EN_num][1] = a->y;
//			BS_buf_EN[BS_EN_num][2] = a->z;
//			BS_buf_EN[BS_EN_num][3] = a->dist;
//			BS_EN_num++;
//		}					
//	}
				
	if (BS_EN_num < 4)    //少于4个基站，无法定位                          
		return 0;
	else if(BS_EN_num > 10) //解算矩阵维度过高发现会解算不了 大于10个基站建议使用软件解算 软件无限制
	{
		Quick_Sort_withdata(sort_bs,0,BS_EN_num - 1);  //快速从小到大排序
		BS_EN_num = 10;  //只要前十个
		for(i=0;i<BS_EN_num;i++)
		{
			uint16_t anc_idx = sort_bs[i][1];
			BS_buf_EN[i][0] = anc_list[anc_idx].x;
			BS_buf_EN[i][1] = anc_list[anc_idx].y;
			BS_buf_EN[i][2] = anc_list[anc_idx].z;
			BS_buf_EN[i][3] = anc_list[anc_idx].dist;
		}
	}
	else  //小于10个直接赋值
	{
		for(i=0;i<BS_EN_num;i++)
		{
			uint16_t anc_idx = sort_bs[i][1];
			BS_buf_EN[i][0] = anc_list[anc_idx].x;
			BS_buf_EN[i][1] = anc_list[anc_idx].y;
			BS_buf_EN[i][2] = anc_list[anc_idx].z;
			BS_buf_EN[i][3] = anc_list[anc_idx].dist;
		}
	}
				
				
	if(Cal_3D_LeastSquare(BS_buf_EN,BS_EN_num,point_temp) == 1)
	{
		x = point_temp[0];
		y = point_temp[1];
		z = point_temp[2];
	}
	 
	point_out[0] = x;
	point_out[1] = y;
	point_out[2] = z;

	//Taylor收敛
	taylor_time = 5;
	do
	{
		if(Cal_Taylor_3D(BS_buf_EN,BS_EN_num,x,y,z,taylor_result) != -1)
		{
			if(fabs(taylor_result[0]) + fabs(taylor_result[1] + fabs(taylor_result[2])) < TAYLOR_3D_THRESH)
			{
//				point_out[0] = x + taylor_result[0];
//				point_out[1] = y + taylor_result[1];
//				point_out[2] = z + taylor_result[2];
				taylor_ok = 1;
				break;
			}
			else
			{
				x += taylor_result[0];
				y += taylor_result[1];
				z += taylor_result[2];
			}						 
		}
		else
		{
			break;
		}
	}
	while(taylor_time-- > 0);
			 
	if(taylor_ok == 1)  //收敛成功 如果失败 则输出收敛前的值
	{
		point_out[0] = x + taylor_result[0];
		point_out[1] = y + taylor_result[1];
		point_out[2] = z + taylor_result[2];
	}
	return 1;
			 
//			 if(taylor_time <= 0)
//			 {
//				 point_out[0] = x + taylor_result[0];
//			   point_out[1] = y + taylor_result[1];
//				 point_out[2] = z + taylor_result[1];
//				 return 1;
//			 }
//			 else
//			 {
//				 //taylor收敛失败 输出第一次计算出来的值
//				 return 1;
//			 }
//				return 0;
}


 
/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 二维解算坐标 直接矩阵解算 旧（5.0更新后不再使用）
 *  公式为AX=B => X = A^-1 * B
 *     -                       -      -   -      -                                          -
 *     | 2(x0 - x1) 2(y0 - y1) |      | x |      | x0^2 + y0^2 - d0^2 - x1^2 - y1^2 + d1^2  |
 * A = |                       |  X = |   |  B = |                                          |
 *     | 2(x0 - x2) 2(y0 - y2) |      | y |      | x0^2 + y0^2 - d0^2 - x2^2 - y2^2 + d2^2  |
 *     -                       -      -   -      -                                          -
 * input parameters
 * @param x1 y1  基站1二维坐标 r1 基站1测得距离
 * @param x2 y2  基站2二维坐标 r2 基站2测得距离
 * @param x3 y3  基站3二维坐标 r3 基站3测得距离
 * @param *PP_point_out  计算结果坐标
 * output parameters 
   1代表计算成功 0失败
 */					
uint8_t Get_three_BS_Out_XY(double x1, double y1, double r1,
												 double x2, double y2, double r2,
												 double x3, double y3, double r3,double *PP_point_out)
{
	double A[2][2];
	double B[2][2];
	double C[2];
	double det = 0;    //determinant
	A[0][0] = 2 * (x1 - x2); 
	A[0][1] = 2 * (y1 - y2); 
	A[1][0] = 2 * (x1 - x3);
	A[1][1] = 2 * (y1 - y3); 
	 
	det =A[0][0] * A[1][1] - A[1][0] * A[0][1];

	if (det != 0)
	{
		B[0][0] = A[1][1] / det;
		B[0][1] = -A[0][1] / det;


		B[1][0] = -A[1][0] / det;
		B[1][1] = A[0][0] / det;

		C[0] = r2 * r2 - r1 * r1 - x2 * x2 + x1 * x1 - y2 * y2 + y1 * y1;
		C[1] = r3 * r3 - r1 * r1 - x3 * x3 + x1 * x1 - y3 * y3 + y1 * y1;

		PP_point_out[0] = B[0][0] * C[0] + B[0][1] * C[1] ;
		PP_point_out[1] = B[1][0] * C[0] + B[1][1] * C[1] ;	
		return 1;
	}
	else
	{
		PP_point_out[0] = 0;
		PP_point_out[1] = 0;
		return 0;
	}
				 
}



/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 三维解算坐标 直接矩阵解算 旧（5.0更新后不再使用）
 *  公式为AX=B => X = A^-1 * B
 *     -                                  -      -   -      -                                                        -
 *     | 2(x0 - x1) 2(y0 - y1) 2(z0 - z1) |      | x |      | x0^2 + y0^2 + z0^2 - d0^2 - x1^2 - y1^2 - z1^2 + d1^2  |
 * A = | 2(x0 - x2) 2(y0 - y2) 2(z0 - y2) |  X = | y |  B = | x0^2 + y0^2 + z0^2 - d0^2 - x2^2 - y2^2 - z2^2 + d2^2  |
 *     | 2(x0 - x3) 2(y0 - y3) 2(z0 - y3) |      | z |      | x0^2 + y0^2 + z0^2 - d0^2 - x3^2 - y2^2 - z3^2 + d3^2  |
 *     -                                  -      -   -      -                                                        -
 * input parameters
 * @param x1 y1 z1  基站1三维坐标 r1 基站1测得距离
 * @param x2 y2 z2  基站2三维坐标 r2 基站2测得距离
 * @param x3 y3 z3  基站3三维坐标 r3 基站3测得距离
 * @param x4 y4 z4  基站4三维坐标 r4 基站4测得距离
 * @param *PP_point_out  计算结果坐标
 * output parameters 
   1代表计算成功 0失败
 */			
uint8_t Get_three_BS_Out_XYZ(double x1, double y1, double z1, double r1,
                           double x2, double y2, double z2, double r2,
                           double x3, double y3, double z3, double r3,
                           double x4, double y4, double z4, double r4,double *Point_xyz)//三维坐标求解
{
	double A[3][3];
	double B[3][3];
	double C[3];
	double det = 0;    //矩阵A的行列式
	//以3*3的二维数组A存储矩阵A的数据
	A[0][0] = 2 * (x1 - x2); A[0][1] = 2 * (y1 - y2); A[0][2] = 2 * (z1 - z2);
	A[1][0] = 2 * (x1 - x3); A[1][1] = 2 * (y1 - y3); A[1][2] = 2 * (z1 - z3);
	A[2][0] = 2 * (x1 - x4); A[2][1] = 2 * (y1 - y4); A[2][2] = 2 * (z1 - z4);  

	//求矩阵A的行列式的值
	det = A[0][0]*A[1][1]*A[2][2]+A[0][1]*A[1][2]*A[2][0]+A[0][2]*A[1][0]*A[2][1]
	-A[2][0]*A[1][1]*A[0][2]-A[1][0]*A[0][1]*A[2][2]-A[0][0]*A[2][1]*A[1][2];

	if (det != 0)  //只有在矩阵A的行列式不为0时，矩阵A才存在逆矩阵，3*3的二维数组B即为A的逆矩阵
	{
		B[0][0] = (A[1][1] * A[2][2] - A[1][2] * A[2][1]) / det;
		B[0][1] = -(A[0][1] * A[2][2] - A[0][2] * A[2][1]) / det;
		B[0][2] = (A[0][1] * A[1][2] - A[0][2] * A[1][1]) / det;

		B[1][0] = -(A[1][0] * A[2][2] - A[1][2] * A[2][0]) / det;
		B[1][1] = (A[0][0] * A[2][2] - A[0][2] * A[2][0]) / det;
		B[1][2] = -(A[0][0] * A[1][2] - A[0][2] * A[1][0]) / det;

		B[2][0] = (A[1][0] * A[2][1] - A[1][1] * A[2][0]) / det;
		B[2][1] = -(A[0][0] * A[2][1] - A[0][1] * A[2][0]) / det;
		B[2][2] = (A[0][0] * A[1][1] - A[0][1] * A[1][0]) / det;

		//数组C为公式A*X=C中的矩阵C
		C[0] = r2 * r2 - r1 * r1 - x2 * x2 + x1 * x1 - y2 * y2 + y1 * y1 - z2 * z2 + z1 * z1;
		C[1] = r3 * r3 - r1 * r1 - x3 * x3 + x1 * x1 - y3 * y3 + y1 * y1 - z3 * z3 + z1 * z1;
		C[2] = r4 * r4 - r1 * r1 - x4 * x4 + x1 * x1 - y4 * y4 + y1 * y1 - z4 * z4 + z1 * z1;

		//将矩阵A的逆矩阵左乘矩阵C得到标签x,y,z的值
		Point_xyz[0] = B[0][0] * C[0] + B[0][1] * C[1] + B[0][2] * C[2];
		Point_xyz[1] = B[1][0] * C[0] + B[1][1] * C[1] + B[1][2] * C[2];
		Point_xyz[2] = B[2][0] * C[0] + B[2][1] * C[1] + B[2][2] * C[2];
		return 1;
	}
	else
	{
		Point_xyz[0] = 0;
		Point_xyz[1] = 0;
		Point_xyz[2] = 0;

	}
	return 0;
}


/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 三维解算坐标 最小二乘法解算 旧（5.0更新后不再使用）
 *  公式为AX=B => X = (AT * A)^-1 * AT * B
 *     -                                  -      -   -      -                                                        -
 *     | 2(x0 - x1) 2(y0 - y1) 2(z0 - z1) |      | x |      | x0^2 + y0^2 + z0^2 - d0^2 - x1^2 - y1^2 - z1^2 + d1^2  |
 * A = | 2(x0 - x2) 2(y0 - y2) 2(z0 - y2) |  X = | y |  B = | x0^2 + y0^2 + z0^2 - d0^2 - x2^2 - y2^2 - z2^2 + d2^2  |
 *     | 2(x0 - x3) 2(y0 - y3) 2(z0 - y3) |      | z |      | x0^2 + y0^2 + z0^2 - d0^2 - x3^2 - y2^2 - z3^2 + d3^2  |
 *     -                                  -      -   -      -                                                        -
 * input parameters
 * @param x1 y1 z1  基站1三维坐标 r1 基站1测得距离
 * @param x2 y2 z2  基站2三维坐标 r2 基站2测得距离
 * @param x3 y3 z3  基站3三维坐标 r3 基站3测得距离
 * @param x4 y4 z4  基站4三维坐标 r4 基站4测得距离
 * @param *PP_point_out  计算结果坐标
 * output parameters 
   1代表计算成功 0失败
 */							 
uint8_t Get_three_BS_Out_XYZ_New(double x1, double y1, double z1, double r1,
								 double x2, double y2, double z2, double r2,
								 double x3, double y3, double z3, double r3,
								 double x4, double y4, double z4, double r4,float *Point_xyz)//三维坐标求解
{
	uint8_t i,j;
	double A[3][3];
	double AT[3][3];
	double ATA[3][3];
	double H[3][3];
	double B[3][3];
	double C[3];
	double det = 0;    //矩阵A的行列式
	//以3*3的二维数组A存储矩阵A的数据
	A[0][0] = 2 * (x1 - x2); A[0][1] = 2 * (y1 - y2); A[0][2] = 2 * (z1 - z2);
	A[1][0] = 2 * (x1 - x3); A[1][1] = 2 * (y1 - y3); A[1][2] = 2 * (z1 - z3);
	A[2][0] = 2 * (x1 - x4); A[2][1] = 2 * (y1 - y4); A[2][2] = 2 * (z1 - z4);  

	//求A的转置矩阵
	for(i=0;i<3;i++)
	{
		for(j=0;j<3;j++)
		{
			AT[i][j] = A[j][i];
		}
	}
 
 //求AT*A
	for(i=0;i<3;i++)
	{
		for(j=0;j<3;j++)
		{
			ATA[i][j] = AT[i][0]*A[0][j]+AT[i][1]*A[1][j]+AT[i][2]*A[2][j];
		}
	}

 
 //求矩阵ATA的行列式的值
	det = ATA[0][0]*ATA[1][1]*ATA[2][2]+ATA[0][1]*ATA[1][2]*ATA[2][0]+ATA[0][2]*ATA[1][0]*ATA[2][1]
			-ATA[2][0]*ATA[1][1]*ATA[0][2]-ATA[1][0]*ATA[0][1]*ATA[2][2]-ATA[0][0]*ATA[2][1]*ATA[1][2];

	 if (det != 0)  //只有在矩阵A的行列式不为0时，矩阵A才存在逆矩阵，3*3的二维数组B即为ATA的逆矩阵
	 {
		B[0][0] = (ATA[1][1] * ATA[2][2] - ATA[1][2] * ATA[2][1]) / det;
		B[0][1] = -(ATA[0][1] * ATA[2][2] - ATA[0][2] * ATA[2][1]) / det;
		B[0][2] = (ATA[0][1] * ATA[1][2] - ATA[0][2] * ATA[1][1]) / det;

		B[1][0] = -(ATA[1][0] * ATA[2][2] - ATA[1][2] * ATA[2][0]) / det;
		B[1][1] = (ATA[0][0] * ATA[2][2] - ATA[0][2] * ATA[2][0]) / det;
		B[1][2] = -(ATA[0][0] * ATA[1][2] - ATA[0][2] * ATA[1][0]) / det;

		B[2][0] = (ATA[1][0] * ATA[2][1] - ATA[1][1] * ATA[2][0]) / det;
		B[2][1] = -(ATA[0][0] * ATA[2][1] - ATA[0][1] * ATA[2][0]) / det;
		B[2][2] = (ATA[0][0] * ATA[1][1] - ATA[0][1] * ATA[1][0]) / det;
			 
		 
		//求B*AT
		for(i=0;i<3;i++)
		{
			for(j=0;j<3;j++)
			{
				H[i][j] = B[i][0]*AT[0][j]+B[i][1]*AT[1][j]+B[i][2]*AT[2][j];
			}
		}
		//数组C为公式H*X=C中的矩阵C
		C[0] = r2 * r2 - r1 * r1 - x2 * x2 + x1 * x1 - y2 * y2 + y1 * y1 - z2 * z2 + z1 * z1;
		C[1] = r3 * r3 - r1 * r1 - x3 * x3 + x1 * x1 - y3 * y3 + y1 * y1 - z3 * z3 + z1 * z1;
		C[2] = r4 * r4 - r1 * r1 - x4 * x4 + x1 * x1 - y4 * y4 + y1 * y1 - z4 * z4 + z1 * z1;

		//将矩阵A的逆矩阵左乘矩阵C得到标签x,y,z的值
		Point_xyz[0] = H[0][0] * C[0] + H[0][1] * C[1] + H[0][2] * C[2];
		Point_xyz[1] = H[1][0] * C[0] + H[1][1] * C[1] + H[1][2] * C[2];
		Point_xyz[2] = H[2][0] * C[0] + H[2][1] * C[1] + H[2][2] * C[2];
		return 1;
	 }
	 else
	 {
		Point_xyz[0] = 0;
		Point_xyz[1] = 0;
		Point_xyz[2] = 0;
	 }
	 return 0;
}
				 
				 
				
