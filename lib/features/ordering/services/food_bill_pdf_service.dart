import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:demo/core/services/restaurant_print_profile_service.dart';
import 'package:demo/core/utils/platform_utils.dart';
import 'package:demo/core/utils/app_messenger.dart';
import 'package:demo/features/ordering/services/food_bill_pdf_io.dart'
    if (dart.library.html) 'package:demo/features/ordering/services/food_bill_pdf_io_web.dart';
import 'package:demo/features/ordering/widgets/billing_progress_dialog.dart';
import 'package:demo/features/ordering/widgets/table_billing_mode_dialog.dart';
import 'package:demo/features/ordering/widgets/whatsapp_share_phone_dialog.dart';
import 'package:demo/features/settings/services/print_settings.dart';
import 'package:demo/core/network/ssl_error_utils.dart';
import 'package:demo/features/zomato/services/imagekit_settings.dart';
import 'package:demo/features/zomato/services/imagekit_upload_service.dart';
import 'package:demo/core/utils/tax_calculator.dart';
import 'package:get/get.dart';

class FoodBillPdfData {
  const FoodBillPdfData({
    required this.tableName,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.total,
    this.customerName,
    this.extra = 0,
    this.invoiceNumber,
    this.cashAmount = 0,
    this.onlineAmount = 0,
    this.cgstPercentage = 0,
    this.sgstPercentage = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
  });

  final String tableName;
  final String? customerName;
  final List<Map<String, dynamic>> items;
  final int subtotal;
  final int tax;
  final int discount;
  final int extra;
  final int total;
  final String? invoiceNumber;
  final int cashAmount;
  final int onlineAmount;
  final double cgstPercentage;
  final double sgstPercentage;
  final int cgstAmount;
  final int sgstAmount;

  /// Name printed on the receipt (customer field, else table name).
  String get receiptCustomerName {
    final customer = customerName?.trim();
    if (customer != null && customer.isNotEmpty) return customer;
    return tableName.trim();
  }

  /// Receipt line label: "Table:" for dine-in names, else "Customer Name:".
  String get receiptCustomerLabelLine {
    final name = receiptCustomerName;
    if (name.toLowerCase().contains('table')) {
      return 'Table: $name';
    }
    return 'Customer Name: $name';
  }
}

class FoodBillPdfService {
  static const _legacyRestaurantAddress =
      '05, Ground Floor, Ayesha Complex, Tandalja, Opposite JP Police Station, Diwalipura, Vadodara';
  static const _legacyRestaurantPhone = '+91 85113 33998';
  static const _legacyRestaurantName = 'AL - HAADI';

  static pw.Font? _cachedFont;
  static pw.MemoryImage? _cachedRestaurantLogo;
  static pw.MemoryImage? _cachedPoweredByLogo;

  /// Preloads PDF assets once so later bills build faster.
  static Future<void> warmUpAssets({bool includeLogos = false}) async {
    await _loadFont();
    if (includeLogos) {
      await _loadLogos();
    }
  }

  static Future<pw.Font> _loadFont() async {
    if (_cachedFont != null) return _cachedFont!;
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    _cachedFont = pw.Font.ttf(fontData);
    return _cachedFont!;
  }

  static Future<void> _loadLogos() async {
    _cachedRestaurantLogo = null;
    if (Get.isRegistered<RestaurantPrintProfileService>()) {
      final profile = Get.find<RestaurantPrintProfileService>();
      await profile.ensureLogoReady();
      _cachedRestaurantLogo = profile.logoImage;
    }
    if (_cachedRestaurantLogo == null) {
      final restaurantLogoBytes = await _loadAssetBytes(
        'assets/images/restaurant_bill_logo.png',
      );
      _cachedRestaurantLogo = pw.MemoryImage(restaurantLogoBytes);
    }
    if (_cachedPoweredByLogo == null) {
      final poweredByLogoBytes = await _tryLoadAssetBytes(
        'assets/images/logo.png',
      );
      if (poweredByLogoBytes != null) {
        _cachedPoweredByLogo = pw.MemoryImage(poweredByLogoBytes);
      }
    }
  }

