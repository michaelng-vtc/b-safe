import 'dart:typed_data';

/// Modbus receive validation result for PG4.9 responses.
enum PgModbusReceiveState {
  crcError,
  idError,
  functionCodeError,
  regNumError,
  recvOk,
}

/// Modbus frame constants for the PG4.9 UWB module.
class PgModbusConstants {
  PgModbusConstants._();

  static const int defaultModbusId = 0x01;

  // Number of holding registers to read in the standard RTLS poll request.
  // Address 0x0000, count 0x006A (106) covers the full RTLS output block.
  static const int regNumPollRead = 106;

  // Register address for the start/stop locate command.
  static const int addrStartLocate = 0x003B; // 59

  // Value to write to addrStartLocate to start continuous RTLS output.
  static const int valueStartLocate = 0x0004;
}

/// Modbus RTU frame builder and CRC validator for the PG4.9 UWB module.
///
/// Ported from BlueToothFlutterApp/lib/services/modbus_rtu.dart.
/// All public members are pure static – no instance state.
class PgModbusRtu {
  PgModbusRtu._();

  // ---------------------------------------------------------------------------
  // CRC-16 (Modbus) lookup tables
  // ---------------------------------------------------------------------------

  static const List<int> _tableCrcHi = [
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x01,
    0xC0,
    0x80,
    0x41,
    0x00,
    0xC1,
    0x81,
    0x40,
  ];

  static const List<int> _tableCrcLo = [
    0x00,
    0xC0,
    0xC1,
    0x01,
    0xC3,
    0x03,
    0x02,
    0xC2,
    0xC6,
    0x06,
    0x07,
    0xC7,
    0x05,
    0xC5,
    0xC4,
    0x04,
    0xCC,
    0x0C,
    0x0D,
    0xCD,
    0x0F,
    0xCF,
    0xCE,
    0x0E,
    0x0A,
    0xCA,
    0xCB,
    0x0B,
    0xC9,
    0x09,
    0x08,
    0xC8,
    0xD8,
    0x18,
    0x19,
    0xD9,
    0x1B,
    0xDB,
    0xDA,
    0x1A,
    0x1E,
    0xDE,
    0xDF,
    0x1F,
    0xDD,
    0x1D,
    0x1C,
    0xDC,
    0x14,
    0xD4,
    0xD5,
    0x15,
    0xD7,
    0x17,
    0x16,
    0xD6,
    0xD2,
    0x12,
    0x13,
    0xD3,
    0x11,
    0xD1,
    0xD0,
    0x10,
    0xF0,
    0x30,
    0x31,
    0xF1,
    0x33,
    0xF3,
    0xF2,
    0x32,
    0x36,
    0xF6,
    0xF7,
    0x37,
    0xF5,
    0x35,
    0x34,
    0xF4,
    0x3C,
    0xFC,
    0xFD,
    0x3D,
    0xFF,
    0x3F,
    0x3E,
    0xFE,
    0xFA,
    0x3A,
    0x3B,
    0xFB,
    0x39,
    0xF9,
    0xF8,
    0x38,
    0x28,
    0xE8,
    0xE9,
    0x29,
    0xEB,
    0x2B,
    0x2A,
    0xEA,
    0xEE,
    0x2E,
    0x2F,
    0xEF,
    0x2D,
    0xED,
    0xEC,
    0x2C,
    0xE4,
    0x24,
    0x25,
    0xE5,
    0x27,
    0xE7,
    0xE6,
    0x26,
    0x22,
    0xE2,
    0xE3,
    0x23,
    0xE1,
    0x21,
    0x20,
    0xE0,
    0xA0,
    0x60,
    0x61,
    0xA1,
    0x63,
    0xA3,
    0xA2,
    0x62,
    0x66,
    0xA6,
    0xA7,
    0x67,
    0xA5,
    0x65,
    0x64,
    0xA4,
    0x6C,
    0xAC,
    0xAD,
    0x6D,
    0xAF,
    0x6F,
    0x6E,
    0xAE,
    0xAA,
    0x6A,
    0x6B,
    0xAB,
    0x69,
    0xA9,
    0xA8,
    0x68,
    0x78,
    0xB8,
    0xB9,
    0x79,
    0xBB,
    0x7B,
    0x7A,
    0xBA,
    0xBE,
    0x7E,
    0x7F,
    0xBF,
    0x7D,
    0xBD,
    0xBC,
    0x7C,
    0xB4,
    0x74,
    0x75,
    0xB5,
    0x77,
    0xB7,
    0xB6,
    0x76,
    0x72,
    0xB2,
    0xB3,
    0x73,
    0xB1,
    0x71,
    0x70,
    0xB0,
    0x50,
    0x90,
    0x91,
    0x51,
    0x93,
    0x53,
    0x52,
    0x92,
    0x96,
    0x56,
    0x57,
    0x97,
    0x55,
    0x95,
    0x94,
    0x54,
    0x9C,
    0x5C,
    0x5D,
    0x9D,
    0x5F,
    0x9F,
    0x9E,
    0x5E,
    0x5A,
    0x9A,
    0x9B,
    0x5B,
    0x99,
    0x59,
    0x58,
    0x98,
    0x88,
    0x48,
    0x49,
    0x89,
    0x4B,
    0x8B,
    0x8A,
    0x4A,
    0x4E,
    0x8E,
    0x8F,
    0x4F,
    0x8D,
    0x4D,
    0x4C,
    0x8C,
    0x44,
    0x84,
    0x85,
    0x45,
    0x87,
    0x47,
    0x46,
    0x86,
    0x82,
    0x42,
    0x43,
    0x83,
    0x41,
    0x81,
    0x80,
    0x40,
  ];

