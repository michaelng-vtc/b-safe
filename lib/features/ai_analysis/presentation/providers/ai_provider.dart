import 'package:bsafe_app/features/ai_analysis/data/repositories/ai_repository_impl.dart';
import 'package:bsafe_app/features/ai_analysis/domain/entities/detection_result_entity.dart';
import 'package:bsafe_app/features/ai_analysis/domain/usecases/get_detection_history_usecase.dart';
import 'package:bsafe_app/features/ai_analysis/domain/usecases/perform_detection_usecase.dart';
import 'package:flutter/foundation.dart';

class AiProvider extends ChangeNotifier {
  final PerformDetectionUsecase _performDetectionUsecase;
  final GetDetectionHistoryUsecase _getDetectionHistoryUsecase;

  factory AiProvider({
    AiRepositoryImpl? repository,
    PerformDetectionUsecase? performDetectionUsecase,
    GetDetectionHistoryUsecase? getDetectionHistoryUsecase,
  }) {
    final repo = repository ?? AiRepositoryImpl();
    return AiProvider._(
      repository: repo,
      performDetectionUsecase:
          performDetectionUsecase ?? PerformDetectionUsecase(repo),
      getDetectionHistoryUsecase:
          getDetectionHistoryUsecase ?? GetDetectionHistoryUsecase(repo),
    );
  }

  AiProvider._({
    required AiRepositoryImpl repository,
    required PerformDetectionUsecase performDetectionUsecase,
    required GetDetectionHistoryUsecase getDetectionHistoryUsecase,
  })  : _performDetectionUsecase = performDetectionUsecase,
        _getDetectionHistoryUsecase = getDetectionHistoryUsecase;

  bool _isAnalyzingVlm = false;
  bool get isAnalyzingVlm => _isAnalyzingVlm;

  bool _isDetectingYolo = false;
  bool get isDetectingYolo => _isDetectingYolo;

  bool _showBoundingBoxes = true;
  bool get showBoundingBoxes => _showBoundingBoxes;

  double _yoloConfidenceThreshold = 0.25;
  double get yoloConfidenceThreshold => _yoloConfidenceThreshold;

  DetectionResultEntity? _lastVlmResult;
  DetectionResultEntity? get lastVlmResult => _lastVlmResult;

  DetectionResultEntity? _lastYoloResult;
  DetectionResultEntity? get lastYoloResult => _lastYoloResult;

  List<DetectionResultEntity> _history = const <DetectionResultEntity>[];
  List<DetectionResultEntity> get history => _history;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> runVlmAnalysis({
    required String imageBase64,
    String? additionalContext,
  }) async {
    _isAnalyzingVlm = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _lastVlmResult = await _performDetectionUsecase(
        engine: DetectionEngine.vlm,
        imageBase64: imageBase64,
        additionalContext: additionalContext,
      );
      await loadHistory();
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
    notifyListeners();

    try {
      _lastYoloResult = await _performDetectionUsecase(
        engine: DetectionEngine.yolo,
        imageBytes: imageBytes,
        confidenceThreshold: _yoloConfidenceThreshold,
      );
      await loadHistory();
    } catch (e) {
      _errorMessage = 'YOLO detection failed: $e';
    } finally {
      _isDetectingYolo = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory() async {
    _history = await _getDetectionHistoryUsecase();
    notifyListeners();
  }

  void setYoloConfidenceThreshold(double value) {
    _yoloConfidenceThreshold = value;
    notifyListeners();
  }

  void toggleBoundingBoxes() {
    _showBoundingBoxes = !_showBoundingBoxes;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
