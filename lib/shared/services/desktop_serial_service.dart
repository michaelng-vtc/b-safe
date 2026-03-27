import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

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
    return const <String>[];
  }

  /// Connect to a specified serial port.
  Future<bool> connect(String portName, {int baudRate = 115200}) async {
    _isConnected = false;
    debugPrint(
      'Desktop serial disabled in compatibility build '
      '(port=$portName, baud=$baudRate)',
    );
    return false;
  }

  /// Auto-connect to the first available serial port.
  Future<bool> autoConnect({int baudRate = 115200}) async {
    _isConnected = false;
    debugPrint('Desktop serial autoConnect disabled (baud=$baudRate)');
    return false;
  }

  /// Disconnect the serial port.
  Future<void> disconnect() async {
    _isConnected = false;
  }

  /// Send data to the serial port.
  Future<bool> write(String data) async {
    if (!_isConnected) {
      return false;
    }

    // Keep API behavior predictable for callers that still invoke write.
    final bytes = utf8.encode(data);
    return bytes.isNotEmpty;
  }

  /// Dispose resources.
  void dispose() {
    _isConnected = false;
    _dataController.close();
    _rawDataController.close();
  }
}
