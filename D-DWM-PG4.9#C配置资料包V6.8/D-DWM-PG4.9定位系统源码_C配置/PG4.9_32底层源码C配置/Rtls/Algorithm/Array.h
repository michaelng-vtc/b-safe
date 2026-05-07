#ifndef _ARRAY_H
#define _ARRAY_H

#include "stdint.h"

typedef struct 
{
	float *array;
	uint16_t size;
}Array_t;

Array_t Array_create(uint16_t init_size);
void Array_free(Array_t* a);
float* Array_get(Array_t *a, uint16_t idx);
void Array_set(Array_t *a, uint16_t idx, float value);
uint16_t Array_size(const Array_t *a);

#endif
