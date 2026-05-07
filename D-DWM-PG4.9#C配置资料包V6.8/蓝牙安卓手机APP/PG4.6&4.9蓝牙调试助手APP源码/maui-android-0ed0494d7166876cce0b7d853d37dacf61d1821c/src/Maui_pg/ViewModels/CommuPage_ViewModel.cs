using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Maui_pg.Models;
using Maui_pg.Services;
using Maui_pg.Shares;
using Maui_pg.Tools;
using Maui_pg.Tools.ModbusHelper;
using Maui_pg.Uuids;
using Plugin.BLE.Abstractions;
using Plugin.BLE.Abstractions.Contracts;
using Plugin.BLE.Abstractions.EventArgs;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Input;

namespace Maui_pg.ViewModels
{
    [QueryProperty("Page_Title","Page_Title")]
    public partial class CommuPage_ViewModel : ObservableObject
    {
        private BluetoothService Ble_service;
        private IService PG_Nordic_service;
        private ICharacteristic PG_Nordic_rx_characteristic { get; set; }
        private ICharacteristic PG_Nordic_tx_characteristic { get; set; }


        private string _Page_Title;
        public string Page_Title
        {
            get => _Page_Title;
            set => SetProperty(ref _Page_Title, value);
        }

        private string _Log_txt;
        public string Log_txt
        {
            get => _Log_txt;
            set => SetProperty(ref _Log_txt, value);
        }


        private string _Send_txt;
        public string Send_txt
        {
            get => _Send_txt;
            set => SetProperty(ref _Send_txt, value);
        }


        private byte _ModbusId;
        public byte ModbusId
        {
            get => _ModbusId;
            set => SetProperty(ref _ModbusId, value);
        }

        private bool _Data_format_ascii;
        public bool Data_format_ascii
        {
            get => _Data_format_ascii;
            set => SetProperty(ref _Data_format_ascii, value);
        }

        private bool Is_Busy = false;
        private bool Is_connect2Pg = false;
        private bool Is_get_config = false;
        

        public AsyncRelayCommand Connect2DeviceAsyncCommand { get; set; }
        public AsyncRelayCommand DisconnectFromDeviceAsyncCommand { get; set; }
        public AsyncRelayCommand Go2DisplayAsyncCommand { get; set; }
        public AsyncRelayCommand SendDataCommand { get; set; }
        public AsyncRelayCommand ChangeModbusIDCommand { get; set; }
        public ICommand BackCommand { get; set; }

        public CommuPage_ViewModel(BluetoothService ble_service)
        {
            Command_init();
            Ble_service = ble_service;
            Data_format_ascii = true;
            ModbusId = Share_Data.Modbus_instance.ModbusID;
            DataHandle_Helper.Instance.ReadConfig_Event += Instance_ReadConfig_Event;
        }

        private void Instance_ReadConfig_Event(object sender, EventArgs e)
        {
            Is_get_config = true;
        }

        private void Command_init() 
        {
            Connect2DeviceAsyncCommand = new AsyncRelayCommand(Connect2DeviceAsync_Handler);
            DisconnectFromDeviceAsyncCommand = new AsyncRelayCommand(DisconnectFromDeviceAsync_Handler);
            SendDataCommand = new AsyncRelayCommand(SendData_Handler);
            BackCommand = new AsyncRelayCommand(Back_Handler);
            Go2DisplayAsyncCommand = new AsyncRelayCommand(Go2DisplayAsync_Handler);
            ChangeModbusIDCommand = new AsyncRelayCommand(ChangeModbusID_Handler);
        }

        private async Task ChangeModbusID_Handler()
        {
            string result = await Shell.Current.DisplayPromptAsync("ModbusID", "设置ModbusID", initialValue: ModbusId.ToString(), maxLength: 3, keyboard: Keyboard.Numeric);
            if(string.IsNullOrWhiteSpace(result))
            {
                return;
            }
            if (!byte.TryParse(result,out byte r))
            {
                await Shell.Current.DisplayAlert("提示", "请输入0-255范围内数字!", "ok");
                return;
            }
            ModbusId = r;
        }

