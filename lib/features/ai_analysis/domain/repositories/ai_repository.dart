import 'dart:typed_data';

import 'package:bsafe_app/features/ai_analysis/domain/entities/detection_result_entity.dart';

abstract class AiRepository {
  Future<DetectionResultEntity> performVlmAnalysis({
    required String imageBase64,
    String? additionalContext,
  });

  Future<DetectionResultEntity> performYoloDetection({
    required Uint8List imageBytes,
    double confidenceThreshold,
  });

  Future<List<DetectionResultEntity>> getDetectionHistory();

  Future<void> saveDetectionResult(DetectionResultEntity result);
}
