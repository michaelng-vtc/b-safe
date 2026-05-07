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
  final List<List<double>>? mask; // optional instance segmentation mask (crop)

  const YoloDetection({
    required this.className,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.mask,
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
        // mask omitted for JSON export by default (heavy), keep flag
        'has_mask': mask != null,
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

      // Read output tensors. For seg models there may be a second proto-mask
      // tensor. We read both when available.
      final out0Bytes =
          Uint8List.fromList(_interpreter!.getOutputTensor(0).data);
      final outputBuffer = out0Bytes.buffer.asFloat32List();

      List<double>? protoBuffer;
      List<int>? protoShape;
      if (_interpreter!.getOutputTensors().length > 1) {
        final out1 = _interpreter!.getOutputTensor(1);
        final out1Bytes = Uint8List.fromList(out1.data);
        protoBuffer = out1Bytes.buffer.asFloat32List().toList();
        protoShape = out1.shape;
      }

      return _parseDetections(
        outputBuffer,
        protos: protoBuffer,
        protoShape: protoShape,
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
    List<double>? protos,
    List<int>? protoShape,
    required double confidenceThreshold,
    required double iouThreshold,
    required int maxDetections,
  }) {
    // Helper: get value[v] for box[b], handles both memory layouts.
    double val(int b, int v) => _isTransposedOutput
        ? rawOutput[v * _numBoxes + b]
        : rawOutput[b * _numValues + v];

    final hasObjectness = !_isTransposedOutput && _numValues >= 85;
    final classStart = hasObjectness ? 5 : 4;
    final classEnd = classStart + _numClasses; // excludes mask coeffs

    // Build parallel lists: normalized detections for NMS and meta info for mask
    final normCandidates = <YoloDetection>[];
    final meta = <Map<String, dynamic>>[]; // holds raw coords + maskCoeffs

    for (int b = 0; b < _numBoxes; b++) {
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

      final score =
          (hasObjectness ? val(b, 4) * bestScore : bestScore).clamp(0.0, 1.0);
      if (score < confidenceThreshold) continue;

      final cx = val(b, 0);
      final cy = val(b, 1);
      final bw = val(b, 2);
      final bh = val(b, 3);
      if (bw <= 0 || bh <= 0) continue;

      // Extract mask coefficients if present
      List<double>? maskCoeffs;
      if (_numMaskCoeffs > 0) {
        maskCoeffs = List<double>.generate(_numMaskCoeffs, (i) {
          final v = val(b, classEnd + i);
          // Keep raw value; later clamp when computing mask
          return v.toDouble();
        });
      }

      normCandidates.add(YoloDetection(
        className: bestClass < _labels.length
            ? _labels[bestClass]
            : 'Class_$bestClass',
        confidence: score,
        x: cx,
        y: cy,
        width: bw,
        height: bh,
        mask: null,
      ));

      meta.add({
        'cx': cx,
        'cy': cy,
        'w': bw,
        'h': bh,
        'classId': bestClass,
        'score': score,
        'maskCoeffs': maskCoeffs,
      });
    }

    final kept = _nms(normCandidates,
        iouThreshold: iouThreshold, maxDetections: maxDetections);

    // If prototype tensor exists and we have mask coeffs, compute instance masks
    if (protos != null && protoShape != null && _numMaskCoeffs > 0) {
      // Decide whether coordinates are normalised (<=1.5 heuristic)
      double maxCoord = 0.0;
      for (final m in meta) {
        maxCoord = math.max(maxCoord, (m['cx'] as double));
        maxCoord = math.max(maxCoord, (m['cy'] as double));
        maxCoord = math.max(maxCoord, (m['w'] as double));
        maxCoord = math.max(maxCoord, (m['h'] as double));
      }
      final bool coordsAreNorm = maxCoord <= 1.5;

      // Prepare pixel-space meta (cx,cy,w,h) in pixels for mask computation
      final metaPx = meta.map((m) {
        final cx = (m['cx'] as double) * (coordsAreNorm ? _inputWidth : 1.0);
        final cy = (m['cy'] as double) * (coordsAreNorm ? _inputHeight : 1.0);
        final w = (m['w'] as double) * (coordsAreNorm ? _inputWidth : 1.0);
        final h = (m['h'] as double) * (coordsAreNorm ? _inputHeight : 1.0);
        return {
          'cx': cx,
          'cy': cy,
          'w': w,
          'h': h,
          'classId': m['classId'],
          'score': m['score'],
          'maskCoeffs': m['maskCoeffs'],
        };
      }).toList();

      // For each kept detection, find best matching meta entry (by IoU) and
      // compute its instance mask using prototype tensor.
      for (int i = 0; i < kept.length; i++) {
        final det = kept[i];
        // find best meta match
        double bestIoU = -1.0;
        int bestIndex = -1;
        for (int j = 0; j < meta.length; j++) {
          final m = meta[j];
          final iou = _iou(
              det,
              YoloDetection(
                className: '',
                confidence: 0,
                x: m['cx'] as double,
                y: m['cy'] as double,
                width: m['w'] as double,
                height: m['h'] as double,
                mask: null,
              ));
          if (iou > bestIoU) {
            bestIoU = iou;
            bestIndex = j;
          }
        }

        if (bestIndex >= 0) {
          final mpx = metaPx[bestIndex];
          final maskCoeffs = mpx['maskCoeffs'] as List<double>?;
          if (maskCoeffs != null) {
            try {
              final mask = _computeInstanceMaskFromProto(
                cx: mpx['cx'] as double,
                cy: mpx['cy'] as double,
                w: mpx['w'] as double,
                h: mpx['h'] as double,
                maskCoeffs: maskCoeffs,
                protos: protos,
                protoShape: protoShape,
              );
              // attach mask to detection by replacing entry in kept
              kept[i] = YoloDetection(
                className: det.className,
                confidence: det.confidence,
                x: det.x,
                y: det.y,
                width: det.width,
                height: det.height,
                mask: mask,
              );
            } catch (e) {
              debugPrint('Mask compute error: $e');
            }
          }
        }
      }
    }

    return kept;
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

  // ──────────────────── Instance Mask Decoding (from proto tensor) ───────

  List<List<double>>? _computeInstanceMaskFromProto({
    required double cx,
    required double cy,
    required double w,
    required double h,
    required List<double> maskCoeffs,
    required List<double> protos,
    required List<int> protoShape,
  }) {
    // Determine proto layout and mask spatial dims
    final int maskH, maskW;
    final bool channelFirst;
    final bool flatSpatial;

    if (protoShape.length == 4) {
      channelFirst = protoShape[1] == _numMaskCoeffs;
      maskH = channelFirst ? protoShape[2] : protoShape[1];
      maskW = channelFirst ? protoShape[3] : protoShape[2];
      flatSpatial = false;
    } else if (protoShape.length == 3 && protoShape[1] == _numMaskCoeffs) {
      final spatial = protoShape[2];
      final side = math.sqrt(spatial).round();
      if (side * side != spatial) return null;
      maskH = side;
      maskW = side;
      channelFirst = true;
      flatSpatial = true;
    } else {
      return null;
    }

    final double scaleX = maskW / _inputWidth;
    final double scaleY = maskH / _inputHeight;

    final int mx1 = ((cx - w / 2) * scaleX).clamp(0, maskW - 1).floor();
    final int my1 = ((cy - h / 2) * scaleY).clamp(0, maskH - 1).floor();
    final int mx2 = ((cx + w / 2) * scaleX).clamp(0, maskW - 1).ceil();
    final int my2 = ((cy + h / 2) * scaleY).clamp(0, maskH - 1).ceil();

    if (mx2 <= mx1 || my2 <= my1) return null;

    // Helper to read proto value at channel i, y, x from flat protos list.
    double protoAt(int ci, int py, int px) {
      if (flatSpatial) {
        // layout [1, 32, H*W]
        final base = ci * (maskH * maskW);
        return protos[base + py * maskW + px];
      }
      if (channelFirst) {
        // layout [1, C, H, W]
        final base = ci * (maskH * maskW);
        return protos[base + py * maskW + px];
      } else {
        // layout [1, H, W, C]
        final base = (py * maskW + px) * _numMaskCoeffs;
        return protos[base + ci];
      }
    }

    final mask = List.generate(my2 - my1, (dy) {
      final py = my1 + dy;
      return List.generate(mx2 - mx1, (dx) {
        final px = mx1 + dx;
        double sum = 0.0;
        for (int i = 0; i < _numMaskCoeffs; i++) {
          final protoVal = protoAt(i, py, px);
          sum += maskCoeffs[i] * protoVal;
        }
        return _sigmoid(sum).clamp(0.0, 1.0);
      });
    });

    return mask;
  }

  static double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

  /// Render a simple overlay image for VLM input using the current YOLO detections.
  Uint8List? renderOverlayImage(
    Uint8List imageBytes,
    List<YoloDetection> detections,
  ) {
    final source = img.decodeImage(imageBytes);
    if (source == null) return null;

    final canvas = img.Image.from(source);
    const maskColor = (0xFF, 0xD6, 0x28, 0x28);
    const boxColor = (0xFF, 0xD6, 0x28, 0x28);

    for (final det in detections) {
      final box =
          det.toPixelBox(canvas.width.toDouble(), canvas.height.toDouble());
      final left = box['left']!.clamp(0.0, canvas.width - 1).round();
      final top = box['top']!.clamp(0.0, canvas.height - 1).round();
      final right = box['right']!.clamp(0.0, canvas.width - 1).round();
      final bottom = box['bottom']!.clamp(0.0, canvas.height - 1).round();

      if (det.mask != null && det.mask!.isNotEmpty) {
        final maskH = det.mask!.length;
        final maskW = det.mask!.first.length;
        for (int my = 0; my < maskH; my++) {
          final y = top + ((bottom - top) * (my / maskH)).round();
          if (y < 0 || y >= canvas.height) continue;
          for (int mx = 0; mx < maskW; mx++) {
            final x = left + ((right - left) * (mx / maskW)).round();
            if (x < 0 || x >= canvas.width) continue;
            final alpha = (det.mask![my][mx] * 180).clamp(0, 180).round();
            if (alpha <= 0) continue;
            final pixel = canvas.getPixel(x, y);
            final blended = img.ColorRgba8(
              ((pixel.r * (255 - alpha)) + (maskColor.$2 * alpha)) ~/ 255,
              ((pixel.g * (255 - alpha)) + (maskColor.$3 * alpha)) ~/ 255,
              ((pixel.b * (255 - alpha)) + (maskColor.$4 * alpha)) ~/ 255,
              255,
            );
            canvas.setPixel(x, y, blended);
          }
        }
      }

      final paint = img.ColorRgba8(boxColor.$2, boxColor.$3, boxColor.$4, 255);
      for (int x = left; x <= right; x++) {
        if (top >= 0 && top < canvas.height) canvas.setPixel(x, top, paint);
        if (bottom >= 0 && bottom < canvas.height) {
          canvas.setPixel(x, bottom, paint);
        }
      }
      for (int y = top; y <= bottom; y++) {
        if (left >= 0 && left < canvas.width) canvas.setPixel(left, y, paint);
        if (right >= 0 && right < canvas.width) {
          canvas.setPixel(right, y, paint);
        }
      }
    }

    return Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
  }

  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
    _instance = null;
  }
}
