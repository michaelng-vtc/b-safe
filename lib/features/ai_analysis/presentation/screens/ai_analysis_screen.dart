import 'dart:convert';
import 'dart:typed_data';

import 'package:bsafe_app/features/ai_analysis/presentation/providers/ai_provider.dart';
import 'package:bsafe_app/features/ai_analysis/presentation/widgets/ai_floating_button.dart';
import 'package:bsafe_app/features/ai_analysis/presentation/widgets/ai_settings_sheet.dart';
import 'package:bsafe_app/features/ai_analysis/presentation/widgets/detection_result_overlay.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AiAnalysisScreen extends StatelessWidget {
  final String imageBase64;
  final String? additionalContext;

  const AiAnalysisScreen({
    super.key,
    required this.imageBase64,
    this.additionalContext,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AiProvider(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI Analysis'),
          actions: [
            Builder(
              builder: (context) {
                final ai = context.watch<AiProvider>();
                return IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => AiSettingsSheet(
                        confidenceThreshold: ai.yoloConfidenceThreshold,
                        onConfidenceChanged: ai.setYoloConfidenceThreshold,
                        showBoundingBoxes: ai.showBoundingBoxes,
                        onShowBoundingBoxesChanged: (_) =>
                            ai.toggleBoundingBoxes(),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
        body: Consumer<AiProvider>(
          builder: (context, ai, _) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(imageBase64),
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: ai.isAnalyzingVlm
                            ? null
                            : () => ai.runVlmAnalysis(
                                  imageBase64: imageBase64,
                                  additionalContext: additionalContext,
                                ),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Run VLM'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: ai.isDetectingYolo
                            ? null
                            : () => ai.runYoloDetection(
                                  Uint8List.fromList(base64Decode(imageBase64)),
                                ),
                        icon: const Icon(Icons.smart_toy),
                        label: const Text('Run YOLO'),
                      ),
                    ),
                  ],
                ),
                if (ai.errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    ai.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                DetectionResultOverlay(
                  vlmResult: ai.lastVlmResult,
                  yoloResult: ai.lastYoloResult,
                ),
              ],
            );
          },
        ),
        floatingActionButton: AiFloatingButton(
          onPressed: () => context.read<AiProvider>().runVlmAnalysis(
                imageBase64: imageBase64,
                additionalContext: additionalContext,
              ),
        ),
      ),
    );
  }
}