  static Future<void> generateAndPrintIfEnabled({
    required BuildContext context,
    required FoodBillPdfData data,
    bool showProgressDialog = true,
  }) async {
    if (!await PrintSettings.getPrintPdfEnabled()) return;
    if (!context.mounted) return;

    final printerType = await PrintSettings.getPrinterType();
    final includeLogos = await PrintSettings.getBillPdfIncludeLogos();
    await warmUpAssets(includeLogos: includeLogos);
    final pageFormat = PrintSettings.receiptPageFormat(
      printerType,
      itemCount: data.items.length,
      hasDiscount: data.discount > 0,
      hasExtra: data.extra > 0,
      hasPaymentLines: data.cashAmount > 0 || data.onlineAmount > 0,
      hasTaxLines: data.cgstAmount > 0 || data.sgstAmount > 0,
      includeLogos: includeLogos,
    );

    if (showProgressDialog) {
      _showLoadingDialog(context, printerType);
    }
    try {
      await _deliverReceipt(
        data: data,
        printerType: printerType,
        pageFormat: pageFormat,
        includeLogos: includeLogos,
        toPrinter: true,
      );
    } catch (e) {
      if (context.mounted) {
        if (showProgressDialog &&
            Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not print POS receipt: $e')),
        );
      }
    } finally {
      if (showProgressDialog &&
          context.mounted &&
          Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  /// Applies print or WhatsApp share based on the billing dialog choice.
  static Future<void> deliverReceiptByAction(
    FoodBillPdfData data,
    BillReceiptAction action, {
    String? whatsappPhone,
  }) async {
    switch (action) {
      case BillReceiptAction.withoutPrint:
        return;
      case BillReceiptAction.print:
        await _deliverReceiptForced(data);
      case BillReceiptAction.shareWhatsApp:
        await _shareReceiptOnWhatsApp(data, whatsappPhone: whatsappPhone);
    }
  }

  static Future<void> _deliverReceiptForced(FoodBillPdfData data) async {
    try {
      final printerType = await PrintSettings.getPrinterType();
      final includeLogos = await PrintSettings.getBillPdfIncludeLogos();
      await warmUpAssets(includeLogos: includeLogos);
      final pageFormat = PrintSettings.receiptPageFormat(
        printerType,
        itemCount: data.items.length,
        hasDiscount: data.discount > 0,
        hasExtra: data.extra > 0,
        hasPaymentLines: data.cashAmount > 0 || data.onlineAmount > 0,
        hasTaxLines: data.cgstAmount > 0 || data.sgstAmount > 0,
        includeLogos: includeLogos,
      );
      await _deliverReceipt(
        data: data,
        printerType: printerType,
        pageFormat: pageFormat,
        includeLogos: includeLogos,
        toPrinter: true,
      );
    } catch (e) {
      AppMessenger.show('Receipt', 'Could not print receipt: $e');
    }
  }

  static Future<void> _shareReceiptOnWhatsApp(
    FoodBillPdfData data, {
    String? whatsappPhone,
  }) async {
    final context = Get.key.currentContext ?? Get.context;
    if (context == null || !context.mounted) {
      AppMessenger.show('Receipt', 'Could not open WhatsApp share dialog.');
      return;
    }

    if (!await ImageKitSettings.isConfigured()) {
      AppMessenger.show(
        'WhatsApp bill',
        'ImageKit is not configured. Open Settings → Zomato / ImageKit and save your keys.',
      );
      return;
    }

    final phone = whatsappPhone ?? await WhatsAppSharePhoneDialog.show(context);
    if (phone == null || phone.isEmpty) return;

    BillingProgressDialog.show(
      context,
      message: 'Sending bill on WhatsApp...',
      subtitle: 'Uploading PDF to ImageKit',
    );

    try {
      final printerType = await PrintSettings.getPrinterType();
      final includeLogos = await PrintSettings.getBillPdfIncludeLogos();
      await warmUpAssets(includeLogos: includeLogos);
      final pageFormat = PrintSettings.receiptPageFormat(
        printerType,
        itemCount: data.items.length,
        hasDiscount: data.discount > 0,
        hasExtra: data.extra > 0,
        hasPaymentLines: data.cashAmount > 0 || data.onlineAmount > 0,
        hasTaxLines: data.cgstAmount > 0 || data.sgstAmount > 0,
        includeLogos: includeLogos,
      );
      final pdfBytes = await _buildPdf(
        data,
        printerType,
        pageFormat,
        includeLogos: includeLogos,
      );
      final fileName = buildReceiptPdfFileName(data);
      final upload = await ImageKitUploadService.uploadBillPdf(
        bytes: pdfBytes,
        fileName: fileName,
      );

      final message = _buildWhatsAppBillMessage(data, upload.url);
      final opened = await openWhatsAppChat(phone, text: message);
      if (!opened) {
        AppMessenger.show(
          'Receipt',
          'Bill uploaded but WhatsApp could not open. Install WhatsApp and try again.',
        );
        return;
      }

      AppMessenger.show(
        'WhatsApp bill',
        'Chat opened for +$phone with bill PDF link. Tap Send in WhatsApp.',
        duration: const Duration(seconds: 8),
      );
    } catch (e) {
      AppMessenger.show('Receipt', SslErrorUtils.userMessage(e));
    } finally {
      if (context.mounted) {
        BillingProgressDialog.hide(context);
      }
    }
  }

  static String _buildWhatsAppBillMessage(FoodBillPdfData data, String pdfUrl) {
    final restaurantName = _headerRestaurantName;
    final customer = data.receiptCustomerName;
    final billId = data.invoiceNumber?.trim();
    final buffer = StringBuffer(
      'Thank you for visiting $restaurantName!\n\nBill',
    );
    if (customer.isNotEmpty) {
      buffer.write(' for $customer');
    }
    if (billId != null && billId.isNotEmpty) {
      buffer.write(' ($billId)');
    }
    buffer.writeln();
    buffer.write('\nDownload Bill PDF:\n$pdfUrl');
    buffer.writeln(
      '\n\nWe appreciate your visit and look forward to serving you again soon.',
    );
    buffer.write('\nRegards\nTeam $restaurantName');
    return buffer.toString();
  }

  /// Opens/saves receipt after billing without needing a [BuildContext].
  /// Call after navigating away so the dashboard stays visible.
  static Future<void> openReceiptIfEnabled(FoodBillPdfData data) async {
    if (!await PrintSettings.getPrintPdfEnabled()) return;

    try {
      final printerType = await PrintSettings.getPrinterType();
      final includeLogos = await PrintSettings.getBillPdfIncludeLogos();
      await warmUpAssets(includeLogos: includeLogos);
      final pageFormat = PrintSettings.receiptPageFormat(
        printerType,
        itemCount: data.items.length,
        hasDiscount: data.discount > 0,
        hasExtra: data.extra > 0,
        hasPaymentLines: data.cashAmount > 0 || data.onlineAmount > 0,
        hasTaxLines: data.cgstAmount > 0 || data.sgstAmount > 0,
        includeLogos: includeLogos,
      );
      await _deliverReceipt(
        data: data,
        printerType: printerType,
        pageFormat: pageFormat,
        includeLogos: includeLogos,
        toPrinter: true,
      );
    } catch (e) {
      AppMessenger.show('Receipt', 'Could not open receipt: $e');
    }
  }

  static Future<void> _deliverReceipt({
    required FoodBillPdfData data,
    required PosPrinterType printerType,
    required PdfPageFormat pageFormat,
    required bool includeLogos,
    bool toPrinter = false,
  }) async {
    final pdfBytes = await _buildPdf(
      data,
      printerType,
      pageFormat,
      includeLogos: includeLogos,
    );
    final fileName = buildReceiptPdfFileName(data);

    if ((isDesktopPlatform || kIsWeb) && !toPrinter) {
      final path = await writeReceiptPdfFile(pdfBytes, fileName);
      if (isDesktopPlatform) {
        await openReceiptPdfFile(path);
      }
      AppMessenger.show(
        'Receipt saved',
        isDesktopPlatform
            ? 'Documents/Flavor Flow Receipts/$fileName'
            : fileName,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    final sentDirect = await _tryDirectPosPrint(
      pdfBytes: pdfBytes,
      pageFormat: pageFormat,
      printerType: printerType,
      fileName: fileName,
    );

    if (sentDirect) return;

    if (isDesktopPlatform) {
      final printers = await Printing.listPrinters();
      if (!PrintSettings.hasReceiptPrinter(printers, type: printerType)) {
        await writeReceiptPdfFile(pdfBytes, fileName);
        AppMessenger.show(
          'Printer not connected',
          'Bill saved. Connect your Rugtek RP326 USB printer, then use Print again or open:\nDocuments/Flavor Flow Receipts/$fileName',
          duration: const Duration(seconds: 8),
        );
        return;
      }
    }

    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: fileName,
      format: pageFormat,
      usePrinterSettings: true,
    );
  }

  /// File name: `{Table Name} - {Bill ID}.pdf`
  static String buildReceiptPdfFileName(FoodBillPdfData data) {
    final namePart = _sanitizeFileNamePart(data.receiptCustomerName);
    final billPart = _sanitizeFileNamePart(
      data.invoiceNumber?.trim().isNotEmpty == true
          ? data.invoiceNumber!.trim()
          : 'receipt',
    );

    if (namePart.isEmpty) return '$billPart.pdf';
    return '$namePart - $billPart.pdf';
  }

  static String _sanitizeFileNamePart(String value) {
    return value
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Sends directly to a connected POS thermal printer (USB / network).
  static Future<bool> _tryDirectPosPrint({
    required Uint8List pdfBytes,
    required PdfPageFormat pageFormat,
    required PosPrinterType printerType,
    required String fileName,
  }) async {
    try {
      final printers = await Printing.listPrinters();
      final candidates = PrintSettings.receiptPrinterCandidates(
        printers,
        type: printerType,
      );
      if (candidates.isEmpty) return false;

      for (final target in candidates) {
        try {
          final sent = await Printing.directPrintPdf(
            printer: target,
            onLayout: (_) async => pdfBytes,
            name: fileName,
            format: pageFormat,
            usePrinterSettings: true,
          );
          if (sent) {
            await PrintSettings.setPreferredPrinterName(target.name);
            return true;
          }
        } catch (_) {
          continue;
        }
      }

      if (isDesktopPlatform) {
        final path = await writeReceiptPdfFile(pdfBytes, fileName);
        for (final target in candidates) {
          final sent = await printPdfToNamedPrinterWindows(
            pdfPath: path,
            printerName: target.name,
          );
          if (sent) {
            await PrintSettings.setPreferredPrinterName(target.name);
            return true;
          }
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Saves the PDF to disk and opens it in the default viewer (Windows/macOS/Linux).
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

  static RestaurantPrintProfileService? get _printProfile =>
      Get.isRegistered<RestaurantPrintProfileService>()
          ? Get.find<RestaurantPrintProfileService>()
          : null;

  static String get _headerRestaurantName {
    final name = _printProfile?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    return _legacyRestaurantName;
  }

  static String get _headerRestaurantAddress {
    final address = _printProfile?.address?.trim();
    if (address != null && address.isNotEmpty) return address;
    return _legacyRestaurantAddress;
  }

  static List<String> get _headerRestaurantPhones {
    final profile = _printProfile;
    final phones = <String>[];
    final mobile1 = profile?.displayMobile1;
    if (mobile1 != null && mobile1.isNotEmpty) {
      phones.add(mobile1);
    }
    final mobile2 = profile?.displayMobile2;
    if (mobile2 != null && mobile2.isNotEmpty) {
      phones.add(mobile2);
    }
    if (phones.isEmpty) {
      phones.add(_legacyRestaurantPhone);
    }
    return phones;
  }

  static Future<Uint8List> _buildPdf(
    FoodBillPdfData data,
    PosPrinterType printerType,
    PdfPageFormat pageFormat, {
    required bool includeLogos,
  }) async {
    final pdf = pw.Document();
    final regular = await _loadFont();

    final now = DateTime.now();
    final invoiceNo = _formatInvoiceNumber(data.invoiceNumber, now);
    final dateText = DateFormat('dd/MM/yyyy').format(now);
    final timeText = DateFormat('hh:mm a').format(now);
    final cgst = data.cgstAmount.toDouble();
    final sgst = data.sgstAmount.toDouble();

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
              if (includeLogos && _cachedRestaurantLogo != null) ...[
                pw.Center(
                  child: pw.Image(
                    _cachedRestaurantLogo!,
                    width: logoWidth * PdfPageFormat.mm,
                    fit: pw.BoxFit.contain,
                  ),
                ),
                pw.SizedBox(height: 6),
              ] else
                pw.Center(
                  child: pw.Text(
                    _headerRestaurantName,
                    style: labelStyle(size: headerSize, isBold: true),
                  ),
                ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  _headerRestaurantAddress,
                  textAlign: pw.TextAlign.center,
                  style: labelStyle(size: baseSize - 1),
                ),
              ),
              ..._headerRestaurantPhones.map(
                (phone) => pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Center(
                    child: pw.Text(
                      phone,
                      style: labelStyle(size: baseSize - 1),
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                data.receiptCustomerLabelLine,
                style: labelStyle(),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'Bill ID: $invoiceNo',
                      style: labelStyle(isBold: true),
                    ),
                  ),
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
              _amountRow('Subtotal', data.subtotal.toDouble(), labelStyle),
              if (data.cgstPercentage > 0 && data.cgstAmount > 0)
                _amountRow(
                  'CGST @ ${TaxCalculator.formatPercent(data.cgstPercentage)}%',
                  cgst,
                  labelStyle,
                ),
              if (data.sgstPercentage > 0 && data.sgstAmount > 0)
                _amountRow(
                  'SGST @ ${TaxCalculator.formatPercent(data.sgstPercentage)}%',
                  sgst,
                  labelStyle,
                ),
              if (data.discount > 0)
                _amountRow(
                  'Discount',
                  -data.discount.toDouble(),
                  labelStyle,
                ),
              if (data.extra > 0)
                _amountRow(
                  'Extra',
                  data.extra.toDouble(),
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
                    if (includeLogos && _cachedPoweredByLogo != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Image(
                        _cachedPoweredByLogo!,
                        width: isNarrow ? 22 : 28,
                        height: isNarrow ? 22 : 28,
                      ),
                    ],
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
    final data = await _tryLoadAssetBytes(path);
    if (data == null) {
      throw FlutterError('Unable to load asset: $path');
    }
    return data;
  }

  static Future<Uint8List?> _tryLoadAssetBytes(String path) async {
    try {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static String _formatInvoiceNumber(String? id, DateTime now) {
    if (id != null && id.trim().isNotEmpty) {
      final trimmed = id.trim();
      if (trimmed.startsWith('BILL-')) return trimmed;
      if (trimmed.length >= 4) {
        return trimmed.substring(trimmed.length - 4).toUpperCase();
      }
      return trimmed.toUpperCase();
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

  static ({double qty, double rate, double amt}) _columnWidths(bool isNarrow) {
    return (
      qty: isNarrow ? 18.0 : 22.0,
      rate: isNarrow ? 32.0 : 38.0,
      amt: isNarrow ? 36.0 : 42.0,
    );
  }

  static pw.Widget _itemTableRow({
    required pw.TextStyle Function({double? size, bool isBold}) labelStyle,
    required bool isNarrow,
    required double headerSize,
    pw.Widget? itemCell,
    String? qty,
    String? rate,
    String? amt,
    bool numericBold = false,
    bool amtBold = false,
    double verticalPadding = 2,
  }) {
    final widths = _columnWidths(isNarrow);

    pw.Widget numericCell(String text, double width, {bool isBold = false}) {
      return pw.SizedBox(
        width: width,
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            text,
            style: labelStyle(
              size: headerSize,
              isBold: isBold,
            ),
          ),
        ),
      );
    }

    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: verticalPadding),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 4,
            child: itemCell ??
                pw.SizedBox(
                  height: headerSize + 2,
                ),
          ),
          if (qty != null) numericCell(qty, widths.qty, isBold: numericBold),
          if (rate != null) numericCell(rate, widths.rate, isBold: numericBold),
          if (amt != null)
            numericCell(
              amt,
              widths.amt,
              isBold: amtBold || numericBold,
            ),
        ],
      ),
    );
  }

  static pw.Widget _tableHeader(
    pw.TextStyle Function({double? size, bool isBold}) labelStyle, {
    required bool isNarrow,
  }) {
    final headerSize = isNarrow ? 6.0 : 7.0;

    return _itemTableRow(
      labelStyle: labelStyle,
      isNarrow: isNarrow,
      headerSize: headerSize,
      itemCell: pw.Text(
        'ITEM',
        style: labelStyle(size: headerSize, isBold: true),
      ),
      qty: 'QTY',
      rate: 'RATE',
      amt: 'AMT',
      numericBold: true,
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
    final rowSize = isNarrow ? 7.0 : 8.0;

    return _itemTableRow(
      labelStyle: labelStyle,
      isNarrow: isNarrow,
      headerSize: rowSize,
      verticalPadding: isNarrow ? 2 : 3,
      itemCell: pw.Text(
        name,
        style: labelStyle(size: rowSize),
        maxLines: 3,
      ),
      qty: '$qty',
      rate: _formatMoney(price),
      amt: _formatMoney(lineTotal),
      amtBold: true,
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
