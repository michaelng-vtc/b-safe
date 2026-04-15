import 'dart:convert';
import 'dart:io';

import 'package:smartsurvey/features/ai_analysis/domain/entities/detection_result_entity.dart';
import 'package:smartsurvey/features/ai_analysis/presentation/providers/ai_provider.dart';
import 'package:smartsurvey/features/ai_analysis/presentation/widgets/ai_settings_sheet.dart';
import 'package:smartsurvey/features/ai_analysis/presentation/widgets/detection_result_overlay.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class AiAnalysisScreenResult {
  final String? imageBase64;
  final String? imagePath;
  final DetectionResultEntity? vlmResult;
  final DetectionResultEntity? yoloResult;

  const AiAnalysisScreenResult({
    this.imageBase64,
    this.imagePath,
    this.vlmResult,
    this.yoloResult,
  });

  DetectionResultEntity? get selectedResult => vlmResult ?? yoloResult;
}

class AiAnalysisScreen extends StatefulWidget {
  final String? imageBase64;
  final String? imagePath;
  final String? additionalContext;

  const AiAnalysisScreen({
    super.key,
    this.imageBase64,
    this.imagePath,
    this.additionalContext,
  });

  @override
  State<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends State<AiAnalysisScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  String? _imageBase64;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _imageBase64 = widget.imageBase64;
    _imagePath = widget.imagePath;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      XFile? image;
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          dialogTitle: 'Select Photo',
        );
        if (result != null && result.files.single.path != null) {
          image = XFile(result.files.single.path!);
        }
      } else {
        image = await _imagePicker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
      }

      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) return;

      setState(() {
        _imageBase64 = base64Encode(bytes);
        _imagePath = image!.path;
      });
    } catch (_) {
      // Ignore on unsupported platforms/devices.
    }
  }

  Future<void> _takePhoto() async {
    await _pickImage(ImageSource.camera);
  }

  Future<void> _showImageSourceOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pick Image'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _returnResult(AiProvider ai) {
    Navigator.pop(
      context,
      AiAnalysisScreenResult(
        imageBase64: _imageBase64,
        imagePath: _imagePath,
        vlmResult: ai.lastVlmResult,
        yoloResult: ai.lastYoloResult,
      ),
    );
  }

  Future<void> _runVlm(AiProvider ai) async {
    if (_imageBase64 == null) return;
    final contextText = widget.additionalContext?.trim();
    await ai.runVlmAnalysis(
      imageBase64: _imageBase64!,
      additionalContext:
          contextText == null || contextText.isEmpty ? null : contextText,
    );
  }

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
                  icon: const Icon(Icons.check),
                  tooltip: 'Apply to pin',
                  onPressed: () => _returnResult(ai),
                );
              },
            ),
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
                if (_imageBase64 != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showImageSourceOptions,
                      borderRadius: BorderRadius.circular(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Image.memory(
                              base64Decode(_imageBase64!),
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Tap to change',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showImageSourceOptions,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              'Select or Take Photo',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: ai.isAnalyzingVlm || _imageBase64 == null
                            ? null
                            : () => _runVlm(ai),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Run VLM'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: ai.isDetectingYolo || _imageBase64 == null
                            ? null
                            : () => ai.runYoloDetection(
                                  Uint8List.fromList(
                                      base64Decode(_imageBase64!)),
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
      ),
    );
  }
}
