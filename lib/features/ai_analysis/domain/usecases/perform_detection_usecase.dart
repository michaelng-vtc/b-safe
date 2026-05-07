import 'dart:typed_data';

import 'package:smartsurvey/features/ai_analysis/domain/entities/detection_result_entity.dart';
import 'package:smartsurvey/features/ai_analysis/domain/repositories/ai_repository.dart';

enum DetectionEngine {
  vlm,
  yolo,
}

class PerformDetectionUsecase {
  final AiRepository repository;

  const PerformDetectionUsecase(this.repository);

  Future<DetectionResultEntity> call({
    required DetectionEngine engine,
    String? imageBase64,
    Uint8List? imageBytes,
    String? additionalContext,
    Map<String, dynamic>? vlmMetadata,
    String? yoloResultImageBase64,
    double confidenceThreshold = 0.25,
  }) async {
    switch (engine) {
      case DetectionEngine.vlm:
        if (imageBase64 == null || imageBase64.isEmpty) {
          throw ArgumentError('imageBase64 is required for VLM analysis');
        }
        return repository.performVlmAnalysis(
          imageBase64: imageBase64,
          additionalContext: additionalContext,
          metadata: vlmMetadata,
          yoloResultImageBase64: yoloResultImageBase64,
        );
      case DetectionEngine.yolo:
        if (imageBytes == null || imageBytes.isEmpty) {
          throw ArgumentError('imageBytes is required for YOLO detection');
        }
        return repository.performYoloDetection(
          imageBytes: imageBytes,
          confidenceThreshold: confidenceThreshold,
        );
    }
  }
}
