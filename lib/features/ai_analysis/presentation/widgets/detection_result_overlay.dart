import 'package:smartsurvey/features/ai_analysis/domain/entities/detection_result_entity.dart';
import 'package:smartsurvey/features/ai_analysis/presentation/widgets/yolo_color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
          if (vlmResult != null)
            _buildCard(
              context,
              'VLM',
              vlmResult!,
              Colors.orange,
              showCopyAction: true,
            ),
          if (vlmResult != null && yoloResult != null)
            const SizedBox(height: 10),
          if (yoloResult != null)
            _buildCard(
              context,
              'YOLO',
              yoloResult!,
              Colors.deepPurple,
              showCopyAction: false,
            ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    String title,
    DetectionResultEntity result,
    Color color, {
    required bool showCopyAction,
  }) {
    final observation =
        (result.raw['observation'] ?? result.analysis).toString();
    final hkConstructionContext =
        (result.raw['hk_construction_context'] ?? '').toString();
    final causeReview = (result.raw['cause_review'] ?? '').toString();
    final recommendations = (result.raw['recommendations'] ?? '').toString();
    final yoloDetections =
        (result.raw['detections'] as List<dynamic>?) ?? const [];

    final sections = <Widget>[
      if (observation.isNotEmpty) _buildSection('Observation', observation),
      if (hkConstructionContext.isNotEmpty || causeReview.isNotEmpty)
        _buildSection(
          'Cause',
          [
            if (hkConstructionContext.isNotEmpty)
              'Hong Kong construction context: $hkConstructionContext',
            if (causeReview.isNotEmpty) 'Defect cause review: $causeReview',
          ].join('\n\n'),
        ),
      if (recommendations.isNotEmpty)
        _buildSection('4. Recommendation', recommendations),
    ];

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
              if (showCopyAction)
                IconButton(
                  tooltip: 'Copy VLM result',
                  icon: Icon(Icons.copy, color: color, size: 18),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: _buildCopyText(result)),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('VLM result copied')),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (title == 'YOLO' && yoloDetections.isNotEmpty)
            _buildYoloDetections(yoloDetections)
          else if (sections.isNotEmpty)
            ...sections
          else
            Text(result.analysis, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  String _buildCopyText(DetectionResultEntity result) {
    final observation =
        (result.raw['observation'] ?? result.analysis).toString();
    final hkConstructionContext =
        (result.raw['hk_construction_context'] ?? '').toString();
    final causeReview = (result.raw['cause_review'] ?? '').toString();
    final recommendations = (result.raw['recommendations'] ?? '').toString();

    return [
      if (observation.isNotEmpty) 'Observation: $observation',
      if (hkConstructionContext.isNotEmpty || causeReview.isNotEmpty)
        'Cause: ${[
          if (hkConstructionContext.isNotEmpty)
            'Hong Kong construction context: $hkConstructionContext',
          if (causeReview.isNotEmpty) 'Defect cause review: $causeReview',
        ].join(' | ')}',
      if (recommendations.isNotEmpty) 'Recommendation: $recommendations',
    ].join('\n\n');
  }

  Widget _buildYoloDetections(List<dynamic> detections) {
    final chips = detections
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final item = entry.value;
          if (item is! Map) return null;
          final className =
              (item['class'] ?? item['className'] ?? '').toString();
          final confidence = item['confidence'];
          final percent = confidence is num
              ? '${(confidence * 100).toStringAsFixed(0)}%'
              : '';
          if (className.isEmpty) return null;
          final color = yoloColor(index);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.55)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.10),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '$className ${percent.isNotEmpty ? '- $percent' : ''}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        })
        .whereType<Widget>()
        .toList(growable: false);

    if (chips.isEmpty) {
      return Text(
        'No detections',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips,
    );
  }

  Widget _buildSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(body, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
