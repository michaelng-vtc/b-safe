import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:smartsurvey/features/ai_analysis/presentation/widgets/yolo_color_utils.dart';
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
      final color = yoloColor(i);

      final left = (det.x - det.width / 2) * size.width;
      final top = (det.y - det.height / 2) * size.height;
      final boxW = det.width * size.width;
      final boxH = det.height * size.height;

      final rect = Rect.fromLTWH(left, top, boxW, boxH);

      // Draw instance segmentation mask if available (mask is a 2D probability
      // array cropped to the bbox). We render each mask pixel as a small
      // rectangle inside the bbox with alpha proportional to probability.
      final hasMask = det.mask != null;
      if (hasMask) {
        final mask = det.mask!;
        final mH = mask.length;
        final mW = mask.isNotEmpty ? mask[0].length : 0;
        if (mH > 0 && mW > 0) {
          final cellW = boxW / mW;
          final cellH = boxH / mH;
          for (int ry = 0; ry < mH; ry++) {
            for (int rx = 0; rx < mW; rx++) {
              final p = mask[ry][rx];
              if (p <= 0.01) continue; // skip near-zero
              final px = rect.left + rx * cellW;
              final py = rect.top + ry * cellH;
              final paint = Paint()
                ..color = color.withValues(alpha: (p * 0.6).clamp(0.0, 0.6))
                ..style = PaintingStyle.fill;
              canvas.drawRect(
                  Rect.fromLTWH(px, py, cellW + 0.5, cellH + 0.5), paint);
            }
          }
        }
      }

      // Draw box border only when no mask is present. Always draw a small
      // class-name label so users can identify the detected class even when
      // the segmentation overlay is shown.
      if (!hasMask) {
        canvas.drawRect(
          rect,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }

      // Draw class label (name only) on top-left of the bbox. Keep it compact
      // so it doesn't obscure the mask too much.
      final label = det.className;
      if (label.isNotEmpty) {
        const textStyle = TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        );
        final tp = TextPainter(
          text: TextSpan(text: label, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();

        // Place label inside the image bounds; prefer top-left of bbox.
        final labelLeft = rect.left.clamp(0.0, size.width - tp.width - 6);
        final labelTop =
            (rect.top - tp.height - 4).clamp(0.0, size.height - tp.height - 2);

        final labelRect = Rect.fromLTWH(
          labelLeft,
          labelTop,
          tp.width + 6,
          tp.height + 4,
        );
        canvas.drawRect(
            labelRect, Paint()..color = color.withValues(alpha: 0.85));
        tp.paint(canvas, Offset(labelRect.left + 3, labelRect.top + 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter old) =>
      old.detections != detections || old.imageSize != imageSize;
}
