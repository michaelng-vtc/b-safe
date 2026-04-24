import 'dart:convert';
import 'dart:io';

import 'package:smartsurvey/features/ai_analysis/domain/entities/detection_result_entity.dart';
import 'package:smartsurvey/features/ai_analysis/presentation/providers/ai_provider.dart';
import 'package:smartsurvey/features/ai_analysis/presentation/widgets/ai_settings_sheet.dart';
import 'package:smartsurvey/features/ai_analysis/presentation/widgets/bounding_box_overlay.dart';
import 'package:smartsurvey/features/ai_analysis/presentation/widgets/detection_result_overlay.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:smartsurvey/shared/services/yolo_service.dart';

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
  static const TextStyle _entrySubtitleStyle = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: Colors.black87,
    height: 1.2,
  );

  static const TextStyle _entryHelpTextStyle = TextStyle(
    fontSize: 13,
    color: Colors.black54,
    height: 1.3,
  );

  static const TextStyle _entryFieldTextStyle = TextStyle(
    fontSize: 14,
    color: Colors.black87,
  );

  final AiProvider _aiProvider = AiProvider();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _defectSizeController = TextEditingController();
  final TextEditingController _buildingDefectController =
      TextEditingController();
  final TextEditingController _buildingElementOtherController =
      TextEditingController();
  final TextEditingController _defectLocationOtherController =
      TextEditingController();
  final TextEditingController _roomUseOtherController = TextEditingController();
  String? _imageBase64;
  String? _imagePath;
  String? _buildingElement;
  List<String> _buildingDefects = [];
  String? _defectLocation;
  String? _roomUse;
  bool? _waterRiskOtherSide;

  static const List<String> _buildingElements = [
    'Ceiling Slab',
    'Floor slab',
    'Wall',
    'Column',
    'Beam',
    'Window',
    'Timber Door',
    'Metal Door',
    'Gate',
    'Drainage Pipe works',
    'Plumbing Pipe works',
    'Staircase Flight',
    'Water tank',
    'Canopy',
    'Sanitary Fitment',
    'Duct works',
    'Supporting Frame for Plants',
    'Others',
  ];

  static const List<String> _defectLocations = [
    'Interior Ceiling',
    'Interior Wall',
    'Interior Floor',
    'Exterior Wall',
    'Roof',
    'Paving',
    'Semi opened area',
    'Door',
    'Window',
    'Others',
  ];

  static const List<String> _roomUses = [
    'Habitation',
    'Washroom',
    'Kitchen',
    'Office',
    'Balcony',
    'Utilities',
    'Plant room',
    'water meter room',
    'pump room',
    'Shop',
    'Factory',
    'Basement',
    'Restaurant',
    'Sport Stadia',
    'Others',
  ];

  InputDecoration _entryFieldDecoration({
    String? hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: _entryHelpTextStyle,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
          width: 1.4,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _imageBase64 = widget.imageBase64;
    _imagePath = widget.imagePath;
  }

  @override
  void dispose() {
    _defectSizeController.dispose();
    _buildingDefectController.dispose();
    _buildingElementOtherController.dispose();
    _defectLocationOtherController.dispose();
    _roomUseOtherController.dispose();
    _aiProvider.dispose();
    super.dispose();
  }

  String? _resolvedBuildingElement() {
    if (_buildingElement == 'Others') {
      final custom = _buildingElementOtherController.text.trim();
      return custom.isEmpty ? 'Others' : custom;
    }
    return _buildingElement;
  }

  String? _resolvedDefectLocation() {
    if (_defectLocation == 'Others') {
      final custom = _defectLocationOtherController.text.trim();
      return custom.isEmpty ? 'Others' : custom;
    }
    return _defectLocation;
  }

  String? _resolvedRoomUse() {
    if (_roomUse == 'Others') {
      final custom = _roomUseOtherController.text.trim();
      return custom.isEmpty ? 'Others' : custom;
    }
    return _roomUse;
  }

  List<String> _extractDistinctDefectClasses(List<YoloDetection> detections) {
    final seen = <String>{};
    final unique = <String>[];

    for (final det in detections) {
      final name = det.className.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (seen.add(key)) {
        unique.add(name);
      }
    }
    return unique;
  }

  Future<void> _runYoloAndSyncDefects(Uint8List imageBytes) async {
    await _aiProvider.runYoloDetection(imageBytes);
    if (!mounted) return;

    setState(() {
      _buildingDefects =
          _extractDistinctDefectClasses(_aiProvider.lastYoloDetections ?? []);
    });
  }

  void _addBuildingDefect(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return;

    final exists = _buildingDefects
        .any((item) => item.toLowerCase() == normalized.toLowerCase());
    if (exists) {
      _buildingDefectController.clear();
      return;
    }

    setState(() {
      _buildingDefects = [..._buildingDefects, normalized];
      _buildingDefectController.clear();
    });
  }

  void _removeBuildingDefect(String value) {
    setState(() {
      _buildingDefects =
          _buildingDefects.where((item) => item != value).toList();
    });
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

      // Auto-run YOLO whenever an image is set and use distinct classes as
      // editable building-defect entries.
      if (mounted) {
        await _runYoloAndSyncDefects(Uint8List.fromList(bytes));
      }
    } catch (e, st) {
      debugPrint('[AiAnalysisScreen] _pickImage error: $e\n$st');
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
    final contextText = [
      widget.additionalContext?.trim(),
      _buildEntryFormContext(),
    ].whereType<String>().where((part) => part.isNotEmpty).join('\n');

    await ai.runVlmAnalysis(
      imageBase64: _imageBase64!,
      additionalContext: contextText.isEmpty ? null : contextText,
    );
  }

  String _buildEntryFormContext() {
    final defectSize = _defectSizeController.text.trim();
    final roomUse = _resolvedRoomUse()?.trim() ?? '';
    final buildingElement = _resolvedBuildingElement()?.trim() ?? '';
    final defectLocation = _resolvedDefectLocation()?.trim() ?? '';
    final buildingDefects = _buildingDefects.isEmpty
        ? 'Not specified'
        : _buildingDefects.join(', ');
    final waterRisk = _waterRiskOtherSide == null
        ? 'Not specified'
        : (_waterRiskOtherSide! ? 'Yes' : 'No');

    return [
      'Entry form details:',
      'Building element: ${buildingElement.isEmpty ? 'Not specified' : buildingElement}',
      'Building defects (editable YOLO classes): $buildingDefects',
      'Defect size: ${defectSize.isEmpty ? 'Not specified' : defectSize}',
      'Defect location: ${defectLocation.isEmpty ? 'Not specified' : defectLocation}',
      'Use of room: ${roomUse.isEmpty ? 'Not specified' : roomUse}',
      'Water risk at other side of element: $waterRisk',
    ].join('\n');
  }

  // ── Photo card (after image selected) ────────────────────────────────────
  Widget _buildPhotoCard(String imageBase64) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showImageSourceOptions,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // No fixed height — image fills full width and auto-sizes
              // height from its aspect ratio, so no black bars appear.
              Image.memory(
                base64Decode(imageBase64),
                width: double.infinity,
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
  }

  // ── Photo placeholder (no image yet) ─────────────────────────────────────
  Widget _buildPhotoPlaceholder(double photoHeight) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showImageSourceOptions,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: photoHeight,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'Select or Take Photo',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── YOLO result section ───────────────────────────────────────────────────
  List<Widget> _buildYoloSection(AiProvider ai, double photoHeight) {
    if (ai.isDetectingYolo) {
      return [
        const SizedBox(height: 4),
        const LinearProgressIndicator(),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Running YOLO detection…',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 8),
      ];
    }

    if (ai.yoloServerOffline) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'YOLO server offline',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: _imageBase64 == null
                    ? null
                    : () => _runYoloAndSyncDefects(
                          Uint8List.fromList(base64Decode(_imageBase64!)),
                        ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ];
    }

    if (ai.lastYoloResult != null) {
      final detections = ai.lastYoloDetections ?? [];
      return [
        // YOLO result: BoundingBoxOverlay self-sizes via AspectRatio.
        BoundingBoxOverlay(
          imageBytes: Uint8List.fromList(base64Decode(_imageBase64!)),
          detections: detections,
        ),
        const SizedBox(height: 6),
        DetectionResultOverlay(
          vlmResult: null,
          yoloResult: ai.lastYoloResult,
        ),
        const SizedBox(height: 8),
      ];
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _aiProvider,
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
            // Use 40 % of screen height for both the photo area and the YOLO
            // result area so neither is cramped on any screen size.
            final photoHeight = MediaQuery.of(context).size.height * 0.40;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Original photo ──────────────────────────────────────
                if (_imageBase64 != null)
                  _buildPhotoCard(_imageBase64!)
                else
                  _buildPhotoPlaceholder(photoHeight),
                const SizedBox(height: 12),

                // ── YOLO Detect Result label ──────────────────────────────
                if (_imageBase64 != null &&
                    context.read<AiProvider>().lastYoloResult != null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'YOLO Detect Result',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),

                // ── YOLO result section ─────────────────────────────────
                if (_imageBase64 != null) ..._buildYoloSection(ai, photoHeight),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Additional Information Entry Form',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Building Element',
                          style: _entrySubtitleStyle,
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _buildingElement,
                          style: _entryFieldTextStyle,
                          decoration: _entryFieldDecoration(
                            hintText: 'Select building element',
                          ),
                          items: _buildingElements
                              .map(
                                (element) => DropdownMenuItem<String>(
                                  value: element,
                                  child: Text(element),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _buildingElement = value;
                              if (value != 'Others') {
                                _buildingElementOtherController.clear();
                              }

                              _defectLocation = _defectLocations.contains(value)
                                  ? value
                                  : null;
                              if (_defectLocation != 'Others') {
                                _defectLocationOtherController.clear();
                              }
                            });
                          },
                        ),
                        if (_buildingElement == 'Others') ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _buildingElementOtherController,
                            style: _entryFieldTextStyle,
                            decoration: _entryFieldDecoration(
                              hintText: 'Enter building element manually',
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        const Text(
                          'Building Defects',
                          style: _entrySubtitleStyle,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Pre-filled from YOLO detect result. Same class is treated as one item, and you can edit it.',
                          style: _entryHelpTextStyle,
                        ),
                        const SizedBox(height: 8),
                        if (_buildingDefects.isEmpty)
                          const Text(
                            'No defects detected yet. Run YOLO or add manually below.',
                            style: _entryHelpTextStyle,
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _buildingDefects
                                .map(
                                  (defect) => Chip(
                                    backgroundColor: Colors.grey.shade100,
                                    label: Text(
                                      defect,
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                    ),
                                    deleteIconColor: Colors.black54,
                                    onDeleted: () =>
                                        _removeBuildingDefect(defect),
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _buildingDefectController,
                                style: _entryFieldTextStyle,
                                decoration: _entryFieldDecoration(
                                  hintText: 'e.g. crack, spalling, dampness',
                                ),
                                onFieldSubmitted: _addBuildingDefect,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _addBuildingDefect(
                                _buildingDefectController.text,
                              ),
                              icon: const Icon(Icons.add_circle_outline),
                              tooltip: 'Add defect item',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Defect Size',
                          style: _entrySubtitleStyle,
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _defectSizeController,
                          style: _entryFieldTextStyle,
                          decoration: _entryFieldDecoration(
                            hintText: 'e.g. 20 mm x 40 mm',
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Location of Defect',
                          style: _entrySubtitleStyle,
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _defectLocation,
                          style: _entryFieldTextStyle,
                          decoration: _entryFieldDecoration(
                            hintText: 'Select location of defect',
                          ),
                          items: _defectLocations
                              .map(
                                (location) => DropdownMenuItem<String>(
                                  value: location,
                                  child: Text(location),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _defectLocation = value;
                              if (value != 'Others') {
                                _defectLocationOtherController.clear();
                              }
                            });
                          },
                        ),
                        if (_defectLocation == 'Others') ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _defectLocationOtherController,
                            style: _entryFieldTextStyle,
                            decoration: _entryFieldDecoration(
                              hintText: 'Enter defect location manually',
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        const Text(
                          'Use of Room',
                          style: _entrySubtitleStyle,
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _roomUse,
                          style: _entryFieldTextStyle,
                          decoration: _entryFieldDecoration(
                            hintText: 'Select use of room',
                          ),
                          items: _roomUses
                              .map(
                                (roomUse) => DropdownMenuItem<String>(
                                  value: roomUse,
                                  child: Text(roomUse),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _roomUse = value;
                              if (value != 'Others') {
                                _roomUseOtherController.clear();
                              }
                            });
                          },
                        ),
                        if (_roomUse == 'Others') ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _roomUseOtherController,
                            style: _entryFieldTextStyle,
                            decoration: _entryFieldDecoration(
                              hintText: 'Enter room use manually',
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text(
                          'Water Risk',
                          style: _entrySubtitleStyle,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Water risk at the other side of the building element?',
                          style: _entryHelpTextStyle,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text(
                                'Yes',
                                style: TextStyle(color: Colors.black),
                              ),
                              selected: _waterRiskOtherSide == true,
                              backgroundColor: Colors.grey.shade100,
                              selectedColor: Colors.green.shade100,
                              onSelected: (_) {
                                setState(() {
                                  _waterRiskOtherSide = true;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text(
                                'No',
                                style: TextStyle(color: Colors.black),
                              ),
                              selected: _waterRiskOtherSide == false,
                              backgroundColor: Colors.grey.shade100,
                              selectedColor: Colors.red.shade100,
                              onSelected: (_) {
                                setState(() {
                                  _waterRiskOtherSide = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: ai.isAnalyzingVlm || _imageBase64 == null
                      ? null
                      : () => _runVlm(ai),
                  label: const Text('AI Diagnosis'),
                ),
                if (ai.errorMessage != null && !ai.yoloServerOffline) ...[
                  const SizedBox(height: 10),
                  Text(
                    ai.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                DetectionResultOverlay(
                  vlmResult: ai.lastVlmResult,
                  yoloResult: null,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
