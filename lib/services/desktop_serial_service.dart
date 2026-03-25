import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

/// Serial data packet containing raw bytes and parsed text.
class SerialDataPacket {
  final Uint8List rawBytes;
  final String text;

  SerialDataPacket(this.rawBytes, this.text);
}

/// Desktop serial service.
/// Used on Windows/Linux/macOS to connect Aithinker UWB BU04 devices.
class DesktopSerialService {
  static final DesktopSerialService _instance =
      DesktopSerialService._internal();
  factory DesktopSerialService() => _instance;
  DesktopSerialService._internal();

  SerialPort? _port;
  SerialPortReader? _reader;
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
    return SerialPort.availablePorts;
  }

  /// Connect to a specified serial port.
  Future<bool> connect(String portName, {int baudRate = 115200}) async {
    try {
      // Disconnect any existing connection.
      if (_isConnected) {
        await disconnect();
      }

      _port = SerialPort(portName);

      // Configure serial port parameters.
      final config = SerialPortConfig();
      config.baudRate = baudRate;
      config.bits = 8;
      config.stopBits = 1;
      config.parity = SerialPortParity.none;
      config.setFlowControl(SerialPortFlowControl.none);

      _port!.config = config;

      // Open the serial port.
      if (!_port!.openReadWrite()) {
        final error = SerialPort.lastError;
        debugPrint('Cannot open port $portName: ${error?.message}');
        return false;
      }

      _isConnected = true;

      // Start reading data.
      _startReading();

      debugPrint('Port $portName connected (baud: $baudRate)');
      return true;
    } catch (e) {
      debugPrint('Serial connect failed: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Auto-connect to the first available serial port (usually a BU04 device).
  Future<bool> autoConnect({int baudRate = 115200}) async {
    final ports = getAvailablePorts();

    if (ports.isEmpty) {
      debugPrint('No serial devices found');
      return false;
    }

    debugPrint('Found ${ports.length} port(s): $ports');

    // On Linux, prefer common USB/UART device paths first.
    final prioritizedPorts = _prioritizePortsForPlatform(ports);

    // Try each port in priority order.
    for (final port in prioritizedPorts) {
      debugPrint('Trying to connect: $port');
      if (await connect(port, baudRate: baudRate)) {
        return true;
      }
    }

    return false;
  }

  List<String> _prioritizePortsForPlatform(List<String> ports) {
    if (!Platform.isLinux) return ports;

    final preferred = <String>[];
    final others = <String>[];

    for (final port in ports) {
      if (port.startsWith('/dev/ttyUSB') ||
          port.startsWith('/dev/ttyACM') ||
          port.startsWith('/dev/ttyAMA')) {
        preferred.add(port);
      } else {
        others.add(port);
      }
    }

    return [...preferred, ...others];
  }

  /// Disconnect the serial port.
  Future<void> disconnect() async {
    _isConnected = false;

    try {
      _reader?.close();
      _reader = null;

      _port?.close();
      _port?.dispose();
      _port = null;

      debugPrint('Serial port disconnected');
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
  }

  // Track received raw byte count (for debugging).
  int _totalBytesReceived = 0;

  /// Start reading serial data.
  void _startReading() {
    if (_port == null || !_isConnected) return;

    try {
      _reader = SerialPortReader(_port!);
      List<int> byteBuffer = [];

      _reader!.stream.listen(
        (Uint8List data) {
          try {
            _totalBytesReceived += data.length;

            // Debug: print periodically as data arrives.
            if (_totalBytesReceived % 500 < data.length) {
              debugPrint(
                  '[Serial] Received $_totalBytesReceived bytes, chunk: ${data.length} bytes');
            }

            // Append incoming data to the buffer.
            byteBuffer.addAll(data);

            // Emit raw data stream.
            _rawDataController.add(data);

            // BU04 TWR packet format: "CmdM:4[" + 91 bytes data + "]".
            // Typical packet length is about 100 bytes (7 + 91 + 1 + newline).
            // Use bytes between two consecutive CmdM markers as one packet.
            while (byteBuffer.length >= 100) {
              // Find the first CmdM marker.
              final firstCmdM = _findCmdMStart(byteBuffer);
              if (firstCmdM < 0) {
                // If no CmdM is found, trim part of the buffer.
                if (byteBuffer.length > 200) {
                  byteBuffer = byteBuffer.sublist(byteBuffer.length - 100);
                }
                break;
              }

              // Drop bytes before CmdM.
              if (firstCmdM > 0) {
                byteBuffer = byteBuffer.sublist(firstCmdM);
              }

              // Find next CmdM marker or fall back to fixed packet length.
              final secondCmdM = _findCmdMStart(byteBuffer.sublist(7));
              int packetEnd;

              if (secondCmdM > 0) {
                // Next CmdM found: current packet ends here.
                packetEnd = 7 + secondCmdM;
              } else if (byteBuffer.length >= 100) {
                // No next CmdM: use fixed packet length (~100 bytes).
                packetEnd = 100;
              } else {
                // Not enough data yet.
                break;
              }

              // Extract packet.
              final packetBytes =
                  Uint8List.fromList(byteBuffer.sublist(0, packetEnd));
              byteBuffer = byteBuffer.sublist(packetEnd);

              // Process only sufficiently long packets (must include distance data).
              if (packetBytes.length >= 20) {
                // Emit RAWBIN payload.
                final hexData = packetBytes
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join(' ');
                _dataController.add('RAWBIN:${packetBytes.length}:$hexData');
              }
            }

            // Prevent oversized buffers.
            if (byteBuffer.length > 500) {
              byteBuffer = byteBuffer.sublist(byteBuffer.length - 200);
            }
          } catch (e) {
            debugPrint('Data parse error: $e');
          }
        },
        onError: (error) {
          debugPrint('Serial read error: $error');
          _isConnected = false;
        },
        onDone: () {
          debugPrint('Serial read ended');
          _isConnected = false;
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Failed to start reading: $e');
      _isConnected = false;
    }
  }

  /// Check whether data is a CmdM binary packet.
  // ignore: unused_element
  bool _isCmdMPacket(Uint8List data) {
    // CmdM ASCII bytes: 43 6d 64 4d.
    if (data.length >= 7) {
      return data[0] == 0x43 && // C
          data[1] == 0x6d && // m
          data[2] == 0x64 && // d
          data[3] == 0x4d; // M
    }
    return false;
  }

  /// Find the start index of a CmdM packet in the buffer.
  int _findCmdMStart(List<int> buffer) {
    // Search for the "CmdM" marker (43 6d 64 4d).
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
      debugPrint('Serial port not connected');
      return false;
    }

    try {
      final bytes = utf8.encode(data);
      final written = _port!.write(Uint8List.fromList(bytes));
      return written == bytes.length;
    } catch (e) {
      debugPrint('Failed to send data: $e');
      return false;
    }
  }

  /// Dispose resources.
  void dispose() {
    disconnect();
    _dataController.close();
    _rawDataController.close();
  }
}
