import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io' show File, Platform;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bsafe_app/shared/models/uwb_model.dart';
import 'package:bsafe_app/shared/services/desktop_serial_service.dart';
import 'package:bsafe_app/shared/services/mobile_serial_service.dart';

/// Central UWB service.
///
/// Responsibilities:
/// - Manage serial connectivity (desktop and Android OTG).
/// - Parse BU04 TWR packets into tag and anchor data.
/// - Maintain UI-facing positioning state.
class UwbService extends ChangeNotifier {
  // Connect.
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Connection mode.
  bool _isRealDevice = false;
  bool get isRealDevice => _isRealDevice;

  // Anchor list.
  List<UwbAnchor> _anchors = [];
  List<UwbAnchor> get anchors => _anchors;

  // Current tag data.
  UwbTag? _currentTag;
  UwbTag? get currentTag => _currentTag;

  // Trajectory history.
  final List<TrajectoryPoint> _trajectory = [];
  List<TrajectoryPoint> get trajectory => _trajectory;

  // Runtime configuration.
  UwbConfig _config = UwbConfig();
  UwbConfig get config => _config;

  // Floor plan image cache.
  ui.Image? _floorPlanImage;
  ui.Image? get floorPlanImage => _floorPlanImage;
  bool _isLoadingFloorPlan = false;
  bool get isLoadingFloorPlan => _isLoadingFloorPlan;

  // Serial service (desktop platforms).
  DesktopSerialService? _desktopSerial;

  // Serial service (Android mobile platform).
  MobileSerialService? _mobileSerial;

  // Serial settings.
  String _portName = 'COM3';
  int _baudRate = 115200;

  // Serial data subscription.
  StreamSubscription<String>? _serialSubscription;

  // Simulation timer.
  Timer? _simulationTimer;

  // UI refresh timer.
  Timer? _uiRefreshTimer;

  // Last error message.
  String? _lastError;
  String? get lastError => _lastError;

  // Data receive statistics (debug).
  DateTime? _lastDataTime;
  int _dataReceiveCount = 0;
  DateTime? get lastDataTime => _lastDataTime;
  int get dataReceiveCount => _dataReceiveCount;

  // Translated legacy comment.
  final List<double> _xHistory = [];
  final List<double> _yHistory = [];
  static const int _filterWindowSize = 5; // Average.

  // Distancehistory ( ).
  final Map<int, List<double>> _distanceHistory = {};
  static const int _distanceFilterSize = 5; // Translated note.

  // Distance byte offset ( ).
  List<int> _learnedOffsets = []; // [D0_pos, D1_pos, D2_pos, D3_pos]
  int _offsetLearnCount = 0;
  final Map<String, int> _offsetPatternCounts = {}; // Mode.
  static const int _offsetLearnThreshold = 10; // Translated note.

  // ( / ) - 1.5m/s.
  static const double _maxSpeed = 3.0;
  DateTime? _lastPositionTime;

  // Data ( debug).
  final List<String> _rawDataLog = [];
  List<String> get rawDataLog => _rawDataLog;

  // Clear data.
  void clearRawDataLog() {
    _rawDataLog.clear();
    notifyListeners();
  }

  // Clear error message.
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  // Translated legacy comment.
  static const String _anchorsStorageKey = 'uwb_anchors_config';

