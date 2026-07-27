import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/core/utils/platform_utils.dart';
import 'package:demo/features/settings/services/export_excel_io.dart'
    if (dart.library.html) 'package:demo/features/settings/services/export_excel_io_web.dart';
import 'package:demo/features/settings/utils/export_date_range.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class ItemSalesRow {
  const ItemSalesRow({
    required this.itemName,
    required this.quantitySold,
  });

  final String itemName;
  final int quantitySold;
}

class ItemSalesReportData {
  const ItemSalesReportData({
    required this.range,
    required this.rows,
    required this.transactionCount,
    required this.totalQuantitySold,
  });

  final ExportDateRange range;
  final List<ItemSalesRow> rows;
  final int transactionCount;
  final int totalQuantitySold;
}

class ExportExcelService {
  static final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

  /// Loads transactions in [range] and aggregates sold qty per item name.
  static Future<ItemSalesReportData> loadItemSales(
    ExportDateRange range,
  ) async {
    final docs = await _fetchTransactions(range);
    if (docs.isEmpty) {
      throw ExportException('No transactions found for ${range.label}.');
    }

    final totals = <String, int>{};
    for (final doc in docs) {
      final items = doc.data()['items'] as List<dynamic>? ?? const [];
      for (final raw in items) {
        if (raw is! Map) continue;
        final name = raw['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final qty = _asInt(raw['qty']);
        if (qty <= 0) continue;
        totals[name] = (totals[name] ?? 0) + qty;
      }
    }

    if (totals.isEmpty) {
      throw ExportException(
        'No sold items found in transactions for ${range.label}.',
      );
    }

    final rows = totals.entries
        .map(
          (e) => ItemSalesRow(itemName: e.key, quantitySold: e.value),
        )
        .toList()
      ..sort((a, b) {
        final byQty = b.quantitySold.compareTo(a.quantitySold);
        if (byQty != 0) return byQty;
        return a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase());
      });

    final totalQuantitySold = rows.fold<int>(
      0,
      (acc, row) => acc + row.quantitySold,
    );

    return ItemSalesReportData(
      range: range,
      rows: rows,
      transactionCount: docs.length,
      totalQuantitySold: totalQuantitySold,
    );
  }

  static Future<String> exportItemSales(
    ExportDateRange range, {
    ItemSalesReportData? report,
  }) async {
    final data = report ?? await loadItemSales(range);

    final excel = Excel.createExcel();
    final defaultName = excel.sheets.keys.first;
    excel.rename(defaultName, 'Item Sales');
    final sheet = excel['Item Sales']!;

    sheet.appendRow([
      TextCellValue('Item Sales Report'),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    sheet.appendRow([
      TextCellValue('Date range'),
      TextCellValue(data.range.label),
      TextCellValue(''),
    ]);
    sheet.appendRow([
      TextCellValue('Transactions'),
      IntCellValue(data.transactionCount),
      TextCellValue(''),
    ]);
    sheet.appendRow([]);
    _appendHeaderRow(sheet, ['Item Name', 'Quantity Sold']);

    for (final row in data.rows) {
      sheet.appendRow([
        TextCellValue(row.itemName),
        IntCellValue(row.quantitySold),
      ]);
    }

    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue('TOTAL'),
      IntCellValue(data.totalQuantitySold),
    ]);

    return _deliverWorkbook(
      excel,
      fileName: 'item_sales_${_fileSuffix(range)}.xlsx',
      subject: 'Item Sales ${range.label}',
    );
  }

  static Future<String> exportTransactions(ExportDateRange range) async {
    final docs = await _fetchTransactions(range);
    if (docs.isEmpty) {
      throw ExportException('No transactions found for ${range.label}.');
    }

    final excel = Excel.createExcel();
    final defaultName = excel.sheets.keys.first;
    excel.rename(defaultName, 'Transactions');
    final sheet = excel['Transactions']!;

    _appendHeaderRow(sheet, [
      'Date & Time',
      'Table',
      'Items',
      'Subtotal',
      'Tax',
      'Discount',
      'Total',
      'Cash',
      'Online',
    ]);

    var totalRevenue = 0;
    var totalCash = 0;
    var totalOnline = 0;

    for (final doc in docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final table = data['table']?.toString() ?? '';
      final subtotal = _asInt(data['subtotal']);
      final tax = _asInt(data['tax']);
      final discount = _asInt(data['discount']);
      final total = _asInt(data['total']);
      final cash = _asInt(data['cashAmount']);
      final online = _asInt(data['onlineAmount']);

      totalRevenue += total;
      totalCash += cash;
      totalOnline += online;

      sheet.appendRow([
        TextCellValue(
          createdAt != null ? _dateTimeFmt.format(createdAt) : '',
        ),
        TextCellValue(table),
        TextCellValue(_formatItems(data['items'])),
        IntCellValue(subtotal),
        IntCellValue(tax),
        IntCellValue(discount),
        IntCellValue(total),
        IntCellValue(cash),
        IntCellValue(online),
      ]);
    }

    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue('TOTAL'),
      TextCellValue(''),
      TextCellValue('${docs.length} transaction(s)'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      IntCellValue(totalRevenue),
      IntCellValue(totalCash),
      IntCellValue(totalOnline),
    ]);

