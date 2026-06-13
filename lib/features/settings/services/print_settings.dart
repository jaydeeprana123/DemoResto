import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PosPrinterType {
  tvs80,
  generic80,
  narrow58,
}

extension PosPrinterTypeLabel on PosPrinterType {
  String get label => switch (this) {
        PosPrinterType.tvs80 => 'TVS Printer (80mm)',
        PosPrinterType.generic80 => 'Generic POS (80mm)',
        PosPrinterType.narrow58 => 'Narrow POS (58mm)',
      };

  String get subtitle => switch (this) {
        PosPrinterType.tvs80 =>
          'Optimized for TVS RP / LP / MLP thermal series',
        PosPrinterType.generic80 => 'Epson & other 80mm USB thermal printers',
        PosPrinterType.narrow58 => '58mm thermal roll printers',
      };
}

class PrintSettings {
  static const _keyPrintPdfEnabled = 'print_pdf_enabled';
  static const _keyPrinterType = 'pos_printer_type';
  static const _keyBillPdfIncludeLogos = 'bill_pdf_include_logos';

  static final ValueNotifier<bool> printPdfEnabled = ValueNotifier(false);
  static final ValueNotifier<PosPrinterType> printerType =
      ValueNotifier(PosPrinterType.tvs80);
  static final ValueNotifier<bool> billPdfIncludeLogos = ValueNotifier(false);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    printPdfEnabled.value = prefs.getBool(_keyPrintPdfEnabled) ?? false;
    printerType.value = _parsePrinterType(
      prefs.getString(_keyPrinterType),
    );
    billPdfIncludeLogos.value =
        prefs.getBool(_keyBillPdfIncludeLogos) ?? false;
  }

  static Future<bool> getPrintPdfEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPrintPdfEnabled) ?? false;
  }

  static Future<PosPrinterType> getPrinterType() async {
    final prefs = await SharedPreferences.getInstance();
    return _parsePrinterType(prefs.getString(_keyPrinterType));
  }

  static Future<void> setPrintPdfEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPrintPdfEnabled, value);
    printPdfEnabled.value = value;
  }

  static Future<void> setPrinterType(PosPrinterType value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPrinterType, value.name);
    printerType.value = value;
  }

  static Future<bool> getBillPdfIncludeLogos() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBillPdfIncludeLogos) ?? false;
  }

  static Future<void> setBillPdfIncludeLogos(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBillPdfIncludeLogos, value);
    billPdfIncludeLogos.value = value;
  }

  static PosPrinterType _parsePrinterType(String? raw) {
    return PosPrinterType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => PosPrinterType.tvs80,
    );
  }

  /// POS roll width with a **finite** height (required by pdf Page widget).
  /// roll80 / roll57 use infinite height which crashes MultiPage.
  static PdfPageFormat receiptPageFormat(
    PosPrinterType type, {
    required int itemCount,
    bool hasDiscount = false,
    bool hasExtra = false,
    bool hasPaymentLines = false,
    bool hasTaxLines = false,
    bool includeLogos = false,
  }) {
    final widthMm = type == PosPrinterType.narrow58 ? 57.0 : 80.0;
    final margins = _marginsFor(type);

    var heightMm = includeLogos ? 102.0 : 88.0;
    heightMm += 14.0; // restaurant address + phone
    heightMm += itemCount * 12.0;
    heightMm += 30.0;
    if (hasTaxLines) heightMm += 12.0;
    if (hasDiscount) heightMm += 6.0;
    if (hasExtra) heightMm += 6.0;
    if (hasPaymentLines) heightMm += 12.0;
    heightMm += 24.0;
    if (!includeLogos) heightMm -= 10.0;

    return PdfPageFormat(
      widthMm * PdfPageFormat.mm,
      heightMm * PdfPageFormat.mm,
      marginLeft: margins.left,
      marginRight: margins.right,
      marginTop: margins.top,
      marginBottom: margins.bottom,
    );
  }

  static ({double left, double right, double top, double bottom}) _marginsFor(
    PosPrinterType type,
  ) {
    switch (type) {
      case PosPrinterType.tvs80:
        return (
          left: 2 * PdfPageFormat.mm,
          right: 2 * PdfPageFormat.mm,
          top: 3 * PdfPageFormat.mm,
          bottom: 5 * PdfPageFormat.mm,
        );
      case PosPrinterType.generic80:
        return (
          left: 4 * PdfPageFormat.mm,
          right: 4 * PdfPageFormat.mm,
          top: 4 * PdfPageFormat.mm,
          bottom: 6 * PdfPageFormat.mm,
        );
      case PosPrinterType.narrow58:
        return (
          left: 2 * PdfPageFormat.mm,
          right: 2 * PdfPageFormat.mm,
          top: 3 * PdfPageFormat.mm,
          bottom: 5 * PdfPageFormat.mm,
        );
    }
  }

  static bool isTvsPrinterName(String name) {
    final lower = name.toLowerCase();
    return lower.contains('tvs') ||
        lower.contains('rp-') ||
        lower.contains('rp ') ||
        lower.contains('lp-') ||
        lower.contains('lp ') ||
        lower.contains('mlp');
  }

  static bool isEpsonPrinterName(String name) {
    final lower = name.toLowerCase();
    return lower.contains('epson') ||
        lower.contains('tm-t') ||
        lower.contains('tm-m') ||
        lower.contains('tm t') ||
        lower.contains('tm m');
  }

  static bool isThermalReceiptPrinterName(String name) {
    final lower = name.toLowerCase();
    return isTvsPrinterName(name) ||
        isEpsonPrinterName(name) ||
        lower.contains('thermal') ||
        lower.contains('receipt');
  }

  /// Windows virtual printers (OneNote, PDF, XPS, etc.) — not for POS receipts.
  static bool isVirtualPrinterName(String name) {
    final lower = name.toLowerCase();
    return lower.contains('onenote') ||
        lower.contains('one note') ||
        lower.contains('print to pdf') ||
        lower.contains('microsoft print') ||
        lower.contains('xps document') ||
        lower.contains('microsoft xps') ||
        lower.contains(' fax') ||
        lower.startsWith('fax') ||
        lower.contains('adobe pdf') ||
        lower.contains('cutepdf') ||
        lower.contains('send to') ||
        lower.contains('virtual') ||
        lower.contains('pdf writer') ||
        lower.contains('snagit');
  }

  static List<Printer> physicalPrinters(List<Printer> printers) {
    return printers
        .where((p) => p.isAvailable && !isVirtualPrinterName(p.name))
        .toList();
  }

  static bool hasReceiptPrinter(
    List<Printer> printers, {
    PosPrinterType type = PosPrinterType.generic80,
  }) {
    return pickReceiptPrinter(printers, type: type) != null;
  }

  /// Picks a USB/network POS printer when available (Epson, TVS, etc.).
  /// Never returns virtual printers such as Send to OneNote.
  static Printer? pickReceiptPrinter(
    List<Printer> printers, {
    PosPrinterType type = PosPrinterType.generic80,
  }) {
    final candidates = physicalPrinters(printers);
    if (candidates.isEmpty) return null;

    bool preferredForSettings(Printer printer) {
      if (type == PosPrinterType.tvs80) {
        return isTvsPrinterName(printer.name);
      }
      return isThermalReceiptPrinterName(printer.name);
    }

    for (final printer in candidates) {
      if (printer.isDefault && preferredForSettings(printer)) {
        return printer;
      }
    }
    for (final printer in candidates) {
      if (isEpsonPrinterName(printer.name)) return printer;
    }
    if (type == PosPrinterType.tvs80) {
      for (final printer in candidates) {
        if (isTvsPrinterName(printer.name)) return printer;
      }
    }
    for (final printer in candidates) {
      if (isThermalReceiptPrinterName(printer.name)) return printer;
    }
    for (final printer in candidates) {
      if (printer.isDefault) return printer;
    }
    for (final printer in candidates) {
      if (preferredForSettings(printer)) return printer;
    }
    return candidates.length == 1 ? candidates.first : null;
  }
}