  // Save anchor configuration to local storage.
  Future<void> _saveAnchorsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final anchorsJson = _anchors.map((a) => a.toJson()).toList();
      await prefs.setString(_anchorsStorageKey, jsonEncode(anchorsJson));
      debugPrint('✅ Anchor config saved: ${_anchors.length} anchor(s)');
    } catch (e) {
      debugPrint('❌ Failed to save anchor config: $e');
    }
  }

  // Load anchor configuration from local storage.
  Future<void> loadAnchorsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final anchorsJsonString = prefs.getString(_anchorsStorageKey);

      if (anchorsJsonString != null && anchorsJsonString.isNotEmpty) {
        final List<dynamic> anchorsJson = jsonDecode(anchorsJsonString);
        _anchors = anchorsJson.map((json) => UwbAnchor.fromJson(json)).toList();
        // Migrate legacy Chinese anchor names (anchorN → AnchorN).
        _anchors = _anchors.map((a) {
          if (a.id.startsWith('基站')) {
            final num = a.id.substring(2);
            return UwbAnchor(
                id: 'Anchor$num', x: a.x, y: a.y, z: a.z, isActive: a.isActive);
          }
          return a;
        }).toList();
        debugPrint(
            '✅ Loaded saved anchor config: ${_anchors.length} anchor(s)');
        notifyListeners();
      } else {
        debugPrint('📝 No saved config found, using default anchors');
        initializeDefaultAnchors();
      }
    } catch (e) {
      debugPrint('❌ Failed to load anchor config, using defaults: $e');
      initializeDefaultAnchors();
    }
  }

  // Initialize anchorconfig ( TWR App ).
  void initializeDefaultAnchors() {
    _anchors = [
      UwbAnchor(id: 'Anchor0', x: 0.00, y: 0.00, z: 3.00),
      UwbAnchor(id: 'Anchor1', x: -6.84, y: 0.00, z: 3.00),
      UwbAnchor(id: 'Anchor2', x: 0.00, y: -5.51, z: 3.00),
      UwbAnchor(id: 'Anchor3', x: -5.34, y: -5.51, z: 3.00),
    ];
    _saveAnchorsToStorage(); // Save config.
    notifyListeners();
  }

  // Update anchor configuration.
  void updateAnchor(int index, UwbAnchor anchor) {
    if (index >= 0 && index < _anchors.length) {
      _anchors[index] = anchor;
      _saveAnchorsToStorage(); // Save.
      notifyListeners();
    }
  }

  // Rename anchor.
  void renameAnchor(int index, String newName) {
    if (index >= 0 && index < _anchors.length) {
      final old = _anchors[index];
      _anchors[index] = UwbAnchor(
        id: newName,
        x: old.x,
        y: old.y,
        z: old.z,
        isActive: old.isActive,
      );
      _saveAnchorsToStorage(); // Save.
      notifyListeners();
    }
  }

  // Anchor list.
  void addAnchor(UwbAnchor anchor) {
    _anchors.add(anchor);
    _saveAnchorsToStorage(); // Save.
    notifyListeners();
  }

  // Anchor list.
  void removeAnchor(int index) {
    if (index >= 0 && index < _anchors.length) {
      _anchors.removeAt(index);
      _saveAnchorsToStorage(); // Save.
      notifyListeners();
    }
  }

  // Updateconfig.
  void updateConfig(UwbConfig newConfig) {
    _config = newConfig;
    notifyListeners();
  }

  // Translated legacy comment.

  /// Translated legacy note.
  static const List<String> supportedImageExtensions = [
    'png',
    'jpg',
    'jpeg',
    'bmp',
    'gif',
    'webp',
  ];
  static const List<String> supportedVectorExtensions = ['svg'];
  static const List<String> supportedPdfExtensions = ['pdf'];
  static const List<String> supportedCadExtensions = ['dwg', 'dxf'];

  /// Translated legacy note.
  String _getFileExtension(String filePath) {
    return filePath.split('.').last.toLowerCase();
  }

  /// Translated legacy note.
  String _getFileType(String filePath) {
    final ext = _getFileExtension(filePath);
    if (supportedImageExtensions.contains(ext)) return 'image';
    if (supportedVectorExtensions.contains(ext)) return 'svg';
    if (supportedPdfExtensions.contains(ext)) return 'pdf';
    if (supportedCadExtensions.contains(ext)) return 'dwg';
    return 'unknown';
  }

  /// Load (auto ).
  Future<void> loadFloorPlanImage(String filePath) async {
    try {
      _isLoadingFloorPlan = true;
      notifyListeners();

      final file = File(filePath);
      if (!await file.exists()) {
        _lastError = 'File not found: $filePath';
        _isLoadingFloorPlan = false;
        notifyListeners();
        return;
      }

      final fileType = _getFileType(filePath);

      switch (fileType) {
        case 'image':
          await _loadRasterImage(filePath);
          break;
        case 'svg':
          await _loadSvgImage(filePath);
          break;
        case 'pdf':
          await _loadPdfImage(filePath);
          break;
        case 'dwg':
          _isLoadingFloorPlan = false;
          _lastError =
              'DWG/DXF format not directly supported. Please convert to PDF or SVG first.';
          notifyListeners();
          return;
        default:
          _isLoadingFloorPlan = false;
          _lastError =
              'Unsupported file format: ${_getFileExtension(filePath)}';
          notifyListeners();
          return;
      }

      _config = _config.copyWith(
        floorPlanImagePath: filePath,
        showFloorPlan: true,
        floorPlanFileType: fileType,
      );

      _isLoadingFloorPlan = false;
      notifyListeners();

      debugPrint(
          'Floor plan loaded ($fileType): ${_floorPlanImage!.width}x${_floorPlanImage!.height}');
    } catch (e) {
      _isLoadingFloorPlan = false;
      _lastError = 'Failed to load floor plan: $e';
      notifyListeners();
      debugPrint('Floor plan load error: $e');
    }
  }

  /// Load (PNG, JPG, BMP, GIF, WEBP).
  Future<void> _loadRasterImage(String filePath) async {
    final file = File(filePath);
    final Uint8List bytes = await file.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();

    _floorPlanImage?.dispose();
    _floorPlanImage = frameInfo.image;
  }

  /// Load SVG → ui.Image.
  Future<void> _loadSvgImage(String filePath) async {
    final file = File(filePath);
    final String svgString = await file.readAsString();

    // Flutter_svg SVG.
    final PictureInfo pictureInfo = await vg.loadPicture(
      SvgStringLoader(svgString),
      null,
    );

    // SVG image.
    final double width = pictureInfo.size.width;
    final double height = pictureInfo.size.height;

    // SVG settings ， default.
    final int renderWidth = width > 0 ? width.toInt() : 1024;
    final int renderHeight = height > 0 ? height.toInt() : 1024;

    // Ui.Image.
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    // Translated legacy note.
    if (width > 0 && height > 0) {
      canvas.scale(
        renderWidth / width,
        renderHeight / height,
      );
    }
    canvas.drawPicture(pictureInfo.picture);

    final ui.Image image =
        await recorder.endRecording().toImage(renderWidth, renderHeight);

    pictureInfo.picture.dispose();

    _floorPlanImage?.dispose();
    _floorPlanImage = image;
  }

  /// Load PDF → ui.Image.
  Future<void> _loadPdfImage(String filePath) async {
    final document = await PdfDocument.openFile(filePath);
    final page = document.pages[0];

    // PDF.
    final pageImage = await page.render(
      width: (page.width * 2).toInt(),
      height: (page.height * 2).toInt(),
    );

    if (pageImage == null) {
      document.dispose();
      throw Exception('PDF page rendering failed');
    }

    // Data ui.Image.
    final pixels = pageImage.pixels;
    final ui.ImmutableBuffer buffer =
        await ui.ImmutableBuffer.fromUint8List(pixels);
    final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: pageImage.width,
      height: pageImage.height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final ui.Codec codec = await descriptor.instantiateCodec();
    final ui.FrameInfo frameInfo = await codec.getNextFrame();

    descriptor.dispose();
    buffer.dispose();

    _floorPlanImage?.dispose();
    _floorPlanImage = frameInfo.image;

    document.dispose();
  }

  /// Clear.
  void clearFloorPlan() {
    _floorPlanImage?.dispose();
    _floorPlanImage = null;
    _config = _config.copyWith(
      showFloorPlan: false,
    );
    notifyListeners();
  }

  /// Show.
  void toggleFloorPlan(bool show) {
    _config = _config.copyWith(showFloorPlan: show);
    notifyListeners();
  }

  /// Update.
  void updateFloorPlanOpacity(double opacity) {
    _config = _config.copyWith(floorPlanOpacity: opacity.clamp(0.0, 1.0));
    notifyListeners();
  }

  // Connect UWBdevice ( platform ).
  Future<bool> connectRealDevice() async {
    try {
      _lastError = null;

      // Platform (Windows/Linux/macOS).
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        _desktopSerial = DesktopSerialService();

        // Serial.
        final ports = _desktopSerial!.getAvailablePorts();
        debugPrint('Available ports: $ports');

        if (ports.isEmpty) {
          _lastError = 'No serial port found. Ensure BU04 is connected.';
          notifyListeners();
          return false;
        }

        // Autoconnect.
        final connected =
            await _desktopSerial!.autoConnect(baudRate: _baudRate);

        if (connected) {
          // Serial data subscription.
          _serialSubscription = _desktopSerial!.dataStream.listen(
            (data) {
              processSerialData(data);
            },
            onError: (error) {
              _lastError = 'Serial port error: $error';
              notifyListeners();
            },
          );

          _isConnected = true;
          _isRealDevice = true;
          notifyListeners();
          return true;
        } else {
          _lastError = 'Cannot connect to serial port. Check your device.';
          notifyListeners();
          return false;
        }
      }

      // Android platform (USB OTG).
      if (!kIsWeb && Platform.isAndroid) {
        _mobileSerial = MobileSerialService();

        // USB device.
        final devices = await _mobileSerial!.getAvailableDevices();
        debugPrint('Available USB devices: $devices');

        if (devices.isEmpty) {
          _lastError =
              'No USB device found. Ensure BU04 is connected via USB-C.';
          notifyListeners();
          return false;
        }

        // Autoconnect.
        final connected = await _mobileSerial!.autoConnect(baudRate: _baudRate);

        if (connected) {
          _serialSubscription = _mobileSerial!.dataStream.listen(
            (data) {
              processSerialData(data);
            },
            onError: (error) {
              _lastError = 'USB serial error: $error';
              notifyListeners();
            },
          );

          _isConnected = true;
          _isRealDevice = true;
          _startUiRefreshTimer();
          notifyListeners();
          return true;
        } else {
          _lastError =
              'Cannot connect USB device. Check connection and OTG settings.';
          notifyListeners();
          return false;
        }
      }

      // Web platform.
      if (kIsWeb) {
        _lastError = 'For Web platform, use the Web Serial API.';
        notifyListeners();
        return false;
      }

      // Platform.
      _lastError = 'Serial connection not supported on this platform.';
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = 'Connection error: $e';
      debugPrint('Failed to connect real device: $e');
      notifyListeners();
      return false;
    }
  }

  // Connect serial( device).
  Future<bool> connectToPort(String portName, {int? baudRate}) async {
    try {
      _lastError = null;
      _portName = portName;
      _baudRate = baudRate ?? _baudRate;

      // Platform (Windows/Linux/macOS).
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        _desktopSerial = DesktopSerialService();

        debugPrint('Trying serial port: $portName');

        // Connect serial.
        final connected =
            await _desktopSerial!.connect(portName, baudRate: _baudRate);

        if (connected) {
          // Serial data subscription.
          _serialSubscription = _desktopSerial!.dataStream.listen(
            (data) {
              processSerialData(data);
            },
            onError: (error) {
              _lastError = 'Serial port error: $error';
              notifyListeners();
            },
          );

          _isConnected = true;
          _isRealDevice = true;

          // UI ( ).
          _startUiRefreshTimer();

          notifyListeners();
          debugPrint('Connected to $portName');
          return true;
        } else {
          _lastError = 'Cannot connect to $portName';
          notifyListeners();
          return false;
        }
      }

      // Android platform (USB OTG).
      if (!kIsWeb && Platform.isAndroid) {
        _mobileSerial = MobileSerialService();

        final devices = await _mobileSerial!.getAvailableDevices();
        if (devices.isEmpty) {
          _lastError = 'USB device not found';
          notifyListeners();
          return false;
        }

        // Android portName.
        int deviceIndex = 0;
        for (int i = 0; i < devices.length; i++) {
          if (devices[i].displayName == portName ||
              devices[i].deviceName == portName) {
            deviceIndex = i;
            break;
          }
        }

        final connected = await _mobileSerial!
            .connectByIndex(deviceIndex, baudRate: _baudRate);

        if (connected) {
          _serialSubscription = _mobileSerial!.dataStream.listen(
            (data) {
              processSerialData(data);
            },
            onError: (error) {
              _lastError = 'USB serial error: $error';
              notifyListeners();
            },
          );

          _isConnected = true;
          _isRealDevice = true;
          _startUiRefreshTimer();
          notifyListeners();
          debugPrint('Connected to USB device');
          return true;
        } else {
          _lastError = 'Cannot connect to USB device';
          notifyListeners();
          return false;
        }
      }

      _lastError = 'Serial connection not supported on this platform.';
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = 'Connection error: $e';
      debugPrint('Serial connection failed: $e');
      notifyListeners();
      return false;
    }
  }

  // Connect device.
  Future<bool> connect(
      {String? port, int? baudRate, bool simulate = true}) async {
    _portName = port ?? _portName;
    _baudRate = baudRate ?? _baudRate;
    _lastError = null;

    if (!simulate) {
      return connectRealDevice();
    }

    // Connect.
    await Future.delayed(const Duration(milliseconds: 500));

    _isConnected = true;
    _isRealDevice = false;
    notifyListeners();

    // Simulation timer.
    startSimulation();

    return true;
  }

  // Disconnectconnect.
  void disconnect() {
    _isConnected = false;
    _isRealDevice = false;
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _uiRefreshTimer?.cancel();
    _uiRefreshTimer = null;
    _serialSubscription?.cancel();
    _serialSubscription = null;

    // Disconnect serial.
    _desktopSerial?.disconnect();
    _desktopSerial = null;

    // Disconnect Android USB serial.
    _mobileSerial?.disconnect();
    _mobileSerial = null;

    notifyListeners();
  }

  // UI - ( 50 ， 20fps).
  void _startUiRefreshTimer() {
    _uiRefreshTimer?.cancel();
    _uiRefreshTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_isConnected) {
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  // Serial data - update.
  void processSerialData(String data) {
    // Debug： data.
    _lastDataTime = DateTime.now();
    _dataReceiveCount++;

    // Data( ).
    if (_rawDataLog.length < 50) {
      final hexData = data.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      _rawDataLog.add(
          '[${DateTime.now().toString().substring(11, 19)}] HEX: $hexData');
    }
    if (_rawDataLog.length > 50) {
      _rawDataLog.removeAt(0);
    }

    // Debug： data ( 50 ).
    if (_dataReceiveCount % 50 == 1) {
      debugPrint(
          'Raw data (first 100 chars): ${data.substring(0, data.length > 100 ? 100 : data.length)}');
      debugPrint(
          'Data type: RAWBIN=${data.startsWith("RAWBIN:")}, CmdM=${data.startsWith("CmdM")}');
    }

    final tag = parseUwbData(data);

    // Debug： result.
    if (_dataReceiveCount % 10 == 0) {
      debugPrint(
          'Packet #$_dataReceiveCount: tag=${tag != null ? "valid x=${tag.x.toStringAsFixed(2)}, y=${tag.y.toStringAsFixed(2)}" : "null"}');
    }

    if (tag != null) {
      _currentTag = tag;

      // UIupdate - show.
      notifyListeners();
    } else {
      // UpdateUI(show data).
      notifyListeners();
    }
  }

  // Data ( ).
  void startSimulation() {
    if (_simulationTimer != null) return;

    final random = Random();
    const double baseX = 4.5;
    const double baseY = 1.8;
    double angle = 0;

    _simulationTimer =
        Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!_isConnected) {
        timer.cancel();
        return;
      }

      // Tag ( trajectory).
      angle += 0.05;
      final double radius = 0.5 + random.nextDouble() * 0.3;
      double newX =
          baseX + cos(angle) * radius + (random.nextDouble() - 0.5) * 0.1;
      double newY =
          baseY + sin(angle) * radius + (random.nextDouble() - 0.5) * 0.1;

      // Translated legacy note.
      newX = newX.clamp(-8.0, 2.0);
      newY = newY.clamp(-7.0, 2.0);

      // Anchor distance.
      final Map<String, double> distances = {};
      for (var anchor in _anchors) {
        final double dx = newX - anchor.x;
        final double dy = newY - anchor.y;
        final double dz = 0 - anchor.z; // Tag.
        double distance = sqrt(dx * dx + dy * dy + dz * dz);
        // Distance.
        distance = distance * _config.correctionA + _config.correctionB;
        distances[anchor.id] = double.parse(distance.toStringAsFixed(3));
      }

      // Updatetagdata.
      _currentTag = UwbTag(
        id: 'Tag0',
        x: double.parse(newX.toStringAsFixed(3)),
        y: double.parse(newY.toStringAsFixed(3)),
        z: 0.0,
        r95: double.parse((random.nextDouble() * 0.1).toStringAsFixed(3)),
        anchorDistances: distances,
      );

      notifyListeners();
    });
  }

  // Stop.
  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  // Cleartrajectory.
  void clearTrajectory() {
    _trajectory.clear();
    notifyListeners();
  }

  // UWBdata.
  // Translated legacy note.
  // 1. mc : "mc 00 00001234 00001234 00001234 00001234 0353 189a 0030 0001 c70f".
  // 2. : "TAG:0 X:4.533 Y:1.868 Z:0.000 Q:95".
  // 3. JSON : {"tag":"0","x":4.533,"y":1.868,"z":0.0,"d0":5.07,"d1":3.104,"d2":4.118,"d3":2.964}.
  // 4. TWR : "mr 00 00001234 00001234 00001234 00001234...".
  // 5. distance : "dis:0,d0:5070,d1:3104,d2:4118,d3:2964".
  // 6. : "pos:0,x:4533,y:1868,z:0".
  // 7. CmdM : "CmdM:4[ data]".
  // 8. RAWBIN : "RAWBIN:length:hex_bytes" ( ).
  UwbTag? parseUwbData(String data) {
    try {
      data = data.trim();
      if (data.isEmpty) return null;

      // RAWBIN.
      if (data.startsWith('RAWBIN:')) {
        return _parseCmdMFormat(data);
      }

      // CmdM ( ).
      if (data.startsWith('CmdM')) {
        return _parseCmdMFormat(data);
      }

      // JSON.
      if (data.startsWith('{')) {
        return _parseJsonFormat(data);
      }

      // TAG.
      if (data.toUpperCase().startsWith('TAG')) {
        return _parseTagFormat(data);
      }

      // Mc/mr ( ).
      if (data.startsWith('mc') || data.startsWith('mr')) {
        return _parseMcFormat(data);
      }

      // Pos ( data).
      if (data.toLowerCase().startsWith('pos')) {
        return _parsePosFormat(data);
      }

      // Dis (distancedata).
      if (data.toLowerCase().startsWith('dis')) {
        return _parseDisFormat(data);
      }

      // X: y.
      if (data.toLowerCase().contains('x:') &&
          data.toLowerCase().contains('y:')) {
        return _parseXYFormat(data);
      }

      // Coordinate (x,y,z).
      if (data.contains(',') && !data.contains(':')) {
        return _parseSimpleFormat(data);
      }

      // Translated legacy note.
      if (RegExp(r'^[\d\s.,-]+$').hasMatch(data)) {
        return _parseSpaceSeparatedFormat(data);
      }

      return null;
    } catch (e) {
      debugPrint('UWB data parse failed: $e');
      return null;
    }
  }

  // CmdM ( BU04 ).
  // RAWBIN:length:hexdata.
  // BU04 TWR data.
  // CmdM:4[data] data anchor distance.
  UwbTag? _parseCmdMFormat(String data) {
    try {
      // RAWBIN:length:hex_bytes.
      if (data.startsWith('RAWBIN:')) {
        return _parseRawBinaryFormat(data);
      }

      // Translated legacy note.
      if (data.length < 10) return null;

      final bracketIndex = data.indexOf('[');
      if (bracketIndex < 0) return null;

      return null;
    } catch (e) {
      debugPrint('CmdM format parse error: $e');
      return null;
    }
  }

  // Simulation timer.
  // RAWBIN:length:43 6d 64 4d 3a 34 5b.
  // BU04 TWR mode data ( analysis).
  // "CmdM:4[" + data (+ "]").
  // 91 data: [ 8B][D0 2B][D1 2B][00...][data ].
  UwbTag? _parseRawBinaryFormat(String data) {
    try {
      final parts = data.split(':');
      if (parts.length < 3) return null;

      final hexString = parts.sublist(2).join(':');
      final hexBytes = hexString.split(' ');

      // Translated legacy note.
      final bytes =
          hexBytes.map((h) => int.tryParse(h, radix: 16) ?? 0).toList();

      // '[' (0x5b) data start.
      final bracketStart = bytes.indexOf(0x5b);
      if (bracketStart < 0) {
        return null;
      }

      // ']' ， data.
      final bracketEnd = bytes.lastIndexOf(0x5d);

      List<int> dataBytes;
      if (bracketEnd > bracketStart) {
        // ']' ， '[' ']' data.
        dataBytes = bytes.sublist(bracketStart + 1, bracketEnd);
      } else {
        // ']'， '[' data.
        dataBytes = bytes.sublist(bracketStart + 1);
      }

      // Simulation timer.
      if (dataBytes.length < 12) {
        return null;
      }

      // ===== BU04 TWR - distance =====.
      final List<double> distances = [-1.0, -1.0, -1.0, -1.0];

      if (_learnedOffsets.length == 4) {
        // Byte offset ，.
        for (int i = 0; i < 4; i++) {
          final pos = _learnedOffsets[i];
          if (pos + 1 < dataBytes.length) {
            final int val = dataBytes[pos] | (dataBytes[pos + 1] << 8);
            if (val > 50 && val < 20000) {
              distances[i] = val / 1000.0;
            }
          }
        }
      } else {
        // ： 4 distance byte.
        // D0 [8-9].
        final List<({int pos, int valueMm})> allValid = [];
        for (int pos = 8; pos < min(dataBytes.length - 1, 40); pos += 2) {
          final int val = dataBytes[pos] | (dataBytes[pos + 1] << 8);
          if (val > 50 && val < 20000) {
            allValid.add((pos: pos, valueMm: val));
          }
        }

        // Translated legacy comment.
        final List<({int pos, int valueMm})> unique = [];
        for (final v in allValid) {
          bool isDup = false;
          for (final u in unique) {
            if ((v.valueMm - u.valueMm).abs() < max(u.valueMm * 0.08, 80)) {
              isDup = true;
              break;
            }
          }
          if (!isDup) unique.add(v);
        }

        // Distance.
        for (int i = 0; i < unique.length && i < 4; i++) {
          distances[i] = unique[i].valueMm / 1000.0;
        }

        // Offset mode.
        if (unique.length >= 3) {
          final pattern = unique.take(4).map((u) => u.pos).join(',');
          _offsetPatternCounts[pattern] =
              (_offsetPatternCounts[pattern] ?? 0) + 1;
          _offsetLearnCount++;

          if (_offsetLearnCount >= _offsetLearnThreshold) {
            // Count occurrences of detected offset patterns.
            String bestPattern = '';
            int bestCount = 0;
            _offsetPatternCounts.forEach((p, c) {
              if (c > bestCount) {
                bestPattern = p;
                bestCount = c;
              }
            });
            if (bestCount >= _offsetLearnThreshold * 0.5) {
              _learnedOffsets = bestPattern.split(',').map(int.parse).toList();
              debugPrint(
                  '✅ Learning complete! Fixed byte offsets: $_learnedOffsets (found $bestCount/$_offsetLearnCount times)');
            } else {
              // Translated legacy note.
              _offsetLearnCount = 0;
              _offsetPatternCounts.clear();
            }
          }
        }
      }

      debugPrint(
          'Raw distances: D0=${distances[0].toStringAsFixed(2)}m D1=${distances[1].toStringAsFixed(2)}m D2=${distances[2].toStringAsFixed(2)}m D3=${distances[3].toStringAsFixed(2)}m ${_learnedOffsets.isNotEmpty ? "(fixed)" : "(learning $_offsetLearnCount/$_offsetLearnThreshold)"}');

      // ===== distance ( distance anchor ) =====.
      final indexMap = _config.distanceIndexMap;
      if (indexMap.length == 4 &&
          !(indexMap[0] == 0 &&
              indexMap[1] == 1 &&
              indexMap[2] == 2 &&
              indexMap[3] == 3)) {
        final original = List<double>.from(distances);
        for (int i = 0; i < 4; i++) {
          if (indexMap[i] >= 0 && indexMap[i] < 4) {
            distances[indexMap[i]] = original[i];
          }
        }
        debugPrint(
            'Mapped distances: D0=${distances[0].toStringAsFixed(2)}m D1=${distances[1].toStringAsFixed(2)}m D2=${distances[2].toStringAsFixed(2)}m D3=${distances[3].toStringAsFixed(2)}m (map: $indexMap)');
      }

      // ===== distance =====.
      final double corrA = _config.correctionA; // 0.78
      final double corrB = _config.correctionB; // 0.0

      for (int i = 0; i < distances.length; i++) {
        if (distances[i] > 0) {
          distances[i] = distances[i] * corrA + corrB;
        }
      }

      // Distance.
      final validCount = distances.where((d) => d > 0).length;

      if (validCount >= 2) {
        // Anchor initialize.
        if (_anchors.isEmpty) {
          debugPrint('Warning: Anchors not initialized, initializing defaults');
          initializeDefaultAnchors();
        }

        // ( 3 distance).
        if (validCount >= 3 && _anchors.length >= 3) {
          final pos = _trilaterationWithDistances(distances);
          if (pos != null) {
            debugPrint(
                '📍 Position: (${pos.$1.toStringAsFixed(3)}, ${pos.$2.toStringAsFixed(3)}) | Anchors: ${_anchors.map((a) => "${a.id}(${a.x.toStringAsFixed(2)},${a.y.toStringAsFixed(2)})").join(" ")}');
            return _createTagWithMeasuredDistances(
                pos.$1, pos.$2, 0.0, '0', distances);
          }
        }

        // 2 distance，.
        // DebugPrint(' ...').
        final pos = _twoCircleIntersection(distances);
        if (pos != null) {
          // DebugPrint(' : x=${pos.$1.toStringAsFixed(2)}, y=${pos.$2.toStringAsFixed(2)}').
          return _createTagWithMeasuredDistances(
              pos.$1, pos.$2, 0.0, '0', distances);
        } else {
          // DebugPrint(' ').
        }

        // Distancedata( anchor ， ).
        if (_currentTag != null) {
          return _createTagWithMeasuredDistances(
              _currentTag!.x, _currentTag!.y, 0, '0', distances);
        }
        // History ， anchor.
        final cx = _anchors.isEmpty
            ? 0.0
            : _anchors.map((a) => a.x).reduce((a, b) => a + b) /
                _anchors.length;
        final cy = _anchors.isEmpty
            ? 0.0
            : _anchors.map((a) => a.y).reduce((a, b) => a + b) /
                _anchors.length;
        return _createTagWithMeasuredDistances(cx, cy, 0, '0', distances);
      }

      return null;
    } catch (e) {
      debugPrint('Parse error: $e');
      return null;
    }
  }

  // Distance ( ).
  (double, double)? _twoCircleIntersection(List<double> distances) {
    // Anchor list.
    final List<int> validIndices = [];
    for (int i = 0; i < min(distances.length, _anchors.length); i++) {
      if (distances[i] > 0 && _anchors[i].isActive) {
        validIndices.add(i);
      }
    }

    // DebugPrint(' : anchor =$validIndices, anchortotal =${_anchors.length}').

    if (validIndices.length < 2) {
      // DebugPrint(' : anchor 2 ').
      return null;
    }

    final a1 = _anchors[validIndices[0]];
    final a2 = _anchors[validIndices[1]];
    final r1 = distances[validIndices[0]];
    final r2 = distances[validIndices[1]];

    // DebugPrint(' : A1=(${a1.x}, ${a1.y}), A2=(${a2.x}, ${a2.y}), R1=$r1, R2=$r2').

    // Height (anchorheight - tagheight).
    const double tagHeight = 1.0; // Tagheight.
    final dz1 = (a1.z - tagHeight).abs();
    final dz2 = (a2.z - tagHeight).abs();

    // 3D distance 2D distance.
    final d1 = r1 > dz1 ? sqrt(r1 * r1 - dz1 * dz1) : r1 * 0.8;
    final d2 = r2 > dz2 ? sqrt(r2 * r2 - dz2 * dz2) : r2 * 0.8;

    // DebugPrint(' : height d1=$d1, d2=$d2').

    // Translated legacy note.
    final dx = a2.x - a1.x;
    final dy = a2.y - a1.y;
    final d = sqrt(dx * dx + dy * dy);

    // DebugPrint(' : anchor d=$d').

    if (d < 0.01 || d > d1 + d2 + 1.0) {
      // Translated legacy comment.
      final ratio = d1 / (d1 + d2 + 0.001);
      return _smoothPosition(
        a1.x + dx * ratio,
        a1.y + dy * ratio,
      );
    }

    // Translated legacy note.
    final a = (d1 * d1 - d2 * d2 + d * d) / (2 * d);
    final hSq = d1 * d1 - a * a;

    if (hSq < 0) {
      // Translated legacy comment.
      final ratio = d1 / (d1 + d2 + 0.001);
      return _smoothPosition(
        a1.x + dx * ratio,
        a1.y + dy * ratio,
      );
    }

    final hVal = sqrt(hSq);

    // Translated legacy note.
    final px = a1.x + a * dx / d;
    final py = a1.y + a * dy / d;

    // Translated legacy note.
    final x1 = px + hVal * dy / d;
    final y1 = py - hVal * dx / d;
    final x2 = px - hVal * dy / d;
    final y2 = py + hVal * dx / d;

    // DebugPrint(' : (${x1.toStringAsFixed(2)}, ${y1.toStringAsFixed(2)}), (${x2.toStringAsFixed(2)}, ${y2.toStringAsFixed(2)})').

    // Anchor list.
    final allX = _anchors.map((a) => a.x).toList();
    final allY = _anchors.map((a) => a.y).toList();
    final anchorMinX = allX.reduce(min);
    final anchorMaxX = allX.reduce(max);
    final anchorMinY = allY.reduce(min);
    final anchorMaxY = allY.reduce(max);
    final margin =
        max((anchorMaxX - anchorMinX), (anchorMaxY - anchorMinY)) * 0.5 + 2.0;
    final bool valid1 = x1 >= anchorMinX - margin &&
        x1 <= anchorMaxX + margin &&
        y1 >= anchorMinY - margin &&
        y1 <= anchorMaxY + margin;
    final bool valid2 = x2 >= anchorMinX - margin &&
        x2 <= anchorMaxX + margin &&
        y2 >= anchorMinY - margin &&
        y2 <= anchorMaxY + margin;

    if (valid1 && valid2) {
      // Translated legacy comment.
      final centerX = (anchorMinX + anchorMaxX) / 2;
      final centerY = (anchorMinY + anchorMaxY) / 2;
      final dist1 =
          (x1 - centerX) * (x1 - centerX) + (y1 - centerY) * (y1 - centerY);
      final dist2 =
          (x2 - centerX) * (x2 - centerX) + (y2 - centerY) * (y2 - centerY);
      return dist1 < dist2 ? _smoothPosition(x1, y1) : _smoothPosition(x2, y2);
    } else if (valid1) {
      return _smoothPosition(x1, y1);
    } else if (valid2) {
      return _smoothPosition(x2, y2);
    } else {
      // Translated legacy comment.
      return _smoothPosition(
        (x1 + x2) / 2,
        (y1 + y2) / 2,
      );
    }
  }

  // Distance ( ).
  double _medianFilter(int anchorIndex, double newDistance) {
    _distanceHistory.putIfAbsent(anchorIndex, () => []);
    final history = _distanceHistory[anchorIndex]!;

    // ： history data， ，.
    if (history.length >= 3) {
      final sorted = List<double>.from(history)..sort();
      final median = sorted[sorted.length ~/ 2];
      // 50%， average.
      if ((newDistance - median).abs() > median * 0.5) {
        newDistance = median * 0.7 + newDistance * 0.3;
      }
    }

    history.add(newDistance);
    if (history.length > _distanceFilterSize) {
      history.removeAt(0);
    }

    if (history.length < 2) return newDistance;

    // Translated legacy note.
    final sorted = List<double>.from(history)..sort();
    return sorted[sorted.length ~/ 2];
  }

  // Translated legacy comment.
  (double, double) _smoothPosition(double x, double y) {
    final now = DateTime.now();

    // ： distance ， distance.
    if (_xHistory.isNotEmpty && _lastPositionTime != null) {
      final lastX = _xHistory.last;
      final lastY = _yHistory.last;
      final dt = now.difference(_lastPositionTime!).inMilliseconds / 1000.0;
      if (dt > 0.01) {
        final dist =
            sqrt((x - lastX) * (x - lastX) + (y - lastY) * (y - lastY));
        final speed = dist / dt;
        if (speed > _maxSpeed) {
          // Distance.
          final maxDist = _maxSpeed * dt;
          final ratio = maxDist / dist;
          x = lastX + (x - lastX) * ratio;
          y = lastY + (y - lastY) * ratio;
        }
      }
    }
    _lastPositionTime = now;

    _xHistory.add(x);
    _yHistory.add(y);

    if (_xHistory.length > _filterWindowSize) {
      _xHistory.removeAt(0);
      _yHistory.removeAt(0);
    }

    // Average ( ， ).
    double sumX = 0, sumY = 0, sumWeight = 0;
    for (int i = 0; i < _xHistory.length; i++) {
      final weight = (i + 1.0) * (i + 1.0); // ，.
      sumX += _xHistory[i] * weight;
      sumY += _yHistory[i] * weight;
      sumWeight += weight;
    }

    return (sumX / sumWeight, sumY / sumWeight);
  }

  // Translated legacy comment.
  (double, double)? _trilaterationWithDistances(List<double> distances) {
    if (_anchors.length < 3 || distances.length < 3) return null;

    // Distance.
    final filteredDistances = <double>[];
    for (int i = 0; i < distances.length; i++) {
      if (distances[i] > 0) {
        filteredDistances.add(_medianFilter(i, distances[i]));
      } else {
        filteredDistances.add(distances[i]);
      }
    }

    // Anchor distance.
    final List<UwbAnchor> validAnchors = [];
    final List<double> validDistances = [];

    // Tagheight ( tag ， 0-1.5m).
    const double tagHeight = 1.0; // Tagheight 1m.

    for (int i = 0; i < min(_anchors.length, filteredDistances.length); i++) {
      if (filteredDistances[i] > 0 && _anchors[i].isActive) {
        validAnchors.add(_anchors[i]);
        // 3D distance 2D distance.
        final d3d = filteredDistances[i];
        final dz = (_anchors[i].z - tagHeight).abs(); // Height.
        // 3D distance height ， distance.
        double d2d;
        if (d3d > dz) {
          d2d = sqrt(d3d * d3d - dz * dz);
        } else {
          // Distance ， ，.
          d2d = d3d * 0.5;
        }
        validDistances.add(d2d);
      }
    }

    if (validAnchors.length < 3) return null;

    // ===== (WLS) =====.
    // Anchor list.
    final double x1 = validAnchors[0].x;
    final double y1 = validAnchors[0].y;
    final double r1 = validDistances[0];

    // Ax = b.
    // Anchor (i, 1)，.
    // 2(xi - x1)x + 2(yi - y1)y = ri² - r1² - xi² + x1² - yi² + y1²

    double sumAA = 0, sumAB = 0, sumBB = 0;
    double sumAC = 0, sumBC = 0;
    double sumWeight = 0; // ignore: unused_local_variable

    for (int i = 1; i < validAnchors.length; i++) {
      final double xi = validAnchors[i].x;
      final double yi = validAnchors[i].y;
      final double ri = validDistances[i];

      final double A = 2 * (xi - x1);
      final double B = 2 * (yi - y1);
      final double C =
          r1 * r1 - ri * ri - x1 * x1 + xi * xi - y1 * y1 + yi * yi;

      // ：distance anchor.
      final double w = 1.0 / (ri + 0.1);

      sumAA += w * A * A;
      sumAB += w * A * B;
      sumBB += w * B * B;
      sumAC += w * A * C;
      sumBC += w * B * C;
      sumWeight += w;
    }

    // 2x2.
    final double det = sumAA * sumBB - sumAB * sumAB;
    if (det.abs() < 1e-10) {
      return _fallbackTrilateration(validAnchors, validDistances);
    }

    double x = (sumBB * sumAC - sumAB * sumBC) / det;
    double y = (sumAA * sumBC - sumAB * sumAC) / det;

    // (Gauss-Newton ).
    for (int iter = 0; iter < 5; iter++) {
      double sumDx = 0, sumDy = 0;
      double totalW = 0;

      for (int i = 0; i < validAnchors.length; i++) {
        final ax = validAnchors[i].x;
        final ay = validAnchors[i].y;
        final r = validDistances[i];

        final dx = x - ax;
        final dy = y - ay;
        final currentDist = sqrt(dx * dx + dy * dy);

        if (currentDist < 0.001) continue;

        final residual = r - currentDist;
        final w = 1.0 / (r + 0.1);

        sumDx += residual * (dx / currentDist) * w;
        sumDy += residual * (dy / currentDist) * w;
        totalW += w;
      }

      if (totalW > 0) {
        x += (sumDx / totalW) * 0.3; // Translated note.
        y += (sumDy / totalW) * 0.3;
      }
    }

    // Anchor list.
    final minX = validAnchors.map((a) => a.x).reduce(min);
    final maxX = validAnchors.map((a) => a.x).reduce(max);
    final minY = validAnchors.map((a) => a.y).reduce(min);
    final maxY = validAnchors.map((a) => a.y).reduce(max);
    final rangeMargin = max((maxX - minX), (maxY - minY)) * 0.3 + 1.0;
    x = x.clamp(minX - rangeMargin, maxX + rangeMargin);
    y = y.clamp(minY - rangeMargin, maxY + rangeMargin);

    // Result： anchor ( ).
    final checkMinX = minX - rangeMargin;
    final checkMaxX = maxX + rangeMargin;
    final checkMinY = minY - rangeMargin;
    final checkMaxY = maxY + rangeMargin;

    if (x < checkMinX || x > checkMaxX || y < checkMinY || y > checkMaxY) {
      // Result ，.
      return _fallbackTrilateration(validAnchors, validDistances);
    }

    // Translated legacy note.
    return _smoothPosition(x, y);
  }

  // Translated legacy comment.
  (double, double)? _fallbackTrilateration(
      List<UwbAnchor> anchors, List<double> distances) {
    if (anchors.length < 3) return null;

    final double x1 = anchors[0].x, y1 = anchors[0].y;
    final double r1 = distances[0];

    double sumX = 0, sumY = 0;
    double totalWeight = 0;

    for (int i = 1; i < anchors.length; i++) {
      for (int j = i + 1; j < anchors.length; j++) {
        final double x2 = anchors[i].x, y2 = anchors[i].y;
        final double x3 = anchors[j].x, y3 = anchors[j].y;
        final double r2 = distances[i];
        final double r3 = distances[j];

        final double A = 2 * (x2 - x1);
        final double B = 2 * (y2 - y1);
        final double C =
            r1 * r1 - r2 * r2 - x1 * x1 + x2 * x2 - y1 * y1 + y2 * y2;
        final double D = 2 * (x3 - x1);
        final double E = 2 * (y3 - y1);
        final double F =
            r1 * r1 - r3 * r3 - x1 * x1 + x3 * x3 - y1 * y1 + y3 * y3;

        final double det = A * E - B * D;
        if (det.abs() > 0.001) {
          final double x = (C * E - B * F) / det;
          final double y = (A * F - C * D) / det;

          // ： anchor.
          final fbMinX = anchors.map((a) => a.x).reduce(min) - 5;
          final fbMaxX = anchors.map((a) => a.x).reduce(max) + 5;
          final fbMinY = anchors.map((a) => a.y).reduce(min) - 5;
          final fbMaxY = anchors.map((a) => a.y).reduce(max) + 5;

          if (x.isFinite &&
              y.isFinite &&
              x >= fbMinX &&
              x <= fbMaxX &&
              y >= fbMinY &&
              y <= fbMaxY) {
            final weight = 1.0 / (r1 + r2 + r3);
            sumX += x * weight;
            sumY += y * weight;
            totalWeight += weight;
          }
        }
      }
    }

    if (totalWeight > 0) {
      return _smoothPosition(sumX / totalWeight, sumY / totalWeight);
    }
    return null;
  }

  // Distance tag.
  UwbTag _createTagWithMeasuredDistances(
      double x, double y, double z, String tagId, List<double> distances) {
    final Map<String, double> anchorDistances = {};
    for (int i = 0; i < min(_anchors.length, distances.length); i++) {
      if (distances[i] > 0) {
        anchorDistances[_anchors[i].id] = distances[i];
      }
    }

    return UwbTag(
      id: 'Tag$tagId',
      x: double.parse(x.toStringAsFixed(3)),
      y: double.parse(y.toStringAsFixed(3)),
      z: double.parse(z.toStringAsFixed(3)),
      r95: 0.1,
      anchorDistances: anchorDistances,
    );
  }

  // Pos : "pos:0,x:4533,y:1868,z:0" "POS,0,4.533,1.868,0.000".
  UwbTag? _parsePosFormat(String data) {
    try {
      // 1: pos:0,x:4533,y:1868,z:0.
      if (data.contains('x:')) {
        final xMatch = RegExp(r'x:(\d+)').firstMatch(data.toLowerCase());
        final yMatch = RegExp(r'y:(\d+)').firstMatch(data.toLowerCase());
        final zMatch = RegExp(r'z:(\d+)').firstMatch(data.toLowerCase());

        if (xMatch != null && yMatch != null) {
          // Translated legacy comment.
          final x = double.parse(xMatch.group(1)!) / 1000.0;
          final y = double.parse(yMatch.group(1)!) / 1000.0;
          final z =
              zMatch != null ? double.parse(zMatch.group(1)!) / 1000.0 : 0.0;

          return _createTagWithDistances(x, y, z);
        }
      }

      // 2: POS,0,4.533,1.868,0.000.
      final parts = data.split(',');
      if (parts.length >= 4) {
        final x = double.tryParse(parts[2]);
        final y = double.tryParse(parts[3]);
        final z = parts.length > 4 ? double.tryParse(parts[4]) : 0.0;

        if (x != null && y != null) {
          return _createTagWithDistances(x, y, z ?? 0.0);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Dis : "dis:0,d0:5070,d1:3104,d2:4118,d3:2964".
  UwbTag? _parseDisFormat(String data) {
    try {
      final Map<String, double> distances = {};

      for (int i = 0; i < 8; i++) {
        final match = RegExp('d$i:(\\d+)').firstMatch(data.toLowerCase());
        if (match != null && i < _anchors.length) {
          // Translated legacy comment.
          distances[_anchors[i].id] = double.parse(match.group(1)!) / 1000.0;
        }
      }

      if (distances.isNotEmpty) {
        // Translated legacy note.
        final pos = _trilaterate(distances);
        if (pos != null) {
          return UwbTag(
            id: 'Tag0',
            x: pos['x']!,
            y: pos['y']!,
            z: pos['z'] ?? 0.0,
            anchorDistances: distances,
          );
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // X: y.
  UwbTag? _parseXYFormat(String data) {
    try {
      final xMatch =
          RegExp(r'x[:\s]*([\d.-]+)', caseSensitive: false).firstMatch(data);
      final yMatch =
          RegExp(r'y[:\s]*([\d.-]+)', caseSensitive: false).firstMatch(data);
      final zMatch =
          RegExp(r'z[:\s]*([\d.-]+)', caseSensitive: false).firstMatch(data);

      if (xMatch != null && yMatch != null) {
        final x = double.parse(xMatch.group(1)!);
        final y = double.parse(yMatch.group(1)!);
        final z = zMatch != null ? double.parse(zMatch.group(1)!) : 0.0;

        return _createTagWithDistances(x, y, z);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Translated legacy note.
  UwbTag? _parseSpaceSeparatedFormat(String data) {
    try {
      final numbers =
          data.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList();

      if (numbers.length >= 2) {
        final x = double.tryParse(numbers[0]);
        final y = double.tryParse(numbers[1]);
        final z = numbers.length > 2 ? double.tryParse(numbers[2]) : 0.0;

        if (x != null && y != null) {
          return _createTagWithDistances(x, y, z ?? 0.0);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Tag anchor distance.
  UwbTag _createTagWithDistances(double x, double y, double z) {
    final Map<String, double> distances = {};
    for (var anchor in _anchors) {
      final double dx = x - anchor.x;
      final double dy = y - anchor.y;
      final double dz = z - anchor.z;
      final double distance = sqrt(dx * dx + dy * dy + dz * dz);
      distances[anchor.id] = double.parse(distance.toStringAsFixed(3));
    }

    return UwbTag(
      id: 'Tag0',
      x: x,
      y: y,
      z: z,
      anchorDistances: distances,
    );
  }

  // Translated legacy note.
  Map<String, double>? _trilaterate(Map<String, double> distances) {
    if (_anchors.length < 3 || distances.length < 3) return null;

    try {
      // Anchor distance.
      final a0 = _anchors[0];
      final a1 = _anchors[1];
      final a2 = _anchors[2];

      final d0 = distances[a0.id];
      final d1 = distances[a1.id];
      final d2 = distances[a2.id];

      if (d0 == null || d1 == null || d2 == null) return null;

      // 2D.
      final A = 2 * (a1.x - a0.x);
      final B = 2 * (a1.y - a0.y);
      final C = d0 * d0 -
          d1 * d1 -
          a0.x * a0.x +
          a1.x * a1.x -
          a0.y * a0.y +
          a1.y * a1.y;
      final D = 2 * (a2.x - a1.x);
      final E = 2 * (a2.y - a1.y);
      final F = d1 * d1 -
          d2 * d2 -
          a1.x * a1.x +
          a2.x * a2.x -
          a1.y * a1.y +
          a2.y * a2.y;

      final denom = A * E - B * D;
      if (denom.abs() < 0.0001) return null;

      final x = (C * E - B * F) / denom;
      final y = (A * F - C * D) / denom;

      return {'x': x, 'y': y, 'z': 0.0};
    } catch (e) {
      return null;
    }
  }

  // JSON.
  UwbTag? _parseJsonFormat(String data) {
    try {
      // ， dart:convert.
      final x = _extractJsonNumber(data, 'x');
      final y = _extractJsonNumber(data, 'y');
      final z = _extractJsonNumber(data, 'z');

      if (x == null || y == null) return null;

      final Map<String, double> distances = {};
      for (int i = 0; i < 8; i++) {
        final d = _extractJsonNumber(data, 'd$i');
        if (d != null && i < _anchors.length) {
          distances[_anchors[i].id] = d;
        }
      }

      return UwbTag(
        id: 'Tag0',
        x: x,
        y: y,
        z: z ?? 0.0,
        anchorDistances: distances,
      );
    } catch (e) {
      return null;
    }
  }

  double? _extractJsonNumber(String json, String key) {
    final regex = RegExp('"$key"\\s*:\\s*([\\d.-]+)');
    final match = regex.firstMatch(json);
    if (match != null) {
      return double.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  // TAG : "TAG:0 X:4.533 Y:1.868 Z:0.000 Q:95".
  UwbTag? _parseTagFormat(String data) {
    try {
      final xMatch = RegExp(r'X:([\d.-]+)').firstMatch(data);
      final yMatch = RegExp(r'Y:([\d.-]+)').firstMatch(data);
      final zMatch = RegExp(r'Z:([\d.-]+)').firstMatch(data);

      if (xMatch == null || yMatch == null) return null;

      final x = double.parse(xMatch.group(1)!);
      final y = double.parse(yMatch.group(1)!);
      final z = zMatch != null ? double.parse(zMatch.group(1)!) : 0.0;

      // Anchor distance.
      final Map<String, double> distances = {};
      for (var anchor in _anchors) {
        final double dx = x - anchor.x;
        final double dy = y - anchor.y;
        final double dz = z - anchor.z;
        final double distance = sqrt(dx * dx + dy * dy + dz * dz);
        distances[anchor.id] = double.parse(distance.toStringAsFixed(3));
      }

      return UwbTag(
        id: 'Tag0',
        x: x,
        y: y,
        z: z,
        anchorDistances: distances,
      );
    } catch (e) {
      return null;
    }
  }

  // Mc.
  UwbTag? _parseMcFormat(String data) {
    try {
      final parts = data.split(' ');
      if (parts.length < 10 || parts[0] != 'mc') return null;

      // Distancedata ( , ).
      final List<double> distances = [];
      for (int i = 2; i < 6 && i < parts.length; i++) {
        final int mm = int.parse(parts[i], radix: 16);
        distances.add(mm / 1000.0);
      }

      // Coordinate ( ).
      final int xMm = int.parse(parts[6], radix: 16);
      final int yMm = int.parse(parts[7], radix: 16);
      final int zMm = int.parse(parts[8], radix: 16);

      final Map<String, double> anchorDistances = {};
      for (int i = 0; i < distances.length && i < _anchors.length; i++) {
        anchorDistances[_anchors[i].id] = distances[i];
      }

      return UwbTag(
        id: 'Tag0',
        x: xMm / 1000.0,
        y: yMm / 1000.0,
        z: zMm / 1000.0,
        anchorDistances: anchorDistances,
      );
    } catch (e) {
      return null;
    }
  }

  // "4.533,1.868,0.000" distance "4.533,1.868,0.000,5.07,3.104,4.118,2.964".
  UwbTag? _parseSimpleFormat(String data) {
    try {
      final parts =
          data.split(',').map((s) => double.tryParse(s.trim())).toList();

      if (parts.length < 2 || parts[0] == null || parts[1] == null) return null;

      final x = parts[0]!;
      final y = parts[1]!;
      final z = parts.length > 2 ? (parts[2] ?? 0.0) : 0.0;

      final Map<String, double> distances = {};
      for (int i = 3; i < parts.length && (i - 3) < _anchors.length; i++) {
        if (parts[i] != null) {
          distances[_anchors[i - 3].id] = parts[i]!;
        }
      }

      // Distancedata， distance.
      if (distances.isEmpty) {
        for (var anchor in _anchors) {
          final double dx = x - anchor.x;
          final double dy = y - anchor.y;
          final double dz = z - anchor.z;
          final double distance = sqrt(dx * dx + dy * dy + dz * dz);
          distances[anchor.id] = double.parse(distance.toStringAsFixed(3));
        }
      }

      return UwbTag(
        id: 'Tag0',
        x: x,
        y: y,
        z: z,
        anchorDistances: distances,
      );
    } catch (e) {
      return null;
    }
  }

  // ( TOA).
  Map<String, double>? calculatePosition(Map<String, double> distances) {
    if (_anchors.length < 3 || distances.length < 3) return null;

    try {
      // Translated legacy note.
      // 3 anchor.
      final a0 = _anchors[0];
      final a1 = _anchors[1];
      final a2 = _anchors[2];

      final double d0 = distances[a0.id] ?? 0;
      final double d1 = distances[a1.id] ?? 0;
      final double d2 = distances[a2.id] ?? 0;

      // (2D ).
      final double A = 2 * (a1.x - a0.x);
      final double B = 2 * (a1.y - a0.y);
      final double C = d0 * d0 -
          d1 * d1 -
          a0.x * a0.x +
          a1.x * a1.x -
          a0.y * a0.y +
          a1.y * a1.y;

      final double D = 2 * (a2.x - a1.x);
      final double E = 2 * (a2.y - a1.y);
      final double F = d1 * d1 -
          d2 * d2 -
          a1.x * a1.x +
          a2.x * a2.x -
          a1.y * a1.y +
          a2.y * a2.y;

      final double denom = A * E - B * D;
      if (denom.abs() < 0.0001) return null;

      final double x = (C * E - F * B) / denom;
      final double y = (A * F - D * C) / denom;

      return {'x': x, 'y': y, 'z': 0.0};
    } catch (e) {
      debugPrint('Positioning calculation failed: $e');
      return null;
    }
  }

  // Translated legacy note.
  double getAreaWidth() {
    if (_anchors.isEmpty) return 10.0;
    final double maxX = _anchors.map((a) => a.x).reduce(max);
    return maxX + 1.0;
  }

  double getAreaHeight() {
    if (_anchors.isEmpty) return 10.0;
    final double maxY = _anchors.map((a) => a.y).reduce(max);
    return maxY + 1.0;
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _serialSubscription?.cancel();
    _floorPlanImage?.dispose();
    super.dispose();
  }
}
