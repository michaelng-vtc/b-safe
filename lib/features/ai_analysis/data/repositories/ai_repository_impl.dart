import 'dart:typed_data';

import 'package:smartsurvey/features/ai_analysis/data/datasources/ai_datasource.dart';
import 'package:smartsurvey/features/ai_analysis/domain/entities/detection_result_entity.dart';
import 'package:smartsurvey/features/ai_analysis/domain/repositories/ai_repository.dart';

class AiRepositoryImpl implements AiRepository {
  final AiDatasource datasource;

  AiRepositoryImpl({AiDatasource? datasource})
      : datasource = datasource ?? AiDatasource();

  @override
  Future<DetectionResultEntity> performVlmAnalysis({
    required String imageBase64,
    String? additionalContext,
    Map<String, dynamic>? metadata,
    String? yoloResultImageBase64,
  }) async {
    final model = await datasource.runVlm(
      imageBase64: imageBase64,
      additionalContext: additionalContext,
      metadata: metadata,
      yoloResultImageBase64: yoloResultImageBase64,
    );
    return model.toEntity();
  }

  @override
  Future<DetectionResultEntity> performYoloDetection({
    required Uint8List imageBytes,
    double confidenceThreshold = 0.25,
  }) async {
    final model = await datasource.runYolo(
      imageBytes: imageBytes,
      confidenceThreshold: confidenceThreshold,
    );
    return model.toEntity();
  }
}
