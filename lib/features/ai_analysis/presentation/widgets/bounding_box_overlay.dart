import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:smartsurvey/shared/services/yolo_service.dart';

/// Displays an image from raw bytes with YOLO bounding boxes drawn on top.
///
/// Uses [BoxFit.contain] so the full image is always visible. The bounding-box
/// painter accounts for the letterbox / pillarbox offset so boxes line up with
/// the actual image content rather than the widget bounds.
class BoundingBoxOverlay extends StatefulWidget {
  final Uint8List imageBytes;
  final List<YoloDetection> detections;

  const BoundingBoxOverlay({
    super.key,
    required this.imageBytes,
    required this.detections,
  });

  @override
  State<BoundingBoxOverlay> createState() => _BoundingBoxOverlayState();
}

class _BoundingBoxOverlayState extends State<BoundingBoxOverlay> {
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _resolveImageSize(widget.imageBytes);
  }

  @override
  void didUpdateWidget(BoundingBoxOverlay old) {
    super.didUpdateWidget(old);
    if (old.imageBytes != widget.imageBytes) {
      _resolveImageSize(widget.imageBytes);
    }
  }

  Future<void> _resolveImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    if (mounted) {
      setState(() {
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      });
    }
    image.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Before image size is decoded, show the image unsized (fills width).
    if (_imageSize == null) {
      return Image.memory(widget.imageBytes, width: double.infinity);
    }

    // AspectRatio makes the container match the image exactly, so there is
    // no letterbox or pillarbox. BoxFit.fill then fills the container with
    // no empty space, and the painter maps normalized coords 1-to-1 to
    // widget size without any offset.
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: _imageSize!.width / _imageSize!.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              widget.imageBytes,
              fit: BoxFit.fill,
            ),
            CustomPaint(
              painter: _BoundingBoxPainter(
                detections: widget.detections,
                imageSize: _imageSize!,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoundingBoxPainter extends CustomPainter {
  final List<YoloDetection> detections;
  final Size imageSize;

  static const List<Color> _palette = [
    Color(0xFFE53935), // red
    Color(0xFF43A047), // green
    Color(0xFF1E88E5), // blue
    Color(0xFFFB8C00), // orange
    Color(0xFF8E24AA), // purple
    Color(0xFF00ACC1), // cyan
    Color(0xFFFFB300), // amber
    Color(0xFF6D4C41), // brown
  ];

  _BoundingBoxPainter({
    required this.detections,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // The widget is sized via AspectRatio to match the image exactly.
    // Normalized box coords map directly: normalized * size = pixel coords.
    for (int i = 0; i < detections.length; i++) {
      final det = detections[i];
      final color = _palette[i % _palette.length];

      final left = (det.x - det.width / 2) * size.width;
      final top = (det.y - det.height / 2) * size.height;
      final boxW = det.width * size.width;
      final boxH = det.height * size.height;

      final rect = Rect.fromLTWH(left, top, boxW, boxH);

      // Draw box border.
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      // Draw label background.
      final label =
          '${det.className} ${(det.confidence * 100).toStringAsFixed(0)}%';
      const textStyle = TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      );
      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - tp.height - 2,
        tp.width + 6,
        tp.height + 2,
      );
      canvas.drawRect(
        labelRect,
        Paint()..color = color.withValues(alpha: 0.85),
      );

      tp.paint(canvas, Offset(rect.left + 3, labelRect.top + 1));
    }
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter old) =>
      old.detections != detections || old.imageSize != imageSize;
}
