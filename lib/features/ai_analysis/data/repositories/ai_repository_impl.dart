import 'dart:typed_data';

import 'package:bsafe_app/features/ai_analysis/data/datasources/ai_datasource.dart';
import 'package:bsafe_app/features/ai_analysis/domain/entities/detection_result_entity.dart';
import 'package:bsafe_app/features/ai_analysis/domain/repositories/ai_repository.dart';

class AiRepositoryImpl implements AiRepository {
  final AiDatasource datasource;

  AiRepositoryImpl({AiDatasource? datasource})
      : datasource = datasource ?? AiDatasource();

  @override
  Future<DetectionResultEntity> performVlmAnalysis({
    required String imageBase64,
    String? additionalContext,
  }) async {
    final model = await datasource.runVlm(
      imageBase64: imageBase64,
      additionalContext: additionalContext,
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
