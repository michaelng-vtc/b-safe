import 'dart:convert';
import 'dart:io';

import 'package:bsafe_app/features/ai_analysis/domain/entities/detection_result_entity.dart';
import 'package:bsafe_app/features/ai_analysis/presentation/providers/ai_provider.dart';
import 'package:bsafe_app/features/ai_analysis/presentation/widgets/ai_settings_sheet.dart';
import 'package:bsafe_app/features/ai_analysis/presentation/widgets/detection_result_overlay.dart';
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

  final _buildingElementController = TextEditingController();
  final _defectTypeController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _suspectedCauseController = TextEditingController();
  final _recommendationController = TextEditingController();
  final _defectSizeController = TextEditingController();

  String? _extentOfDefect;
  final _currentUseController = TextEditingController();
  final _designedUseController = TextEditingController();
  bool? _onlyTypicalFloor;
  final _useOfAboveController = TextEditingController();
  bool? _adjacentWetArea;
  bool? _adjacentExternalWall;
  bool? _concealedPipeworks;
  final _repetitivePatternController = TextEditingController();
  bool? _heavyLoadingAbove;
  final _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _imageBase64 = widget.imageBase64;
    _imagePath = widget.imagePath;
  }

  @override
  void dispose() {
    _buildingElementController.dispose();
    _defectTypeController.dispose();
    _diagnosisController.dispose();
    _suspectedCauseController.dispose();
    _recommendationController.dispose();
    _defectSizeController.dispose();
    _currentUseController.dispose();
    _designedUseController.dispose();
    _useOfAboveController.dispose();
    _repetitivePatternController.dispose();
    _remarksController.dispose();
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

  String? _readAiStringValue(
      Map<String, dynamic> result, List<String> candidateKeys) {
    for (final key in candidateKeys) {
      final value = result[key];
      if (value == null) continue;
      if (value is String) {
        final text = value.trim();
        if (text.isNotEmpty) return text;
        continue;
      }
      if (value is num || value is bool) {
        return value.toString();
      }
    }
    return null;
  }

  void _applyAiResultToInspectorFields(Map<String, dynamic> result) {
    final buildingElement = _readAiStringValue(result, const [
      'building_element',
      'buildingElement',
      'Building Element',
    ]);
    final defectType = _readAiStringValue(result, const [
      'defect_type',
      'defectType',
      'Defect Type',
    ]);
    final diagnosis =
        _readAiStringValue(result, const ['diagnosis', 'Diagnosis']);
    final suspectedCause = _readAiStringValue(result, const [
      'suspected_cause',
      'suspectedCause',
      'Suspected Cause',
    ]);
    String? recommendation =
        _readAiStringValue(result, const ['recommendation', 'Recommendation']);
    final defectSize = _readAiStringValue(result, const [
      'defect_size',
      'defectSize',
      'Defect Size',
    ]);

    if (recommendation == null) {
      final recommendations = result['recommendations'];
      if (recommendations is List && recommendations.isNotEmpty) {
        final firstRecommendation = recommendations.first;
        if (firstRecommendation is String &&
            firstRecommendation.trim().isNotEmpty) {
          recommendation = firstRecommendation.trim();
        }
      }
    }

    if (buildingElement != null) {
      _buildingElementController.text = buildingElement;
    }
    if (defectType != null) {
      _defectTypeController.text = defectType;
    }
    if (diagnosis != null) {
      _diagnosisController.text = diagnosis;
    }
    if (suspectedCause != null) {
      _suspectedCauseController.text = suspectedCause;
    }
    if (recommendation != null) {
      _recommendationController.text = recommendation;
    }
    if (defectSize != null) {
      _defectSizeController.text = defectSize;
    }
  }

  Future<void> _runVlm(AiProvider ai) async {
    if (_imageBase64 == null) return;
    final contextText = _buildVlmAdditionalContext();
    await ai.runVlmAnalysis(
      imageBase64: _imageBase64!,
      additionalContext: contextText.isEmpty ? null : contextText,
    );
    final result = ai.lastVlmResult?.raw;
    if (result != null && mounted) {
      setState(() {
        _applyAiResultToInspectorFields(result);
      });
    }
  }

  String _buildVlmAdditionalContext() {
    final contextBuf = StringBuffer();

    if (_buildingElementController.text.trim().isNotEmpty) {
      contextBuf.writeln(
          'Building Element: ${_buildingElementController.text.trim()}');
    }
    if (_defectTypeController.text.trim().isNotEmpty) {
      contextBuf.writeln('Defect Type: ${_defectTypeController.text.trim()}');
    }
    if (_diagnosisController.text.trim().isNotEmpty) {
      contextBuf.writeln('Diagnosis: ${_diagnosisController.text.trim()}');
    }
    if (_suspectedCauseController.text.trim().isNotEmpty) {
      contextBuf
          .writeln('Suspected Cause: ${_suspectedCauseController.text.trim()}');
    }
    if (_recommendationController.text.trim().isNotEmpty) {
      contextBuf
          .writeln('Recommendation: ${_recommendationController.text.trim()}');
    }
    if (_defectSizeController.text.trim().isNotEmpty) {
      contextBuf.writeln('Defect Size: ${_defectSizeController.text.trim()}');
    }
    if (_extentOfDefect != null) {
      contextBuf.writeln(
          'Extent of Defect: ${_extentOfDefect == 'locally' ? 'Locally noted' : 'Generally noted'}');
    }
    if (_currentUseController.text.trim().isNotEmpty) {
      contextBuf
          .writeln('Room Current Use: ${_currentUseController.text.trim()}');
    }
    if (_designedUseController.text.trim().isNotEmpty) {
      contextBuf
          .writeln('Room Designed Use: ${_designedUseController.text.trim()}');
    }
    if (_onlyTypicalFloor != null) {
      contextBuf
          .writeln('Only Typical Floor: ${_onlyTypicalFloor! ? 'Yes' : 'No'}');
    }
    if (_useOfAboveController.text.trim().isNotEmpty) {
      contextBuf.writeln('Use of Above: ${_useOfAboveController.text.trim()}');
    }
    if (_adjacentWetArea != null) {
      contextBuf.writeln(
          'Adjacent Space is Wet Area: ${_adjacentWetArea! ? 'Yes' : 'No'}');
    }
    if (_adjacentExternalWall != null) {
      contextBuf.writeln(
          'Adjacent to External Wall: ${_adjacentExternalWall! ? 'Yes' : 'No'}');
    }
    if (_concealedPipeworks != null) {
      contextBuf.writeln(
          'Concealed Pipeworks: ${_concealedPipeworks! ? 'Yes' : 'No'}');
    }
    if (_repetitivePatternController.text.trim().isNotEmpty) {
      contextBuf.writeln(
          'Repetitive Pattern: ${_repetitivePatternController.text.trim()}');
    }
    if (_heavyLoadingAbove != null) {
      contextBuf.writeln(
          'Heavy Loading on Floor Above: ${_heavyLoadingAbove! ? 'Yes' : 'No'}');
    }
    if (_remarksController.text.trim().isNotEmpty) {
      contextBuf.writeln('Remarks: ${_remarksController.text.trim()}');
    }

    if (widget.additionalContext != null &&
        widget.additionalContext!.trim().isNotEmpty) {
      if (contextBuf.isNotEmpty) {
        contextBuf.writeln();
      }
      contextBuf.writeln(widget.additionalContext!.trim());
    }

    return contextBuf.toString().trim();
  }

  Widget _buildChoiceChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border:
              Border.all(color: selected ? Colors.blue : Colors.grey.shade400),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 11, color: selected ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildYesNoRow(
      String label, bool? value, ValueChanged<bool> onChanged) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          flex: 5,
          child: Row(
            children: [
              _buildChoiceChip('Yes', value == true, () => onChanged(true)),
              const SizedBox(width: 6),
              _buildChoiceChip('No', value == false, () => onChanged(false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextInputRow(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 4,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          flex: 6,
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 12),
            maxLines: maxLines,
          ),
        ),
      ],
    );
  }

  Widget _buildInspectorInputField(
      String label, TextEditingController controller, String hint) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildStructuredInputFields() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: Colors.orange.shade700),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Additional Information',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInspectorInputField('Building Element',
              _buildingElementController, 'e.g. Column, Beam, Slab, Wall'),
          const SizedBox(height: 6),
          _buildInspectorInputField('Defect Type', _defectTypeController,
              'e.g. Crack, Spalling, Corrosion'),
          const SizedBox(height: 6),
          _buildInspectorInputField('Diagnosis', _diagnosisController,
              'e.g. Structural damage observed'),
          const SizedBox(height: 6),
          _buildInspectorInputField('Suspected Cause',
              _suspectedCauseController, 'e.g. Water ingress, Overloading'),
          const SizedBox(height: 6),
          _buildInspectorInputField('Recommendation', _recommendationController,
              'e.g. Immediate repair required'),
          const SizedBox(height: 6),
          _buildInspectorInputField('Defect Size', _defectSizeController,
              'e.g. 30cm x 10cm, Width 2mm'),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                flex: 4,
                child: Text('0. Extent of Defect:',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ),
              Expanded(
                flex: 6,
                child: Wrap(
                  spacing: 6,
                  children: [
                    _buildChoiceChip(
                        'Locally noted',
                        _extentOfDefect == 'locally',
                        () => setState(() => _extentOfDefect = 'locally')),
                    _buildChoiceChip(
                        'Generally noted',
                        _extentOfDefect == 'generally',
                        () => setState(() => _extentOfDefect = 'generally')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('1. Room Information:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          _buildTextInputRow('1.1 Current use:', _currentUseController),
          const SizedBox(height: 4),
          _buildTextInputRow('1.2 Designed use:', _designedUseController),
          const SizedBox(height: 4),
          _buildYesNoRow('1.3 Only typical floor:', _onlyTypicalFloor,
              (v) => setState(() => _onlyTypicalFloor = v)),
          const SizedBox(height: 4),
          _buildTextInputRow('1.4 Use of above:', _useOfAboveController),
          const SizedBox(height: 6),
          _buildYesNoRow('2. Adjacent space is wet area:', _adjacentWetArea,
              (v) => setState(() => _adjacentWetArea = v)),
          const SizedBox(height: 4),
          _buildYesNoRow('3. Adjacent to External wall:', _adjacentExternalWall,
              (v) => setState(() => _adjacentExternalWall = v)),
          const SizedBox(height: 4),
          _buildYesNoRow('4. Any concealed pipeworks:', _concealedPipeworks,
              (v) => setState(() => _concealedPipeworks = v)),
          const SizedBox(height: 4),
          _buildTextInputRow(
              '5. Any repetitive pattern:', _repetitivePatternController),
          const SizedBox(height: 4),
          _buildYesNoRow('6. Heavy loading on floor above:', _heavyLoadingAbove,
              (v) => setState(() => _heavyLoadingAbove = v)),
          const SizedBox(height: 6),
          _buildTextInputRow('Remarks:', _remarksController, maxLines: 2),
        ],
      ),
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
                const SizedBox(height: 12),
                _buildStructuredInputFields(),
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
