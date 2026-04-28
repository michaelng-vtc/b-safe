import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

// ─────────────────────── Internal helper ──────────────────────────────────

class _RawDetection {
  final double cx, cy, w, h;
  final int classId;
  final double confidence;
  final List<double> maskCoeffs;

  const _RawDetection({
    required this.cx,
    required this.cy,
    required this.w,
    required this.h,
    required this.classId,
    required this.confidence,
    required this.maskCoeffs,
  });
}

// ──────────────────────── Public types ────────────────────────────────────

/// One detected instance from the YOLOv11x-seg model.
class YoloDetection {
  final String className;
  final double confidence;

  /// Bounding-box centre + size, all normalised to [0, 1].
  final double x;
  final double y;
  final double width;
  final double height;

  /// Instance segmentation mask (reserved; currently null).
  final List<List<double>>? mask;

  const YoloDetection({
    required this.className,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.mask,
  });

  /// Convert normalised centre-size box to pixel coordinates.
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

/// Bundles detection results from a single inference pass.
class YoloInferenceResult {
  final List<YoloDetection> detections;
  final Size imageSize;
  const YoloInferenceResult(
      {required this.detections, this.imageSize = Size.zero});
}

// ──────────────────────── YoloService ─────────────────────────────────────

/// Singleton YOLO service for the custom **YOLOv11x-seg** TFLite model.
///
/// Uses [tflite_flutter] for direct inference with software NMS.
/// Supports Android, iOS, Linux, macOS, and Windows.
class YoloService {
  static YoloService? _instance;

  Interpreter? _interpreter;

  /// Class label list, index-aligned with model output classes.
  List<String> _classLabels = ['crack', 'spalling'];

  bool _isLoaded = false;
  bool _isLoading = false;

  static const _kModelAsset = 'assets/model/yolo.tflite';
  static const _kInputSize = 640;
  static const _kNmMasks = 32; // mask coefficient count for seg models
  static const _kMaxDetections = 100;

  YoloService._();

  static YoloService get instance {
    _instance ??= YoloService._();
    return _instance!;
  }

  /// tflite_flutter supports all non-web platforms.
  static bool get isSupported => !kIsWeb;

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;

  /// Provide human-readable class names (index-aligned with the model).
  void setLabels(List<String> labels) => _classLabels = labels;

  String _labelFor(int classId) =>
      (classId >= 0 && classId < _classLabels.length)
          ? _classLabels[classId]
          : 'class_$classId';

  // ─────────────────────────── Model Loading ───────────────────────────────

