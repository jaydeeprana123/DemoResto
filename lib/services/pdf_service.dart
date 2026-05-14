import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class PdfService {
  static pw.Widget _pdfDottedLine(pw.Font ttf) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    child: pw.Row(
      children: List.generate(
        48,
        (_) => pw.Expanded(
          child: pw.Text(
            '.',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: ttf,
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),
        ),
      ),
    ),
  );

  static pw.Widget _pdfSolidLine() => pw.Container(
    height: 0.5,
    color: PdfColors.grey500,
    margin: const pw.EdgeInsets.symmetric(vertical: 4),
  );

  static pw.Widget _pdfSummaryRow(
    pw.Font ttf,
    String label,
    String value, {
    bool bold = false,
    double size = 9,
  }) {
    final style = pw.TextStyle(
      font: ttf,
      fontSize: size,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  static Future<Uint8List> generateInvoicePdf({
    required String tableName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double tax,
    required double discount,
    required int total,
    required int cashAmount,
    required int onlineAmount,
  }) async {
    final pdf = pw.Document();

    // ✅ Load custom Unicode font
    final fontData = await rootBundle.load("assets/fonts/NotoSans-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    // ✅ Load logo
    final ByteData logoData = await rootBundle.load('assets/images/logo.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoBytes);

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.Page(
        // 80mm thermal receipt ≈ 226pt wide
        pageFormat: const PdfPageFormat(226, double.infinity, marginAll: 10),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // ── Logo ───────────────────────────────────────────────────
              pw.Image(logoImage, width: 48, height: 48),
              pw.SizedBox(height: 5),

              // ── Business Name ───────────────────────────────────────────
              pw.Text(
                'FLAVOR FLOW',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Restaurant & Café',
                style: pw.TextStyle(font: ttf, fontSize: 8),
              ),
              pw.Text(
                'Tel: +91-XXXXXXXXXX',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),

              _pdfDottedLine(ttf),

              // ── Order Info ──────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Order:',
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 7,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        tableName,
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        dateStr,
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 7,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        timeStr,
                        style: pw.TextStyle(font: ttf, fontSize: 7),
                      ),
                    ],
                  ),
                ],
              ),

              _pdfDottedLine(ttf),

              // ── Column Headers ──────────────────────────────────────────
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text(
                      'Item',
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: 20,
                    child: pw.Text(
                      'Qty',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: 34,
                    child: pw.Text(
                      'Price',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: 36,
                    child: pw.Text(
                      'Total',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              _pdfSolidLine(),

              // ── Line Items ──────────────────────────────────────────────
              ...items.map((item) {
                final qty = item['qty'] ?? 1;
                final price = double.tryParse(item['price'].toString()) ?? 0.0;
                final lineTotal = price * qty;
                final remarks = (item['remarks'] as String? ?? '').trim();

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 5,
                          child: pw.Text(
                            item['name'] ?? '',
                            style: pw.TextStyle(font: ttf, fontSize: 8),
                          ),
                        ),
                        pw.SizedBox(
                          width: 20,
                          child: pw.Text(
                            '$qty',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: ttf, fontSize: 8),
                          ),
                        ),
                        pw.SizedBox(
                          width: 34,
                          child: pw.Text(
                            '₹${price.toStringAsFixed(0)}',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(font: ttf, fontSize: 8),
                          ),
                        ),
                        pw.SizedBox(
                          width: 36,
                          child: pw.Text(
                            '₹${lineTotal.toStringAsFixed(0)}',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (remarks.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 4, bottom: 2),
                        child: pw.Text(
                          '  * $remarks',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 6.5,
                            color: PdfColors.grey700,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ),
                    pw.SizedBox(height: 3),
                  ],
                );
              }).toList(),

              _pdfDottedLine(ttf),

              // ── Totals ──────────────────────────────────────────────────
              _pdfSummaryRow(
                ttf,
                'Sub Total',
                '₹${subtotal.toStringAsFixed(0)}',
              ),
              _pdfSummaryRow(ttf, 'Tax (8.5%)', '₹${tax.toStringAsFixed(0)}'),
              if (discount > 0)
                _pdfSummaryRow(
                  ttf,
                  'Discount',
                  '-₹${discount.toStringAsFixed(0)}',
                ),

              _pdfDottedLine(ttf),

              _pdfSummaryRow(ttf, 'TOTAL', '₹$total', bold: true, size: 12),

              _pdfDottedLine(ttf),

              // ── Payment ─────────────────────────────────────────────────
              if (cashAmount > 0) _pdfSummaryRow(ttf, 'Cash', '₹$cashAmount'),
              if (onlineAmount > 0)
                _pdfSummaryRow(ttf, 'Online', '₹$onlineAmount'),

              _pdfDottedLine(ttf),

              // ── Footer ──────────────────────────────────────────────────
              pw.SizedBox(height: 4),
              pw.Text(
                'THANK YOU FOR',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'YOUR VISIT!',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Please come again',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
