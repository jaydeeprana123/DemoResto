import 'package:demo/core/utils/table_name_utils.dart';
import 'package:demo/features/kitchen/services/kitchen_cross_table_pending_index.dart';
import 'package:demo/features/tables/repositories/table_item_served.dart';

class KitchenPreparationTableLine {
  const KitchenPreparationTableLine({
    required this.tableName,
    required this.tableLabel,
    required this.qty,
    required this.orderTime,
    required this.itemKeys,
    required this.isServed,
    this.remarks,
  });

  final String tableName;
  final String tableLabel;
  final int qty;
  final DateTime orderTime;
  final List<TableItemKey> itemKeys;
  final bool isServed;
  final String? remarks;
}

class KitchenPreparationItemGroup {
  const KitchenPreparationItemGroup({
    required this.itemName,
    required this.totalQty,
    required this.lines,
    required this.sortTime,
  });

  final String itemName;
  final int totalQty;
  final List<KitchenPreparationTableLine> lines;
  final DateTime sortTime;
}

class KitchenPreparationSourceLine {
  const KitchenPreparationSourceLine({
    required this.itemName,
    required this.tableName,
    required this.qty,
    required this.orderTime,
    required this.itemKey,
    required this.isServed,
    this.remarks,
    this.isZomato = false,
  });

  final String itemName;
  final String tableName;
  final int qty;
  final DateTime orderTime;
  final TableItemKey itemKey;
  final bool isServed;
  final String? remarks;
  final bool isZomato;
}

class KitchenPreparationViewIndex {
  KitchenPreparationViewIndex._();

  static String tableDisplayLabel(String tableName) {
    final trimmed = tableName.trim();
    if (isTakeAwayOrderName(trimmed)) return trimmed;
    return KitchenCrossTablePendingIndex.tableShortLabel(trimmed);
  }

  static List<KitchenPreparationItemGroup> fromLines(
    Iterable<KitchenPreparationSourceLine> lines,
  ) {
    final displayNames = <String, String>{};
    final perItem = <String, Map<String, _LineAgg>>{};

    for (final line in lines) {
      final name = line.itemName.trim();
      if (name.isEmpty) continue;

      final normalized = KitchenCrossTablePendingIndex.normalizeItemName(name);
      displayNames.putIfAbsent(normalized, () => name);

      final aggKey = _aggregateKey(line);
      final itemMap = perItem.putIfAbsent(normalized, () => {});
      final existing = itemMap[aggKey];
      if (existing == null) {
        itemMap[aggKey] = _LineAgg(
          tableName: line.tableName,
          tableLabel: tableDisplayLabel(line.tableName),
          qty: line.qty,
          orderTime: line.orderTime,
          itemKeys: [line.itemKey],
          isServed: line.isServed,
          remarks: line.remarks?.trim(),
        );
      } else {
        itemMap[aggKey] = _LineAgg(
          tableName: line.tableName,
          tableLabel: existing.tableLabel,
          qty: existing.qty + line.qty,
          orderTime: existing.orderTime.isAfter(line.orderTime)
              ? existing.orderTime
              : line.orderTime,
          itemKeys: [...existing.itemKeys, line.itemKey],
          isServed: line.isServed,
          remarks: existing.remarks ?? line.remarks?.trim(),
        );
      }
    }

    final groups = <KitchenPreparationItemGroup>[];
    for (final entry in perItem.entries) {
      final tableLines = entry.value.values
          .map(
            (agg) => KitchenPreparationTableLine(
              tableName: agg.tableName,
              tableLabel: agg.tableLabel,
              qty: agg.qty,
              orderTime: agg.orderTime,
              itemKeys: agg.itemKeys,
              isServed: agg.isServed,
              remarks: agg.remarks,
            ),
          )
          .toList()
        ..sort((a, b) => a.orderTime.compareTo(b.orderTime));

      if (tableLines.isEmpty) continue;

      final totalQty =
          tableLines.fold<int>(0, (sum, tableLine) => sum + tableLine.qty);
      groups.add(
        KitchenPreparationItemGroup(
          itemName: displayNames[entry.key] ?? entry.key,
          totalQty: totalQty,
          lines: tableLines,
          sortTime: tableLines.first.orderTime,
        ),
      );
    }

    groups.sort((a, b) {
      final byTime = a.sortTime.compareTo(b.sortTime);
      if (byTime != 0) return byTime;
      return a.itemName.compareTo(b.itemName);
    });
    return groups;
  }

  static String _aggregateKey(KitchenPreparationSourceLine line) {
    final remark = line.remarks?.trim() ?? '';
    return '${line.tableName}|${line.isServed}|$remark';
  }
}

class _LineAgg {
  const _LineAgg({
    required this.tableName,
    required this.tableLabel,
    required this.qty,
    required this.orderTime,
    required this.itemKeys,
    required this.isServed,
    this.remarks,
  });

  final String tableName;
  final String tableLabel;
  final int qty;
  final DateTime orderTime;
  final List<TableItemKey> itemKeys;
  final bool isServed;
  final String? remarks;
}
