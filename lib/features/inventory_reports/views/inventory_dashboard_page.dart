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

class InventoryDashboardPage extends StatefulWidget {
  const InventoryDashboardPage({super.key});

  @override
  State<InventoryDashboardPage> createState() => _InventoryDashboardPageState();
}

class _InventoryDashboardPageState extends State<InventoryDashboardPage>
    with InventoryReportDateMixin {
  InventoryDashboardData? _data;
  bool _loading = false;
  bool _exporting = false;

  static final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await Get.find<InventoryReportsRepository>().loadDashboard(range);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Error', e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportExcel() async {
    final data = _data;
    if (data == null) return;
    setState(() => _exporting = true);
    try {
      await InventoryExportService.exportDashboard(data: data);
    } on ExportException catch (e) {
      Get.snackbar('Export failed', e.message);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdf() async {
    final data = _data;
    if (data == null) return;
    await InventoryReportPdfService.printReport(
      reportTitle: 'Inventory Dashboard',
      range: data.range,
      headers: ['Metric', 'Value'],
      rows: [
        ['Total Items', '${data.totalItems}'],
        ['Low Stock Items', '${data.lowStockItems}'],
        ['Out of Stock Items', '${data.outOfStockItems}'],
        ['Total Inventory Value', _currency.format(data.totalInventoryValue)],
        ['Stock In', formatInventoryQuantity(data.stockInTotal)],
        ['Stock Out', formatInventoryQuantity(data.stockOutTotal)],
        ['Wastage Qty', formatInventoryQuantity(data.wastageTotal)],
        ['Wastage Cost', _currency.format(data.wastageCost)],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return InventoryReportScaffold(
      title: 'Inventory Dashboard',
      body: Column(
        children: [
          InventoryDateFilterBar(
            quickFilter: quickFilter,
            range: range,
            loading: _loading,
            onQuickFilterChanged: (f) {
              applyQuickFilter(f);
              setState(() => _data = null);
            },
            onPickFrom: () => pickDate(isFrom: true),
            onPickTo: () => pickDate(isFrom: false),
            onGenerate: _load,
          ),
          Expanded(
            child: data == null
                ? Center(
                    child: Text(
                      _loading
                          ? 'Loading dashboard…'
                          : 'Select a date range and tap Generate Report.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : RefreshIndicator(
                    color: InventoryReportColors.orange,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final crossCount = constraints.maxWidth > 600 ? 4 : 2;
                            return GridView.count(
                              crossAxisCount: crossCount,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 1.4,
                              children: [
                                InventorySummaryCard(
                                  label: 'Total Items',
                                  value: '${data.totalItems}',
                                  icon: Icons.inventory_2_outlined,
                                ),
                                InventorySummaryCard(
                                  label: 'Low Stock',
                                  value: '${data.lowStockItems}',
                                  color: InventoryReportColors.amber,
                                  icon: Icons.warning_amber_rounded,
                                ),
                                InventorySummaryCard(
                                  label: 'Out of Stock',
                                  value: '${data.outOfStockItems}',
                                  color: InventoryReportColors.red,
                                  icon: Icons.remove_shopping_cart_outlined,
                                ),
                                InventorySummaryCard(
                                  label: 'Inventory Value',
                                  value: _currency.format(data.totalInventoryValue),
                                  color: InventoryReportColors.green,
                                  icon: Icons.payments_outlined,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _sectionTitle('Stock In vs Stock Out'),
                        _barCompare(data.stockInTotal, data.stockOutTotal),
                        const SizedBox(height: 14),
                        _sectionTitle('Top Consumed Items'),
                        ...data.topConsumedItems.map(
                          (row) => _listTile(
                            row.itemName,
                            '${formatInventoryQuantity(row.quantityConsumed)} sold',
                          ),
                        ),
                        if (data.topConsumedItems.isEmpty)
                          _emptyHint('No consumption in this period.'),
                        const SizedBox(height: 14),
                        _sectionTitle('Wastage'),
                        _listTile(
                          'Total wastage qty',
                          formatInventoryQuantity(data.wastageTotal),
                        ),
                        _listTile(
                          'Total wastage cost',
                          _currency.format(data.wastageCost),
                        ),
                        const SizedBox(height: 14),
                        _sectionTitle('Inventory Value by Category'),
                        ...data.valuationByCategory.entries.map(
                          (e) => _listTile(e.key, _currency.format(e.value)),
                        ),
                      ],
                    ),
                  ),
          ),
          if (data != null)
            InventoryExportBar(
              exporting: _exporting,
              onExportExcel: _exportExcel,
              onExportPdf: _exportPdf,
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: fontMulishBold,
          fontSize: 15,
          color: InventoryReportColors.navy,
        ),
      ),
    );
  }

  Widget _listTile(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontFamily: fontMulishSemiBold)),
          ),
          Text(value, style: const TextStyle(fontFamily: fontMulishBold, color: InventoryReportColors.orange)),
        ],
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 13));
  }

  Widget _barCompare(double stockIn, double stockOut) {
    final max = [stockIn, stockOut, 1.0].reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _barRow('Stock In', stockIn, stockIn / max, InventoryReportColors.green),
          const SizedBox(height: 10),
          _barRow('Stock Out', stockOut, stockOut / max, InventoryReportColors.red),
        ],
      ),
    );
  }

  Widget _barRow(String label, double value, double fraction, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontFamily: fontMulishSemiBold)),
            Text(formatInventoryQuantity(value)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            color: color,
          ),
        ),
      ],
    );
  }
}
