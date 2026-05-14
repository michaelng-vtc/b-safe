import 'package:flutter/foundation.dart';
import 'package:smartsurvey/features/inspection/domain/entities/uwb_model.dart';
import 'pg_modbus_rtu.dart';

/// PG4.9 Modbus/RTLS protocol data handler for smartsurvey.
///
/// Ported and adapted from BlueToothFlutterApp/lib/services/data_handler.dart.
///
/// Receives raw BLE notification bytes via [addRxData], reassembles them in a
/// ring-buffer (BLE splits frames across multiple notifications), detects
/// complete Modbus RTU frames, validates CRC, and dispatches parsed tag
/// position updates via [onTagRtlsUpdate].
///
/// Adaptations from the original DataHandler:
///   • Riverpod / AppSharedState removed – pure callback API.
///   • Coordinates converted mm (int16 big-endian) → meters (double).
///   • UwbTag.id uses String ('Tag0', 'Tag1', …) to match smartsurvey model.
///   • Anchor distances extracted from the ranging block and attached to UwbTag.
///   • modbusId is mutable so UwbService can update it without reconstruction.
class PgDataHandler {
  static const int _recvBufferMax = 20480;

  final List<int> _recvBuffer = [];

  /// Modbus device address to match (default 0x01 for PG4.9).
  /// Update this if the hardware is configured to a non-default address.
  int modbusId;

  /// Called whenever a valid RTLS tag position frame is parsed.
  final void Function(UwbTag tag)? onTagRtlsUpdate;

  // Watchdog: detect data stalls (no valid frame for >10 s).
  DateTime _lastFrameTime = DateTime.now();
  static const Duration _stallThreshold = Duration(seconds: 10);

  bool get isStalled =>
      DateTime.now().difference(_lastFrameTime) > _stallThreshold;

  // Diagnostic counters (reset on each reset() call).
  int bytesReceived = 0;
  int framesReceived = 0;
  int rtlsFramesReceived = 0;
  String lastHex = '';

  // Last-seen RTLS frame values (for the diagnostic banner).
  int lastTagId = -1;
  int lastFlags = -1; // raw flags byte (bit0=ranging, bit1=positioning)
  int lastValidFlag = -1; // last seen validFlag inside positioning block
  int noPositioningCount = 0; // frames where positioning bit was 0
  int validFlagZeroCount = 0; // frames where positioning bit=1 but validFlag≠1

  PgDataHandler({
    this.modbusId = 1,
    this.onTagRtlsUpdate,
  });

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Feed raw bytes received from the BLE TX characteristic.
  ///
  /// Safe to call on every BLE notification; internally buffers fragments and
  /// emits [onTagRtlsUpdate] only when a complete, CRC-valid frame arrives.
  void addRxData(Uint8List data) {
    _lastFrameTime = DateTime.now();

    // Overflow guard: trim the oldest half instead of discarding all buffered
    // data, so that partial frames already in the buffer are preserved.
    if (_recvBuffer.length + data.length > _recvBufferMax) {
      final trim = _recvBuffer.length ~/ 2;
      _recvBuffer.removeRange(0, trim);
    }
    _recvBuffer.addAll(data);
    bytesReceived += data.length;
    lastHex =
        data.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

    // Debug: log every incoming chunk so we can tell if BLE data is flowing.
    debugPrint('[PgDataHandler] RX ${data.length}B  '
        'buf=${_recvBuffer.length}  '
        'hex=${data.take(12).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}${data.length > 12 ? '…' : ''}');

    _processBuffer();
  }

  /// Clear the receive buffer. Call before a new connection to avoid stale data.
  void reset() {
    _recvBuffer.clear();
    bytesReceived = 0;
    framesReceived = 0;
    rtlsFramesReceived = 0;
    lastHex = '';
    lastTagId = -1;
    lastFlags = -1;
    lastValidFlag = -1;
    noPositioningCount = 0;
    validFlagZeroCount = 0;
    debugPrint('[PgDataHandler] Buffer reset');
  }

  // ---------------------------------------------------------------------------
  // Frame assembly (mirrors C# Data_RecvTask)
  // ---------------------------------------------------------------------------

