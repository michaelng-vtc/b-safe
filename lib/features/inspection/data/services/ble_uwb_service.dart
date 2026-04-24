import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleDeviceInfo {
  final BluetoothDevice device;
  final String name;
  final String id;
  final int rssi;

  BleDeviceInfo({
    required this.device,
    required this.name,
    required this.id,
    required this.rssi,
  });

  @override
  String toString() => '$name ($id), RSSI=$rssi';
}

class BleUwbService {
  static final BleUwbService _instance = BleUwbService._internal();
  factory BleUwbService() => _instance;
  BleUwbService._internal();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _notifyCharacteristic;
  BluetoothCharacteristic? _writeCharacteristic;
  StreamSubscription<List<int>>? _notifySubscription;
  bool _isConnected = false;

  final StreamController<String> _dataController =
      StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataController.stream;

  bool get isConnected => _isConnected;
  String? get connectedDeviceName => _device?.platformName;

  Future<List<BleDeviceInfo>> scanDevices({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final found = <String, BleDeviceInfo>{};

    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final id = r.device.remoteId.str;
        final advName = r.advertisementData.advName;
        final platformName = r.device.platformName;
        final name = advName.isNotEmpty
            ? advName
            : (platformName.isNotEmpty ? platformName : 'Unknown BLE Device');
        found[id] = BleDeviceInfo(
          device: r.device,
          name: name,
          id: id,
          rssi: r.rssi,
        );
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: timeout);
      await Future.delayed(timeout + const Duration(milliseconds: 300));
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('[BLE] scan failed: $e');
    } finally {
      await sub.cancel();
    }

    final list = found.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return list;
  }

  Future<bool> autoConnect() async {
    final devices = await scanDevices();
    if (devices.isEmpty) return false;

    final preferred = devices.where((d) {
      final n = d.name.toLowerCase();
      return n.contains('pg') ||
          n.contains('d-dwm') ||
          n.contains('uwb') ||
          n.contains('tag');
    }).toList();

    final target = preferred.isNotEmpty ? preferred.first : devices.first;
    return connect(target);
  }

  Future<bool> connect(BleDeviceInfo deviceInfo) async {
    await disconnect();

    try {
      _device = deviceInfo.device;
      await _device!.connect(
        timeout: const Duration(seconds: 12),
        autoConnect: false,
      );

      final services = await _device!.discoverServices();

      for (final s in services) {
        for (final c in s.characteristics) {
          if (_notifyCharacteristic == null &&
              (c.properties.notify || c.properties.indicate)) {
            _notifyCharacteristic = c;
          }
          if (_writeCharacteristic == null &&
              (c.properties.write || c.properties.writeWithoutResponse)) {
            _writeCharacteristic = c;
          }
        }
      }

      if (_notifyCharacteristic == null) {
        debugPrint('[BLE] notify characteristic not found');
        await disconnect();
        return false;
      }

      await _notifyCharacteristic!.setNotifyValue(true);
      _notifySubscription = _notifyCharacteristic!.lastValueStream.listen(
        (value) {
          if (value.isEmpty) return;
          final bytes = Uint8List.fromList(value);
          final hex =
              bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
          _dataController.add('RAWBIN:${bytes.length}:$hex');
        },
        onError: (e) {
          debugPrint('[BLE] notify error: $e');
          _isConnected = false;
        },
      );

      _isConnected = true;
      debugPrint('[BLE] Connected to ${deviceInfo.name} (${deviceInfo.id})');
      return true;
    } catch (e) {
      debugPrint('[BLE] connect failed: $e');
      await disconnect();
      return false;
    }
  }

  Future<bool> writeBytes(Uint8List bytes) async {
    if (!_isConnected || _writeCharacteristic == null) return false;

    try {
      await _writeCharacteristic!.write(
        bytes,
        withoutResponse: _writeCharacteristic!.properties.writeWithoutResponse,
      );
      return true;
    } catch (e) {
      debugPrint('[BLE] write failed: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    _isConnected = false;

    await _notifySubscription?.cancel();
    _notifySubscription = null;

    try {
      if (_notifyCharacteristic != null) {
        await _notifyCharacteristic!.setNotifyValue(false);
      }
    } catch (_) {
      // Ignore notify disable errors during disconnect.
    }

    _notifyCharacteristic = null;
    _writeCharacteristic = null;

    try {
      await _device?.disconnect();
    } catch (_) {
      // Ignore disconnect errors during cleanup.
    }
    _device = null;
  }

  void dispose() {
    disconnect();
    _dataController.close();
  }
}
