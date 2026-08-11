import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:intl/intl.dart';

class StockMovementReportPage extends StatefulWidget {
  const StockMovementReportPage({super.key});

  @override
  State<StockMovementReportPage> createState() =>
      _StockMovementReportPageState();
}

class _StockMovementReportPageState extends State<StockMovementReportPage>
    with InventoryReportDateMixin {
  final _searchController = TextEditingController();
  List<InventoryMovementRecord> _rows = [];
  List<String> _categories = [];
  String? _category;
  InventoryMovementType? _movementType;
  String _search = '';
  bool _loading = false;
  bool _exporting = false;
  bool _hasMore = false;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  static final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

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

  Future<void> _load({bool loadMore = false}) async {
    setState(() => _loading = true);
    try {
      final page = await Get.find<InventoryReportsRepository>().loadStockMovements(
        range: range,
        category: _category,
        movementType: _movementType,
        startAfter: loadMore ? _lastDoc : null,
      );
      var rows = page.records;
      if (_search.trim().isNotEmpty) {
        final q = _search.trim().toLowerCase();
        rows = rows
            .where((r) => r.itemName.toLowerCase().contains(q))
            .toList();
      }
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _rows = [..._rows, ...rows];
        } else {
          _rows = rows;
        }
        _hasMore = page.hasMore;
        _lastDoc = page.lastDocument;
      });
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _exporting = true);
    try {
      await InventoryExportService.exportStockMovements(
        range: range,
        rows: _rows,
        filters: {
          if (_search.isNotEmpty) 'Search': _search,
          if (_category != null) 'Category': _category!,
          if (_movementType != null) 'Movement': _movementType!.label,
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
      reportTitle: 'Stock Movement Report',
      range: range,
      filters: {
        if (_search.isNotEmpty) 'Search': _search,
        if (_category != null) 'Category': _category!,
        if (_movementType != null) 'Movement': _movementType!.label,
      },
      headers: [
        'Date',
        'Item',
        'Type',
        'Qty',
        'Prev',
        'Current',
        'Reason',
        'By',
      ],
      rows: _rows
          .map(
            (r) => [
              r.createdAt != null ? _dateTimeFmt.format(r.createdAt!) : '',
              r.itemName,
              r.movementType.label,
              formatInventoryQuantity(r.quantity),
              formatInventoryQuantity(r.previousStock),
              formatInventoryQuantity(r.currentStock),
              r.reason ?? '',
              r.addedBy,
            ],
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InventoryReportScaffold(
      title: 'Stock Movement',
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
            onGenerate: () => _load(),
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
                    child: DropdownButtonFormField<InventoryMovementType?>(
                      value: _movementType,
                      decoration: const InputDecoration(
                        labelText: 'Movement',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All')),
                        ...InventoryMovementType.values.map(
                          (t) =>
                              DropdownMenuItem(value: t, child: Text(t.label)),
                        ),
                      ],
                      onChanged: _loading
                          ? null
                          : (v) {
                              setState(() => _movementType = v);
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
                      _loading ? 'Loading…' : 'Generate report to view movements.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: _rows.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _rows.length) {
                        return TextButton(
                          onPressed: _loading ? null : () => _load(loadMore: true),
                          child: const Text('Load more'),
                        );
                      }
                      final row = _rows[index];
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
                                Text(
                                  row.movementType.label,
                                  style: const TextStyle(
                                    fontFamily: fontMulishSemiBold,
                                    color: InventoryReportColors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              row.createdAt != null
                                  ? _dateTimeFmt.format(row.createdAt!)
                                  : '—',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Qty ${formatInventoryQuantity(row.quantity)} · '
                              'Prev ${formatInventoryQuantity(row.previousStock)} → '
                              'Now ${formatInventoryQuantity(row.currentStock)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if ((row.reason ?? '').isNotEmpty)
                              Text('Reason: ${row.reason}',
                                  style: const TextStyle(fontSize: 12)),
                            Text('By: ${row.addedBy}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade600)),
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
}
