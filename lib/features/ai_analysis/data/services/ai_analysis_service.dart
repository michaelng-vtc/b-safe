import 'dart:typed_data';

import 'package:smartsurvey/shared/services/api_service.dart';
import 'package:smartsurvey/shared/services/yolo_service.dart';

/// Feature-local service adapter to keep ai_analysis datasource isolated
/// from shared infrastructure details.
class AiAnalysisService {
  final ApiService _apiService;
  final YoloService _yoloService;

  AiAnalysisService({
    ApiService? apiService,
    YoloService? yoloService,
  })  : _apiService = apiService ?? ApiService.instance,
        _yoloService = yoloService ?? YoloService.instance;

  Future<Map<String, dynamic>> analyzeImageWithVlm({
    required String imageBase64,
    String? additionalContext,
    Map<String, dynamic>? metadata,
    String? yoloResultImageBase64,
  }) {
    return _apiService.analyzeImageWithAI(
      imageBase64,
      additionalContext: additionalContext,
      metadata: metadata,
      yoloResultImageBase64: yoloResultImageBase64,
    );
  }

  Future<Map<String, dynamic>> analyzeImageWithYolo(
    Uint8List imageBytes, {
    double confidenceThreshold = 0.25,
  }) async {
    final detections = await _yoloService.detect(
      imageBytes,
      confidenceThreshold: confidenceThreshold,
    );
    return {
      'detections': detections.map((d) => d.toJson()).toList(),
      'detection_count': detections.length,
    };
  }
}
