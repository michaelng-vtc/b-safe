class DetectionResultEntity {
  final String id;
  final String source; // vlm | yolo
  final String riskLevel;
  final int riskScore;
  final String analysis;
  final List<String> recommendations;
  final Map<String, dynamic> raw;
  final DateTime createdAt;

  const DetectionResultEntity({
    required this.id,
    required this.source,
    required this.riskLevel,
    required this.riskScore,
    required this.analysis,
    required this.recommendations,
    required this.raw,
    required this.createdAt,
  });
}
