import 'dart:typed_data';

import 'package:smartsurvey/features/ai_analysis/domain/entities/detection_result_entity.dart';

abstract class AiRepository {
  Future<DetectionResultEntity> performVlmAnalysis({
    required String imageBase64,
    String? additionalContext,
    Map<String, dynamic>? metadata,
    String? yoloResultImageBase64,
  });

  Future<DetectionResultEntity> performYoloDetection({
    required Uint8List imageBytes,
    double confidenceThreshold,
  });
}
