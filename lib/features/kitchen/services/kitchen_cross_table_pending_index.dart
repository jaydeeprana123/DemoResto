import 'package:smartKitchen/core/utils/table_name_utils.dart';
import 'package:smartKitchen/features/tables/repositories/table_item_served.dart';

class KitchenCrossTablePendingEntry {
  const KitchenCrossTablePendingEntry({
    required this.tableName,
    required this.tableLabel,
    required this.qty,
    required this.orderTime,
    required this.itemKeys,
    this.remarks = const [],
  });

  final String tableName;
  final String tableLabel;
  final int qty;
  final DateTime orderTime;
  final List<TableItemKey> itemKeys;
  final List<String> remarks;

  String? get remarksText =>
      remarks.isEmpty ? null : remarks.join(' · ');
}

class KitchenCrossTablePendingSummary {
  const KitchenCrossTablePendingSummary({
    required this.itemName,
    required this.totalQty,
    required this.entries,
  });

  final String itemName;
  final int totalQty;
  final List<KitchenCrossTablePendingEntry> entries;

  int get tableCount => entries.length;

  bool get spansMultipleTables => tableCount >= 2;
}

/// One unserved kitchen line used to build cross-table totals.
class KitchenCrossTablePendingLine {
  const KitchenCrossTablePendingLine({
    required this.tableName,
    required this.itemName,
    required this.qty,
    required this.orderTime,
    required this.itemKey,
    this.isZomato = false,
    this.remarks,
  });

  final String tableName;
  final String itemName;
  final int qty;
  final DateTime orderTime;
  final TableItemKey itemKey;
  final bool isZomato;
  final String? remarks;
}

class KitchenCrossTablePendingIndex {
  KitchenCrossTablePendingIndex._(this._byNormalizedName);

  KitchenCrossTablePendingIndex.empty() : _byNormalizedName = const {};

  final Map<String, KitchenCrossTablePendingSummary> _byNormalizedName;

  KitchenCrossTablePendingSummary? summaryForItemName(String name) {
    final key = normalizeItemName(name);
    if (key.isEmpty) return null;
    return _byNormalizedName[key];
  }

  static String normalizeItemName(String name) => name.trim().toLowerCase();

  static String tableShortLabel(String tableName) {
    final trimmed = tableName.trim();
    final match = RegExp(
      r'table\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (match != null) {
      return 'T${match.group(1)}';
    }
    if (isTakeAwayOrderName(trimmed)) {
      final withoutPrefix = trimmed
          .replaceFirst(RegExp(r'^take\s*away\s*', caseSensitive: false), '')
          .trim();
      if (withoutPrefix.isNotEmpty && withoutPrefix.length <= 14) {
        return withoutPrefix;
      }
    }
    if (trimmed.length <= 14) return trimmed;
    return '${trimmed.substring(0, 12)}…';
  }

  static KitchenCrossTablePendingIndex fromLines(
    Iterable<KitchenCrossTablePendingLine> lines,
  ) {
    final tableAggregates = <String, Map<String, _TablePendingAgg>>{};
    final displayNames = <String, String>{};

    for (final line in lines) {
      if (line.isZomato) continue;
      final name = line.itemName.trim();
      if (name.isEmpty) continue;

      final normalized = normalizeItemName(name);
      displayNames.putIfAbsent(normalized, () => name);

      final tableName = line.tableName;
      final tableLabel = tableShortLabel(tableName);
      final perTable = tableAggregates.putIfAbsent(normalized, () => {});
      final existing = perTable[tableName];
      if (existing == null) {
        perTable[tableName] = _TablePendingAgg(
          qty: line.qty,
          orderTime: line.orderTime,
          tableLabel: tableLabel,
          remarks: _remarksFromLine(line),
          itemKeys: [line.itemKey],
        );
      } else {
        perTable[tableName] = _TablePendingAgg(
          qty: existing.qty + line.qty,
          orderTime: existing.orderTime.isAfter(line.orderTime)
              ? existing.orderTime
              : line.orderTime,
          tableLabel: tableLabel,
          remarks: _mergeRemarks(existing.remarks, line.remarks),
          itemKeys: [...existing.itemKeys, line.itemKey],
        );
      }
    }

    final summaries = <String, KitchenCrossTablePendingSummary>{};
    for (final entry in tableAggregates.entries) {
      if (entry.value.length < 2) continue;

      final tableLines = entry.value.entries
          .map(
            (tableEntry) => KitchenCrossTablePendingEntry(
              tableName: tableEntry.key,
              tableLabel: tableEntry.value.tableLabel,
              qty: tableEntry.value.qty,
              orderTime: tableEntry.value.orderTime,
              remarks: tableEntry.value.remarks,
              itemKeys: tableEntry.value.itemKeys,
            ),
          )
          .toList()
        ..sort((a, b) => a.orderTime.compareTo(b.orderTime));

      final totalQty =
          tableLines.fold<int>(0, (sum, tableLine) => sum + tableLine.qty);
      summaries[entry.key] = KitchenCrossTablePendingSummary(
        itemName: displayNames[entry.key] ?? entry.key,
        totalQty: totalQty,
        entries: tableLines,
      );
    }

    return KitchenCrossTablePendingIndex._(summaries);
  }

  static int itemQty(Map<String, dynamic> item) {
    final raw = item['qty'] ?? 1;
    if (raw is int) return raw.clamp(1, 999);
    return (int.tryParse(raw.toString()) ?? 1).clamp(1, 999);
  }

  static List<String> _remarksFromLine(KitchenCrossTablePendingLine line) {
    final remark = line.remarks?.trim();
    if (remark == null || remark.isEmpty) return const [];
    return [remark];
  }

  static List<String> _mergeRemarks(
    List<String> existing,
    String? incoming,
  ) {
    final remark = incoming?.trim();
    if (remark == null || remark.isEmpty) return existing;
    if (existing.contains(remark)) return existing;
    return [...existing, remark];
  }
}

class _TablePendingAgg {
  const _TablePendingAgg({
    required this.qty,
    required this.orderTime,
    required this.tableLabel,
    required this.itemKeys,
    this.remarks = const [],
  });

  final int qty;
  final DateTime orderTime;
  final String tableLabel;
  final List<TableItemKey> itemKeys;
  final List<String> remarks;
}