  // ---------------------------------------------------------------------------
  // CRC-16
  // ---------------------------------------------------------------------------

  /// Compute Modbus-RTU CRC-16 over [data] (first [length] bytes).
  /// Returns a 16-bit value where the high byte is sent first on the wire.
  static int crc16(Uint8List data, int length) {
    int crcHi = 0xFF;
    int crcLo = 0xFF;
    for (int i = 0; i < length; i++) {
      final t = crcHi ^ data[i];
      crcHi = crcLo ^ _tableCrcHi[t];
      crcLo = _tableCrcLo[t];
    }
    return ((crcHi << 8) | crcLo) & 0xFFFF;
  }

  // ---------------------------------------------------------------------------
  // Frame builders
  // ---------------------------------------------------------------------------

  /// Build a Modbus FC-03 (read holding registers) request.
  static Uint8List buildRead03(int id, int addr, int regNum) {
    final buf = Uint8List(8);
    buf[0] = id & 0xFF;
    buf[1] = 0x03;
    buf[2] = (addr >> 8) & 0xFF;
    buf[3] = addr & 0xFF;
    buf[4] = (regNum >> 8) & 0xFF;
    buf[5] = regNum & 0xFF;
    final crc = crc16(buf, 6);
    buf[6] = (crc >> 8) & 0xFF;
    buf[7] = crc & 0xFF;
    return buf;
  }

  /// Build a Modbus FC-16 (write multiple registers) request.
  /// [writeData] must be exactly [regNum * 2] bytes.
  static Uint8List buildWrite10(
      int id, int addr, int regNum, Uint8List writeData) {
    final totalLen = regNum * 2 + 9;
    final buf = Uint8List(totalLen);
    int pos = 0;
    buf[pos++] = id & 0xFF;
    buf[pos++] = 0x10;
    buf[pos++] = (addr >> 8) & 0xFF;
    buf[pos++] = addr & 0xFF;
    buf[pos++] = (regNum >> 8) & 0xFF;
    buf[pos++] = regNum & 0xFF;
    buf[pos++] = (regNum * 2) & 0xFF;
    for (int i = 0; i < regNum * 2; i++) {
      buf[pos++] = writeData[i];
    }
    final crc = crc16(buf, pos);
    buf[pos++] = (crc >> 8) & 0xFF;
    buf[pos] = crc & 0xFF;
    return buf;
  }

  /// Build a Modbus FC-06 (write single register) request.
  static Uint8List buildWrite06(int id, int addr, int regValue) {
    final buf = Uint8List(8);
    buf[0] = id & 0xFF;
    buf[1] = 0x06;
    buf[2] = (addr >> 8) & 0xFF;
    buf[3] = addr & 0xFF;
    buf[4] = (regValue >> 8) & 0xFF;
    buf[5] = regValue & 0xFF;
    final crc = crc16(buf, 6);
    buf[6] = (crc >> 8) & 0xFF;
    buf[7] = crc & 0xFF;
    return buf;
  }

  // ---------------------------------------------------------------------------
  // PG4.9 convenience commands
  // ---------------------------------------------------------------------------

  /// Standard RTLS poll request:
  /// read 106 registers from address 0 (covers the full RTLS output block).
  static Uint8List buildPollRequest({int modbusId = 1}) =>
      buildRead03(modbusId, 0x0000, PgModbusConstants.regNumPollRead);

  /// Start-locate command:
  /// write value 0x0004 to register 0x003B to enable continuous RTLS output.
  static Uint8List buildStartLocateRequest({int modbusId = 1}) => buildWrite10(
        modbusId,
        PgModbusConstants.addrStartLocate,
        1,
        Uint8List.fromList([0x00, PgModbusConstants.valueStartLocate]),
      );

  // ---------------------------------------------------------------------------
  // Frame validator
  // ---------------------------------------------------------------------------

  /// Validate a received FC-03 response frame.
  ///
  /// Returns [PgModbusReceiveState.recvOk] when the frame is structurally
  /// valid (correct CRC and device ID).  The [regNum] check is skipped when
  /// [checkRegNum] is false (default for RTLS frames whose byte-count varies).
  static ({PgModbusReceiveState state, Uint8List? payload})
      validateRead03Response(
    Uint8List buf,
    int id,
    int functionCode,
    int regNum, {
    bool checkRegNum = false,
  }) {
    if (buf.length < 5) {
      return (state: PgModbusReceiveState.crcError, payload: null);
    }
    final length = buf.length;
    final crc = crc16(buf, length - 2);
    final rxCrc = (buf[length - 2] << 8) | buf[length - 1];
    if (crc != rxCrc) {
      return (state: PgModbusReceiveState.crcError, payload: null);
    }
    if (buf[0] != id) {
      return (state: PgModbusReceiveState.idError, payload: null);
    }
    if (buf[1] != functionCode) {
      return (state: PgModbusReceiveState.functionCodeError, payload: null);
    }
    if (checkRegNum && buf[2] != regNum * 2) {
      return (state: PgModbusReceiveState.regNumError, payload: null);
    }
    final payload = buf.sublist(3, length - 2);
    return (state: PgModbusReceiveState.recvOk, payload: payload);
  }

  /// Convert a byte list to an uppercase hex string (e.g. "01 03 AC DA").
  static String toHexString(Uint8List data) {
    return data
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ')
        .toUpperCase();
  }
}
