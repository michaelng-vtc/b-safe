import 'dart:typed_data';

import 'package:smartsurvey/features/ai_analysis/data/models/detection_result_model.dart';
import 'package:smartsurvey/features/ai_analysis/data/services/ai_analysis_service.dart';
import 'package:uuid/uuid.dart';

class AiDatasource {
  final AiAnalysisService _aiService;
  final Uuid _uuid;

  AiDatasource({
    AiAnalysisService? aiService,
    Uuid? uuid,
  })  : _aiService = aiService ?? AiAnalysisService(),
        _uuid = uuid ?? const Uuid();

  Future<DetectionResultModel> runVlm({
    required String imageBase64,
    String? additionalContext,
  }) async {
    final raw = await _aiService.analyzeImageWithVlm(
        imageBase64: imageBase64, additionalContext: additionalContext);

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
    final raw = await _aiService.analyzeImageWithYolo(
      imageBytes,
      confidenceThreshold: confidenceThreshold,
    );

    return DetectionResultModel.fromRaw(
      id: _uuid.v4(),
      source: 'yolo',
      raw: raw,
    );
  }
}