  /// Load the YOLOv11x-seg TFLite model from assets.
  Future<bool> loadModel() async {
    if (!isSupported) return false;
    if (_isLoaded) return true;
    if (_isLoading) return false;

    _isLoading = true;
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        _kModelAsset,
        options: options,
      );
      _interpreter!.allocateTensors();
      _isLoaded = true;
      debugPrint('✅ YOLOv11x-seg: model loaded via tflite_flutter');
    } catch (e) {
      debugPrint('❌ YOLOv11x-seg: loadModel error: $e');
      _interpreter = null;
      _isLoaded = false;
    } finally {
      _isLoading = false;
    }
    return _isLoaded;
  }

  // ──────────────────────────── Inference ───────────────────────────────────

  /// Run inference + NMS on [imageBytes].
  ///
  /// Returns normalised (cx, cy, w, h) bounding boxes after NMS filtering.
  Future<YoloInferenceResult> detect(
    Uint8List imageBytes, {
    double confidenceThreshold = 0.25,
    double iouThreshold = 0.45,
  }) async {
    await _ensureLoaded();
    final interp = _interpreter;
    if (interp == null || !_isLoaded) {
      return const YoloInferenceResult(detections: []);
    }

    // Decode source image for original dimensions.
    final original = img.decodeImage(imageBytes);
    if (original == null) return const YoloInferenceResult(detections: []);
    final imgW = original.width.toDouble();
    final imgH = original.height.toDouble();

    try {
      // 1. Preprocess → 4D [1, 640, 640, 3] float input.
      final inputData = _preprocessImage(original);

      // 2. Allocate output buffers matching each output tensor's shape.
      final outputTensors = interp.getOutputTensors();
      final outputs = <int, Object>{
        for (int i = 0; i < outputTensors.length; i++)
          i: _allocateBuffer(outputTensors[i].shape),
      };

      // 3. Run inference.
      interp.runForMultipleInputs([inputData], outputs);

      // 4. Decode predictions tensor (output 0) + apply NMS.
      final predShape = outputTensors[0].shape;

      // Mask prototypes from output 1 (if available).
      final List? protos = outputTensors.length > 1 ? outputs[1] as List : null;
      final List<int>? protoShape =
          outputTensors.length > 1 ? outputTensors[1].shape : null;

      debugPrint('🔍 YOLOv11x-seg: ${outputTensors.length} output tensor(s)');
      for (int i = 0; i < outputTensors.length; i++) {
        debugPrint(
            '   output[$i] shape=${outputTensors[i].shape} type=${outputTensors[i].type}');
      }

      final detections = _decodeAndNms(
        outputs[0] as List,
        predShape,
        protos: protos,
        protoShape: protoShape,
        confidenceThreshold: confidenceThreshold,
        iouThreshold: iouThreshold,
      );

      return YoloInferenceResult(
        detections: detections,
        imageSize: Size(imgW, imgH),
      );
    } catch (e, st) {
      debugPrint('❌ YOLOv11x-seg: detect error: $e\n$st');
      return const YoloInferenceResult(detections: []);
    }
  }

  // ─────────────────────────── Preprocessing ────────────────────────────────

  /// Resize to 640×640, normalise to [0, 1], return [1, 640, 640, 3] nested list.
  List<List<List<List<double>>>> _preprocessImage(img.Image source) {
    final resized = img.copyResize(
      source,
      width: _kInputSize,
      height: _kInputSize,
      interpolation: img.Interpolation.linear,
    );

    // Build [H, W, 3] nested list.
    final image = List.generate(_kInputSize, (y) {
      return List.generate(_kInputSize, (x) {
        final pixel = resized.getPixel(x, y);
        return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
      });
    });

    // Wrap in batch dimension → [1, H, W, 3].
    return [image];
  }

  // ──────────────────────────── NMS + Decode ────────────────────────────────

  /// Decode raw predictions and apply per-class NMS.
  ///
  /// Handles both channel-last  [1, numBoxes, channels]
  /// and channel-first          [1, channels, numBoxes]  output layouts.
  List<YoloDetection> _decodeAndNms(
    List rawPred,
    List<int> predShape, {
    List? protos,
    List<int>? protoShape,
    required double confidenceThreshold,
    required double iouThreshold,
  }) {
    if (predShape.length != 3) {
      debugPrint('⚠️ YOLOv11x-seg: unexpected pred shape $predShape');
      return [];
    }

    // Determine layout by size: the larger dimension is numBoxes (≈8400),
    // the smaller is channels (= 4 + nc + 32).
    final dim1 = predShape[1];
    final dim2 = predShape[2];
    final bool transposed = dim1 < dim2; // [1, ch, boxes] → transposed
    final int numBoxes = transposed ? dim2 : dim1;
    final int channels = transposed ? dim1 : dim2;

    // channels = 4 (box) + nc (class scores) + 32 (mask coeffs)
    final nc = channels - 4 - _kNmMasks;
    if (nc <= 0) {
      debugPrint('⚠️ YOLOv11x-seg: cannot derive nc from channels=$channels');
      return [];
    }

    final batchPred = rawPred[0] as List;
    final rawDetections = <_RawDetection>[];

    for (int b = 0; b < numBoxes; b++) {
      final double cx, cy, w, h;
      final List<double> classScores;
      final List<double> maskCoeffs;

      if (!transposed) {
        // [1, numBoxes, channels] — one row per box.
        final row = batchPred[b] as List;
        cx = (row[0] as num).toDouble();
        cy = (row[1] as num).toDouble();
        w = (row[2] as num).toDouble();
        h = (row[3] as num).toDouble();
        classScores = List.generate(nc, (i) => (row[4 + i] as num).toDouble());
        maskCoeffs = List.generate(
            _kNmMasks, (i) => (row[4 + nc + i] as num).toDouble());
      } else {
        // [1, channels, numBoxes] — one row per channel.
        cx = ((batchPred[0] as List)[b] as num).toDouble();
        cy = ((batchPred[1] as List)[b] as num).toDouble();
        w = ((batchPred[2] as List)[b] as num).toDouble();
        h = ((batchPred[3] as List)[b] as num).toDouble();
        classScores = List.generate(
            nc, (i) => ((batchPred[4 + i] as List)[b] as num).toDouble());
        maskCoeffs = List.generate(_kNmMasks,
            (i) => ((batchPred[4 + nc + i] as List)[b] as num).toDouble());
      }

      // Keep only boxes above confidence threshold.
      int bestClass = 0;
      double bestScore = classScores[0];
      for (int c = 1; c < nc; c++) {
        if (classScores[c] > bestScore) {
          bestScore = classScores[c];
          bestClass = c;
        }
      }
      if (bestScore < confidenceThreshold || w <= 0 || h <= 0) continue;

      rawDetections.add(_RawDetection(
        cx: cx,
        cy: cy,
        w: w,
        h: h,
        classId: bestClass,
        confidence: bestScore,
        maskCoeffs: maskCoeffs,
      ));
    }

    // Auto-detect normalised vs pixel coordinates.
    // Standard YOLO outputs pixel coords in [0, 640]; some TFLite exports
    // normalise to [0, 1]. If the largest coordinate value is ≤ 1.5 we
    // treat them as normalised and scale to pixel space so the rest of
    // the pipeline (mask cropping, final normalisation) works uniformly.
    if (rawDetections.isNotEmpty) {
      final maxCoord = rawDetections.fold<double>(
        0,
        (m, d) =>
            math.max(m, math.max(math.max(d.cx, d.cy), math.max(d.w, d.h))),
      );
      if (maxCoord <= 1.5) {
        debugPrint(
            '🔄 YOLOv11x-seg: normalised coords detected (max=$maxCoord), '
            'scaling to ${_kInputSize}px');
        for (int i = 0; i < rawDetections.length; i++) {
          final d = rawDetections[i];
          rawDetections[i] = _RawDetection(
            cx: d.cx * _kInputSize,
            cy: d.cy * _kInputSize,
            w: d.w * _kInputSize,
            h: d.h * _kInputSize,
            classId: d.classId,
            confidence: d.confidence,
            maskCoeffs: d.maskCoeffs,
          );
        }
      }
    }

    // Apply per-class NMS and cap results.
    final kept =
        _nms(rawDetections, iouThreshold).take(_kMaxDetections).toList();

    return kept.map((r) {
      List<List<double>>? mask;
      if (protos != null && protoShape != null) {
        try {
          mask = _computeInstanceMask(r, protos, protoShape);
        } catch (e) {
          debugPrint('🎭 mask error for ${_labelFor(r.classId)}: $e');
        }
        debugPrint(
            '🎭 ${_labelFor(r.classId)}: mask=${mask != null ? "${mask.length}x${mask[0].length}" : "null"} '
            'box=(${r.cx.toStringAsFixed(1)},${r.cy.toStringAsFixed(1)},${r.w.toStringAsFixed(1)},${r.h.toStringAsFixed(1)})');
      } else {
        debugPrint(
            '🎭 ${_labelFor(r.classId)}: no proto tensor (outputs=${protos != null})');
      }
      return YoloDetection(
        className: _labelFor(r.classId),
        confidence: r.confidence,
        x: r.cx / _kInputSize,
        y: r.cy / _kInputSize,
        width: r.w / _kInputSize,
        height: r.h / _kInputSize,
        mask: mask,
      );
    }).toList();
  }

  /// Greedy per-class NMS — sort by confidence, suppress overlapping boxes.
  List<_RawDetection> _nms(
      List<_RawDetection> detections, double iouThreshold) {
    final sorted = List<_RawDetection>.from(detections)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    final suppressed = List<bool>.filled(sorted.length, false);
    final kept = <_RawDetection>[];

    for (int i = 0; i < sorted.length; i++) {
      if (suppressed[i]) continue;
      kept.add(sorted[i]);
      for (int j = i + 1; j < sorted.length; j++) {
        if (suppressed[j]) continue;
        if (sorted[i].classId != sorted[j].classId) continue;
        if (_iou(sorted[i], sorted[j]) >= iouThreshold) suppressed[j] = true;
      }
    }
    return kept;
  }

  double _iou(_RawDetection a, _RawDetection b) {
    final ax1 = a.cx - a.w / 2, ay1 = a.cy - a.h / 2;
    final ax2 = a.cx + a.w / 2, ay2 = a.cy + a.h / 2;
    final bx1 = b.cx - b.w / 2, by1 = b.cy - b.h / 2;
    final bx2 = b.cx + b.w / 2, by2 = b.cy + b.h / 2;

    final iw = math.max(0.0, math.min(ax2, bx2) - math.max(ax1, bx1));
    final ih = math.max(0.0, math.min(ay2, by2) - math.max(ay1, by1));
    final intersection = iw * ih;
    if (intersection == 0) return 0.0;

    final union = a.w * a.h + b.w * b.h - intersection;
    return union > 0 ? intersection / union : 0.0;
  }

  // ──────────────────── Instance Mask Decoding ─────────────────────────────

  /// Compute a per-instance segmentation mask by multiplying the detection's
  /// 32 mask coefficients with the 32 prototype masks from the model's second
  /// output, then applying sigmoid and cropping to the bounding box.
  ///
  /// Returns a 2-D list [cropH][cropW] of probabilities in [0, 1],
  /// or `null` if prototypes are unavailable / shape is unexpected.
  List<List<double>>? _computeInstanceMask(
    _RawDetection det,
    List protos,
    List<int> protoShape,
  ) {
    // Standard 4D proto: [1, 32, H, W] or [1, H, W, 32]
    // Some TFLite exports produce 3D: [1, 32, H*W]
    final int maskH, maskW;
    final bool channelFirst;
    final bool flatSpatial; // true when proto is 3D [1, 32, H*W]

    if (protoShape.length == 4) {
      channelFirst = protoShape[1] == _kNmMasks;
      maskH = channelFirst ? protoShape[2] : protoShape[1];
      maskW = channelFirst ? protoShape[3] : protoShape[2];
      flatSpatial = false;
    } else if (protoShape.length == 3 && protoShape[1] == _kNmMasks) {
      // [1, 32, H*W] → assume square mask
      final spatial = protoShape[2];
      final side = math.sqrt(spatial).round();
      if (side * side != spatial) {
        debugPrint('⚠️ proto spatial dim $spatial is not a perfect square');
        return null;
      }
      maskH = side;
      maskW = side;
      channelFirst = true;
      flatSpatial = true;
    } else {
      debugPrint('⚠️ unsupported protoShape=$protoShape');
      return null;
    }

    debugPrint('🎭 proto: shape=$protoShape, maskH=$maskH, maskW=$maskW, '
        'channelFirst=$channelFirst, flatSpatial=$flatSpatial');

    // Scale from input pixel coords (640) → mask coords (e.g. 160)
    final double scaleX = maskW / _kInputSize;
    final double scaleY = maskH / _kInputSize;

    // Bbox in mask coordinates, clamped.
    final int mx1 = ((det.cx - det.w / 2) * scaleX).clamp(0, maskW - 1).floor();
    final int my1 = ((det.cy - det.h / 2) * scaleY).clamp(0, maskH - 1).floor();
    final int mx2 = ((det.cx + det.w / 2) * scaleX).clamp(0, maskW - 1).ceil();
    final int my2 = ((det.cy + det.h / 2) * scaleY).clamp(0, maskH - 1).ceil();

    debugPrint('🎭 bbox in mask coords: mx1=$mx1, my1=$my1, mx2=$mx2, my2=$my2 '
        '(det: cx=${det.cx.toStringAsFixed(1)}, cy=${det.cy.toStringAsFixed(1)}, '
        'w=${det.w.toStringAsFixed(1)}, h=${det.h.toStringAsFixed(1)})');

    if (mx2 <= mx1 || my2 <= my1) {
      debugPrint('⚠️ degenerate mask bbox, skipping');
      return null;
    }

    final batch = protos[0] as List;

    final mask = List.generate(my2 - my1, (dy) {
      final py = my1 + dy;
      return List.generate(mx2 - mx1, (dx) {
        final px = mx1 + dx;
        double sum = 0;
        for (int i = 0; i < _kNmMasks; i++) {
          final double protoVal;
          if (flatSpatial) {
            // 3D buffer: batch[i] is List<double> of length H*W
            protoVal = ((batch[i] as List)[py * maskW + px] as num).toDouble();
          } else if (channelFirst) {
            // 4D buffer: batch[i][py][px]
            protoVal = (((batch[i] as List)[py] as List)[px] as num).toDouble();
          } else {
            // 4D buffer: batch[py][px][i]
            protoVal = (((batch[py] as List)[px] as List)[i] as num).toDouble();
          }
          sum += det.maskCoeffs[i] * protoVal;
        }
        return _sigmoid(sum);
      });
    });

    debugPrint('🎭 mask generated: ${mask.length}x${mask[0].length}');
    return mask;
  }

  static double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

  // ─────────────────────────── Buffer Helpers ───────────────────────────────

  /// Allocate a nested List matching [shape] for use as a tflite output buffer.
  Object _allocateBuffer(List<int> shape) {
    return switch (shape.length) {
      1 => List<double>.filled(shape[0], 0.0),
      2 => List.generate(shape[0], (_) => List<double>.filled(shape[1], 0.0)),
      3 => List.generate(
          shape[0],
          (_) => List.generate(
              shape[1], (_) => List<double>.filled(shape[2], 0.0))),
      4 => List.generate(
          shape[0],
          (_) => List.generate(
              shape[1],
              (_) => List.generate(
                  shape[2], (_) => List<double>.filled(shape[3], 0.0)))),
      _ => throw ArgumentError('Unsupported tensor rank: ${shape.length}'),
    };
  }

  // ─────────────────────────── Load Guard ──────────────────────────────────

  Future<void> _ensureLoaded() async {
    if (_isLoading) {
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (_isLoading && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    if (!_isLoaded) await loadModel();
  }

  // ─────────────────────────── Quick Safety Analysis ───────────────────────

  static Map<String, dynamic> toSafetyAnalysis(List<YoloDetection> detections) {
    if (detections.isEmpty) {
      return {
        'risk_level': 'low',
        'risk_score': 10,
        'analysis': '未發現明顯缺陷',
        'recommendations': ['建議進一步人工檢查確認'],
        'detections': [],
        'detection_count': 0,
      };
    }

    final labels = detections
        .map((d) =>
            '${d.className} (${(d.confidence * 100).toStringAsFixed(0)}%)')
        .toList();

    final int riskScore = (10 + detections.length * 8).clamp(0, 100);
    final riskLevel = riskScore >= 70
        ? 'high'
        : riskScore >= 40
            ? 'medium'
            : 'low';

    return {
      'risk_level': riskLevel,
      'risk_score': riskScore,
      'analysis':
          'YOLOv11x-seg 偵測到 ${detections.length} 個缺陷：\n- ${labels.join('\n- ')}',
      'recommendations': ['建議交由 LLM 進行風險等級與修復建議分析'],
      'detections': detections.map((d) => d.toJson()).toList(),
      'detection_count': detections.length,
    };
  }

  // ──────────────────────────── Lifecycle ───────────────────────────────────

  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
    _instance = null;
  }
}
