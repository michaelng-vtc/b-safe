import 'package:flutter/material.dart';

class AiSettingsSheet extends StatelessWidget {
  final double confidenceThreshold;
  final ValueChanged<double> onConfidenceChanged;
  final bool showBoundingBoxes;
  final ValueChanged<bool> onShowBoundingBoxesChanged;

  const AiSettingsSheet({
    super.key,
    required this.confidenceThreshold,
    required this.onConfidenceChanged,
    required this.showBoundingBoxes,
    required this.onShowBoundingBoxesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Settings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              'YOLO Confidence: ${confidenceThreshold.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Slider(
              value: confidenceThreshold,
              min: 0.1,
              max: 0.9,
              divisions: 16,
              onChanged: onConfidenceChanged,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show YOLO Bounding Boxes'),
              value: showBoundingBoxes,
              onChanged: onShowBoundingBoxesChanged,
            ),
          ],
        ),
      ),
    );
  }
}