        private async Task Go2DisplayAsync_Handler()
        {
            await Shell.Current.GoToAsync("///DisplayPage", true);
        }

        private async Task Back_Handler()
        {
            DataHandle_Helper.Instance.ReadConfig_Event -= Instance_ReadConfig_Event;
            bool result = await Shell.Current.DisplayAlert("提示", "退出则断开该蓝牙连接", "好的", "取消");
            if (result)
            {
                //断开蓝牙连接
                await DisconnectFromDeviceAsync_Handler();
                //返回上一页
                await Shell.Current.GoToAsync("..", true);  //..
            }

        }

        private async Task SendData_Handler()
        {
            if (!Ble_service.BluetoothLE.IsOn)
            {
                await Shell.Current.DisplayAlert("提示", "蓝牙未开启", "OK");
                return;
            }
            if (string.IsNullOrWhiteSpace(Send_txt))
            {
                await Shell.Current.DisplayAlert("提示", "发送数据不能为空!", "OK");
                return;
            }
            if (!Get_DataSend_byte(Send_txt, !Data_format_ascii, out byte[] send_buff)) 
            {
                await Shell.Current.DisplayAlert("提示", "发送解析有误!", "OK");
                return;
            }
            if(PG_Nordic_rx_characteristic == null)
            {
                await Shell.Current.DisplayAlert("提示", "发送服务无效!", "OK");
                return;
            }
            if (!PG_Nordic_rx_characteristic.CanWrite)
            {
                await Shell.Current.DisplayAlert("提示", "禁止发送!", "OK");
                return;
            }
            if (send_buff == null)
            {
                return;
            }
            string send_str = ByteBuff_To_HexString(send_buff);
            if (string.IsNullOrWhiteSpace(send_str))
            {
                return;
            }
            Add_Log_tx($"[Tx] -> {send_str}");
            
            await PG_Nordic_rx_characteristic.WriteAsync(send_buff);
            
        }

        /// <summary>
        /// 通过输入的字符串转换成字节数据
        /// </summary>
        /// <param name="input_str">输入字符串</param>
        /// <param name="Is_hex">是否hex发送</param>
        /// <returns></returns>
        bool Get_DataSend_byte(string input_str, bool Is_hex, out byte[] send_buff)
        {
            send_buff = new byte[0];
            if (string.IsNullOrEmpty(input_str))
            {
                return false;
            }
            ////排除首尾多余的空格
            while (input_str.IndexOf(' ') == 0)
                input_str = input_str.Remove(0, 1);
            while (input_str.LastIndexOf(' ') == input_str.Length - 1)
                input_str = input_str.Remove(input_str.Length - 1);
            //转换成数组
            if (Is_hex)
            {
                //转换为16进制
                string[] str_sp = input_str.Split(' ');
                if (str_sp.Length > 0)
                {                    
                    try
                    {
                        send_buff = new byte[str_sp.Length];
                        for (int i = 0; i < str_sp.Length; i++)
                        {
                            send_buff[i] = Convert.ToByte(str_sp[i], 16);
                        }
                    }
                    catch
                    {
                        return false;
                    }
                }
            }
            else
            {

                try
                {
                    send_buff = Encoding.ASCII.GetBytes(input_str);
                }
                catch (Exception)
                {
                    return false;
                }
            }
            return true;
        }


        private void Add_Log_tx(string str)
        {
            Log_txt += $"{DateTime.Now:yyyy/MM/dd HH:mm:ss fff}: {str}\r\n";
            if(Log_txt.Length > 10000)
            {
                Log_txt = string.Empty;
            }
        }

        private string ByteBuff_To_HexString(byte[] buff)
        {
            if(buff == null)
            {
                return string.Empty;
            }
            if(buff.Length == 0)
            {
                return string.Empty;
            }
            StringBuilder sb = new StringBuilder(buff.Length * 2);
            for (int i = 0; i < buff.Length; i++)
            {
                sb.Append($"{buff[i].ToString("x2")} ");
            }
            return sb.ToString();
        }


