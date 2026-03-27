import 'dart:typed_data';

import 'package:bsafe_app/features/ai_analysis/data/datasources/yolo_datasource.dart';
import 'package:bsafe_app/features/ai_analysis/domain/entities/detection_result_entity.dart';
import 'package:bsafe_app/features/ai_analysis/domain/repositories/ai_repository.dart';

class AiRepositoryImpl implements AiRepository {
  final AiDatasource datasource;
  final List<DetectionResultEntity> _history = <DetectionResultEntity>[];

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
    final entity = model.toEntity();
    await saveDetectionResult(entity);
    return entity;
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
    final entity = model.toEntity();
    await saveDetectionResult(entity);
    return entity;
  }

  @override
  Future<List<DetectionResultEntity>> getDetectionHistory() async {
    return List<DetectionResultEntity>.from(_history);
  }

  @override
  Future<void> saveDetectionResult(DetectionResultEntity result) async {
    _history.insert(0, result);
  }
}
