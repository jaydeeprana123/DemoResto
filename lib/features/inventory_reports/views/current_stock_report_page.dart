import 'package:smartKitchen/features/inventory_reports/models/inventory_models.dart';
import 'package:smartKitchen/features/inventory_reports/repositories/inventory_reports_repository.dart';
import 'package:smartKitchen/features/inventory_reports/services/inventory_export_service.dart';
import 'package:smartKitchen/features/inventory_reports/services/inventory_report_pdf_service.dart';
import 'package:smartKitchen/features/inventory_reports/utils/inventory_date_utils.dart';
import 'package:smartKitchen/features/inventory_reports/utils/inventory_report_date_mixin.dart';
import 'package:smartKitchen/features/inventory_reports/widgets/inventory_report_widgets.dart';
import 'package:smartKitchen/features/settings/services/export_excel_service.dart';
import 'package:smartKitchen/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CurrentStockReportPage extends StatefulWidget {
  const CurrentStockReportPage({super.key});

  @override
  State<CurrentStockReportPage> createState() => _CurrentStockReportPageState();
}

class _CurrentStockReportPageState extends State<CurrentStockReportPage>
    with InventoryReportDateMixin {
  final _searchController = TextEditingController();
  List<CurrentStockRow> _rows = [];
  List<String> _categories = [];
  String? _category;
  InventoryStockStatus? _status;
  String _search = '';
  bool _loading = false;
  bool _exporting = false;
  int _page = 0;
  static const _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _loadCategories();
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
    setState(() {
      _loading = true;
      _page = 0;
    });
    try {
      final rows = await Get.find<InventoryReportsRepository>().loadCurrentStock(
        range: range,
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

  List<CurrentStockRow> get _pageRows {
    final end = ((_page + 1) * _pageSize).clamp(0, _rows.length);
    return _rows.sublist(0, end);
  }

  Future<void> _exportExcel() async {
    setState(() => _exporting = true);
    try {
      await InventoryExportService.exportCurrentStock(
        range: range,
        rows: _rows,
        search: _search,
        category: _category,
        status: _status,
      );
    } on ExportException catch (e) {
      Get.snackbar('Export failed', e.message);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdf() async {
    await InventoryReportPdfService.printReport(
      reportTitle: 'Current Stock Report',
      range: range,
      filters: {
        if (_search.isNotEmpty) 'Search': _search,
        if (_category != null) 'Category': _category!,
        if (_status != null) 'Status': _status!.label,
      },
      headers: [
        'Item',
        'Category',
        'Opening',
        'In',
        'Used',
        'Wastage',
        'Adj',
        'Current',
        'Min',
        'Status',
      ],
      rows: _rows
          .map(
            (r) => [
              r.itemName,
              r.category,
              formatInventoryQuantity(r.openingStock),
              formatInventoryQuantity(r.stockIn),
              formatInventoryQuantity(r.stockUsed),
              formatInventoryQuantity(r.wastage),
              formatInventoryQuantity(r.adjustment),
              formatInventoryQuantity(r.currentStock),
              formatInventoryQuantity(r.minimumStock),
              r.status.label,
            ],
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _pageRows;
    final hasMore = visible.length < _rows.length;

    return InventoryReportScaffold(
      title: 'Current Stock',
      body: Column(
        children: [
          InventoryDateFilterBar(
            quickFilter: quickFilter,
            range: range,
            loading: _loading,
            onQuickFilterChanged: (f) {
              applyQuickFilter(f);
              setState(() => _rows = []);
            },
            onPickFrom: () => pickDate(isFrom: true),
            onPickTo: () => pickDate(isFrom: false),
            onGenerate: _load,
          ),
          if (_rows.isNotEmpty) ...[
            InventorySearchField(
              controller: _searchController,
              hint: 'Search item…',
              onChanged: (v) => setState(() => _search = v),
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
                        ...InventoryStockStatus.values.map(
                          (s) => DropdownMenuItem(value: s, child: Text(s.label)),
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
          ],
          Expanded(
            child: _rows.isEmpty
                ? Center(
                    child: Text(
                      _loading ? 'Loading…' : 'Generate report to view stock.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: visible.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == visible.length) {
                        return TextButton(
                          onPressed: () => setState(() => _page++),
                          child: const Text('Load more'),
                        );
                      }
                      final row = visible[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: inventoryStatusColor(row.status)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    row.status.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: fontMulishSemiBold,
                                      color: inventoryStatusColor(row.status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(row.category,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                _chip('Opening', row.openingStock),
                                _chip('In', row.stockIn),
                                _chip('Used', row.stockUsed),
                                _chip('Wastage', row.wastage),
                                _chip('Adj', row.adjustment),
                                _chip('Current', row.currentStock, bold: true),
                                _chip('Min', row.minimumStock),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
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

  Widget _chip(String label, double value, {bool bold = false}) {
    return Text(
      '$label: ${formatInventoryQuantity(value)}',
      style: TextStyle(
        fontSize: 12,
        fontFamily: bold ? fontMulishBold : fontMulishRegular,
        color: bold ? InventoryReportColors.orange : Colors.grey.shade700,
      ),
    );
  }
}
