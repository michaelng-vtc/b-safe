import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bsafe_app/features/defect_reporting/presentation/providers/report_provider.dart';
import 'package:bsafe_app/core/providers/connectivity_provider.dart';
import 'package:bsafe_app/core/providers/navigation_provider.dart';
import 'package:bsafe_app/core/theme/app_theme.dart';
import 'package:bsafe_app/shared/widgets/ai_analysis_result.dart';
import 'package:bsafe_app/infrastructure/yolo_service.dart';
import 'package:bsafe_app/l10n/generated/app_localizations.dart';

class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  XFile? _selectedImage;
  String? _imageBase64;
  Uint8List? _imageBytes;
  List<YoloDetection> _yoloDetections = [];
  Size _imageSize = Size.zero;
  bool _isAnalyzing = false;
  bool _isSubmitting = false;
  bool _isScanning = false;
  Map<String, dynamic>? _aiResult;

  String? _aiCategory;
  String? _aiSeverity;
  String? _aiTitle;
  String? _aiDescription;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (YoloService.isSupported) {
      YoloService.instance.loadModel();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _isScanning = true);
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();

        List<YoloDetection> detections = [];
        Size imgSize = Size.zero;
        if (YoloService.isSupported) {
          final yoloResult = await YoloService.instance.detect(bytes);
          detections = yoloResult.detections;
          imgSize = yoloResult.imageSize;
        }

        if (!mounted) return;
        setState(() {
          _selectedImage = image;
          _imageBase64 = base64Encode(bytes);
          _imageBytes = bytes;
          _yoloDetections = detections;
          _imageSize = imgSize;
          _aiResult = null;
          _aiCategory = null;
          _aiSeverity = null;
          _aiTitle = null;
          _aiDescription = null;
          _isScanning = false;
        });
        _analyzeWithAI();
        if (mounted) _showSuccess('✨ AI 分析完成！');
      } else {
        setState(() => _isScanning = false);
      }
    } catch (e) {
      setState(() => _isScanning = false);
      _showError('無法選取圖片: $e');
    }
  }

  void _openCamera() => _pickImage(ImageSource.camera);
  void _openGallery() => _pickImage(ImageSource.gallery);

  Future<void> _analyzeWithAI() async {
    if (_imageBase64 == null) {
      _showError(AppLocalizations.of(context)!.uploadPhoto);
      return;
    }
    setState(() => _isAnalyzing = true);
    try {
      final reportProvider = ref.read(reportNotifierProvider.notifier);
      final l10n = AppLocalizations.of(context)!;
      String? yoloContext;
      if (_yoloDetections.isNotEmpty) {
        final yoloMap = YoloService.toSafetyAnalysis(_yoloDetections);
        yoloContext = '[YOLO Local Detection]\n${yoloMap['analysis']}';
      }
      final result = await reportProvider.analyzeImage(_imageBase64!,
          yoloContext: yoloContext);
      if (!mounted) return;
      if (result != null) {
        final damageDetected = result['damage_detected'] == true;
        setState(() {
          _aiResult = result;
          _aiCategory = result['category'] ??
              (damageDetected ? 'structural' : 'inspection');
          _aiSeverity =
              result['severity'] ?? (damageDetected ? 'moderate' : 'mild');
          _aiTitle = result['title'] ??
              (damageDetected
                  ? l10n.buildingSafetyIssue
                  : l10n.aiNoObviousDefect);
          _aiDescription = result['analysis'] ??
              (damageDetected
                  ? l10n.aiAutoDetectBuildingDamage
                  : l10n.aiNoObviousDefect);
        });
        damageDetected
            ? _showSuccess(l10n.aiDefectFound)
            : _showSuccess(l10n.aiNoDefect);
      } else {
        _showError(l10n.aiInvalidResult);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('${AppLocalizations.of(context)!.aiAnalysisFailed}$e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _submitReport() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedImage == null) {
      _showError(l10n.uploadPhoto);
      return;
    }
    if (_aiResult == null) {
      _showError(l10n.waitAiAnalysis);
      return;
    }
    if (_aiResult!['damage_detected'] != true) {
      _showError(l10n.noDefectDetected);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final connectivity = ref.read(connectivityNotifierProvider);
      final reportProvider = ref.read(reportNotifierProvider.notifier);
      final navigationProvider = ref.read(navigationNotifierProvider.notifier);

      final report = await reportProvider.addReport(
        title: _aiTitle ?? l10n.buildingSafetyIssue,
        description: _aiDescription ?? l10n.aiAutoDetect,
        category: _aiCategory ?? 'structural',
        severity: _aiSeverity ?? 'moderate',
        imagePath: _selectedImage!.path,
        imageBase64: _imageBase64,
        location: l10n.positioning,
        isOnline: connectivity.isOnline,
      );

      if (report != null) {
        _resetForm();
        _showSuccess(l10n.submitSuccess);
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) navigationProvider.goToHistory();
        });
      }
    } catch (e) {
      _showError('${l10n.submitFailed}$e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    setState(() {
      _selectedImage = null;
      _imageBase64 = null;
      _imageBytes = null;
      _yoloDetections = [];
      _imageSize = Size.zero;
      _aiResult = null;
      _aiCategory = null;
      _aiSeverity = null;
      _aiTitle = null;
      _aiDescription = null;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message))
      ]),
      backgroundColor: AppTheme.riskHigh,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message))
      ]),
      backgroundColor: AppTheme.riskLow,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  Icon(Icons.add_a_photo,
                      size: 60, color: Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(height: 12),
                  Text(l10n.takeBuildingPhoto,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(l10n.aiAnalyzeCategorySeverity,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectedImage == null)
                    Stack(
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: _imageSourceTile(
                                    icon: Icons.camera_alt,
                                    color: AppTheme.primaryColor,
                                    title: l10n.takePhoto,
                                    subtitle: l10n.takePhotoDesc,
                                    onTap: _isScanning ? null : _openCamera)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _imageSourceTile(
                                    icon: Icons.photo_library,
                                    color: Colors.purple,
                                    title: l10n.gallery,
                                    subtitle: l10n.selectPhotoDesc,
                                    onTap: _openGallery)),
                          ],
                        ),
                        if (_isScanning)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(30)),
                              child: Center(
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: const BoxDecoration(
                                              color: AppTheme.primaryColor,
                                              shape: BoxShape.circle),
                                          child:
                                              const CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                              Color>(
                                                          Colors.white))),
                                      const SizedBox(height: 16),
                                      Text(l10n.aiAnalyzing,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text(l10n.identifySafetyRisks,
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14)),
                                    ]),
                              ),
                            ),
                          ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              if (_imageBytes != null)
                                SizedBox(
                                  width: double.infinity,
                                  height: 280,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Container(color: Colors.black),
                                      Image.memory(_imageBytes!,
                                          width: double.infinity,
                                          height: 280,
                                          fit: BoxFit.contain),
                                      if (_yoloDetections.isNotEmpty)
                                        Positioned.fill(
                                          child: CustomPaint(
                                            painter: _YoloBoxPainter(
                                                _yoloDetections, _imageSize),
                                          ),
                                        ),
                                      if (_yoloDetections.isNotEmpty)
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.visibility,
                                                    color: Colors.greenAccent,
                                                    size: 14),
                                                const SizedBox(width: 4),
                                                Text(
                                                    '${_yoloDetections.length} objects',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                    width: double.infinity,
                                    height: 280,
                                    color: Colors.grey[300],
                                    child: const Center(
                                        child: CircularProgressIndicator())),
                              if (_isAnalyzing)
                                Positioned.fill(
                                    child: Container(
                                        color: Colors.black54,
                                        child: const Center(
                                            child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                              CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(Colors.white)),
                                              SizedBox(height: 16),
                                              Dec(text: 'AI 分析中...')
                                            ])))),
                              Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                      decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: IconButton(
                                          icon: const Icon(Icons.close,
                                              color: Colors.white),
                                          onPressed: _isAnalyzing
                                              ? null
                                              : _resetForm))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!_isAnalyzing)
                          Row(children: [
                            Expanded(
                                child: OutlinedButton.icon(
                                    onPressed: _openCamera,
                                    icon: const Icon(Icons.camera_alt),
                                    label: Text(l10n.takePhoto),
                                    style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 16),
                                        side: const BorderSide(
                                            color: AppTheme.primaryColor),
                                        foregroundColor:
                                            AppTheme.primaryColor))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: OutlinedButton.icon(
                                    onPressed: _openGallery,
                                    icon: const Icon(Icons.photo_library),
                                    label: Text(l10n.gallery),
                                    style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 16),
                                        side: const BorderSide(
                                            color: Colors.purple),
                                        foregroundColor: Colors.purple))),
                          ]),
                      ],
                    ),
                  const SizedBox(height: 24),
                  if (_aiResult != null) ...[
                    AIAnalysisResult(result: _aiResult!),
                    const SizedBox(height: 24)
                  ],
                  if (_isAnalyzing)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200)),
                      child: Row(children: [
                        const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryColor))),
                        const SizedBox(width: 12),
                        Text(l10n.aiAnalyzing,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500))
                      ]),
                    ),
                  if (_aiResult != null && !_isAnalyzing) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitReport,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 2),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white)))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  const Icon(Icons.send, size: 20),
                                  const SizedBox(width: 8),
                                  Text(l10n.quickReport,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold))
                                ]),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.info_outline,
                                size: 20, color: AppTheme.textSecondary),
                            SizedBox(width: 8),
                            Text('Instructions',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary))
                          ]),
                          const SizedBox(height: 12),
                          _instruction(
                              'Take a clear photo of the building damage'),
                          _instruction(
                              'AI will automatically analyze the issue category and severity'),
                          _instruction(
                              'Confirm the AI analysis results and submit the report'),
                          _instruction(
                              'Location information will be automatically positioned via UWB'),
                        ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageSourceTile(
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.05)
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: color)),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ]),
      ),
    );
  }

  Widget _instruction(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('• ',
            style: TextStyle(fontSize: 16, color: AppTheme.primaryColor)),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary, height: 1.4))),
      ]),
    );
  }
}

