import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

/// Serial data packet containing raw bytes and parsed text.
class SerialDataPacket {
  final Uint8List rawBytes;
  final String text;

  SerialDataPacket(this.rawBytes, this.text);
}

/// Compatibility-safe desktop serial service.
///
/// Native libserialport integration is disabled in this build to keep Android
/// binaries compatible with 16KB page-size requirements.
class DesktopSerialService {
  static final DesktopSerialService _instance =
      DesktopSerialService._internal();
  factory DesktopSerialService() => _instance;
  DesktopSerialService._internal();

  bool _isConnected = false;
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _readerSubscription;

  // Text stream (backward compatible).
  final StreamController<String> _dataController =
      StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataController.stream;

  // Raw byte stream (for binary protocol parsing).
  final StreamController<Uint8List> _rawDataController =
      StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get rawDataStream => _rawDataController.stream;

  bool get isConnected => _isConnected;

  /// Get all available serial ports.
  List<String> getAvailablePorts() {
    try {
      return SerialPort.availablePorts;
    } catch (e) {
      debugPrint('Failed to list serial ports: $e');
      return const <String>[];
    }
  }

  /// Connect to a specified serial port.
  Future<bool> connect(String portName, {int baudRate = 115200}) async {
    await disconnect();

    try {
      final port = SerialPort(portName);
      final opened = port.openReadWrite();
      if (!opened) {
        debugPrint(
          'Failed to open serial port $portName: ${SerialPort.lastError}',
        );
        port.dispose();
        return false;
      }

      final config = port.config;
      config.baudRate = baudRate;
      config.bits = 8;
      config.parity = SerialPortParity.none;
      config.stopBits = 1;
      config.setFlowControl(SerialPortFlowControl.none);
      port.config = config;

      final reader = SerialPortReader(port, timeout: 100);
      _readerSubscription = reader.stream.listen(
        (bytes) {
          _rawDataController.add(bytes);
          final hexData =
              bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
          _dataController.add('RAWBIN:${bytes.length}:$hexData');
        },
        onError: (error) {
          debugPrint('Desktop serial read error: $error');
          _isConnected = false;
        },
        cancelOnError: false,
      );

      _port = port;
      _reader = reader;
      _isConnected = true;
      debugPrint('Desktop serial connected: $portName @ $baudRate');
      return true;
    } catch (e) {
      debugPrint('Desktop serial connect exception: $e');
      await disconnect();
      return false;
    }
  }

  /// Auto-connect to the first available serial port.
  Future<bool> autoConnect({int baudRate = 115200}) async {
    final ports = getAvailablePorts();
    if (ports.isEmpty) {
      debugPrint('No desktop serial ports found');
      return false;
    }

    final preferred = {
      ...ports.where((p) => p.contains('ttyUSB')),
      ...ports.where((p) => p.contains('ttyACM')),
      ...ports,
    }.toList();

    for (final port in preferred) {
      if (await connect(port, baudRate: baudRate)) {
        return true;
      }
    }
    return false;
  }

  /// Disconnect the serial port.
  Future<void> disconnect() async {
    await _readerSubscription?.cancel();
    _readerSubscription = null;
    _reader?.close();
    _reader = null;

    if (_port != null) {
      try {
        if (_port!.isOpen) {
          _port!.close();
        }
      } catch (_) {
        // Ignore close errors during cleanup.
      }
      _port!.dispose();
      _port = null;
    }

    _isConnected = false;
  }

  /// Send data to the serial port.
  Future<bool> write(String data) async {
    if (!_isConnected || _port == null) {
      return false;
    }

    try {
      final bytes = Uint8List.fromList(utf8.encode(data));
      final written = _port!.write(bytes, timeout: 1000);
      return written > 0;
    } catch (e) {
      debugPrint('Desktop serial write failed: $e');
      return false;
    }
  }

  /// Send raw binary data to the serial port.
  Future<bool> writeBytes(Uint8List bytes) async {
    if (!_isConnected || _port == null) {
      return false;
    }

    try {
      final written = _port!.write(bytes, timeout: 1000);
      return written == bytes.length;
    } catch (e) {
      debugPrint('Desktop serial binary write failed: $e');
      return false;
    }
  }

  /// Dispose resources.
  void dispose() {
    _isConnected = false;
    _dataController.close();
    _rawDataController.close();
  }
}
