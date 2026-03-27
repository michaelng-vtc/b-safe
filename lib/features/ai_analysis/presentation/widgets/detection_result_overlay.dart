import 'package:bsafe_app/features/ai_analysis/domain/entities/detection_result_entity.dart';
import 'package:flutter/material.dart';

class DetectionResultOverlay extends StatelessWidget {
  final DetectionResultEntity? vlmResult;
  final DetectionResultEntity? yoloResult;

  const DetectionResultOverlay({
    super.key,
    this.vlmResult,
    this.yoloResult,
  });

  @override
  Widget build(BuildContext context) {
    if (vlmResult == null && yoloResult == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (vlmResult != null) _buildCard('VLM', vlmResult!, Colors.orange),
          if (vlmResult != null && yoloResult != null)
            const SizedBox(height: 10),
          if (yoloResult != null)
            _buildCard('YOLO', yoloResult!, Colors.deepPurple),
        ],
      ),
    );
  }

  Widget _buildCard(String title, DetectionResultEntity result, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$title Result',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                'Risk ${result.riskScore}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(result.analysis, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