class Dec extends StatelessWidget {
  final String text;
  const Dec({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600));
}

class _YoloBoxPainter extends CustomPainter {
  final List<YoloDetection> detections;
  final Size imageSize;
  _YoloBoxPainter(this.detections, this.imageSize);

  static const _colors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFE65100),
    Color(0xFF8E24AA),
  ];

  static Color colorFor(String cls) =>
      _colors[cls.hashCode.abs() % _colors.length];

  /// Compute the rect the image occupies inside the canvas with BoxFit.contain.
  Rect _fitRect(Size canvasSize) {
    if (imageSize.width == 0 || imageSize.height == 0) {
      return Offset.zero & canvasSize;
    }
    final imageAspect = imageSize.width / imageSize.height;
    final canvasAspect = canvasSize.width / canvasSize.height;
    final double scale = imageAspect > canvasAspect
        ? canvasSize.width / imageSize.width
        : canvasSize.height / imageSize.height;
    return Rect.fromCenter(
      center: Offset(canvasSize.width / 2, canvasSize.height / 2),
      width: imageSize.width * scale,
      height: imageSize.height * scale,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final imgR = _fitRect(size);
    // Detections have x/y/w/h normalised to [0,1].
    for (final det in detections) {
      final color = colorFor(det.className);
      final left = imgR.left + (det.x - det.width / 2) * imgR.width;
      final top = imgR.top + (det.y - det.height / 2) * imgR.height;
      final bboxW = det.width * imgR.width;
      final bboxH = det.height * imgR.height;

      if (det.mask != null && det.mask!.isNotEmpty) {
        // ── Segmentation mask overlay ──
        final maskH = det.mask!.length;
        final maskW = det.mask![0].length;
        final cellW = bboxW / maskW;
        final cellH = bboxH / maskH;
        final fillPaint = Paint()..color = color.withValues(alpha: 0.40);

        for (int my = 0; my < maskH; my++) {
          for (int mx = 0; mx < maskW; mx++) {
            if (det.mask![my][mx] > 0.5) {
              canvas.drawRect(
                Rect.fromLTWH(
                  left + mx * cellW,
                  top + my * cellH,
                  cellW + 0.5,
                  cellH + 0.5,
                ),
                fillPaint,
              );
            }
          }
        }
      } else {
        // Fallback: filled region (no border)
        final rect = Rect.fromLTWH(left, top, bboxW, bboxH);
        canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.30));
      }

      // ── Label chip ──
      final label =
          '${det.className} ${(det.confidence * 100).toStringAsFixed(0)}%';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final chipW = tp.width + 8;
      final chipH = tp.height + 4;
      final labelTop = top >= chipH ? top - chipH : top;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, labelTop, chipW, chipH),
          const Radius.circular(3),
        ),
        Paint()..color = color.withValues(alpha: 0.9),
      );
      tp.paint(canvas, Offset(left + 4, labelTop + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _YoloBoxPainter old) =>
      old.detections != detections;
}
