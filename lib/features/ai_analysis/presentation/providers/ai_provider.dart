import 'package:smartsurvey/features/ai_analysis/data/repositories/ai_repository_impl.dart';
import 'package:smartsurvey/features/ai_analysis/domain/entities/detection_result_entity.dart';
import 'package:smartsurvey/features/ai_analysis/domain/usecases/perform_detection_usecase.dart';
import 'package:smartsurvey/shared/services/yolo_service.dart';
import 'package:flutter/foundation.dart';

class AiProvider extends ChangeNotifier {
  final PerformDetectionUsecase _performDetectionUsecase;

  factory AiProvider({
    AiRepositoryImpl? repository,
    PerformDetectionUsecase? performDetectionUsecase,
  }) {
    final repo = repository ?? AiRepositoryImpl();
    return AiProvider._(
      performDetectionUsecase:
          performDetectionUsecase ?? PerformDetectionUsecase(repo),
    );
  }

  AiProvider._({
    required PerformDetectionUsecase performDetectionUsecase,
  })  : _performDetectionUsecase = performDetectionUsecase,
        super();

  bool _isAnalyzingVlm = false;
  bool get isAnalyzingVlm => _isAnalyzingVlm;

  bool _isDetectingYolo = false;
  bool get isDetectingYolo => _isDetectingYolo;

  double _yoloConfidenceThreshold = 0.5;
  double get yoloConfidenceThreshold => _yoloConfidenceThreshold;

  DetectionResultEntity? _lastVlmResult;
  DetectionResultEntity? get lastVlmResult => _lastVlmResult;

  DetectionResultEntity? _lastYoloResult;
  DetectionResultEntity? get lastYoloResult => _lastYoloResult;

  List<YoloDetection>? _lastYoloDetections;
  List<YoloDetection>? get lastYoloDetections => _lastYoloDetections;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _yoloServerOffline = false;
  bool get yoloServerOffline => _yoloServerOffline;

  Future<void> runVlmAnalysis({
    required String imageBase64,
    String? additionalContext,
    Map<String, dynamic>? metadata,
    String? yoloResultImageBase64,
  }) async {
    _isAnalyzingVlm = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _lastVlmResult = await _performDetectionUsecase(
        engine: DetectionEngine.vlm,
        imageBase64: imageBase64,
        additionalContext: additionalContext,
        vlmMetadata: metadata,
        yoloResultImageBase64: yoloResultImageBase64,
      );
    } catch (e) {
      _errorMessage = 'VLM analysis failed: $e';
    } finally {
      _isAnalyzingVlm = false;
      notifyListeners();
    }
  }

  Future<void> runYoloDetection(Uint8List imageBytes) async {
    _isDetectingYolo = true;
    _errorMessage = null;
    _yoloServerOffline = false;
    notifyListeners();

    try {
      // Run detection first to capture raw bounding boxes for UI display.
      final yoloService = YoloService.instance;
      _lastYoloDetections = await yoloService.detect(
        imageBytes,
        confidenceThreshold: _yoloConfidenceThreshold,
      );
      _lastYoloResult = await _performDetectionUsecase(
        engine: DetectionEngine.yolo,
        imageBytes: imageBytes,
        confidenceThreshold: _yoloConfidenceThreshold,
      );
    } catch (e) {
      _errorMessage = 'YOLO detection failed: $e';
      _yoloServerOffline = true;
    } finally {
      _isDetectingYolo = false;
      notifyListeners();
    }
  }

  void setYoloConfidenceThreshold(double value) {
    _yoloConfidenceThreshold = value;
    notifyListeners();
  }
}
