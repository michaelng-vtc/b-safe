#include "Array.h"
#include "string.h"
#include "stdlib.h"

/*! ------------------------------------------------------------------------------------------------------------------
 * @brief 创建数组
 *
 * input parameters
 * @param init_size    数组长度 
 * output parameters
 * 返回创建的数组
 */
Array_t Array_create(uint16_t init_size)
{
	Array_t a;
	a.array = (float*)malloc(sizeof(float) * init_size);
	a.size = init_size;
	return a;
}

/*! ------------------------------------------------------------------------------------------------------------------
* @brief 销毁数组
 *
 * input parameters
 * @param a    数组指针
 * output parameters
 * none
 */
void Array_free(Array_t* a)
{
	free(a->array);
	a->array = NULL;
	a->size = 0;
}

/*! ------------------------------------------------------------------------------------------------------------------
* @brief 获取数组对应索引的元素值
 *
 * input parameters
 * @param a    数组指针
 * @param idx  数组索引
 * output parameters
 * 该索引对应值
 */
float* Array_get(Array_t *a, uint16_t idx)
{
	return &(a->array[idx]);
}

/*! ------------------------------------------------------------------------------------------------------------------
* @brief 设置数组对应索引的元素值
 *
 * input parameters
 * @param a    数组指针
 * @param idx  数组索引
 * output parameters
 * none
 */
void Array_set(Array_t *a, uint16_t idx, float value)
{
	(a->array)[idx] = value;
}

/*! ------------------------------------------------------------------------------------------------------------------
* @brief 获取数组长度
 *
 * input parameters
 * @param a    数组指针
 * output parameters
 * 该数组长度
 */
uint16_t Array_size(const Array_t *a)
{
	return a->size;
}


