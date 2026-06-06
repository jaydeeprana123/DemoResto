import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:demo/features/settings/services/print_settings.dart';

class FoodBillPdfData {
  const FoodBillPdfData({
    required this.tableName,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.total,
    this.invoiceNumber,
    this.cashAmount = 0,
    this.onlineAmount = 0,
  });

  final String tableName;
  final List<Map<String, dynamic>> items;
  final int subtotal;
  final int tax;
  final int discount;
  final int total;
  final String? invoiceNumber;
  final int cashAmount;
  final int onlineAmount;
}

class FoodBillPdfService {
  static Future<void> generateAndPrintIfEnabled({
    required BuildContext context,
    required FoodBillPdfData data,
  }) async {
    if (!await PrintSettings.getPrintPdfEnabled()) return;
    if (!context.mounted) return;

    final printerType = await PrintSettings.getPrinterType();
    final pageFormat = PrintSettings.receiptPageFormat(
      printerType,
      itemCount: data.items.length,
      hasDiscount: data.discount > 0,
      hasPaymentLines: data.cashAmount > 0 || data.onlineAmount > 0,
    );

    _showLoadingDialog(context, printerType);
    try {
      final pdfBytes = await _buildPdf(data, printerType, pageFormat);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final sentToTvs = await _tryDirectTvsPrint(
        pdfBytes: pdfBytes,
        pageFormat: pageFormat,
        printerType: printerType,
        invoiceNumber: data.invoiceNumber,
      );

      if (!sentToTvs) {
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: 'pos_bill_${data.invoiceNumber ?? 'receipt'}.pdf',
          format: pageFormat,
          usePrinterSettings: true,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not print POS receipt: $e')),
        );
      }
    }
  }

  /// Sends directly to a connected TVS printer when detected (USB / network).
  static Future<bool> _tryDirectTvsPrint({
    required Uint8List pdfBytes,
    required PdfPageFormat pageFormat,
    required PosPrinterType printerType,
    String? invoiceNumber,
  }) async {
    if (printerType != PosPrinterType.tvs80) return false;

    try {
      final printers = await Printing.listPrinters();
      Printer? tvsPrinter;
      for (final printer in printers) {
        if (PrintSettings.isTvsPrinterName(printer.name)) {
          tvsPrinter = printer;
          break;
        }
      }

      if (tvsPrinter == null) return false;

      return Printing.directPrintPdf(
        printer: tvsPrinter,
        onLayout: (_) async => pdfBytes,
        name: 'tvs_bill_${invoiceNumber ?? 'receipt'}.pdf',
        format: pageFormat,
        usePrinterSettings: true,
      );
    } catch (_) {
      return false;
    }
  }

  static void _showLoadingDialog(
    BuildContext context,
    PosPrinterType printerType,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFFf57c35)),
                const SizedBox(height: 20),
                Text(
                  'Printing on ${printerType.label}...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                const LinearProgressIndicator(
                  color: Color(0xFFf57c35),
                  backgroundColor: Color(0xFFE5E7EB),
                ),
                const SizedBox(height: 8),
                Text(
                  printerType == PosPrinterType.tvs80
                      ? 'Searching for TVS printer...'
                      : 'Preparing POS receipt PDF',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<Uint8List> _buildPdf(
    FoodBillPdfData data,
    PosPrinterType printerType,
    PdfPageFormat pageFormat,
  ) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final regular = pw.Font.ttf(fontData);

    final restaurantLogoBytes = await _loadAssetBytes(
      'assets/images/restaurant_bill_logo.png',
    );
    final poweredByLogoBytes = await _loadAssetBytes('assets/images/logo.png');

    final restaurantLogo = pw.MemoryImage(restaurantLogoBytes);
    final poweredByLogo = pw.MemoryImage(poweredByLogoBytes);

    final now = DateTime.now();
    final invoiceNo = _formatInvoiceNumber(data.invoiceNumber, now);
    final dateText = DateFormat('dd/MM/yyyy').format(now);
    final timeText = DateFormat('hh:mm a').format(now);
    final cgst = data.tax / 2.0;
    final sgst = data.tax / 2.0;

    final isNarrow = printerType == PosPrinterType.narrow58;
    final baseSize = isNarrow ? 7.0 : 8.0;
    final headerSize = isNarrow ? 10.0 : 12.0;
    final totalSize = isNarrow ? 10.0 : 11.0;
    final logoWidth = isNarrow ? 48.0 : 68.0;

    pw.TextStyle labelStyle({double? size, bool isBold = false}) =>
        pw.TextStyle(
          font: regular,
          fontSize: size ?? baseSize,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Image(
                  restaurantLogo,
                  width: logoWidth * PdfPageFormat.mm,
                  fit: pw.BoxFit.contain,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'FOOD BILL',
                  style: labelStyle(size: headerSize, isBold: true),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Table: ${data.tableName}', style: labelStyle()),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice #: $invoiceNo', style: labelStyle()),
                  pw.Text('Date $dateText', style: labelStyle()),
                ],
              ),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  timeText,
                  style: labelStyle(size: baseSize - 1),
                ),
              ),
              pw.SizedBox(height: 8),
              _divider(),
              _tableHeader(labelStyle, isNarrow: isNarrow),
              _divider(),
              ...data.items.map(
                (item) => _tableRow(item, labelStyle, isNarrow: isNarrow),
              ),
              _divider(),
              _amountRow('CGST @ 4.25%', cgst, labelStyle),
              _amountRow('SGST @ 4.25%', sgst, labelStyle),
              if (data.discount > 0)
                _amountRow(
                  'Discount',
                  -data.discount.toDouble(),
                  labelStyle,
                ),
              _divider(thick: true),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: labelStyle(size: totalSize, isBold: true),
                  ),
                  pw.Text(
                    '₹ ${_formatMoney(data.total)}',
                    style: labelStyle(size: totalSize, isBold: true),
                  ),
                ],
              ),
              _divider(thick: true),
              if (data.cashAmount > 0 || data.onlineAmount > 0) ...[
                pw.SizedBox(height: 4),
                if (data.cashAmount > 0)
                  _amountRow('Cash', data.cashAmount.toDouble(), labelStyle),
                if (data.onlineAmount > 0)
                  _amountRow(
                    'Online',
                    data.onlineAmount.toDouble(),
                    labelStyle,
                  ),
              ],
              pw.SizedBox(height: 10),
              _divider(),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Powered By',
                      style: labelStyle(size: baseSize - 1),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Image(
                      poweredByLogo,
                      width: isNarrow ? 22 : 28,
                      height: isNarrow ? 22 : 28,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Flavor Flow',
                      style: labelStyle(size: baseSize, isBold: true),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> _loadAssetBytes(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  static String _formatInvoiceNumber(String? id, DateTime now) {
    if (id != null && id.length >= 4) {
      return id.substring(id.length - 4).toUpperCase();
    }
    return DateFormat('HHmm').format(now);
  }

  static String _formatMoney(num value) {
    return value.abs().toStringAsFixed(2);
  }

  static pw.Widget _divider({bool thick = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Container(
        height: thick ? 1 : 0.6,
        color: PdfColors.black,
      ),
    );
  }

  static pw.Widget _tableHeader(
    pw.TextStyle Function({double? size, bool isBold}) labelStyle, {
    required bool isNarrow,
  }) {
    final headerSize = isNarrow ? 6.0 : 7.0;
    final qtyWidth = isNarrow ? 18.0 : 22.0;
    final rateWidth = isNarrow ? 32.0 : 38.0;
    final amtWidth = isNarrow ? 36.0 : 42.0;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Text(
              'ITEM',
              style: labelStyle(size: headerSize, isBold: true),
            ),
          ),
          pw.SizedBox(
            width: qtyWidth,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'QTY',
                style: labelStyle(size: headerSize, isBold: true),
              ),
            ),
          ),
          pw.SizedBox(
            width: rateWidth,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'RATE',
                style: labelStyle(size: headerSize, isBold: true),
              ),
            ),
          ),
          pw.SizedBox(
            width: amtWidth,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'AMT',
                style: labelStyle(size: headerSize, isBold: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableRow(
    Map<String, dynamic> item,
    pw.TextStyle Function({double? size, bool isBold}) labelStyle, {
    required bool isNarrow,
  }) {
    final qty = (item['qty'] as num?)?.toInt() ?? 1;
    final price = (item['price'] as num?)?.toDouble() ??
        double.tryParse(item['price']?.toString() ?? '') ??
        0;
    final lineTotal = price * qty;
    final name = item['name']?.toString() ?? '-';
    final qtyWidth = isNarrow ? 18.0 : 22.0;
    final rateWidth = isNarrow ? 32.0 : 38.0;
    final amtWidth = isNarrow ? 36.0 : 42.0;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(name, style: labelStyle(), maxLines: 2),
          pw.SizedBox(height: 2),
          pw.Row(
            children: [
               pw.Spacer(),
              pw.SizedBox(
                width: qtyWidth,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('$qty', style: labelStyle()),
                ),
              ),
              pw.SizedBox(
                width: rateWidth,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    _formatMoney(price),
                    style: labelStyle(),
                  ),
                ),
              ),
              pw.SizedBox(
                width: amtWidth,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    _formatMoney(lineTotal),
                    style: labelStyle(isBold: true),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _amountRow(
    String label,
    double amount,
    pw.TextStyle Function({double? size, bool isBold}) labelStyle,
  ) {
    final prefix = amount < 0 ? '-₹' : '₹';
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(child: pw.Text(label, style: labelStyle())),
          pw.Text('$prefix${_formatMoney(amount)}', style: labelStyle()),
        ],
      ),
    );
  }
}
