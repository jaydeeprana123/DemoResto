import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smartKitchen/core/utils/platform_utils.dart';
import 'package:smartKitchen/features/inventory_reports/models/inventory_models.dart';
import 'package:smartKitchen/features/settings/services/export_excel_io.dart'
    if (dart.library.html) 'package:smartKitchen/features/settings/services/export_excel_io_web.dart';
import 'package:smartKitchen/features/settings/services/export_excel_service.dart';
import 'package:smartKitchen/features/settings/utils/export_date_range.dart';

class InventoryExportService {
  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

  static Future<String> exportCurrentStock({
    required ExportDateRange range,
    required List<CurrentStockRow> rows,
    String? search,
    String? category,
    InventoryStockStatus? status,
  }) {
    final excel = _baseWorkbook('Current Stock');
    final sheet = excel['Current Stock']!;
    _metaRows(sheet, 'Current Stock Report', range, {
      if (search != null && search.isNotEmpty) 'Search': search,
      if (category != null && category.isNotEmpty) 'Category': category,
      if (status != null) 'Status': status.label,
    });
    _appendHeaderRow(sheet, [
      'Item Name',
      'Category',
      'Opening Stock',
      'Stock In',
      'Used',
      'Wastage',
      'Adjustment',
      'Current Stock',
      'Minimum Stock',
      'Status',
    ]);
    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(row.itemName),
        TextCellValue(row.category),
        DoubleCellValue(row.openingStock),
        DoubleCellValue(row.stockIn),
        DoubleCellValue(row.stockUsed),
        DoubleCellValue(row.wastage),
        DoubleCellValue(row.adjustment),
        DoubleCellValue(row.currentStock),
        DoubleCellValue(row.minimumStock),
        TextCellValue(row.status.label),
      ]);
    }
    return _deliver(excel, 'current_stock_${_suffix(range)}.xlsx', range);
  }

  static Future<String> exportStockMovements({
    required ExportDateRange range,
    required List<InventoryMovementRecord> rows,
    Map<String, String> filters = const {},
  }) {
    final excel = _baseWorkbook('Stock Movement');
    final sheet = excel['Stock Movement']!;
    _metaRows(sheet, 'Stock Movement Report', range, filters);
    _appendHeaderRow(sheet, [
      'Date & Time',
      'Item',
      'Category',
      'Movement Type',
      'Quantity',
      'Previous Stock',
      'Current Stock',
      'Reason',
      'Added By',
    ]);
    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(
          row.createdAt != null ? _dateTimeFmt.format(row.createdAt!) : '',
        ),
        TextCellValue(row.itemName),
        TextCellValue(row.categoryName),
        TextCellValue(row.movementType.label),
        DoubleCellValue(row.quantity),
        DoubleCellValue(row.previousStock),
        DoubleCellValue(row.currentStock),
        TextCellValue(row.reason ?? ''),
        TextCellValue(row.addedBy),
      ]);
    }
    return _deliver(excel, 'stock_movement_${_suffix(range)}.xlsx', range);
  }

  static Future<String> exportStockIn({
    required ExportDateRange range,
    required List<InventoryMovementRecord> rows,
    Map<String, String> filters = const {},
  }) {
    final excel = _baseWorkbook('Stock In');
    final sheet = excel['Stock In']!;
    _metaRows(sheet, 'Stock In Report', range, filters);
    _appendHeaderRow(sheet, [
      'Date',
      'Item',
      'Category',
      'Supplier',
      'Quantity',
      'Unit',
      'Purchase Price',
      'Total Cost',
      'Invoice/Reference',
      'Added By',
    ]);
    var totalCost = 0.0;
    for (final row in rows) {
      final cost = row.totalCost;
      totalCost += cost;
      sheet.appendRow([
        TextCellValue(
          row.createdAt != null ? _dateFmt.format(row.createdAt!) : '',
        ),
        TextCellValue(row.itemName),
        TextCellValue(row.categoryName),
        TextCellValue(row.supplier ?? ''),
        DoubleCellValue(row.quantity),
        TextCellValue(row.unit ?? ''),
        DoubleCellValue(row.purchasePrice ?? 0),
        DoubleCellValue(cost),
        TextCellValue(row.invoiceNumber ?? ''),
        TextCellValue(row.addedBy),
      ]);
    }
    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue('TOTAL COST'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totalCost),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    return _deliver(excel, 'stock_in_${_suffix(range)}.xlsx', range);
  }

  static Future<String> exportWastage({
    required ExportDateRange range,
    required List<InventoryMovementRecord> rows,
    Map<String, String> filters = const {},
  }) {
    final excel = _baseWorkbook('Wastage');
    final sheet = excel['Wastage']!;
    _metaRows(sheet, 'Wastage Report', range, filters);
    _appendHeaderRow(sheet, [
      'Date',
      'Item',
      'Category',
      'Quantity',
      'Unit',
      'Reason',
      'Cost',
      'Added By',
    ]);
    var totalCost = 0.0;
    for (final row in rows) {
      final cost = row.totalCost;
      totalCost += cost;
      sheet.appendRow([
        TextCellValue(
          row.createdAt != null ? _dateFmt.format(row.createdAt!) : '',
        ),
        TextCellValue(row.itemName),
        TextCellValue(row.categoryName),
        DoubleCellValue(row.quantity),
        TextCellValue(row.unit ?? ''),
        TextCellValue(row.wastageReason?.label ?? row.reason ?? ''),
        DoubleCellValue(cost),
        TextCellValue(row.addedBy),
      ]);
    }
    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue('TOTAL WASTAGE COST'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totalCost),
      TextCellValue(''),
    ]);
    return _deliver(excel, 'wastage_${_suffix(range)}.xlsx', range);
  }

  static Future<String> exportLowStock({
    required List<LowStockRow> rows,
    Map<String, String> filters = const {},
  }) {
    final excel = _baseWorkbook('Low Stock');
    final sheet = excel['Low Stock']!;
    sheet.appendRow([TextCellValue('Low Stock Report')]);
    for (final entry in filters.entries) {
      sheet.appendRow([TextCellValue(entry.key), TextCellValue(entry.value)]);
    }
    sheet.appendRow([]);
    _appendHeaderRow(sheet, [
      'Item Name',
      'Category',
      'Current Stock',
      'Minimum Stock',
      'Unit',
      'Reorder Qty',
      'Status',
    ]);
    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(row.itemName),
        TextCellValue(row.category),
        DoubleCellValue(row.currentStock),
        DoubleCellValue(row.minimumStock),
        TextCellValue(row.unit),
        DoubleCellValue(row.reorderQuantity),
        TextCellValue(row.status.label),
      ]);
    }
    return _deliver(excel, 'low_stock_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx', null);
  }

  static Future<String> exportValuation({
    required List<ValuationRow> rows,
    required double totalValue,
    Map<String, String> filters = const {},
  }) {
    final excel = _baseWorkbook('Valuation');
    final sheet = excel['Valuation']!;
    sheet.appendRow([TextCellValue('Inventory Valuation')]);
    for (final entry in filters.entries) {
      sheet.appendRow([TextCellValue(entry.key), TextCellValue(entry.value)]);
    }
    sheet.appendRow([]);
    _appendHeaderRow(sheet, [
      'Item',
      'Current Quantity',
      'Unit',
      'Cost Per Unit',
      'Total Value',
    ]);
    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(row.itemName),
        DoubleCellValue(row.currentQuantity),
        TextCellValue(row.unit),
        DoubleCellValue(row.costPerUnit),
        DoubleCellValue(row.totalValue),
      ]);
    }
    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue('TOTAL INVENTORY VALUE'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totalValue),
    ]);
    return _deliver(excel, 'inventory_valuation_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx', null);
  }

  static Future<String> exportItemConsumption({
    required ExportDateRange range,
    required List<ItemConsumptionRow> rows,
    Map<String, String> filters = const {},
  }) {
    final excel = _baseWorkbook('Item Consumption');
    final sheet = excel['Item Consumption']!;
    _metaRows(sheet, 'Item Consumption Report', range, filters);
    _appendHeaderRow(sheet, [
      'Item Name',
      'Category',
      'Quantity Sold/Consumed',
      'Revenue',
      'Estimated Cost',
      'Gross Profit',
    ]);
    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(row.itemName),
        TextCellValue(row.category),
        DoubleCellValue(row.quantityConsumed),
        DoubleCellValue(row.revenue),
        DoubleCellValue(row.estimatedCost),
        DoubleCellValue(row.grossProfit),
      ]);
    }
    return _deliver(excel, 'item_consumption_${_suffix(range)}.xlsx', range);
  }

  static Future<String> exportDashboard({
    required InventoryDashboardData data,
  }) {
    final excel = _baseWorkbook('Dashboard');
    final sheet = excel['Dashboard']!;
    _metaRows(sheet, 'Inventory Dashboard', data.range, {});
    sheet.appendRow([TextCellValue('Metric'), TextCellValue('Value')]);
    sheet.appendRow([TextCellValue('Total Items'), IntCellValue(data.totalItems)]);
    sheet.appendRow([TextCellValue('Low Stock Items'), IntCellValue(data.lowStockItems)]);
    sheet.appendRow([TextCellValue('Out of Stock Items'), IntCellValue(data.outOfStockItems)]);
    sheet.appendRow([
      TextCellValue('Total Inventory Value'),
      DoubleCellValue(data.totalInventoryValue),
    ]);
    sheet.appendRow([TextCellValue('Stock In (period)'), DoubleCellValue(data.stockInTotal)]);
    sheet.appendRow([TextCellValue('Stock Out (period)'), DoubleCellValue(data.stockOutTotal)]);
    sheet.appendRow([TextCellValue('Wastage Qty (period)'), DoubleCellValue(data.wastageTotal)]);
    sheet.appendRow([TextCellValue('Wastage Cost (period)'), DoubleCellValue(data.wastageCost)]);
    return _deliver(excel, 'inventory_dashboard_${_suffix(data.range)}.xlsx', data.range);
  }

  static Excel _baseWorkbook(String sheetName) {
    final excel = Excel.createExcel();
    final defaultName = excel.sheets.keys.first;
    excel.rename(defaultName, sheetName);
    return excel;
  }

  static void _metaRows(
    Sheet sheet,
    String title,
    ExportDateRange range,
    Map<String, String> filters,
  ) {
    sheet.appendRow([TextCellValue(title)]);
    sheet.appendRow([
      TextCellValue('Date Range'),
      TextCellValue('${_dateFmt.format(range.from)} - ${_dateFmt.format(range.to)}'),
    ]);
    for (final entry in filters.entries) {
      sheet.appendRow([TextCellValue(entry.key), TextCellValue(entry.value)]);
    }
    sheet.appendRow([]);
  }

  static void _appendHeaderRow(Sheet sheet, List<String> headers) {
    sheet.appendRow(headers.map(TextCellValue.new).toList());
  }

  static String _suffix(ExportDateRange range) {
    final fmt = DateFormat('yyyyMMdd');
    return '${fmt.format(range.from)}_${fmt.format(range.to)}';
  }

  static Future<String> _deliver(
    Excel excel,
    String fileName,
    ExportDateRange? range,
  ) async {
    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw ExportException('Could not generate Excel file.');
    }
    final data = Uint8List.fromList(bytes);
    final subject = range != null
        ? 'Inventory Report ${range.label}'
        : 'Inventory Report';

    if (kIsWeb) {
      final savedName = await saveExportExcelWithDialog(data, fileName);
      if (savedName == null) throw ExportException('Could not download file.');
      await Share.shareXFiles(
        [XFile.fromData(data, name: fileName, mimeType: exportXlsxMime)],
        subject: subject,
      );
      return savedName;
    }
    if (isDesktopPlatform) {
      final savedPath = await saveExportExcelWithDialog(data, fileName);
      if (savedPath == null) throw ExportException('Export cancelled.');
      await Share.shareXFiles(
        [XFile(savedPath, mimeType: exportXlsxMime, name: fileName)],
        subject: subject,
      );
      return savedPath;
    }
    final path = await writeExportExcelTempFile(data, fileName);
    await Share.shareXFiles(
      [XFile(path, mimeType: exportXlsxMime, name: fileName)],
      subject: subject,
    );
    return path;
  }
}
