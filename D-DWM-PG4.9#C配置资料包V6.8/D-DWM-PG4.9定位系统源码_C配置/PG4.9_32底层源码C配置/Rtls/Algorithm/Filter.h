#ifndef __Filter_H
#define __Filter_H

typedef struct 
{
	char Dist_index;    //当前标签测距值保存索引 用于记录要保存到数组的第几个数据里
	float Dist[3];       //缓存近3次该基站对标签测距值
//	double Last_Dist;	
	float p_last_x;     //该标签坐标x上一次卡尔曼滤波增益
	float p_last_y;     //该标签坐标y上一次卡尔曼滤波增益
	float p_last_z;     //该标签坐标z上一次卡尔曼滤波增益 
	float last_x;       //该标签上一次坐标x
	float last_y;       //该标签上一次坐标y
	float last_z;       //该标签上一次坐标z
}Tag_t;

extern Tag_t tag_DistList[100];                //标签滤波距离缓存

//double LD(int index, double dist_now);
float Average_ex(int index, float dist_now);
float KalmanFilter(const float ResrcData,float ProcessNiose_Q,float MeasureNoise_R, char idx, char mode);
#endif
