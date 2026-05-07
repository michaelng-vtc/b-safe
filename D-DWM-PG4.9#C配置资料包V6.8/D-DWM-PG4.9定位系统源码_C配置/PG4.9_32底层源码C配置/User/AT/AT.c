#include "AT.h"
#include "bsp_uart.h"
#include "string.h"
#include "common_config.h"
#include "ble_app.h"

unsigned char AT_Return_Ok[4] = {'O','K','\r','\n'};
unsigned char AT_Return_error[7] = {'E','R','R','O','R','\r','\n'};
//unsigned char AT_Return_Print[14] = {'A','T','+','P','r','i','n','t','M','o','d','e','\r','\n'};
unsigned char AT_Return_Send[13] = {'A','T','+','D','a','t','a','S','e','n','d','\r','\n'};

uint8_t Recv_method_at = RX_DATA_UART;

//AT读取指令后返回
void AT_Return(int Mode, int At_read_flag)
{
	uint8_t *reply_data_ptr;
	uint8_t data_len = 0;
	switch(Mode)
	{
		
//		case AT_MODE_PRINT:
		case AT_MODE_DATASEND:	
		{
			if(At_read_flag == 0)
			{
				reply_data_ptr = AT_Return_error;
				data_len = sizeof(AT_Return_error);
			}
			else
			{
				reply_data_ptr = AT_Return_Ok;
				data_len = sizeof(AT_Return_Ok);
			}
			break;
		}
		
		case AT_MODE_ASK:
		{
			reply_data_ptr = AT_Return_Send;
			data_len = sizeof(AT_Return_Send);
			break;
		}
		default:break;
	}
	if(Recv_method_at == RX_DATA_UART)
	{
		Uart_Sendstring(reply_data_ptr,data_len);					
	}
	else if(Recv_method_at == RX_DATA_BLE)
	{
		Ble_uart_send_data(reply_data_ptr,data_len);
	}
}


//AT读取指令 对于nrf52832只有一个串口 这个usartNum无效
void AT_Read(unsigned char *buf, int length)
{
	int Read_Flag = 1;   //0 error 1 good
	if(buf[3] == '?')
		AT_Return(AT_MODE_ASK,1);	
	else if(buf[3] == 'D' && buf[4] == 'a' && buf[5] == 't' && buf[6] == 'a' && buf[7] == 'S'
			&& buf[8] == 'e' && buf[9] == 'n' && buf[10] == 'd' && buf[11] == '=')
	{
		Uwb_commu_data_send_t sender; //新建一个发送方结构体对象缓存赋值
		//找到所有的双引号位置
		uint8_t i;
		uint8_t check_index[4] = {0};
		int check_num = 0;
		for(i=0;i<length;i++)
		{
			if(buf[i] == '"')
			{
				if(check_num <= 4)
					check_index[check_num] = i;
				else
				{
					check_num = -1;
					break;
				}
				check_num++;
			}
		}
		
		if(check_index[0] == 12)
		{
			
			memset(sender.DataBuff,0,sizeof(sender.DataBuff));
			if(check_index[1] - 12 - 1 > UWB_COMMU_DATA_MAXLEN)   //要传递的数据大于10字节
			{
				for(i=0;i<UWB_COMMU_DATA_MAXLEN;i++)							
				  sender.DataBuff[i] = buf[13 + i];
				sender.Data_commu_len = UWB_COMMU_DATA_MAXLEN;
			}
			else
			{
				for(i=0;i<check_index[1] - 13;i++)							
				  sender.DataBuff[i] = buf[13 + i];
				sender.Data_commu_len = check_index[1] - 13;
			}						
			sender.Data_commu_En = 1;
		}
		else    //出错
			Read_Flag = 0;
		
		if(Read_Flag == 1 && buf[check_index[2] - 1] == ',' && check_index[3] == length - 3) 
		{
			unsigned char temp[3] = {'0'};
			uint8_t temp_len = 0;
			for(i=0;i<check_index[3] - check_index[2] - 1;i++)
			{
				temp[temp_len] = buf[check_index[2] + 1 + i];
				temp_len++;
			}
			if(temp_len > 0)
			{
				switch(temp_len)
				{
					case 1:
					{
						sender.Data_commu_RevID = temp[0] - 0x30;
						break;
					}
					case 2:
					{
						sender.Data_commu_RevID = (temp[0] - 0x30)*10 + temp[1] - 0x30;
						break;
					}
					case 3:
					{
						sender.Data_commu_RevID = (temp[0] - 0x30)*100 + (temp[1] - 0x30)*10 + temp[2] - 0x30;
						break;
					}
				}
			}
		}
		else
			Read_Flag = 0;
		if(Read_Flag == 1)
		{
			//指令正确 赋值
			memcpy(&(Uwb_commu_helper_ptr->Sender),&sender,sizeof(Uwb_commu_data_send_t));
		}
		AT_Return(AT_MODE_DATASEND,Read_Flag);
	}						 
}




void AT_event(uint8_t* buf, uint16_t length, uint8_t recv_method)
{
	if(buf[0] == 'A' && buf[1] == 'T' && buf[2] == '+'
			&& buf[length - 2] == '\r' && buf[length - 1] == '\n')
	{
		Recv_method_at = recv_method;
		AT_Read(buf,length);
	}	
}
