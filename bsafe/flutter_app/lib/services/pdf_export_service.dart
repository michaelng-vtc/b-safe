import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:bsafe_app/models/inspection_model.dart';

class PdfExportService {
  static Future<void> exportReport({
    required String outputPath,
    required String buildingName,
    required List<InspectionSession> sessions,
  }) async {
    final sorted = List<InspectionSession>.from(sessions)
      ..sort((a, b) => a.floor.compareTo(b.floor));

    final pdf = pw.Document();

    // Title page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: 80),
            pw.Center(
              child: pw.Text(
                'B-SAFE Inspection Report',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1F4E79'),
                ),
              ),
            ),
            pw.SizedBox(height: 40),
            pw.Divider(color: PdfColor.fromHex('#2E75B6'), thickness: 2),
            pw.SizedBox(height: 20),
            _infoRow('Project', buildingName),
            _infoRow('Export Date',
                DateTime.now().toString().substring(0, 16)),
            _infoRow('Total Floors', '${sorted.length}'),
            _infoRow(
                'Total Inspection Points',
                '${sorted.fold<int>(0, (sum, s) => sum + s.totalPins)}'),
          ],
        ),
      ),
    );

    // Pages per floor
    for (final session in sorted) {
      final widgets = <pw.Widget>[];

      widgets.add(pw.Header(
        level: 1,
        text: 'Floor ${session.floor}F',
        textStyle: pw.TextStyle(
          fontSize: 22,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#2E75B6'),
        ),
      ));

      widgets.add(pw.Text(
        'Inspection Points: ${session.totalPins}  |  '
        'Low Risk: ${session.lowRiskDefects}  |  '
        'Medium Risk: ${session.mediumRiskDefects}  |  '
        'High Risk: ${session.highRiskDefects}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ));
      widgets.add(pw.SizedBox(height: 12));

      int defectNum = 0;
      for (int i = 0; i < session.pins.length; i++) {
        final pin = session.pins[i];
        if (pin.defects.isEmpty) continue;

        widgets.add(pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          color: PdfColor.fromHex('#E8F0FE'),
          child: pw.Text(
            'Inspection Point #${i + 1}  (${pin.x.toStringAsFixed(2)}, ${pin.y.toStringAsFixed(2)})',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#404040'),
            ),
          ),
        ));
        widgets.add(pw.SizedBox(height: 6));

        for (int j = 0; j < pin.defects.length; j++) {
          defectNum++;
          final defect = pin.defects[j];
          final riskLabel = defect.riskLevelLabel;
          final riskColor = _riskColor(defect.riskScore);

          // Risk badge
          widgets.add(pw.Row(children: [
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: pw.BoxDecoration(
                color: riskColor,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'Defect $defectNum — $riskLabel',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          ]));
          widgets.add(pw.SizedBox(height: 4));

          // Structured fields
          final structuredFields = <String, String?>{
            'Building Element': defect.buildingElement,
            'Defect Type': defect.defectType,
            'Diagnosis': defect.diagnosis,
            'Suspected Cause': defect.suspectedCause,
            'Inspector Recommendation': defect.recommendation,
            'Defect Size': defect.defectSize,
          };
          for (final entry in structuredFields.entries) {
            if (entry.value != null && entry.value!.isNotEmpty) {
              widgets.add(pw.Padding(
                padding: const pw.EdgeInsets.only(left: 8),
                child: pw.Text('${entry.key}: ${entry.value}',
                    style: const pw.TextStyle(fontSize: 10)),
              ));
            }
          }

          // Description
          if (defect.description != null && defect.description!.isNotEmpty) {
            widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8),
              child: pw.Text('AI Analysis: ${defect.description}',
                  style: const pw.TextStyle(fontSize: 10)),
            ));
          }

          // Recommendations
          if (defect.recommendations.isNotEmpty) {
            widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8, top: 4),
              child: pw.Text('Recommendations:',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ));
            for (final rec in defect.recommendations) {
              widgets.add(pw.Padding(
                padding: const pw.EdgeInsets.only(left: 16),
                child: pw.Bullet(
                  text: rec,
                  style: const pw.TextStyle(fontSize: 10),
                  bulletSize: 4,
                ),
              ));
            }
          }

          // Chat history
          if (defect.chatMessages.isNotEmpty) {
            widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8, top: 4),
              child: pw.Text('Chat History:',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ));
            for (final msg in defect.chatMessages) {
              final prefix = msg.role == 'user' ? 'User' : 'AI';
              widgets.add(pw.Padding(
                padding: const pw.EdgeInsets.only(left: 16),
                child: pw.Text('[$prefix] ${msg.content}',
                    style: const pw.TextStyle(fontSize: 9)),
              ));
            }
          }

          // Image
          if (defect.imageBase64 != null && defect.imageBase64!.isNotEmpty) {
            try {
              final imgBytes = base64Decode(defect.imageBase64!);
              final image = pw.MemoryImage(Uint8List.fromList(imgBytes));
              widgets.add(pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6, left: 8),
                child: pw.ClipRect(
                  child: pw.Image(image, width: 240, height: 160,
                      fit: pw.BoxFit.contain),
                ),
              ));
            } catch (_) {
              // Skip broken images
            }
          }

          widgets.add(pw.SizedBox(height: 10));
          widgets.add(pw.Divider(color: PdfColors.grey300));
          widgets.add(pw.SizedBox(height: 6));
        }
      }

      if (defectNum == 0) {
        widgets.add(pw.Text(
          'No defect records for this floor.',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
        ));
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => widgets,
        ),
      );
    }

    final bytes = await pdf.save();
    final file = File(outputPath);
    await file.writeAsBytes(bytes);
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(children: [
        pw.SizedBox(
          width: 180,
          child: pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800)),
        ),
        pw.Text(value, style: const pw.TextStyle(fontSize: 13)),
      ]),
    );
  }

  static PdfColor _riskColor(int score) {
    if (score >= 70) return PdfColor.fromHex('#E53935');
    if (score >= 40) return PdfColor.fromHex('#FB8C00');
    return PdfColor.fromHex('#43A047');
  }
}
