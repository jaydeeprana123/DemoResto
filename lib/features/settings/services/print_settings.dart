import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReceiptConnectionMode {
  systemPrinter,
  bluetooth,
}

extension ReceiptConnectionModeLabel on ReceiptConnectionMode {
  String get label => switch (this) {
        ReceiptConnectionMode.systemPrinter => 'System / USB printer',
        ReceiptConnectionMode.bluetooth => 'Bluetooth thermal',
      };

  String get subtitle => switch (this) {
        ReceiptConnectionMode.systemPrinter =>
          'Windows USB printers (Rugtek, TVS, etc.)',
        ReceiptConnectionMode.bluetooth =>
          '58mm / 80mm Bluetooth receipt printers on Android / iOS',
      };
}

enum PosPrinterType {
  tvs80,
  rugtek80,
  generic80,
  narrow58,
}

extension PosPrinterTypeLabel on PosPrinterType {
  String get label => switch (this) {
        PosPrinterType.tvs80 => 'TVS Printer (80mm)',
        PosPrinterType.rugtek80 => 'Rugtek RP326 (80mm)',
        PosPrinterType.generic80 => 'Generic POS (80mm)',
        PosPrinterType.narrow58 => 'Narrow POS (58mm)',
      };

  String get subtitle => switch (this) {
        PosPrinterType.tvs80 =>
          'Optimized for TVS RP / LP / MLP thermal series',
        PosPrinterType.rugtek80 =>
          'Rugtek RP326 / RP327 / RP328 and Rongta USB printers',
        PosPrinterType.generic80 =>
          'Epson, Rugtek & other 80mm USB thermal printers',
        PosPrinterType.narrow58 => '58mm thermal roll printers',
      };
}

class PrintSettings {
  static const _keyPrintPdfEnabled = 'print_pdf_enabled';
  static const _keyPrinterType = 'pos_printer_type';
  static const _keyBillPdfIncludeLogos = 'bill_pdf_include_logos';
  static const _keyPreferredPrinterName = 'pos_preferred_printer_name';
  static const _keyConnectionMode = 'receipt_connection_mode';
  static const _keyBluetoothMac = 'bluetooth_printer_mac';
  static const _keyBluetoothName = 'bluetooth_printer_name';

