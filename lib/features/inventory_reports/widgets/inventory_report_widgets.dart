import 'package:smartKitchen/features/inventory_reports/models/inventory_models.dart';
import 'package:smartKitchen/Styles/my_font.dart';
import 'package:smartKitchen/features/inventory_reports/utils/inventory_date_utils.dart';
import 'package:smartKitchen/features/settings/utils/export_date_range.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InventoryReportColors {
  InventoryReportColors._();

  static const navy = Color(0xFF1A3A5C);
  static const orange = Color(0xFFf57c35);
  static const background = Color(0xFFF5F6FA);
  static const green = Color(0xFF2E7D32);
  static const red = Color(0xFFC62828);
  static const amber = Color(0xFFF9A825);
}

class InventoryReportScaffold extends StatelessWidget {
  const InventoryReportScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InventoryReportColors.background,
      appBar: AppBar(
        backgroundColor: InventoryReportColors.navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontFamily: fontMulishBold,
            color: Colors.white,
          ),
        ),
        actions: actions,
      ),
      body: body,
    );
  }
}

class InventoryDateFilterBar extends StatelessWidget {
  const InventoryDateFilterBar({
    super.key,
    required this.quickFilter,
    required this.range,
    required this.onQuickFilterChanged,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onGenerate,
    this.loading = false,
    this.showGenerate = true,
  });

  final InventoryQuickDateFilter quickFilter;
  final ExportDateRange range;
  final ValueChanged<InventoryQuickDateFilter> onQuickFilterChanged;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onGenerate;
  final bool loading;
  final bool showGenerate;

  static final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: InventoryQuickDateFilter.values.map((filter) {
                final selected = quickFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter.label),
                    selected: selected,
                    onSelected: loading
                        ? null
                        : (_) => onQuickFilterChanged(filter),
                    selectedColor:
                        InventoryReportColors.orange.withValues(alpha: 0.2),
                    checkmarkColor: InventoryReportColors.orange,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DateTile(
                  label: 'From',
                  value: _dateFmt.format(range.from),
                  onTap: loading ? null : onPickFrom,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateTile(
                  label: 'To',
                  value: _dateFmt.format(range.to),
                  onTap: loading ? null : onPickTo,
                ),
              ),
            ],
          ),
          if (showGenerate) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: loading ? null : onGenerate,
              style: FilledButton.styleFrom(
                backgroundColor: InventoryReportColors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.assessment_outlined),
              label: Text(
                loading ? 'Loading…' : 'Generate Report',
                style: const TextStyle(fontFamily: fontMulishSemiBold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          value,
          style: const TextStyle(fontFamily: fontMulishSemiBold, fontSize: 13),
        ),
      ),
    );
  }
}

class InventorySummaryCard extends StatelessWidget {
  const InventorySummaryCard({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.icon,
  });

  final String label;
  final String value;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Icon(icon, size: 20, color: color ?? InventoryReportColors.navy),
          if (icon != null) const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: fontMulishRegular,
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: fontMulishBold,
              fontSize: 18,
              color: color ?? InventoryReportColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class InventoryExportBar extends StatelessWidget {
  const InventoryExportBar({
    super.key,
    required this.onExportExcel,
    required this.onExportPdf,
    this.exporting = false,
  });

  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final bool exporting;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: exporting ? null : onExportPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: exporting ? null : onExportExcel,
                style: FilledButton.styleFrom(
                  backgroundColor: InventoryReportColors.navy,
                  foregroundColor: Colors.white,
                ),
                icon: exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.file_download_outlined),
                label: Text(exporting ? 'Exporting…' : 'Export Excel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InventorySearchField extends StatelessWidget {
  const InventorySearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: onClear,
                )
              : null,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }
}

Color inventoryStatusColor(InventoryStockStatus status) {
  switch (status) {
    case InventoryStockStatus.inStock:
      return InventoryReportColors.green;
    case InventoryStockStatus.lowStock:
      return InventoryReportColors.amber;
    case InventoryStockStatus.outOfStock:
      return InventoryReportColors.red;
  }
}
