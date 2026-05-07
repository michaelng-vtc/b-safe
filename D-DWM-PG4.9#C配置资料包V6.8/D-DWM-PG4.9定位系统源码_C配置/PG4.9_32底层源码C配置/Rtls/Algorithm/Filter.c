#include "Filter.h"

Tag_t tag_DistList[100];

/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 滑动去极值取均值滤波
 *
 * input parameters
 * @param index    标签ID 
 * @param dist_now 本次测得距离 
 * output parameters
 * 滤波后的距离值
 */
float Average_ex(int index, float dist_now)
{
	float result = 0;

	float max,min;
	char i;
	Tag_t *t = &tag_DistList[index];
	
	if(t->Dist_index >= 3)
	 t->Dist_index = 0;

	t->Dist[t->Dist_index] = dist_now;  //存入本次测距值
	
	t->Dist_index = t->Dist_index + 1;
	
	//找到最大最小值
	max = t->Dist[0];
	min = max;
	result = max;
	for(i = 1;i < 3;i++)
	{
		if(max < t->Dist[i])
			max = t->Dist[i];
		if(min > t->Dist[i])
			min = t->Dist[i];
		result += t->Dist[i];
	}
	return (result - max - min);
}


/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 卡尔曼滤波 模型为本次位置和上一次相同
 *
 * input parameters
 * @param ResrcData    本次计算得到位置坐标
 * @param ProcessNiose_Q 设定的过程噪声 卡尔曼参数Q
 * @param ProcessNiose_Q 设定的测量噪声 卡尔曼参数R
 * @param idx 标签ID
 * @param mode 滤波情形 0滤波的是x坐标 1滤波y坐标 2滤波z坐标
 * output parameters
 * 滤波后对应的坐标值
 */
float KalmanFilter(const float ResrcData,float ProcessNiose_Q,float MeasureNoise_R, char idx, char mode)
{

    float R = MeasureNoise_R;
    float Q = ProcessNiose_Q;
     
	Tag_t *t = &tag_DistList[idx];
	
    float last_data;
    float filter_data;

    float p_mid;
    float p_now;

    float kg;

	  //根据模式写入信息
	if(mode == 0)
	{
		last_data = t->last_x;                       
		p_mid = t->p_last_x + Q;          //预测本次误差
	}      
	else if(mode == 1)
	{
		last_data = t->last_y; 
		p_mid = t->p_last_y + Q;         //预测本次误差
	}			
	else if(mode == 2)
	{
		last_data = t->last_z;
		p_mid = t->p_last_z + Q;         //预测本次误差
	}


	//计算
    kg = p_mid/(p_mid+R);             //更新本次卡尔曼增益    
    filter_data=last_data+kg*(ResrcData-last_data);   //根据本次观测值预测本次输出
    p_now=(1-kg)*p_mid;               //更新误差  
			
	//更新滤波信息
	if(mode == 0)
	{
		t->last_x = filter_data;                       
		t->p_last_x = p_now;  
	}      
	else if(mode == 1)
	{
		t->last_y = filter_data;                       
		t->p_last_y = p_now;
	}			
	else if(mode == 2)
	{
		t->last_z = filter_data;                       
		t->p_last_z = p_now;
	}	
		
    return filter_data;

}
