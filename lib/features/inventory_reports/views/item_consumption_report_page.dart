import 'package:smartKitchen/features/inventory_reports/models/inventory_models.dart';
import 'package:smartKitchen/features/inventory_reports/repositories/inventory_reports_repository.dart';
import 'package:smartKitchen/features/inventory_reports/services/inventory_export_service.dart';
import 'package:smartKitchen/features/inventory_reports/services/inventory_report_pdf_service.dart';
import 'package:smartKitchen/features/inventory_reports/utils/inventory_report_date_mixin.dart';
import 'package:smartKitchen/features/inventory_reports/widgets/inventory_report_widgets.dart';
import 'package:smartKitchen/features/settings/services/export_excel_service.dart';
import 'package:smartKitchen/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ItemConsumptionReportPage extends StatefulWidget {
  const ItemConsumptionReportPage({super.key});

  @override
  State<ItemConsumptionReportPage> createState() =>
      _ItemConsumptionReportPageState();
}

class _ItemConsumptionReportPageState extends State<ItemConsumptionReportPage>
    with InventoryReportDateMixin {
  final _searchController = TextEditingController();
  List<ItemConsumptionRow> _rows = [];
  List<String> _categories = [];
  String? _category;
  String _search = '';
  ConsumptionSortOption _sort = ConsumptionSortOption.highestConsumption;
  bool _loading = false;
  bool _exporting = false;

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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Get.find<InventoryReportsRepository>().loadItemConsumption(
        range,
        sort: _sort,
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
      await InventoryExportService.exportItemConsumption(
        range: range,
        rows: _rows,
        filters: {
          if (_search.isNotEmpty) 'Search': _search,
          if (_category != null) 'Category': _category!,
          'Sort': _sort.label,
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
      reportTitle: 'Item Consumption Report',
      range: range,
      filters: {
        if (_search.isNotEmpty) 'Search': _search,
        if (_category != null) 'Category': _category!,
        'Sort': _sort.label,
      },
      headers: [
        'Item',
        'Category',
        'Qty',
        'Revenue',
        'Est. Cost',
        'Gross Profit',
      ],
      rows: _rows
          .map(
            (r) => [
              r.itemName,
              r.category,
              '${r.quantityConsumed}',
              _currency.format(r.revenue),
              _currency.format(r.estimatedCost),
              _currency.format(r.grossProfit),
            ],
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InventoryReportScaffold(
      title: 'Item Consumption',
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
                    child: DropdownButtonFormField<ConsumptionSortOption>(
                      value: _sort,
                      decoration: const InputDecoration(
                        labelText: 'Sort by',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: ConsumptionSortOption.values
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.label, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: _loading
                          ? null
                          : (v) {
                              if (v == null) return;
                              setState(() => _sort = v);
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
                      _loading ? 'Loading…' : 'Generate report to view consumption.',
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
                              row.category,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Qty ${row.quantityConsumed} · '
                              'Revenue ${_currency.format(row.revenue)} · '
                              'Profit ${_currency.format(row.grossProfit)}',
                              style: const TextStyle(fontSize: 12),
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
}