  static final ValueNotifier<bool> printPdfEnabled = ValueNotifier(false);
  static final ValueNotifier<PosPrinterType> printerType =
      ValueNotifier(PosPrinterType.rugtek80);
  static final ValueNotifier<bool> billPdfIncludeLogos = ValueNotifier(false);
  static final ValueNotifier<ReceiptConnectionMode> connectionMode =
      ValueNotifier(ReceiptConnectionMode.systemPrinter);
  static final ValueNotifier<String?> bluetoothPrinterName =
      ValueNotifier<String?>(null);
  static String? preferredPrinterName;
  static String? bluetoothMacAddress;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    printPdfEnabled.value = prefs.getBool(_keyPrintPdfEnabled) ?? false;
    printerType.value = _parsePrinterType(
      prefs.getString(_keyPrinterType),
    );
    billPdfIncludeLogos.value =
        prefs.getBool(_keyBillPdfIncludeLogos) ?? false;
    preferredPrinterName = prefs.getString(_keyPreferredPrinterName);
    connectionMode.value = _parseConnectionMode(
      prefs.getString(_keyConnectionMode),
    );
    bluetoothMacAddress = prefs.getString(_keyBluetoothMac);
    bluetoothPrinterName.value = prefs.getString(_keyBluetoothName);
  }

  static Future<void> setPreferredPrinterName(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(_keyPreferredPrinterName);
      preferredPrinterName = null;
      return;
    }
    await prefs.setString(_keyPreferredPrinterName, trimmed);
    preferredPrinterName = trimmed;
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

  static Future<ReceiptConnectionMode> getConnectionMode() async {
    final prefs = await SharedPreferences.getInstance();
    return _parseConnectionMode(prefs.getString(_keyConnectionMode));
  }

  static Future<void> setConnectionMode(ReceiptConnectionMode value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyConnectionMode, value.name);
    connectionMode.value = value;
  }

  static Future<void> setBluetoothPrinter({
    required String name,
    required String macAddress,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBluetoothMac, macAddress);
    await prefs.setString(_keyBluetoothName, name);
    bluetoothMacAddress = macAddress;
    bluetoothPrinterName.value = name;
  }

  static Future<void> clearBluetoothPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBluetoothMac);
    await prefs.remove(_keyBluetoothName);
    bluetoothMacAddress = null;
    bluetoothPrinterName.value = null;
  }

  static ReceiptConnectionMode _parseConnectionMode(String? raw) {
    return ReceiptConnectionMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => ReceiptConnectionMode.systemPrinter,
    );
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
      orElse: () => PosPrinterType.rugtek80,
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
      case PosPrinterType.rugtek80:
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
    if (lower.contains('rugtek') ||
        lower.contains('rug tek') ||
        lower.contains('rp326') ||
        lower.contains('rp327') ||
        lower.contains('rp328') ||
        lower.contains('rongta')) {
      return false;
    }
    return lower.contains('tvs') ||
        lower.contains('rp-') ||
        lower.contains('rp ') ||
        lower.contains('lp-') ||
        lower.contains('lp ') ||
        lower.contains('mlp');
  }

  static bool isRugtekPrinterName(String name) {
    final lower = name.toLowerCase();
    return lower.contains('rugtek') ||
        lower.contains('rug tek') ||
        lower.contains('rp326') ||
        lower.contains('rp-326') ||
        lower.contains('rp 326') ||
        lower.contains('rp327') ||
        lower.contains('rp328') ||
        isRongtaPrinterName(name);
  }

  static bool isRongtaPrinterName(String name) {
    final lower = name.toLowerCase();
    return lower.contains('rongta') || lower.contains('rong ta');
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
    return isTvsPrinterName(name) ||
        isRugtekPrinterName(name) ||
        isEpsonPrinterName(name) ||
        name.toLowerCase().contains('thermal') ||
        name.toLowerCase().contains('receipt');
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
    return printers.where((p) => !isVirtualPrinterName(p.name)).toList();
  }

  static bool _matchesSettingsType(Printer printer, PosPrinterType type) {
    switch (type) {
      case PosPrinterType.tvs80:
        return isTvsPrinterName(printer.name);
      case PosPrinterType.rugtek80:
        return isRugtekPrinterName(printer.name);
      case PosPrinterType.narrow58:
        return isThermalReceiptPrinterName(printer.name);
      case PosPrinterType.generic80:
        return isThermalReceiptPrinterName(printer.name);
    }
  }

  static void _addCandidate(Printer printer, List<Printer> ordered, Set<String> seen) {
    if (seen.contains(printer.name)) return;
    seen.add(printer.name);
    ordered.add(printer);
  }

  /// Ordered candidates for silent receipt printing (best match first).
  static List<Printer> receiptPrinterCandidates(
    List<Printer> printers, {
    PosPrinterType type = PosPrinterType.rugtek80,
  }) {
    final candidates = physicalPrinters(printers);
    if (candidates.isEmpty) return const [];

    final ordered = <Printer>[];
    final seen = <String>{};

    final saved = preferredPrinterName;
    if (saved != null && saved.isNotEmpty) {
      for (final printer in candidates) {
        if (printer.name == saved) {
          _addCandidate(printer, ordered, seen);
          break;
        }
      }
    }

    for (final printer in candidates) {
      if (printer.isDefault && _matchesSettingsType(printer, type)) {
        _addCandidate(printer, ordered, seen);
      }
    }

    for (final printer in candidates) {
      if (isRugtekPrinterName(printer.name)) {
        _addCandidate(printer, ordered, seen);
      }
    }
    for (final printer in candidates) {
      if (isEpsonPrinterName(printer.name)) {
        _addCandidate(printer, ordered, seen);
      }
    }
    if (type == PosPrinterType.tvs80) {
      for (final printer in candidates) {
        if (isTvsPrinterName(printer.name)) {
          _addCandidate(printer, ordered, seen);
        }
      }
    }
    for (final printer in candidates) {
      if (isThermalReceiptPrinterName(printer.name)) {
        _addCandidate(printer, ordered, seen);
      }
    }
    for (final printer in candidates) {
      if (printer.isDefault) {
        _addCandidate(printer, ordered, seen);
      }
    }
    for (final printer in candidates) {
      if (_matchesSettingsType(printer, type)) {
        _addCandidate(printer, ordered, seen);
      }
    }
    if (ordered.isEmpty && candidates.length == 1) {
      _addCandidate(candidates.first, ordered, seen);
    }

    return ordered;
  }

  static bool hasReceiptPrinter(
    List<Printer> printers, {
    PosPrinterType type = PosPrinterType.rugtek80,
  }) {
    return receiptPrinterCandidates(printers, type: type).isNotEmpty;
  }

  /// Picks the best USB/network POS printer for one-shot printing.
  static Printer? pickReceiptPrinter(
    List<Printer> printers, {
    PosPrinterType type = PosPrinterType.rugtek80,
  }) {
    final candidates = receiptPrinterCandidates(printers, type: type);
    if (candidates.isEmpty) return null;
    return candidates.first;
  }
}
