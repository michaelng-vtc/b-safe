import 'dart:typed_data';

import 'package:bsafe_app/shared/services/api_service.dart';
import 'package:bsafe_app/shared/services/yolo_service.dart';

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
  }) {
    return _apiService.analyzeImageWithAI(
      imageBase64,
      additionalContext: additionalContext,
    );
  }

  Future<List<YoloDetection>> detectWithYolo(
    Uint8List imageBytes, {
    double confidenceThreshold = 0.25,
  }) {
    return _yoloService.detect(
      imageBytes,
      confidenceThreshold: confidenceThreshold,
    );
  }

  Map<String, dynamic> toYoloSafetyAnalysis(List<YoloDetection> detections) {
    return YoloService.toSafetyAnalysis(detections);
  }
}
