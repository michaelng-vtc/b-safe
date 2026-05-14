import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pg_service_uuids.dart';

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

/// BLE transport service for PG4.9 UWB module.
///
/// Uses the Nordic UART Service (NUS) UUIDs to locate the correct
/// characteristics, which avoids false matches on multi-service devices.
///
/// Two data streams are exposed:
///   • [rawBytesStream] – primary stream (Uint8List), used by Phase-3
///     PgDataHandler for full Modbus frame parsing.
///   • [dataStream]     – legacy string stream (RAWBIN:len:hex format),
///     kept for backward compatibility with the existing UwbService parser.
class BleUwbService {
  static final BleUwbService _instance = BleUwbService._internal();
  factory BleUwbService() => _instance;
  BleUwbService._internal();

  BluetoothDevice? _device;

  /// RX characteristic: write commands TO the device.
  BluetoothCharacteristic? _rxCharacteristic;

  /// TX characteristic: receive notifications FROM the device.
  BluetoothCharacteristic? _txCharacteristic;

  StreamSubscription<List<int>>? _txSubscription;
  StreamSubscription<BluetoothConnectionState>? _connStateSubscription;
  bool _isConnected = false;

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Primary raw-bytes stream (Phase 3 entry point).
  final StreamController<Uint8List> _rawBytesController =
      StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get rawBytesStream => _rawBytesController.stream;

  /// Legacy string stream for backward compatibility with UwbService.
  /// Emits 'RAWBIN:<len>:<hex>' frames derived from raw BLE notifications.
  final StreamController<String> _dataController =
      StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataController.stream;

  bool get isConnected => _isConnected;
  String? get connectedDeviceName => _device?.platformName;

  // ── Permissions (Android) ──────────────────────────────────────────────────

