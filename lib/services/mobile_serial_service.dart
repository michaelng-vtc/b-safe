import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';

/// USB device information.
class UsbDeviceInfo {
  final String deviceName;
  final int vid;
  final int pid;
  final String? productName;
  final String? manufacturerName;
  final UsbDevice rawDevice;

  UsbDeviceInfo({
    required this.deviceName,
    required this.vid,
    required this.pid,
    this.productName,
    this.manufacturerName,
    required this.rawDevice,
  });

  String get displayName {
    if (productName != null && productName!.isNotEmpty) {
      return '$productName ($deviceName)';
    }
    // Common chip name mapping.
    if (vid == 0x1A86 && pid == 0x7523) return 'CH340 ($deviceName)';
    if (vid == 0x10C4 && pid == 0xEA60) return 'CP2102 ($deviceName)';
    if (vid == 0x0403 && pid == 0x6001) return 'FTDI ($deviceName)';
    if (vid == 0x2341) return 'Arduino ($deviceName)';
    return 'USB Serial ($deviceName)';
  }

  @override
  String toString() =>
      'UsbDeviceInfo(name: $deviceName, vid: 0x${vid.toRadixString(16)}, pid: 0x${pid.toRadixString(16)})';
}

/// Android USB OTG serial service.
/// Used to connect Aithinker UWB BU04 devices via USB-C cable.
class MobileSerialService {
  static final MobileSerialService _instance = MobileSerialService._internal();
  factory MobileSerialService() => _instance;
  MobileSerialService._internal();

  UsbPort? _port;
  UsbDevice? _device;
  bool _isConnected = false;

  // Text stream (backward compatible with DesktopSerialService API).
  final StreamController<String> _dataController =
      StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataController.stream;

  // Raw byte stream.
  final StreamController<Uint8List> _rawDataController =
      StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get rawDataStream => _rawDataController.stream;

  // USB attach/detach events.
  StreamSubscription? _usbEventSubscription;

  // Connection state callbacks.
  VoidCallback? onDeviceConnected;
  VoidCallback? onDeviceDisconnected;

  bool get isConnected => _isConnected;
  String? get connectedDeviceName => _device?.deviceName;

  /// Get all connected USB serial devices.
  Future<List<UsbDeviceInfo>> getAvailableDevices() async {
    try {
      final devices = await UsbSerial.listDevices();
      debugPrint('[USB] Found ${devices.length} USB device(s)');

      return devices.map((d) {
        debugPrint(
            '[USB] Device: ${d.deviceName}, VID: 0x${d.vid?.toRadixString(16)}, PID: 0x${d.pid?.toRadixString(16)}, Product: ${d.productName}');
        return UsbDeviceInfo(
          deviceName: d.deviceName,
          vid: d.vid ?? 0,
          pid: d.pid ?? 0,
          productName: d.productName,
          manufacturerName: d.manufacturerName,
          rawDevice: d,
        );
      }).toList();
    } catch (e) {
      debugPrint('[USB] Failed to get device list: $e');
      return [];
    }
  }

  /// Get available device names (compatible with DesktopSerialService.getAvailablePorts).
  Future<List<String>> getAvailablePorts() async {
    final devices = await getAvailableDevices();
    return devices.map((d) => d.displayName).toList();
  }

