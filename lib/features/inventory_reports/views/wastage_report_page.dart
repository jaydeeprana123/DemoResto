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

class WastageReportPage extends StatefulWidget {
  const WastageReportPage({super.key});

  @override
  State<WastageReportPage> createState() => _WastageReportPageState();
}

class _WastageReportPageState extends State<WastageReportPage>
    with InventoryReportDateMixin {
  final _searchController = TextEditingController();
  List<InventoryMovementRecord> _rows = [];
  List<String> _categories = [];
  String? _category;
  String _search = '';
  bool _loading = false;
  bool _exporting = false;

  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

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

  double get _totalCost =>
      _rows.fold(0.0, (sum, r) => sum + r.totalCost);

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows =
          await Get.find<InventoryReportsRepository>().loadWastageReport(
        range: range,
        search: _search,
        category: _category,
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
      await InventoryExportService.exportWastage(
        range: range,
        rows: _rows,
        filters: {
          if (_search.isNotEmpty) 'Search': _search,
          if (_category != null) 'Category': _category!,
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
      reportTitle: 'Wastage Report',
      range: range,
      filters: {
        if (_search.isNotEmpty) 'Search': _search,
        if (_category != null) 'Category': _category!,
      },
      headers: ['Date', 'Item', 'Qty', 'Reason', 'Cost', 'By'],
      rows: _rows
          .map(
            (r) => [
              r.createdAt != null ? _dateFmt.format(r.createdAt!) : '',
              r.itemName,
              formatInventoryQuantity(r.quantity),
              r.wastageReason?.label ?? r.reason ?? '',
              _currency.format(r.totalCost),
              r.addedBy,
            ],
          )
          .toList(),
      summaryLines: ['Total Wastage Cost: ${_currency.format(_totalCost)}'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return InventoryReportScaffold(
      title: 'Wastage Report',
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
              hint: 'Search item or reason…',
              onChanged: (v) => setState(() => _search = v),
              onClear: () {
                _searchController.clear();
                setState(() => _search = '');
                _load();
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
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
          ],
          Expanded(
            child: _rows.isEmpty
                ? Center(
                    child: Text(
                      _loading ? 'Loading…' : 'Generate report to view wastage.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: _rows.length,
                    itemBuilder: (context, index) {
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
                            Text(
                              row.itemName,
                              style: const TextStyle(
                                fontFamily: fontMulishBold,
                                color: InventoryReportColors.navy,
                              ),
                            ),
                            Text(
                              row.createdAt != null
                                  ? _dateFmt.format(row.createdAt!)
                                  : '—',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${formatInventoryQuantity(row.quantity)} ${row.unit ?? 'pcs'} · '
                              '${row.wastageReason?.label ?? row.reason ?? '—'} · '
                              '${_currency.format(row.totalCost)}',
                            ),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Text(
                'Total Wastage Cost: ${_currency.format(_totalCost)}',
                style: const TextStyle(
                  fontFamily: fontMulishBold,
                  color: InventoryReportColors.navy,
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
