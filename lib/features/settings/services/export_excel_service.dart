import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:flutter/foundation.dart';
import 'package:demo/features/settings/utils/export_date_range.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportExcelService {
  static final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

  static Future<void> exportTransactions(ExportDateRange range) async {
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

    await _shareWorkbook(
      excel,
      fileName: 'transactions_${_fileSuffix(range)}.xlsx',
      subject: 'Transactions ${range.label}',
    );
  }

  static Future<void> exportExpenses(ExportDateRange range) async {
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

    await _shareWorkbook(
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

  static Future<void> _shareWorkbook(
    Excel excel, {
    required String fileName,
    required String subject,
  }) async {
    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw ExportException('Could not generate Excel file.');
    }

    final xFile = kIsWeb
        ? XFile.fromData(
            Uint8List.fromList(bytes),
            name: fileName,
            mimeType: _xlsxMime,
          )
        : XFile(
            await _writeTempFile(bytes, fileName),
            mimeType: _xlsxMime,
          );

    await Share.shareXFiles(
      [xFile],
      subject: subject,
      text: 'Flavor Flow export: $subject',
    );
  }

  static Future<String> _writeTempFile(List<int> bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  static const _xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
}

class ExportException implements Exception {
  final String message;
  ExportException(this.message);

  @override
  String toString() => message;
}
