import 'package:smartsurvey/features/ai_analysis/domain/entities/detection_result_entity.dart';

class DetectionResultModel {
  final String id;
  final String source;
  final String riskLevel;
  final int riskScore;
  final String analysis;
  final List<String> recommendations;
  final Map<String, dynamic> raw;
  final DateTime createdAt;

  const DetectionResultModel({
    required this.id,
    required this.source,
    required this.riskLevel,
    required this.riskScore,
    required this.analysis,
    required this.recommendations,
    required this.raw,
    required this.createdAt,
  });

  factory DetectionResultModel.fromRaw({
    required String id,
    required String source,
    required Map<String, dynamic> raw,
  }) {
    final observation = (raw['observation'] ?? raw['analysis'] ?? '').toString();
    final hkConstructionContext =
        (raw['hk_construction_context'] ?? '').toString();
    final causeReview = (raw['cause_review'] ?? '').toString();
    final recommendations = (raw['recommendations'] ?? '').toString();

    final formattedAnalysis = [
      if (observation.isNotEmpty) '1. $observation',
      if (hkConstructionContext.isNotEmpty) '2. $hkConstructionContext',
      if (causeReview.isNotEmpty) '3. $causeReview',
      if (recommendations.isNotEmpty) '4. $recommendations',
    ].join('\n\n');

    return DetectionResultModel(
      id: id,
      source: source,
      riskLevel: (raw['risk_level'] as String?) ?? 'low',
      riskScore: (raw['risk_score'] as int?) ?? 0,
      analysis: formattedAnalysis.isNotEmpty
          ? formattedAnalysis
          : observation.isNotEmpty
              ? observation
              : 'No analysis result',
      recommendations: recommendations.isNotEmpty ? [recommendations] : const [],
      raw: raw,
      createdAt: DateTime.now(),
    );
  }

  DetectionResultEntity toEntity() {
    return DetectionResultEntity(
      id: id,
      source: source,
      riskLevel: riskLevel,
      riskScore: riskScore,
      analysis: analysis,
      recommendations: recommendations,
      raw: raw,
      createdAt: createdAt,
    );
  }
}
