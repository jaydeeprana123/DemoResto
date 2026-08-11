import 'package:smartKitchen/features/inventory_reports/models/inventory_models.dart';
import 'package:smartKitchen/features/inventory_reports/repositories/inventory_reports_repository.dart';
import 'package:smartKitchen/features/inventory_reports/services/inventory_export_service.dart';
import 'package:smartKitchen/features/inventory_reports/services/inventory_report_pdf_service.dart';
import 'package:smartKitchen/features/inventory_reports/utils/inventory_date_utils.dart';
import 'package:smartKitchen/features/inventory_reports/widgets/inventory_report_widgets.dart';
import 'package:smartKitchen/features/settings/services/export_excel_service.dart';
import 'package:smartKitchen/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LowStockReportPage extends StatefulWidget {
  const LowStockReportPage({super.key});

  @override
  State<LowStockReportPage> createState() => _LowStockReportPageState();
}

class _LowStockReportPageState extends State<LowStockReportPage> {
  final _searchController = TextEditingController();
  List<LowStockRow> _rows = [];
  List<String> _categories = [];
  String? _category;
  InventoryStockStatus? _status;
  String _search = '';
  bool _loading = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await Get.find<InventoryReportsRepository>().loadCategories();
    if (mounted) setState(() => _categories = cats);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Get.find<InventoryReportsRepository>().loadLowStockReport(
        search: _search,
        category: _category,
        statusFilter: _status,
      );
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _exporting = true);
    try {
      await InventoryExportService.exportLowStock(
        rows: _rows,
        filters: {
          if (_search.isNotEmpty) 'Search': _search,
          if (_category != null) 'Category': _category!,
          if (_status != null) 'Status': _status!.label,
        },
      );
    } on ExportException catch (e) {
      Get.snackbar('Export failed', e.message);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdf() async {
    await InventoryReportPdfService.printReport(
      reportTitle: 'Low Stock Report',
      range: null,
      filters: {
        if (_search.isNotEmpty) 'Search': _search,
        if (_category != null) 'Category': _category!,
        if (_status != null) 'Status': _status!.label,
      },
      headers: [
        'Item',
        'Category',
        'Current',
        'Minimum',
        'Unit',
        'Reorder',
        'Status',
      ],
      rows: _rows
          .map(
            (r) => [
              r.itemName,
              r.category,
              formatInventoryQuantity(r.currentStock),
              formatInventoryQuantity(r.minimumStock),
              r.unit,
              formatInventoryQuantity(r.reorderQuantity),
              r.status.label,
            ],
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InventoryReportScaffold(
      title: 'Low Stock Report',
      body: Column(
        children: [
          InventorySearchField(
            controller: _searchController,
            hint: 'Search item…',
            onChanged: (v) {
              setState(() => _search = v);
              _load();
            },
            onClear: () {
              _searchController.clear();
              setState(() => _search = '');
              _load();
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      ..._categories.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                    ],
                    onChanged: _loading
                        ? null
                        : (v) {
                            setState(() => _category = v);
                            _load();
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<InventoryStockStatus?>(
                    value: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      ...InventoryStockStatus.values
                          .where((s) => s != InventoryStockStatus.inStock)
                          .map(
                            (s) =>
                                DropdownMenuItem(value: s, child: Text(s.label)),
                          ),
                    ],
                    onChanged: _loading
                        ? null
                        : (v) {
                            setState(() => _status = v);
                            _load();
                          },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? Center(
                        child: Text(
                          'No low or out-of-stock items found.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : RefreshIndicator(
                        color: InventoryReportColors.orange,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: _rows.length,
                          itemBuilder: (context, index) {
                            final row = _rows[index];
                            final color = inventoryStatusColor(row.status);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          row.itemName,
                                          style: const TextStyle(
                                            fontFamily: fontMulishBold,
                                            color: InventoryReportColors.navy,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        row.status.label,
                                        style: TextStyle(
                                          fontFamily: fontMulishSemiBold,
                                          color: color,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(row.category,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600)),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Current ${formatInventoryQuantity(row.currentStock)} ${row.unit} · '
                                    'Min ${formatInventoryQuantity(row.minimumStock)} · '
                                    'Reorder ${formatInventoryQuantity(row.reorderQuantity)}',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
          if (_rows.isNotEmpty)
            InventoryExportBar(
              exporting: _exporting,
              onExportExcel: _exportExcel,
              onExportPdf: _exportPdf,
            ),
        ],
      ),
    );
  }
}