  /// Request Android BLE permissions (BLUETOOTH_SCAN + BLUETOOTH_CONNECT +
  /// ACCESS_FINE_LOCATION).  Returns true when all are granted.
  /// On non-Android platforms this is a no-op and always returns true.
  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;

    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final granted = results.values.every((s) => s.isGranted);
    if (!granted) {
      debugPrint('[BLE] Permission denied: $results');
    }
    return granted;
  }

  // ── Scan ───────────────────────────────────────────────────────────────────

  Future<List<BleDeviceInfo>> scanDevices({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final found = <String, BleDeviceInfo>{};

    // Include already-connected system devices first (mirrors BluetoothService).
    for (final d in FlutterBluePlus.connectedDevices) {
      found[d.remoteId.str] = BleDeviceInfo(
        device: d,
        name: d.platformName.isNotEmpty ? d.platformName : '(Unknown)',
        id: d.remoteId.str,
        rssi: 0,
      );
    }

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

  // ── Connect ────────────────────────────────────────────────────────────────

  Future<bool> connect(BleDeviceInfo deviceInfo) async {
    await disconnect();

    try {
      _device = deviceInfo.device;
      await _device!.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      final services = await _device!.discoverServices();

      // Locate the Nordic UART service by UUID.
      BluetoothService? uartService;
      for (final s in services) {
        if (s.serviceUuid.str128.toLowerCase() ==
            PgServiceUuids.nordicUartService) {
          uartService = s;
          break;
        }
      }

      if (uartService == null) {
        // Fall back: accept the first service with both notify and write chars.
        debugPrint(
            '[BLE] Nordic UART service not found, attempting fallback discovery');
        for (final s in services) {
          bool hasNotify = false;
          bool hasWrite = false;
          for (final c in s.characteristics) {
            if (c.properties.notify || c.properties.indicate) hasNotify = true;
            if (c.properties.write || c.properties.writeWithoutResponse) {
              hasWrite = true;
            }
          }
          if (hasNotify && hasWrite) {
            uartService = s;
            break;
          }
        }
      }

      if (uartService == null) {
        debugPrint('[BLE] No suitable UART service found');
        await disconnect();
        return false;
      }

      // Locate RX (write) and TX (notify) characteristics.
      for (final c in uartService.characteristics) {
        final uuid = c.characteristicUuid.str128.toLowerCase();
        if (uuid == PgServiceUuids.nordicUartRx) {
          _rxCharacteristic = c;
        } else if (uuid == PgServiceUuids.nordicUartTx) {
          _txCharacteristic = c;
        }
      }

      // Fallback: if UUIDs didn't match (firmware variant), use property flags.
      for (final c in uartService.characteristics) {
        if (_txCharacteristic == null &&
            (c.properties.notify || c.properties.indicate)) {
          _txCharacteristic = c;
        }
        if (_rxCharacteristic == null &&
            (c.properties.write || c.properties.writeWithoutResponse)) {
          _rxCharacteristic = c;
        }
      }

      if (_txCharacteristic == null) {
        debugPrint('[BLE] TX characteristic (notify) not found');
        await disconnect();
        return false;
      }

      // Subscribe to TX notifications BEFORE MTU negotiation.
      // Reference app order: setNotifyValue → requestMtu → requestConnectionPriority.
      // Doing MTU first on some Android stacks can cause the characteristic to
      // become stale, silently dropping subsequent notifications.
      await _txCharacteristic!.setNotifyValue(true);

      // Request larger MTU to support long config responses (115 regs × 2 bytes).
      try {
        await _device!.requestMtu(512);
      } catch (e) {
        debugPrint('[BLE] MTU request failed (non-critical): $e');
      }

      // Request HIGH connection priority for continuous RTLS streaming.
      try {
        await _device!.requestConnectionPriority(
          connectionPriorityRequest: ConnectionPriority.high,
        );
      } catch (e) {
        debugPrint(
            '[BLE] Connection priority request failed (non-critical): $e');
      }

      // Use onValueReceived (fires on every notification) instead of
      // lastValueStream (BehaviorSubject – deduplicates identical frames).
      _txSubscription = _txCharacteristic!.onValueReceived.listen(
        (value) {
          if (value.isEmpty) return;
          final bytes = Uint8List.fromList(value);

          // Emit raw bytes for Phase-3 PgDataHandler.
          _rawBytesController.add(bytes);

          // Emit legacy RAWBIN string for backward compat with UwbService.
          final hex =
              bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
          _dataController.add('RAWBIN:${bytes.length}:$hex');
        },
        onError: (e) {
          debugPrint('[BLE] TX notify error: $e');
          _isConnected = false;
        },
      );

      _isConnected = true;
      debugPrint('[BLE] Connected to ${deviceInfo.name} (${deviceInfo.id})');

      // Monitor for unexpected disconnects.
      _connStateSubscription = _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && _isConnected) {
          debugPrint('[BLE] Unexpected disconnect from ${deviceInfo.name}');
          _isConnected = false;
          _cleanupSubscriptions();
        }
      });

      return true;
    } catch (e) {
      debugPrint('[BLE] connect failed: $e');
      await disconnect();
      return false;
    }
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  Future<bool> writeBytes(Uint8List bytes) async {
    if (!_isConnected || _rxCharacteristic == null) return false;

    try {
      await _rxCharacteristic!.write(
        bytes,
        withoutResponse: _rxCharacteristic!.properties.writeWithoutResponse,
      );
      return true;
    } catch (e) {
      debugPrint('[BLE] write failed: $e');
      return false;
    }
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _isConnected = false;
    _cleanupSubscriptions();

    try {
      if (_txCharacteristic != null) {
        await _txCharacteristic!.setNotifyValue(false);
      }
    } catch (_) {
      // Ignore notify-disable errors during disconnect.
    }

    _rxCharacteristic = null;
    _txCharacteristic = null;

    try {
      await _device?.disconnect();
    } catch (_) {
      // Ignore disconnect errors during cleanup.
    }
    _device = null;
  }

  void _cleanupSubscriptions() {
    _txSubscription?.cancel();
    _txSubscription = null;
    _connStateSubscription?.cancel();
    _connStateSubscription = null;
  }

  void dispose() {
    disconnect();
    _rawBytesController.close();
    _dataController.close();
  }
}