        private async Task Connect2DeviceAsync_Handler()
        {
            if (!Ble_service.BluetoothLE.IsOn)
            {
                await Shell.Current.DisplayAlert($"提示", $"蓝牙未开启", "OK");
                return;
            }

            if (Ble_service.Adapter.IsScanning)
            {
                await Ble_service.ShowToastAsync("蓝牙正在搜索设备，请等待完成后重试");
                return;
            }

            try
            {
                Is_Busy = true;
                Add_Log_tx("开始连接设备!");
                if (Ble_service.Device != null)
                {
                    if (Ble_service.Device.State == DeviceState.Connected)
                    {
                        if (Ble_service.Device.Id.Equals(Ble_service.NowSelect_Device.Id))
                        {
                            //await Ble_service.ShowToastAsync($"{Ble_service.Device.Name} is already connected.");
                            Add_Log_tx("该设备已连接!");
                            return;
                        }

                        if (Ble_service.NowSelect_Device != null)
                        {
                            #region another device
                            if (!Ble_service.Device.Id.Equals(Ble_service.NowSelect_Device.Id))
                            {
                                await DisconnectFromDeviceAsync_Handler();
                                Add_Log_tx("断开该设备连接!");
                                //await Ble_service.ShowToastAsync($"{Ble_service.Device.Name} has been disconnected.");
                            }
                            #endregion another device
                        }
                    }
                }

                Ble_service.Device = await Ble_service.Adapter.ConnectToKnownDeviceAsync(Ble_service.NowSelect_Device.Id);

                if (Ble_service.Device.State == DeviceState.Connected)
                {
                    //await Ble_service.ShowToastAsync($"{Ble_service.Device.Name} connect ok.");
                    Add_Log_tx("设备连接成功!开始获取服务");

                    /* 获取服务 */
                    PG_Nordic_service = await Ble_service.Device.GetServiceAsync(Pg_Service_Uuids.Pg_Nordic_uart_service_uuid);
                    if (PG_Nordic_service == null)
                    {
                        Add_Log_tx("获取PG服务UUID失败，将断开连接!");
                        Is_connect2Pg = false;
                        return;
                    }

                    Add_Log_tx("获取服务成功!");
                    Is_connect2Pg = true;
                    //rx特征符代表发送给蓝牙设备的服务特征
                    PG_Nordic_rx_characteristic = await PG_Nordic_service.GetCharacteristicAsync(Pg_Service_Uuids.Pg_Nordic_uart_service_rx_character_uuid);
                    if (PG_Nordic_rx_characteristic == null)
                    {
                        Add_Log_tx("获取PG服务rx特征UUID失败，将断开连接!");
                        return;
                    }
                    CharacteristicPropertyType rx_property = PG_Nordic_rx_characteristic.Properties;
                    Add_Log_tx($"PG_Nordic_rx_characteristic: property=>[{rx_property}]!");

                    //tx特征符代表接收到蓝牙设备数据的服务特征
                    PG_Nordic_tx_characteristic = await PG_Nordic_service.GetCharacteristicAsync(Pg_Service_Uuids.Pg_Nordic_uart_service_tx_character_uuid);
                    if (PG_Nordic_tx_characteristic == null)
                    {
                        Add_Log_tx("获取PG服务tx特征UUID失败，将断开连接!");
                        return;
                    }
                    CharacteristicPropertyType tx_property = PG_Nordic_tx_characteristic.Properties;
                    Add_Log_tx($"PG_Nordic_tx_characteristic: property=>[{tx_property}]!");
                    if (PG_Nordic_tx_characteristic.CanUpdate)  //绑定接收事件
                    {
                        PG_Nordic_tx_characteristic.ValueUpdated += PG_Nordic_tx_characteristic_ValueUpdated;
                        await PG_Nordic_tx_characteristic.StartUpdatesAsync();
                    }

                    //确认连接完成 发送数据尝试获取模块信息
                    await CheckPG_Config();
                }
            }
            catch (Exception ex)
            {
                Add_Log_tx($"设备连接失败! [{ex.Message}]");
                //Debug.WriteLine($"Unable to connect to {Ble_service.NowSelect_Device.Name} {Ble_service.NowSelect_Device.Id}: {ex.Message}.");
                //await Shell.Current.DisplayAlert($"{Ble_service.NowSelect_Device.Name}", $"Unable to connect to {Ble_service.NowSelect_Device.Name}.", "OK");
            }
            finally
            {
                Is_Busy = false;
            }
        }