  void _processBuffer() {
    while (_recvBuffer.length >= 4) {
      final firstByte = _recvBuffer[0];

      if (firstByte != modbusId) {
        // Not our device ID – discard and keep scanning.
        debugPrint(
            '[PgDataHandler] DISCARD byte=0x${firstByte.toRadixString(16).padLeft(2, '0')} '
            '(expected modbusId=0x${modbusId.toRadixString(16).padLeft(2, '0')})  '
            'buf=${_recvBuffer.length}');
        _recvBuffer.removeAt(0);
        continue;
      }

      final funcCode = _recvBuffer[1];

      if (funcCode == 0x03 || funcCode == 0x10 || funcCode == 0x06) {
        int expectedLen;

        if (funcCode == 0x03) {
          // FC-03 response: [ID][0x03][byte-count][data…][CRC-H][CRC-L]
          final byteCount = _recvBuffer[2];
          expectedLen = byteCount + 5; // ID + FC + BC + data + 2 CRC bytes
        } else {
          // FC-10 and FC-06 acknowledgements are always 8 bytes.
          expectedLen = 8;
        }

        if (expectedLen > _recvBuffer.length) {
          // Incomplete frame – wait for more bytes.
          break;
        }

        final frame = Uint8List.fromList(_recvBuffer.sublist(0, expectedLen));

        // Pre-validate CRC before consuming the buffer.
        //
        // The BLE module can split a long Modbus response across two
        // overlapping notifications (partial first + full second).  When
        // concatenated the "frame" at position 0 has corrupt interior bytes
        // and fails CRC.  Discarding only byte[0] and rescanning lets the
        // parser realign and find the real frame start in the next pass.
        final computedCrc = PgModbusRtu.crc16(frame, expectedLen - 2);
        final receivedCrc =
            (frame[expectedLen - 2] << 8) | frame[expectedLen - 1];

        if (computedCrc != receivedCrc) {
          debugPrint(
              '[PgDataHandler] CRC FAIL  fc=0x${funcCode.toRadixString(16)}  '
              'expected=0x${receivedCrc.toRadixString(16)}  '
              'computed=0x${computedCrc.toRadixString(16)}  '
              'header=${_recvBuffer.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
          _recvBuffer.removeAt(0); // skip one byte and retry
          continue;
        }

        debugPrint(
            '[PgDataHandler] FRAME OK  fc=0x${funcCode.toRadixString(16)}  '
            'len=$expectedLen  '
            'payload=${frame.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}…');

        _recvBuffer.removeRange(0, expectedLen);
        framesReceived++;
        _dispatchFrame(frame, funcCode);
      } else {
        // Device ID found but followed by an unknown function code – skip.
        _recvBuffer.removeAt(0);
      }
    }
  }

  void _dispatchFrame(Uint8List frame, int funcCode) {
    if (funcCode == 0x03) {
      _handleModbus03Response(frame);
    }
    // FC-10 / FC-06 are write acknowledgements with no payload; ignore.
  }

  // ---------------------------------------------------------------------------
  // FC-03 response handler
  // ---------------------------------------------------------------------------

  void _handleModbus03Response(Uint8List frame) {
    // CRC already validated by _processBuffer; only check ID here.
    if (frame[0] != modbusId) return;

    // RTLS magic is 0xAC 0xDA at frame[3][4].
    // Require frame.length >= 9 (byteCount >= 4) so that keep-alive
    // 1-register responses (7 bytes, where frame[5][6] are CRC bytes,
    // not tagId/flags) are never mis-detected as RTLS frames.
    final bool hasRtlsMagic =
        frame.length >= 9 && frame[3] == 0xAC && frame[4] == 0xDA;
    debugPrint('[PgDataHandler] FC03  len=${frame.length}  '
        'byte3=0x${(frame.length > 3 ? frame[3] : 0).toRadixString(16)}  '
        'byte4=0x${(frame.length > 4 ? frame[4] : 0).toRadixString(16)}  '
        'rtls_magic=$hasRtlsMagic');

    // Tag RTLS frame is identified by magic bytes 0xAC 0xDA at positions [3][4].
    if (hasRtlsMagic) {
      rtlsFramesReceived++;
      _parseTagRtlsData(frame);
    }
  }

  // ---------------------------------------------------------------------------
  // Tag RTLS position parser
  // ---------------------------------------------------------------------------

  /// Parse a PG4.9 tag RTLS frame and fire [onTagRtlsUpdate].
  ///
  /// Mirrors the C# official app (DataHandle_Helper.Tag_RtlsDataRecv):
  /// the tag is **always** emitted so it appears on the canvas immediately.
  /// When position data is not yet valid, (0, 0, 0) is used – matching the
  /// C# behaviour where the tag is added to TagList during config read and
  /// shown at the origin until the module converges on a valid fix.
  void _parseTagRtlsData(Uint8List frame) {
    // Minimum frame: ID+FC+BC+magic(2)+tagId+flags = 7 bytes.
    if (frame.length < 7) return;

    const int anchorMaxCount = 16;

    final int tagId = frame[5];
    final int flags = frame[6];
    final bool rangingEnabled = (flags & 0x01) != 0;
    final bool positioningEnabled = (flags & 0x02) != 0;

    // Always record last-seen values for the diagnostic banner.
    lastTagId = tagId;
    lastFlags = flags;

    debugPrint(
        '[PgDataHandler] RTLS  tagId=$tagId  flags=0x${flags.toRadixString(16)}  '
        'ranging=$rangingEnabled  positioning=$positioningEnabled');

    // --- Extract anchor distances (ranging block) ----------------------------
    final Map<String, double> anchorDistances = {};
    int buffIdx = 7;

    if (rangingEnabled) {
      if (buffIdx + 2 > frame.length) {
        _emitTag(tagId, 0.0, 0.0, 0.0, anchorDistances);
        return;
      }
      final int distFlag = (frame[buffIdx] << 8) | frame[buffIdx + 1];
      buffIdx += 2;

      // Mirror C# which always advances past all 16 anchor slots regardless of
      // how many are valid.  We do the same but guard against truncated frames:
      // if the frame is shorter than expected, force buffIdx to the full
      // ranging-block end (41) so the positioning data is read from the
      // correct offset.
      int i = 0;
      for (; i < anchorMaxCount; i++) {
        if (buffIdx + 2 > frame.length) break;
        final int rawCm = (frame[buffIdx] << 8) | frame[buffIdx + 1];
        buffIdx += 2;
        final bool valid = ((distFlag >> i) & 0x01) != 0;
        if (valid && rawCm > 0) {
          anchorDistances['Anchor$i'] = rawCm / 100.0;
        }
      }
      if (i < anchorMaxCount) {
        // Frame truncated mid-ranging-block; advance to expected end so
        // the positioning block (if any) starts at the right offset.
        buffIdx = 7 + 2 + anchorMaxCount * 2; // = 41
      }
      // buffIdx == 41 here.
    }

    // --- Extract position (positioning block) --------------------------------
    // If positioning is not enabled, the module is in ranging-only mode.
    // We still emit the tag at (0, 0, 0) so it appears on the canvas,
    // exactly as the C# official app does (tag is always in TagList).
    if (!positioningEnabled) {
      noPositioningCount++;
      debugPrint('[PgDataHandler] RTLS: positioning NOT enabled '
          'flags=0x${flags.toRadixString(16)}  count=$noPositioningCount');
      _emitTag(tagId, 0.0, 0.0, 0.0, anchorDistances);
      return;
    }

    if (buffIdx + 2 > frame.length) {
      debugPrint('[PgDataHandler] RTLS: frame too short for validFlag  '
          'buffIdx=$buffIdx  len=${frame.length}');
      _emitTag(tagId, 0.0, 0.0, 0.0, anchorDistances);
      return;
    }
    final int validFlag = (frame[buffIdx] << 8) | frame[buffIdx + 1];
    lastValidFlag = validFlag;
    buffIdx += 2;

    debugPrint('[PgDataHandler] RTLS  validFlag=$validFlag  '
        'buffIdx=$buffIdx  frameLen=${frame.length}');

    if (validFlag != 1) {
      // Module has not yet converged; emit at origin (matches C# behaviour).
      validFlagZeroCount++;
      debugPrint(
          '[PgDataHandler] RTLS: validFlag=$validFlag≠1  count=$validFlagZeroCount');
      _emitTag(tagId, 0.0, 0.0, 0.0, anchorDistances);
      return;
    }

    if (buffIdx + 6 > frame.length) {
      debugPrint('[PgDataHandler] RTLS: frame too short for xyz  '
          'buffIdx=$buffIdx  len=${frame.length}');
      _emitTag(tagId, 0.0, 0.0, 0.0, anchorDistances);
      return;
    }

    // PG4.9 reports coordinates in cm; convert to metres.
    final double xMeters = _toInt16(frame, buffIdx) / 100.0;
    final double yMeters = _toInt16(frame, buffIdx + 2) / 100.0;
    final double zMeters = _toInt16(frame, buffIdx + 4) / 100.0;

    debugPrint('[PgDataHandler] TAG POSITION  id=Tag$tagId  '
        'x=${xMeters.toStringAsFixed(2)}m  '
        'y=${yMeters.toStringAsFixed(2)}m  '
        'z=${zMeters.toStringAsFixed(2)}m');

    _emitTag(tagId, xMeters, yMeters, zMeters, anchorDistances);
  }

  void _emitTag(int tagId, double x, double y, double z,
      Map<String, double> anchorDistances) {
    final tag = UwbTag(
      id: 'Tag$tagId',
      x: x,
      y: y,
      z: z,
      anchorDistances: anchorDistances,
    );
    onTagRtlsUpdate?.call(tag);
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  /// Interpret two bytes at [offset] as a big-endian signed 16-bit integer.
  static int _toInt16(List<int> buf, int offset) {
    final raw = (buf[offset] << 8) | buf[offset + 1];
    return raw >= 0x8000 ? raw - 0x10000 : raw;
  }
}
