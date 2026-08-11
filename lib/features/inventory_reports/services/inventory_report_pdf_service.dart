import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:smartKitchen/core/services/restaurant_print_profile_service.dart';
import 'package:smartKitchen/features/settings/utils/export_date_range.dart';

class InventoryReportPdfService {
  static pw.Font? _cachedFont;
  static pw.MemoryImage? _cachedPoweredByLogo;

  static Future<pw.Font> _loadFont() async {
    if (_cachedFont != null) return _cachedFont!;
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    _cachedFont = pw.Font.ttf(fontData);
    return _cachedFont!;
  }

  static Future<pw.MemoryImage?> _loadPoweredByLogo() async {
    if (_cachedPoweredByLogo != null) return _cachedPoweredByLogo;
    try {
      final data = await rootBundle.load('assets/images/app_icon.png');
      _cachedPoweredByLogo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {}
    return _cachedPoweredByLogo;
  }

  static Future<void> printReport({
    required String reportTitle,
    required ExportDateRange? range,
    Map<String, String> filters = const {},
    required List<String> headers,
    required List<List<String>> rows,
    List<String>? summaryLines,
  }) async {
    final pdf = await buildReportPdf(
      reportTitle: reportTitle,
      range: range,
      filters: filters,
      headers: headers,
      rows: rows,
      summaryLines: summaryLines,
    );
    await Printing.layoutPdf(onLayout: (_) async => pdf);
  }

  static Future<Uint8List> buildReportPdf({
    required String reportTitle,
    required ExportDateRange? range,
    Map<String, String> filters = const {},
    required List<String> headers,
    required List<List<String>> rows,
    List<String>? summaryLines,
  }) async {
    final font = await _loadFont();
    final poweredBy = await _loadPoweredByLogo();
    RestaurantPrintProfileService? profile;
    if (Get.isRegistered<RestaurantPrintProfileService>()) {
      profile = Get.find<RestaurantPrintProfileService>();
      await profile.ensureLogoReady();
    }

    final dateFmt = DateFormat('dd MMM yyyy');
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: font));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (profile?.logoImage != null)
                pw.Container(
                  width: 48,
                  height: 48,
                  margin: const pw.EdgeInsets.only(right: 12),
                  child: pw.Image(profile!.logoImage!, fit: pw.BoxFit.contain),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      profile?.name.isNotEmpty == true
                          ? profile!.name
                          : 'Smart Kitchen',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      reportTitle,
                      style: const pw.TextStyle(fontSize: 13),
                    ),
                    if (range != null)
                      pw.Text(
                        'Date Range: ${dateFmt.format(range.from)} - ${dateFmt.format(range.to)}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                  ],
                ),
              ),
              if (poweredBy != null)
                pw.SizedBox(
                  width: 72,
                  height: 24,
                  child: pw.Image(poweredBy, fit: pw.BoxFit.contain),
                ),
            ],
          ),
          if (filters.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 12,
              runSpacing: 4,
              children: filters.entries
                  .map(
                    (e) => pw.Text(
                      '${e.key}: ${e.value}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  )
                  .toList(),
            ),
          ],
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
            },
          ),
          if (summaryLines != null && summaryLines.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            ...summaryLines.map(
              (line) => pw.Text(
                line,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }
}
