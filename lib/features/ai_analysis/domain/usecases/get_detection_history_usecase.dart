import 'package:bsafe_app/features/ai_analysis/domain/entities/detection_result_entity.dart';
import 'package:bsafe_app/features/ai_analysis/domain/repositories/ai_repository.dart';

class GetDetectionHistoryUsecase {
  final AiRepository repository;

  const GetDetectionHistoryUsecase(this.repository);

  Future<List<DetectionResultEntity>> call() {
    return repository.getDetectionHistory();
  }
}
