import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/monthly_report.dart';

class ReportExportService {
  static Future<String> exportPdf({
    required PeriodReportDocument report,
  }) async {
    final fileBytes = await _buildPdf(report: report);
    final dir = await getTemporaryDirectory();
    final fileName = 'farmgenius_${report.periodType}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(fileBytes, flush: true);
    return file.path;
  }

  static Future<void> sharePdf({
    required PeriodReportDocument report,
  }) async {
    final path = await exportPdf(report: report);
    await Share.shareXFiles(
      [XFile(path)],
      text: report.whatsappMessage,
      subject: 'FarmGenius ${report.periodType.toUpperCase()} Report',
    );
  }

  static Future<Uint8List> _buildPdf({
    required PeriodReportDocument report,
  }) async {
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Text(
              'FarmGenius ${report.periodType.toUpperCase()} Report',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Period: ${report.periodLabel}'),
            pw.Text('Generated: ${report.generatedAt.toIso8601String()}'),
            pw.SizedBox(height: 16),
            pw.Text('Key Metrics', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            ...report.kpis.map(
              (kpi) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text('${kpi.label}: ${kpi.value}'),
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Text('Highlights', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            ...report.highlights.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text('- ${item.title}: ${item.detail}'),
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Message Copy', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text(report.whatsappMessage),
          ];
        },
      ),
    );

    return document.save();
  }
}
