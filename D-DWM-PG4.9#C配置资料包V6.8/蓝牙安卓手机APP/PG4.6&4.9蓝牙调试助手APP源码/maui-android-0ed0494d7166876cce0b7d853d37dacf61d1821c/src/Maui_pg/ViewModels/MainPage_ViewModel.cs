using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Maui_pg.Models;
using Maui_pg.Services;
using Maui_pg.Views;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maui_pg.ViewModels
{
    public partial class MainPage_ViewModel : ObservableObject
    {
        
        private BluetoothService Ble_Service;  //蓝牙服务
        public IAsyncRelayCommand ScanBLEDevicesAsyncCommand { get; set; }
        public IAsyncRelayCommand SelectBLEDeviceAsyncCommand { get; private set; }


        #region UI绑定变量
        private string _click_txt;
        public string Click_txt
        {
            get => _click_txt;
            set => SetProperty(ref _click_txt, value);
        }

        private bool _Is_scanning;
        public bool Is_scanning
        {
            get => _Is_scanning;
            set => SetProperty(ref _Is_scanning, value);
        }


        private string _Scan_txt;
        public string Scan_txt
        {
            get => _Scan_txt;
            set => SetProperty(ref _Scan_txt, value);
        }

        public ObservableCollection<DeviceCandidate> Discovered_device_List { get; } = new ObservableCollection<DeviceCandidate>();
        #endregion


        public MainPage_ViewModel(BluetoothService bluetoothService)
        {
            ScanBLEDevicesAsyncCommand = new AsyncRelayCommand(ScanBLEDevicesAsync);
            SelectBLEDeviceAsyncCommand = new AsyncRelayCommand<DeviceCandidate>(SelectBLEDeviceAsync);
            Click_txt = "Click me";
            Ble_Service = bluetoothService;
            Discovered_device_List.Clear();
            Scan_txt = "列表为空,请打开蓝牙并搜索设备";
        }

        private async Task SelectBLEDeviceAsync(DeviceCandidate device)
        {
            if (Is_scanning)
            {
                await Ble_Service.ShowToastAsync($"蓝牙正在搜索设备，请重试...");
                return;
            }

            if (device == null)
            {
                return;
            }

            Ble_Service.NowSelect_Device = device;

            //await Shell.Current.DisplayAlert("Tips", $"device name: {device.Name}", "OK");
            //导航跳转并传递设备名参数
            await Shell.Current.GoToAsync($"CommuPage?Page_Title={Ble_Service.NowSelect_Device.Name}", true);
        }


        private async Task ScanBLEDevicesAsync()
        {
            if (Is_scanning)
            {
                return;
            }

            if (!Ble_Service.BluetoothLE.IsAvailable)
            {
                Debug.WriteLine($"Bluetooth is missing.");
                await Shell.Current.DisplayAlert($"提示", $"蓝牙不可用", "OK");
                return;
            }

#if ANDROID
            PermissionStatus permissionStatus = await Ble_Service.CheckBluetoothPermissions();
            if (permissionStatus != PermissionStatus.Granted)
            {
                permissionStatus = await Ble_Service.RequestBluetoothPermissions();
                if (permissionStatus != PermissionStatus.Granted)
                {
                    await Shell.Current.DisplayAlert($"提示", $"蓝牙获取权限失败", "OK");
                    return;
                }
            }
#elif IOS
#elif WINDOWS
#endif

            try
            {
                if (!Ble_Service.BluetoothLE.IsOn)
                {
                    await Shell.Current.DisplayAlert($"提示", $"蓝牙未开启，请打开蓝牙", "OK");
                    return;
                }

                if (Discovered_device_List.Count > 0)
                {
                    Discovered_device_List.Clear();
                }

                Is_scanning = true;

                Scan_txt = "搜索设备中...";

                List<DeviceCandidate> deviceCandidates = await Ble_Service.ScanForDevicesAsync();

                if (deviceCandidates.Count == 0)
                {
                    await Ble_Service.ShowToastAsync("未搜索到设备，请检查定位权限开启并重试");
                }
                //await Shell.Current.DisplayAlert("Bluetooth is on", $"find device: {deviceCandidates.Count}","ok");

                
                foreach (var deviceCandidate in deviceCandidates)
                {
                    Discovered_device_List.Add(deviceCandidate);
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Unable to get nearby Bluetooth LE devices: {ex.Message}");
                await Shell.Current.DisplayAlert("提示", $"蓝牙搜索出错:{ex.Message}.", "OK");
            }
            finally
            {
                Is_scanning = false;
            }
        }
    }
}
