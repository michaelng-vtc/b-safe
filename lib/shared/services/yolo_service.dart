import 'package:flutter/foundation.dart';

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

/// Compatibility-safe YOLO service.
///
/// Native YOLO plugin is disabled to avoid Android 16KB page-size
/// compatibility issues from third-party native libraries.
class YoloService {
  static YoloService? _instance;
  static const String _defaultCustomModel = 'best_float32';
  bool _isLoaded = false;
  bool _isLoading = false;

  YoloService._();

  static YoloService get instance {
    _instance ??= YoloService._();
    return _instance!;
  }

  /// YOLO runtime is disabled in this compatibility build.
  static bool get isSupported => false;

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;

  /// Initialize YOLO.
  Future<bool> loadModel({String modelPath = _defaultCustomModel}) async {
    _isLoading = true;
    _isLoaded = false;
    debugPrint('YOLO disabled in compatibility build (model: $modelPath)');
    _isLoading = false;
    return false;
  }

  /// Detect objects from image bytes.
  Future<List<YoloDetection>> detect(
    Uint8List imageBytes, {
    double confidenceThreshold = 0.25,
  }) async {
    debugPrint(
      'YOLO detect skipped in compatibility build '
      '(bytes=${imageBytes.length}, conf=$confidenceThreshold)',
    );
    return const <YoloDetection>[];
  }

  /// Result riskanalysis.
  static Map<String, dynamic> toSafetyAnalysis(List<YoloDetection> detections) {
    if (detections.isEmpty) {
      return {
        'risk_level': 'low',
        'risk_score': 10,
        'analysis':
            'YOLO is disabled in this compatibility build. No detections.',
        'recommendations': ['Use cloud/manual inspection for object analysis'],
        'detections': [],
        'detection_count': 0,
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
      analysisLines.add('- Facilities/Furniture: ${structuralItems.join(', ')}');
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
      recommendations.add('Environment normal. Regular inspection recommended.');
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
    _isLoaded = false;
    _instance = null;
  }
}
