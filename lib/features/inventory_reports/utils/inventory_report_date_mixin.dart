import 'package:smartKitchen/features/inventory_reports/utils/inventory_date_utils.dart';
import 'package:smartKitchen/features/settings/utils/export_date_range.dart';
import 'package:flutter/material.dart';

mixin InventoryReportDateMixin<T extends StatefulWidget> on State<T> {
  InventoryQuickDateFilter quickFilter = InventoryQuickDateFilter.today;
  late ExportDateRange range;

  @override
  void initState() {
    super.initState();
    range = inventoryQuickDateRange(quickFilter);
  }

  void applyQuickFilter(InventoryQuickDateFilter filter) {
    setState(() {
      quickFilter = filter;
      if (filter != InventoryQuickDateFilter.custom) {
        range = inventoryQuickDateRange(filter);
      }
    });
  }

  Future<void> pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final base = isFrom ? range.from : range.to;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2023),
      lastDate: now,
    );
    if (pickedDate == null || !mounted) return;

    final selected = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      isFrom ? 0 : 23,
      isFrom ? 0 : 59,
      isFrom ? 0 : 59,
      isFrom ? 0 : 999,
    );

    setState(() {
      quickFilter = InventoryQuickDateFilter.custom;
      if (isFrom) {
        range = ExportDateRange(from: selected, to: range.to);
      } else {
        range = ExportDateRange(from: range.from, to: selected);
      }
    });
  }
}
