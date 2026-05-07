#ifndef BSP_FLASH_H
#define BSP_FLASH_H

#include <stdint.h>
#include "fds.h"

void Flash_fds_Init(void);
void Flash_read_config(void);
void Flash_write_config(void);

#endif