  /// Connect to a specified USB device.
  Future<bool> connect(UsbDevice device, {int baudRate = 115200}) async {
    try {
      // Disconnect any existing connection first.
      if (_isConnected) {
        await disconnect();
      }

      debugPrint('[USB] Trying: ${device.deviceName}');

      _port = await device.create();
      if (_port == null) {
        debugPrint('[USB] Cannot create port');
        return false;
      }

      final openResult = await _port!.open();
      if (!openResult) {
        debugPrint('[USB] Cannot open port');
        _port = null;
        return false;
      }

      // Configure serial port parameters.
      await _port!.setDTR(true);
      await _port!.setRTS(true);
      _port!.setPortParameters(
        baudRate,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _device = device;
      _isConnected = true;

      // Start reading data.
      _startReading();

      debugPrint('[USB] Connected: ${device.deviceName} (baud: $baudRate)');
      return true;
    } catch (e) {
      debugPrint('[USB] Connection failed: $e');
      _isConnected = false;
      _port = null;
      return false;
    }
  }

  /// Auto-connect to the first available USB serial device.
  Future<bool> autoConnect({int baudRate = 115200}) async {
    final devices = await getAvailableDevices();

    if (devices.isEmpty) {
      debugPrint('[USB] No USB serial devices found');
      return false;
    }

    debugPrint('[USB] Found ${devices.length} device(s), trying first');

    // Prefer CH340/CP210x devices (common BU04 chipsets).
    UsbDeviceInfo? preferredDevice;
    for (final d in devices) {
      if (d.vid == 0x1A86 || d.vid == 0x10C4) {
        preferredDevice = d;
        break;
      }
    }

    final targetDevice = preferredDevice ?? devices.first;
    return connect(targetDevice.rawDevice, baudRate: baudRate);
  }

  /// Connect to the device at the specified index.
  Future<bool> connectByIndex(int index, {int baudRate = 115200}) async {
    final devices = await getAvailableDevices();
    if (index < 0 || index >= devices.length) return false;
    return connect(devices[index].rawDevice, baudRate: baudRate);
  }

  /// Disconnect.
  Future<void> disconnect() async {
    _isConnected = false;

    try {
      await _port?.close();
      _port = null;
      _device = null;
      debugPrint('[USB] Disconnected');
    } catch (e) {
      debugPrint('[USB] Disconnect error: $e');
    }
  }

  // Track received raw byte count (for debugging).
  int _totalBytesReceived = 0;

  /// Start reading serial data.
  void _startReading() {
    if (_port == null || !_isConnected) return;

    try {
      List<int> byteBuffer = [];

      _port!.inputStream?.listen(
        (Uint8List data) {
          try {
            _totalBytesReceived += data.length;

            if (_totalBytesReceived % 500 < data.length) {
              debugPrint(
                  '[USB] Received $_totalBytesReceived bytes, current chunk: ${data.length} bytes');
            }

            // Append incoming data to the buffer.
            byteBuffer.addAll(data);

            // Emit raw data stream.
            _rawDataController.add(data);

            // BU04 TWR packet format: "CmdM:4[" + 91 bytes data + "]".
            while (byteBuffer.length >= 100) {
              final firstCmdM = _findCmdMStart(byteBuffer);
              if (firstCmdM < 0) {
                if (byteBuffer.length > 200) {
                  byteBuffer = byteBuffer.sublist(byteBuffer.length - 100);
                }
                break;
              }

              if (firstCmdM > 0) {
                byteBuffer = byteBuffer.sublist(firstCmdM);
              }

              final secondCmdM = _findCmdMStart(byteBuffer.sublist(7));
              int packetEnd;

              if (secondCmdM > 0) {
                packetEnd = 7 + secondCmdM;
              } else if (byteBuffer.length >= 100) {
                packetEnd = 100;
              } else {
                break;
              }

              final packetBytes =
                  Uint8List.fromList(byteBuffer.sublist(0, packetEnd));
              byteBuffer = byteBuffer.sublist(packetEnd);

              if (packetBytes.length >= 20) {
                final hexData = packetBytes
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join(' ');
                _dataController.add('RAWBIN:${packetBytes.length}:$hexData');
              }
            }

            // Prevent the buffer from growing too large.
            if (byteBuffer.length > 500) {
              byteBuffer = byteBuffer.sublist(byteBuffer.length - 200);
            }
          } catch (e) {
            debugPrint('[USB] Data parse error: $e');
          }
        },
        onError: (error) {
          debugPrint('[USB] Read error: $error');
          _isConnected = false;
          onDeviceDisconnected?.call();
        },
        onDone: () {
          debugPrint('[USB] Read ended');
          _isConnected = false;
          onDeviceDisconnected?.call();
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[USB] Failed to start reading: $e');
      _isConnected = false;
    }
  }

  /// Find the start index of a CmdM packet in the buffer.
  int _findCmdMStart(List<int> buffer) {
    for (int i = 0; i < buffer.length - 7; i++) {
      if (buffer[i] == 0x43 &&
          buffer[i + 1] == 0x6d &&
          buffer[i + 2] == 0x64 &&
          buffer[i + 3] == 0x4d) {
        return i;
      }
    }
    return -1;
  }

  /// Send data to the serial port.
  Future<bool> write(String data) async {
    if (_port == null || !_isConnected) {
      debugPrint('[USB] Serial port not connected');
      return false;
    }

    try {
      final bytes = utf8.encode(data);
      await _port!.write(Uint8List.fromList(bytes));
      return true;
    } catch (e) {
      debugPrint('[USB] Failed to send data: $e');
      return false;
    }
  }

  /// Listen for USB attach/detach events.
  void startUsbEventListening() {
    _usbEventSubscription?.cancel();
    _usbEventSubscription = UsbSerial.usbEventStream?.listen((UsbEvent event) {
      debugPrint(
          '[USB] Event: ${event.event}, Device: ${event.device?.deviceName}');
      if (event.event == UsbEvent.ACTION_USB_ATTACHED) {
        onDeviceConnected?.call();
      } else if (event.event == UsbEvent.ACTION_USB_DETACHED) {
        if (_device != null &&
            event.device?.deviceName == _device!.deviceName) {
          _isConnected = false;
          _port = null;
          _device = null;
        }
        onDeviceDisconnected?.call();
      }
    });
  }

  /// Stop listening for USB events.
  void stopUsbEventListening() {
    _usbEventSubscription?.cancel();
    _usbEventSubscription = null;
  }

  /// Dispose resources.
  void dispose() {
    disconnect();
    stopUsbEventListening();
    _dataController.close();
    _rawDataController.close();
  }
}
