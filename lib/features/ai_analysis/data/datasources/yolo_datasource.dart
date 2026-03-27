import 'dart:typed_data';

import 'package:bsafe_app/features/ai_analysis/data/models/detection_result_model.dart';
import 'package:bsafe_app/shared/services/api_service.dart';
import 'package:bsafe_app/shared/services/yolo_service.dart';
import 'package:uuid/uuid.dart';

class AiDatasource {
  final ApiService _apiService;
  final YoloService _yoloService;
  final Uuid _uuid;

  AiDatasource({
    ApiService? apiService,
    YoloService? yoloService,
    Uuid? uuid,
  })  : _apiService = apiService ?? ApiService.instance,
        _yoloService = yoloService ?? YoloService.instance,
        _uuid = uuid ?? const Uuid();

  Future<DetectionResultModel> runVlm({
    required String imageBase64,
    String? additionalContext,
  }) async {
    final raw = await _apiService.analyzeImageWithAI(
      imageBase64,
      additionalContext: additionalContext,
    );

    return DetectionResultModel.fromRaw(
      id: _uuid.v4(),
      source: 'vlm',
      raw: raw,
    );
  }

  Future<DetectionResultModel> runYolo({
    required Uint8List imageBytes,
    double confidenceThreshold = 0.25,
  }) async {
    final detections = await _yoloService.detect(
      imageBytes,
      confidenceThreshold: confidenceThreshold,
    );
    final raw = YoloService.toSafetyAnalysis(detections);

    return DetectionResultModel.fromRaw(
      id: _uuid.v4(),
      source: 'yolo',
      raw: raw,
    );
  }
}
