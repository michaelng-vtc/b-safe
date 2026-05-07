#ifndef _AT_H
#define _AT_H

#include <stdint.h>

//#define AT_MODE_PRINT     0
#define AT_MODE_DATASEND  1
#define AT_MODE_ASK       2

void AT_event(uint8_t* buf, uint16_t length, uint8_t recv_method);

#endif