        /// <summary>
        /// 接收到模块上传数据的处理
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void PG_Nordic_tx_characteristic_ValueUpdated(object sender, CharacteristicUpdatedEventArgs e)
        {
            byte[] recv_buffer = e.Characteristic.Value;
            string recv_str = ByteBuff_To_HexString(recv_buffer);
            if (string.IsNullOrWhiteSpace(recv_str))
            {
                return;
            }
            Add_Log_tx($"[Recv] -> {recv_str}");
            //解析数据
            DataHandle_Helper.Instance.Add_rx_data(recv_buffer);
        }

        public async Task DisconnectFromDeviceAsync_Handler()
        {
            if (Is_Busy)
            {
                return;
            }

            //没有连接过设备 直接退出
            if (Ble_service.Device == null)
            {
                return;
            }

            //蓝牙未开启 直接退出
            if (!Ble_service.BluetoothLE.IsOn)
            {             
                return;
            }

            //蓝牙搜索设备中
            if (Ble_service.Adapter.IsScanning)
            {
                await Ble_service.ShowToastAsync("蓝牙正在搜索设备，请等待完成后重试");
                return;
            }

            //蓝牙已经断开连接 直接退出
            if (Ble_service.Device.State == DeviceState.Disconnected)
            {
                return;
            }

            //存在连接 断开连接
            try
            {
                Is_Busy = true;

                //await HeartRateMeasurementCharacteristic.StopUpdatesAsync();

                await Ble_service.Adapter.DisconnectDeviceAsync(Ble_service.Device);
                Add_Log_tx("已断开连接!");
                Is_connect2Pg = false;
                //await Shell.Current.GoToAsync("..", true);
                //HeartRateMeasurementCharacteristic.ValueUpdated -= HeartRateMeasurementCharacteristic_ValueUpdated;
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Unable to disconnect from {Ble_service.Device.Name} {Ble_service.Device.Id}: {ex.Message}.");
                await Shell.Current.DisplayAlert("提示", $"断开蓝牙设备{Ble_service.Device.Name}失败", "OK");
            }
            finally
            {
                Ble_service.Device?.Dispose();
                Ble_service.Device = null;
                Is_Busy = false;
            }
        }

        private async Task CheckPG_Config()
        {
            //发送获取配置数据
            Is_get_config = false;
            byte[] send_buff;
            Share_Data.Modbus_instance.ModbusID = ModbusId;
            Share_Data.Modbus_instance.FunctionCode = 0x03;
            Share_Data.Modbus_instance.Addr = 0x00;
            Share_Data.Modbus_instance.RegNum = ModbusRTU.RegNum_ReadConfig;
            send_buff = ModbusRTU.Modbus03Send(Share_Data.Modbus_instance);
            if(send_buff != null)
            {
                Share_Data.Work_State = WorkState.ReadConfig;
                int retry_time = 5;
                do
                {
                    await PG_Nordic_rx_characteristic.WriteAsync(send_buff);
                    await Task.Delay(100);
                }
                while (!Is_get_config && retry_time-- > 0);
                Share_Data.Work_State = WorkState.Idle;
                if(!Is_get_config)
                {
                    //获取配置失败
                    Add_Log_tx("通讯失败，断开连接!");
                    await DisconnectFromDeviceAsync_Handler();
                }
                else
                {
                    Add_Log_tx("获取配置成功!");
                }
            }
        }


    }
}
