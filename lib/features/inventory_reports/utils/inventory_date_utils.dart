import 'package:smartKitchen/features/inventory_reports/models/inventory_models.dart';
import 'package:smartKitchen/features/settings/utils/export_date_range.dart';

enum InventoryQuickDateFilter {
  today('Today'),
  yesterday('Yesterday'),
  last7Days('Last 7 Days'),
  last30Days('Last 30 Days'),
  thisMonth('This Month'),
  custom('Custom');

  const InventoryQuickDateFilter(this.label);
  final String label;
}

ExportDateRange inventoryQuickDateRange(InventoryQuickDateFilter filter) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

  switch (filter) {
    case InventoryQuickDateFilter.today:
      return ExportDateRange(from: todayStart, to: todayEnd);
    case InventoryQuickDateFilter.yesterday:
      final y = todayStart.subtract(const Duration(days: 1));
      return ExportDateRange(
        from: y,
        to: DateTime(y.year, y.month, y.day, 23, 59, 59, 999),
      );
    case InventoryQuickDateFilter.last7Days:
      return ExportDateRange(
        from: todayStart.subtract(const Duration(days: 6)),
        to: todayEnd,
      );
    case InventoryQuickDateFilter.last30Days:
      return ExportDateRange(
        from: todayStart.subtract(const Duration(days: 29)),
        to: todayEnd,
      );
    case InventoryQuickDateFilter.thisMonth:
      return ExportDateRange(
        from: DateTime(now.year, now.month, 1),
        to: todayEnd,
      );
    case InventoryQuickDateFilter.custom:
      return ExportDateRange(from: todayStart, to: todayEnd);
  }
}

InventoryStockStatus inventoryStockStatus({
  required double currentStock,
  required double minimumStock,
}) {
  if (currentStock <= 0) return InventoryStockStatus.outOfStock;
  if (currentStock <= minimumStock) return InventoryStockStatus.lowStock;
  return InventoryStockStatus.inStock;
}

double inventoryReorderQuantity({
  required double currentStock,
  required double minimumStock,
}) {
  if (minimumStock <= 0) return 0;
  final gap = minimumStock - currentStock;
  return gap > 0 ? gap : 0;
}

String formatInventoryQuantity(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}
