import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// YOLO detection result.
class YoloDetection {
  final String className;
  final double confidence;
  final double x; // center x (normalized 0-1 of image width)
  final double y; // center y (normalized 0-1 of image height)
  final double width; // box width (normalized)
  final double height; // box height (normalized)

  const YoloDetection({
    required this.className,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Bounding box image coordinates (pixel values).
  Map<String, double> toPixelBox(double imgWidth, double imgHeight) {
    return {
      'left': (x - width / 2) * imgWidth,
      'top': (y - height / 2) * imgHeight,
      'right': (x + width / 2) * imgWidth,
      'bottom': (y + height / 2) * imgHeight,
      'width': width * imgWidth,
      'height': height * imgHeight,
    };
  }

  Map<String, dynamic> toJson() => {
        'class': className,
        'confidence': confidence,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
}

/// YOLO service backed by tflite_flutter (bounding-box mode).
///
/// Supports YOLOv5/v8 float32 TFLite models whose output tensor has shape
/// [1, numBoxes, 5 + numClasses].  Each row is:
///   [x_center, y_center, width, height, objectness, cls0, cls1, ...]
/// all normalised to 0-1.
///
/// Linux setup: place libtensorflowlite_c-linux.so in blobs/ at the
/// project root (see scripts/download_tflite_linux.sh).
class YoloService {
  static YoloService? _instance;
  static const String _modelAsset = 'assets/models/yolo.tflite';

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoaded = false;
  bool _isLoading = false;
  bool _isTransposedOutput =
      false; // true when shape is [1, numValues, numBoxes]

  int _inputWidth = 640;
  int _inputHeight = 640;
  int _numBoxes = 0;
  int _numValues = 0; // total values per anchor (bbox + classes + mask coeffs)
  int _numClasses = 0; // detection classes only (excludes mask coefficients)
  int _numMaskCoeffs = 0; // 32 for seg models, 0 for detection-only

  YoloService._();

  static YoloService get instance {
    _instance ??= YoloService._();
    return _instance!;
  }

  static bool get isSupported => true;

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;

  /// Load the TFLite model from assets.
  /// Build the best [InterpreterOptions] available on the current device.
  ///
  /// Priority:
  ///   Android   → GpuDelegateV2 (OpenCL/OpenGL) → XNNPack (CPU SIMD)
  ///   iOS/macOS → MetalDelegate (GPU)            → XNNPack (CPU SIMD)
  ///   Linux/Win → XNNPack (CPU SIMD)
  ///   fallback  → bare CPU
  static Future<InterpreterOptions> _buildOptions() async {
    final options = InterpreterOptions();
    if (kIsWeb) return options;

    if (Platform.isAndroid) {
      // GPU delegate (OpenCL / OpenGL ES on Android)
      try {
        options.addDelegate(GpuDelegateV2());
        debugPrint('YOLO delegate: GPU (Android)');
        return options;
      } catch (_) {}
    } else if (Platform.isIOS || Platform.isMacOS) {
      // GpuDelegate = Metal GPU on iOS/macOS
      try {
        options.addDelegate(GpuDelegate());
        debugPrint('YOLO delegate: Metal/GPU (Apple)');
        return options;
      } catch (_) {}
    }

    // XNNPack — CPU SIMD, works on all platforms.
    // Previously disabled on Linux due to "XNNPack delegate failed to reshape
    // runtime" — that was caused by passing a flat Float32List to run(), which
    // triggered resizeInputTensor(0, [1228800]).  Fixed by using tensor.data
    // directly instead of run(), so XNNPack can be re-enabled everywhere.
    try {
      options.addDelegate(XNNPackDelegate());
      debugPrint('YOLO delegate: XNNPack (CPU SIMD)');
      return options;
    } catch (_) {}
    debugPrint('YOLO delegate: bare CPU');
    return options;
  }

  Future<bool> loadModel({String modelPath = 'best_float32'}) async {
    if (_isLoaded) return true;
    _isLoading = true;
    try {
      final options = await _buildOptions();

      // Attempt to load with the chosen delegate; fall back to bare CPU if
      // the delegate fails at model-load time (e.g. GPU driver mismatch).
      try {
        _interpreter = await Interpreter.fromAsset(
          _modelAsset,
          options: options,
        );
      } catch (delegateErr) {
        debugPrint(
            'YOLO delegate load failed ($delegateErr), retrying with bare CPU');
        _interpreter = await Interpreter.fromAsset(_modelAsset);
      }

      // Read actual input dimensions from the model.
      final inputShape = _interpreter!.getInputTensor(0).shape;
      // Expected: [1, height, width, 3]
      _inputHeight = inputShape[1];
      _inputWidth = inputShape[2];

      // Read output dimensions.
      // Shape is [1, A, B].
      // YOLO11/v8 transposed export: [1, numValues, numBoxes] → A < B
      // YOLOv5/v8 standard export:  [1, numBoxes, numValues] → A > B
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      if (outputShape[1] < outputShape[2]) {
        _isTransposedOutput = true;
        _numValues = outputShape[1]; // e.g. 38
        _numBoxes = outputShape[2]; // e.g. 8400
      } else {
        _isTransposedOutput = false;
        _numBoxes = outputShape[1];
        _numValues = outputShape[2];
      }

      // Detect seg model: second output tensor is prototype masks.
      // Ultralytics always uses 32 prototypes. TFLite may export it as
      // NCHW [1, 32, H, W] OR NHWC [1, H, W, 32] depending on the export.
      // Do NOT blindly use shape[1] — find 32 explicitly in the shape.
      _numMaskCoeffs = 0;
      final allOutputs = _interpreter!.getOutputTensors();
      if (allOutputs.length >= 2) {
        final maskShape = allOutputs[1].shape;
        if (maskShape.length == 4 && maskShape.contains(32)) {
          _numMaskCoeffs = 32;
        }
      }

      // Fallback: single-output TFLite seg exports embed 32 mask coefficients
      // after the class scores. Heuristic: numValues - 4 > nc + small_margin.
      // Since nc is unknown here, assume 32 mask coeffs when numValues - 4 > 32.
      if (_numMaskCoeffs == 0 && _numValues - 4 > 32) {
        _numMaskCoeffs = 32;
        debugPrint('YOLO: assuming 32 seg mask coefficients (single output)');
      }

      _numClasses = _numValues - 4 - _numMaskCoeffs;
      if (_numClasses <= 0) {
        _numClasses = _numValues - 4; // last-resort fallback
      }

      debugPrint('YOLO model loaded | input: $inputShape | output: $outputShape'
          ' | classes: $_numClasses | maskCoeffs: $_numMaskCoeffs');

      await _loadLabels();

      // After labels load, reconcile _numClasses with labels count.
      // If the shape-based calculation was wrong (e.g. mask coeff detection
      // failed), trust the labels file as the authoritative class count.
      if (_labels.length != _numClasses) {
        debugPrint('YOLO: _numClasses=$_numClasses but labels=${_labels.length}'
            ' – correcting to match labels.');
        _numClasses = _labels.length;
      }

      _isLoaded = true;
      return true;
    } catch (e) {
      debugPrint('Failed to load YOLO model: $e');
      _isLoaded = false;
      return false;
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _loadLabels() async {
    try {
      final raw = await rootBundle.loadString('assets/models/labels.txt');
      _labels = raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      debugPrint('YOLO labels loaded: ${_labels.length}');
    } catch (_) {
      // Use the class count computed in loadModel (excludes mask coefficients).
      final nc = _numClasses > 0 ? _numClasses : (_numValues - 4);
      _labels = nc > 0 ? List.generate(nc, (i) => 'Class_$i') : ['object'];
      debugPrint(
          'labels.txt not found – using ${_labels.length} generic labels.');
    }
  }

  /// Detect objects in [imageBytes] (any format supported by the image package).
  Future<List<YoloDetection>> detect(
    Uint8List imageBytes, {
    double confidenceThreshold = 0.5,
    double iouThreshold = 0.40,
    int maxDetections = 50,
  }) async {
    if (!_isLoaded) {
      final ok = await loadModel();
      if (!ok) return [];
    }
    try {
      final rawImage = img.decodeImage(imageBytes);
      if (rawImage == null) return [];

      final resized = img.copyResize(
        rawImage,
        width: _inputWidth,
        height: _inputHeight,
        interpolation: img.Interpolation.linear,
      );

      // Flat [H * W * 3] Float32 input buffer.
      // Using a flat typed buffer avoids the null check crash that occurs when
      // tflite_flutter's native bindings traverse deeply-nested Dart lists.
      final inputBuffer = Float32List(_inputHeight * _inputWidth * 3);
      int pIdx = 0;
      for (int y = 0; y < _inputHeight; y++) {
        for (int x = 0; x < _inputWidth; x++) {
          final pixel = resized.getPixel(x, y);
          final maxVal = pixel.maxChannelValue;
          inputBuffer[pIdx++] = pixel.r.toDouble() / maxVal;
          inputBuffer[pIdx++] = pixel.g.toDouble() / maxVal;
          inputBuffer[pIdx++] = pixel.b.toDouble() / maxVal;
        }
      }

      // Write input bytes directly into the tensor's native buffer.
      // DO NOT use interpreter.run(Float32List, ...) — tflite_flutter's
      // getInputShapeIfDifferent() sees Float32List as a 1D Dart List and calls
      // resizeInputTensor(0, [1228800]), which corrupts the input shape and
      // causes PAD/XNNPack to fail with "4 != 1" or "reshape runtime" errors.
      // Passing Uint8List would also bypass shape-inference, but using
      // tensor.data= + invoke() is the most direct and handles multi-output
      // seg models cleanly without crashing on the prototype-mask tensor.
      _interpreter!.getInputTensor(0).data = inputBuffer.buffer.asUint8List();
      _interpreter!.invoke();

      // Read first output tensor only (seg model has a second mask-protos
      // tensor that we ignore — bounding boxes come from output 0).
      // Uint8List.fromList copies the bytes into a regular Dart heap buffer so
      // asFloat32List() is guaranteed aligned.
      final rawBytes =
          Uint8List.fromList(_interpreter!.getOutputTensor(0).data);
      final outputBuffer = rawBytes.buffer.asFloat32List();

      return _parseDetections(
        outputBuffer,
        confidenceThreshold: confidenceThreshold,
        iouThreshold: iouThreshold,
        maxDetections: maxDetections,
      );
    } catch (e, st) {
      debugPrint('YOLO detect error: $e\n$st');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Post-processing helpers
  // ---------------------------------------------------------------------------

  List<YoloDetection> _parseDetections(
    Float32List rawOutput, {
    required double confidenceThreshold,
    required double iouThreshold,
    required int maxDetections,
  }) {
    final candidates = <YoloDetection>[];

    // Helper: get value[v] for box[b], handles both memory layouts.
    //   Transposed [numValues, numBoxes]: index = v * numBoxes + b
    //   Standard   [numBoxes, numValues]: index = b * numValues + v
    double val(int b, int v) => _isTransposedOutput
        ? rawOutput[v * _numBoxes + b]
        : rawOutput[b * _numValues + v];

    // YOLO11/v8 (no objectness): bbox at 0-3, classes at 4..4+nc-1
    // YOLOv5    (has objectness): bbox at 0-3, objectness at 4, classes at 5..5+nc-1
    // Seg model: mask coefficients at 4+nc..4+nc+31 — we ignore them here.
    // Heuristic: standard layout with _numValues>=85 is YOLOv5 (80 COCO classes+5).
    final hasObjectness = !_isTransposedOutput && _numValues >= 85;
    final classStart = hasObjectness ? 5 : 4;
    final classEnd = classStart + _numClasses; // excludes mask coefficients

    for (int b = 0; b < _numBoxes; b++) {
      // Pre-filter: for YOLOv5 use objectness; for YOLO11 scan class scores.
      if (hasObjectness && val(b, 4) < confidenceThreshold) continue;

      int bestClass = 0;
      double bestScore = 0.0;
      for (int c = classStart; c < classEnd; c++) {
        final s = val(b, c);
        if (s > bestScore) {
          bestScore = s;
          bestClass = c - classStart;
        }
      }

      // Clamp to [0,1]: mask-coefficient values or raw logits can exceed 1.0.
      final score =
          (hasObjectness ? val(b, 4) * bestScore : bestScore).clamp(0.0, 1.0);
      if (score < confidenceThreshold) continue;

      // Bbox is always in center format (cx, cy, w, h) normalized 0-1.
      final cx = val(b, 0);
      final cy = val(b, 1);
      final bw = val(b, 2);
      final bh = val(b, 3);
      if (bw <= 0 || bh <= 0) continue;

      candidates.add(YoloDetection(
        className: bestClass < _labels.length
            ? _labels[bestClass]
            : 'Class_$bestClass',
        confidence: score,
        x: cx,
        y: cy,
        width: bw,
        height: bh,
      ));
    }

    return _nms(candidates,
        iouThreshold: iouThreshold, maxDetections: maxDetections);
  }

  /// Greedy NMS – suppresses lower-confidence boxes overlapping above [iouThreshold].
  /// Returns at most [maxDetections] results.
  List<YoloDetection> _nms(
    List<YoloDetection> detections, {
    required double iouThreshold,
    int maxDetections = 50,
  }) {
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    final result = <YoloDetection>[];
    final suppressed = List<bool>.filled(detections.length, false);

    for (var i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;
      result.add(detections[i]);
      if (result.length >= maxDetections) break;
      for (var j = i + 1; j < detections.length; j++) {
        if (!suppressed[j] &&
            _iou(detections[i], detections[j]) > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }
    return result;
  }

  double _iou(YoloDetection a, YoloDetection b) {
    final aL = a.x - a.width / 2;
    final aT = a.y - a.height / 2;
    final aR = a.x + a.width / 2;
    final aB = a.y + a.height / 2;

    final bL = b.x - b.width / 2;
    final bT = b.y - b.height / 2;
    final bR = b.x + b.width / 2;
    final bB = b.y + b.height / 2;

    final iL = math.max(aL, bL);
    final iT = math.max(aT, bT);
    final iR = math.min(aR, bR);
    final iB = math.min(aB, bB);

    if (iR <= iL || iB <= iT) return 0.0;

    final inter = (iR - iL) * (iB - iT);
    final union = a.width * a.height + b.width * b.height - inter;
    return union <= 0 ? 0.0 : inter / union;
  }

  // ---------------------------------------------------------------------------
  // Risk analysis
  // ---------------------------------------------------------------------------

  /// Result risk analysis (class-agnostic – works for building defect labels).
  static Map<String, dynamic> toSafetyAnalysis(List<YoloDetection> detections) {
    if (detections.isEmpty) {
      return {
        'risk_level': 'low',
        'risk_score': 10,
        'analysis': 'No objects detected.',
        'recommendations': ['Regular inspection recommended.'],
        'detections': [],
        'detection_count': 0,
        'person_count': 0,
      };
    }

    final safetyHazards = <String>[];
    final structuralItems = <String>[];
    final normalItems = <String>[];

    const hazardClasses = {
      'fire hydrant',
      'stop sign',
      'traffic light',
      'scissors',
      'knife',
    };
    const structuralClasses = {
      'chair',
      'couch',
      'bed',
      'dining table',
      'toilet',
      'sink',
      'tv',
      'laptop',
      'microwave',
      'oven',
      'refrigerator',
      'door',
      'window',
    };
    const personClasses = {'person'};

    int personCount = 0;

    for (final det in detections) {
      final cls = det.className.toLowerCase();
      if (personClasses.contains(cls)) {
        personCount++;
      } else if (hazardClasses.contains(cls)) {
        safetyHazards.add(
            '${det.className} (${(det.confidence * 100).toStringAsFixed(0)}%)');
      } else if (structuralClasses.contains(cls)) {
        structuralItems.add(
            '${det.className} (${(det.confidence * 100).toStringAsFixed(0)}%)');
      } else {
        normalItems.add(
            '${det.className} (${(det.confidence * 100).toStringAsFixed(0)}%)');
      }
    }

    int riskScore = 10;
    String riskLevel = 'low';

    if (safetyHazards.isNotEmpty) {
      riskScore += safetyHazards.length * 20;
    }
    if (personCount > 3) {
      riskScore += 15;
    }
    riskScore = riskScore.clamp(0, 100);

    if (riskScore >= 70) {
      riskLevel = 'high';
    } else if (riskScore >= 40) {
      riskLevel = 'medium';
    }

    final analysisLines = <String>[];
    analysisLines.add('YOLO detected ${detections.length} object(s):');
    if (personCount > 0) {
      analysisLines.add('- People: $personCount person(s)');
    }
    if (safetyHazards.isNotEmpty) {
      analysisLines.add('- Safety-related: ${safetyHazards.join(', ')}');
    }
    if (structuralItems.isNotEmpty) {
      analysisLines
          .add('- Facilities/Furniture: ${structuralItems.join(', ')}');
    }
    if (normalItems.isNotEmpty) {
      analysisLines.add('- Other objects: ${normalItems.join(', ')}');
    }

    final recommendations = <String>[];
    if (safetyHazards.isNotEmpty) {
      recommendations.add(
          'Safety-related objects detected. Verify fire equipment status.');
    }
    if (personCount > 3) {
      recommendations
          .add('High occupancy. Ensure evacuation routes are clear.');
    }
    if (structuralItems.isNotEmpty) {
      recommendations.add('Check facility conditions.');
    }
    if (recommendations.isEmpty) {
      recommendations
          .add('Environment normal. Regular inspection recommended.');
    }

    return {
      'risk_level': riskLevel,
      'risk_score': riskScore,
      'analysis': analysisLines.join('\n'),
      'recommendations': recommendations,
      'detections': detections.map((d) => d.toJson()).toList(),
      'detection_count': detections.length,
      'person_count': personCount,
    };
  }

  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
    _instance = null;
  }
}
