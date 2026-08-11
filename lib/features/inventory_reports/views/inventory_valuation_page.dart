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
import 'package:intl/intl.dart';

class InventoryValuationPage extends StatefulWidget {
  const InventoryValuationPage({super.key});

  @override
  State<InventoryValuationPage> createState() => _InventoryValuationPageState();
}

class _InventoryValuationPageState extends State<InventoryValuationPage> {
  final _searchController = TextEditingController();
  List<ValuationRow> _rows = [];
  List<String> _categories = [];
  String? _category;
  String _search = '';
  bool _loading = false;
  bool _exporting = false;

  static final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

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

  double get _totalValue =>
      _rows.fold(0.0, (sum, r) => sum + r.totalValue);

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Get.find<InventoryReportsRepository>().loadValuationReport(
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
      await InventoryExportService.exportValuation(
        rows: _rows,
        totalValue: _totalValue,
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
      reportTitle: 'Inventory Valuation',
      range: null,
      filters: {
        if (_search.isNotEmpty) 'Search': _search,
        if (_category != null) 'Category': _category!,
      },
      headers: ['Item', 'Qty', 'Unit', 'Cost/Unit', 'Total Value'],
      rows: _rows
          .map(
            (r) => [
              r.itemName,
              formatInventoryQuantity(r.currentQuantity),
              r.unit,
              _currency.format(r.costPerUnit),
              _currency.format(r.totalValue),
            ],
          )
          .toList(),
      summaryLines: [
        'Total Inventory Value: ${_currency.format(_totalValue)}',
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return InventoryReportScaffold(
      title: 'Inventory Valuation',
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
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? Center(
                        child: Text(
                          'No inventory items found.',
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
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row.itemName,
                                          style: const TextStyle(
                                            fontFamily: fontMulishBold,
                                            color: InventoryReportColors.navy,
                                          ),
                                        ),
                                        Text(
                                          '${formatInventoryQuantity(row.currentQuantity)} ${row.unit} · '
                                          '${_currency.format(row.costPerUnit)}/unit',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _currency.format(row.totalValue),
                                    style: const TextStyle(
                                      fontFamily: fontMulishBold,
                                      color: InventoryReportColors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Text(
              'Total Inventory Value: ${_currency.format(_totalValue)}',
              style: const TextStyle(
                fontFamily: fontMulishBold,
                fontSize: 15,
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
