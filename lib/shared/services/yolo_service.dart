import 'dart:io';
import 'package:flutter/foundation.dart';

// Conditional import: ultralytics_yolo only works on Android/iOS
import 'package:ultralytics_yolo/yolo.dart';

/// YOLO result.
class YoloDetection {
  final String className;
  final double confidence;
  final double x; // center x (normalized 0-1 of image width)
  final double y; // center y (normalized 0-1 of image height)
  final double width; // box width (normalized)
  final double height; // box height (normalized)

  YoloDetection({
    required this.className,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Bounding box image coordinate (pixel values).
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

/// YOLO - ultralytics_yolo.
class YoloService {
  static YoloService? _instance;
  static const String _defaultCustomModel = 'best_float32';
  static const String _fallbackModel = 'yolo11n';
  YOLO? _yolo;
  String? _activeModelPath;
  bool _isLoaded = false;
  bool _isLoading = false;

  YoloService._();

  static YoloService get instance {
    _instance ??= YoloService._();
    return _instance!;
  }

  /// Platform YOLO ( Android/iOS).
  static bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;

  /// Initialize YOLO.
  Future<bool> loadModel({String modelPath = _defaultCustomModel}) async {
    if (!isSupported) {
      debugPrint('YOLO: Platform not supported (Android/iOS only)');
      return false;
    }

    if (_isLoaded && _activeModelPath == modelPath) return true;
    if (_isLoading) return false;

    _isLoading = true;

    try {
      await _yolo?.dispose();
      _yolo = null;
      _isLoaded = false;

      final normalized = modelPath.trim();
      final withoutAssetsPrefix = normalized.startsWith('assets/models/')
          ? normalized.substring('assets/models/'.length)
          : normalized;
      final withoutExt = withoutAssetsPrefix.endsWith('.tflite')
          ? withoutAssetsPrefix.substring(
              0, withoutAssetsPrefix.length - '.tflite'.length)
          : withoutAssetsPrefix;

      final candidates = <String>{};
      if (Platform.isAndroid) {
        candidates.add(withoutAssetsPrefix);
        candidates.add(withoutExt);
        candidates.add('$withoutExt.tflite');
        candidates.add('assets/models/$withoutExt');
        candidates.add('assets/models/$withoutExt.tflite');
      } else {
        candidates.add(withoutExt);
        candidates.add(normalized);
      }

      for (final candidate in candidates) {
        try {
          final exists = await YOLO.checkModelExists(candidate);
          debugPrint('YOLO: checkModelExists($candidate) => $exists');

          _yolo = YOLO(
            modelPath: candidate,
            task: YOLOTask.detect,
          );

          await _yolo!.loadModel();
          _isLoaded = true;
          _activeModelPath = candidate;
          debugPrint('YOLO: Model loaded successfully from $candidate');
          return true;
        } catch (e) {
          debugPrint('YOLO: Failed candidate $candidate: $e');
          await _yolo?.dispose();
          _yolo = null;
        }
      }

      debugPrint('YOLO: Unable to load model from candidates: $candidates');
      return false;
    } catch (e) {
      debugPrint('YOLO: Model load failed: $e');
      _yolo = null;
      _isLoaded = false;
      _activeModelPath = null;
      return false;
    } finally {
      _isLoading = false;
    }
  }

  List<YoloDetection> _parseDetections(Map<dynamic, dynamic> results) {
    final boxes = results['boxes'] as List<dynamic>? ?? [];
    final detections = <YoloDetection>[];

    for (final box in boxes) {
      final map = box as Map<dynamic, dynamic>;
      detections.add(YoloDetection(
        className: (map['class'] as String?) ?? 'unknown',
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
        x: (map['x'] as num?)?.toDouble() ?? 0.0,
        y: (map['y'] as num?)?.toDouble() ?? 0.0,
        width: (map['width'] as num?)?.toDouble() ?? 0.0,
        height: (map['height'] as num?)?.toDouble() ?? 0.0,
      ));
    }

    return detections;
  }

  /// Floor plan image cache.
  Future<List<YoloDetection>> detect(Uint8List imageBytes,
      {double confidenceThreshold = 0.25}) async {
    if (!_isLoaded || _yolo == null) {
      // Autoload.
      final loaded = await loadModel();
      if (!loaded) return [];
    }

    try {
      final results = await _yolo!.predict(
        imageBytes,
        confidenceThreshold: confidenceThreshold,
        iouThreshold: 0.45,
      );

      final detections = _parseDetections(results);

      debugPrint('YOLO: Detected ${detections.length} object(s)');
      return detections;
    } catch (e) {
      debugPrint('YOLO: Detection failed on $_activeModelPath: $e');

      if (_activeModelPath != _fallbackModel) {
        debugPrint('YOLO: Retrying with fallback model $_fallbackModel');
        _isLoaded = false;
        _activeModelPath = null;
        await _yolo?.dispose();
        _yolo = null;

        final loadedFallback = await loadModel(modelPath: _fallbackModel);
        if (loadedFallback && _yolo != null) {
          try {
            final retryResults = await _yolo!.predict(
              imageBytes,
              confidenceThreshold: confidenceThreshold,
              iouThreshold: 0.45,
            );

            final fallbackDetections = _parseDetections(retryResults);
            debugPrint(
                'YOLO: Fallback $_fallbackModel detected ${fallbackDetections.length} object(s)');
            return fallbackDetections;
          } catch (retryError) {
            debugPrint('YOLO: Fallback detection failed: $retryError');
          }
        }
      }

      return [];
    }
  }

  /// Result riskanalysis.
  static Map<String, dynamic> toSafetyAnalysis(List<YoloDetection> detections) {
    if (detections.isEmpty) {
      return {
        'risk_level': 'low',
        'risk_score': 10,
        'analysis': 'YOLO detection complete. No obvious anomalies found.',
        'recommendations': ['Recommend manual inspection for confirmation'],
        'detections': [],
        'detection_count': 0,
      };
    }

    // Translated legacy note.
    final safetyHazards = <String>[];
    final structuralItems = <String>[];
    final normalItems = <String>[];

    // COCO dataset.
    const hazardClasses = {
      'fire hydrant', 'stop sign', 'traffic light', // / device.
      'scissors', 'knife', // Translated note.
    };
    const structuralClasses = {
      'chair', 'couch', 'bed', 'dining table', 'toilet',
      'sink', // Translated note.
      'tv', 'laptop', 'microwave', 'oven', 'refrigerator', // Translated note.
      'door', 'window', // Translated note.
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

    // Risk.
    int riskScore = 10; // Translated note.
    String riskLevel = 'low';

    if (safetyHazards.isNotEmpty) {
      riskScore += safetyHazards.length * 20;
    }
    if (personCount > 3) {
      riskScore += 15; // Translated note.
    }
    riskScore = riskScore.clamp(0, 100);

    if (riskScore >= 70) {
      riskLevel = 'high';
    } else if (riskScore >= 40) {
      riskLevel = 'medium';
    }

    // Analysis.
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

    // Recommendation.
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

  /// Translated legacy note.
  Future<void> dispose() async {
    try {
      await _yolo?.dispose();
    } catch (e) {
      debugPrint('YOLO dispose error: $e');
    }
    _yolo = null;
    _isLoaded = false;
    _activeModelPath = null;
    _instance = null;
  }
}