    return _deliverWorkbook(
      excel,
      fileName: 'transactions_${_fileSuffix(range)}.xlsx',
      subject: 'Transactions ${range.label}',
    );
  }

  static Future<String> exportExpenses(ExportDateRange range) async {
    final docs = await _fetchExpenses(range);
    if (docs.isEmpty) {
      throw ExportException('No expenses found for ${range.label}.');
    }

    final excel = Excel.createExcel();
    final defaultName = excel.sheets.keys.first;
    excel.rename(defaultName, 'Expenses');
    final sheet = excel['Expenses']!;

    _appendHeaderRow(sheet, [
      'Date & Time',
      'Title',
      'Category',
      'Amount',
      'Note',
    ]);

    var totalAmount = 0.0;

    for (final doc in docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final title = data['title']?.toString() ?? '';
      final category = data['category']?.toString() ?? '';
      final note = data['note']?.toString() ?? '';
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      totalAmount += amount;

      sheet.appendRow([
        TextCellValue(
          createdAt != null ? _dateTimeFmt.format(createdAt) : '',
        ),
        TextCellValue(title),
        TextCellValue(category),
        DoubleCellValue(amount),
        TextCellValue(note),
      ]);
    }

    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue('TOTAL'),
      TextCellValue('${docs.length} record(s)'),
      TextCellValue(''),
      DoubleCellValue(totalAmount),
      TextCellValue(''),
    ]);

    return _deliverWorkbook(
      excel,
      fileName: 'expenses_${_fileSuffix(range)}.xlsx',
      subject: 'Expenses ${range.label}',
    );
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _fetchTransactions(ExportDateRange range) async {
    final snapshot = await FirestorePaths
        .scoped('transactions')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.from),
        )
        .where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(range.to),
        )
        .orderBy('createdAt', descending: false)
        .get();
    return snapshot.docs;
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _fetchExpenses(ExportDateRange range) async {
    final snapshot = await FirestorePaths
        .scoped('expenses')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.from),
        )
        .where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(range.to),
        )
        .orderBy('createdAt', descending: false)
        .get();
    return snapshot.docs;
  }

  static void _appendHeaderRow(Sheet sheet, List<String> headers) {
    sheet.appendRow(headers.map(TextCellValue.new).toList());
  }

  static String _formatItems(dynamic itemsRaw) {
    final items = itemsRaw as List<dynamic>? ?? [];
    if (items.isEmpty) return '';

    final parts = <String>[];
    for (final item in items) {
      if (item is! Map) continue;
      final name = item['name']?.toString() ?? '';
      final qty = _asInt(item['qty']);
      final price = _asInt(item['price']);
      final remarks = item['remarks']?.toString() ?? '';
      var line = '${qty}x $name @ ₹$price';
      if (remarks.isNotEmpty) line += ' ($remarks)';
      parts.add(line);
    }
    return parts.join('; ');
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _fileSuffix(ExportDateRange range) {
    final fmt = DateFormat('yyyyMMdd');
    return '${fmt.format(range.from)}_${fmt.format(range.to)}';
  }

  static Future<String> _deliverWorkbook(
    Excel excel, {
    required String fileName,
    required String subject,
  }) async {
    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw ExportException('Could not generate Excel file.');
    }

    final data = Uint8List.fromList(bytes);

    if (kIsWeb) {
      return _deliverWorkbookWeb(data, fileName: fileName, subject: subject);
    }
    if (isDesktopPlatform) {
      return _deliverWorkbookDesktop(data, fileName: fileName, subject: subject);
    }
    return _deliverWorkbookMobile(data, fileName: fileName, subject: subject);
  }

  static Future<String> _deliverWorkbookDesktop(
    Uint8List bytes, {
    required String fileName,
    required String subject,
  }) async {
    final savedPath = await saveExportExcelWithDialog(bytes, fileName);
    if (savedPath == null) {
      throw ExportException('Export cancelled.');
    }

    await _shareSavedFile(
      XFile(savedPath, mimeType: exportXlsxMime, name: fileName),
      subject: subject,
    );

    return savedPath;
  }

  static Future<String> _deliverWorkbookMobile(
    Uint8List bytes, {
    required String fileName,
    required String subject,
  }) async {
    final path = await writeExportExcelTempFile(bytes, fileName);
    await _shareSavedFile(
      XFile(path, mimeType: exportXlsxMime, name: fileName),
      subject: subject,
    );
    return path;
  }

  static Future<String> _deliverWorkbookWeb(
    Uint8List bytes, {
    required String fileName,
    required String subject,
  }) async {
    final savedName = await saveExportExcelWithDialog(bytes, fileName);
    if (savedName == null) {
      throw ExportException('Could not download Excel file.');
    }

    await _shareSavedFile(
      XFile.fromData(
        bytes,
        name: fileName,
        mimeType: exportXlsxMime,
      ),
      subject: subject,
    );

    return savedName;
  }

  static Future<void> _shareSavedFile(
    XFile file, {
    required String subject,
  }) async {
    // Do not pass [text] with files — on Windows it shares text only and drops
    // the Excel attachment.
    await Share.shareXFiles(
      [file],
      subject: subject,
    );
  }
}

class ExportException implements Exception {
  final String message;
  ExportException(this.message);

  @override
  String toString() => message;
}
