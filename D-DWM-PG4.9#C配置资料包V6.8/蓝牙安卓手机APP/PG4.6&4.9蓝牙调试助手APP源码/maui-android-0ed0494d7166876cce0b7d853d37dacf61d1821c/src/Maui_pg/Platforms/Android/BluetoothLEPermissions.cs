using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

public class BluetoothLEPermissions : Permissions.BasePlatformPermission
{
    //public override (string androidPermission, bool isRuntime)[] RequiredPermissions
    //{
    //    get
    //    {

    //        return new List<(string androidPermission, bool isRuntime)>
    //        {

    //            (Android.Manifest.Permission.Bluetooth, true),
    //            (Android.Manifest.Permission.BluetoothAdmin, true),
    //            //(Android.Manifest.Permission.BluetoothScan, true),
    //            //(Android.Manifest.Permission.BluetoothConnect, true),
    //            (Android.Manifest.Permission.AccessFineLocation, true),
    //            (Android.Manifest.Permission.AccessCoarseLocation, true),
    //            //(Android.Manifest.Permission.AccessBackgroundLocation, true),

    //        }.ToArray();
    //    }
    //}

    public override (string androidPermission, bool isRuntime)[] RequiredPermissions => GetRequiredPermissions();

    private (string androidPermission, bool isRuntime)[] GetRequiredPermissions()
    {
        var permissions = new List<string>();

        if (DeviceInfo.Version.Major >= 12)
        {
            // Android 版本大于等于 12 时，申请新的蓝牙权限
            permissions.Add(global::Android.Manifest.Permission.BluetoothScan);
            permissions.Add(global::Android.Manifest.Permission.BluetoothConnect);
        }
        else
        {
            //csproj文件指定SupportedOSPlatformVersion android 28.0可以继续使用安卓9的权限
            permissions.Add(global::Android.Manifest.Permission.Bluetooth);
            permissions.Add(global::Android.Manifest.Permission.BluetoothAdmin);
        }
        permissions.Add(global::Android.Manifest.Permission.AccessCoarseLocation);
        permissions.Add(global::Android.Manifest.Permission.AccessFineLocation);
        var result = new List<(string androidPermission, bool isRuntime)>();
        foreach (var permission in permissions)
        {
            result.Add((permission, true));
        }

        return result.ToArray();
    }

}
