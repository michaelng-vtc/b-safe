import 'package:flutter/material.dart';

/// Generates a unique, deterministic color for each YOLO detection index.
///
/// Uses the golden-angle hue distribution (≈137.5°) so consecutive indices
/// always produce visually distinct, well-separated hues.  The saturation and
/// lightness are fixed so every color is vivid and readable on both light and
/// dark backgrounds.
Color yoloColor(int index) {
  // Golden angle in degrees.
  const double goldenAngle = 137.508;
  final double hue = (index * goldenAngle) % 360.0;
  return HSLColor.fromAHSL(1.0, hue, 0.72, 0.48).toColor();
}
