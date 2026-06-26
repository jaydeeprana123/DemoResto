import 'package:demo/features/tables/repositories/table_item_served.dart';

/// Detects Firestore table updates that only mark items as served.
class TableServeChangeUtils {
  TableServeChangeUtils._();

  static const serveBlinkColor = 0xFFE1F5FE; // light sky blue

  static bool isServeOnlyItemsChange(
    List<dynamic> previousItems,
    List<dynamic> currentItems,
  ) {
    if (previousItems.length != currentItems.length) return false;
    if (_contentSignature(previousItems) != _contentSignature(currentItems)) {
      return false;
    }
    return _newlyServedCount(previousItems, currentItems) > 0;
  }

  static bool isServeOnlyTableChange(
    List<List<Map<String, dynamic>>> previous,
    List<List<Map<String, dynamic>>> current,
  ) {
    final prevItems = _flattenTableGroups(previous);
    final currItems = _flattenTableGroups(current);
    if (prevItems.length != currItems.length) return false;
    if (_contentSignature(prevItems) != _contentSignature(currItems)) {
      return false;
    }
    return _newlyServedCount(prevItems, currItems) > 0;
  }

  static bool isServeOnlyPrepTokenChange(
    Set<String> previous,
    Set<String> current,
  ) {
    final removed = previous.difference(current);
    final added = current.difference(previous);
    if (removed.isEmpty || added.isEmpty) return false;
    if (removed.length != added.length) return false;

    for (final addedLine in added) {
      if (!addedLine.endsWith('|true')) return false;
      final base = addedLine.substring(0, addedLine.length - '|true'.length);
      if (!removed.contains('$base|false')) return false;
    }

    for (final removedLine in removed) {
      if (!removedLine.endsWith('|false')) return false;
      final base = removedLine.substring(0, removedLine.length - '|false'.length);
      if (!added.contains('$base|true')) return false;
    }

    return true;
  }

  static Set<String> newlyServedTableItemKeyIds(
    String docId,
    List<dynamic> previousItems,
    List<dynamic> currentItems,
  ) {
    final prevMap = _itemStateMap(previousItems);
    final ids = <String>{};

    for (final raw in currentItems) {
      final item = TableItemServed.asItemMap(raw);
      if (item == null) continue;

      final contentKey = _itemContentKey(item);
      final wasServed = prevMap[contentKey] ?? false;
      if (wasServed || !TableItemServed.isServed(item)) continue;

      final groupIndex = TableItemServed.firestoreGroupIndexFor(
        item,
        TableItemServed.parseGroupIndex(item['groupIndex']),
      );
      final itemIndex = TableItemServed.itemIndexInGroupFor(item, 0);
      ids.add(
        TableItemKey(
          docId: docId,
          groupIndex: groupIndex,
          itemIndexInGroup: itemIndex,
        ).id,
      );
    }

    return ids;
  }

  static String eventKeyForDoc(String docId, Iterable<String> itemKeys) {
    final sorted = itemKeys.toList()..sort();
    return '$docId:${sorted.join(',')}';
  }

  static List<String> newlyServedItemKeys(
    List<dynamic> previousItems,
    List<dynamic> currentItems,
  ) {
    final prevMap = _itemStateMap(previousItems);
    final currMap = _itemStateMap(currentItems);
    final keys = <String>[];

    for (final entry in currMap.entries) {
      final wasServed = prevMap[entry.key] ?? false;
      if (!wasServed && entry.value) {
        keys.add(entry.key);
      }
    }

    return keys;
  }

  static String _contentSignature(List<dynamic> items) {
    final parts = <String>[];
    for (final raw in items) {
      final item = TableItemServed.asItemMap(raw);
      if (item == null) continue;
      parts.add(_itemContentKey(item));
    }
    parts.sort();
    return parts.join('|');
  }

  static int _newlyServedCount(List<dynamic> previous, List<dynamic> current) {
    return newlyServedItemKeys(previous, current).length;
  }

  static Map<String, bool> _itemStateMap(List<dynamic> items) {
    final map = <String, bool>{};
    for (final raw in items) {
      final item = TableItemServed.asItemMap(raw);
      if (item == null) continue;
      map[_itemContentKey(item)] = TableItemServed.isServed(item);
    }
    return map;
  }

  static String _itemContentKey(Map<String, dynamic> item) {
    final groupIndex = TableItemServed.firestoreGroupIndexFor(
      item,
      TableItemServed.parseGroupIndex(item['groupIndex']),
    );
    final itemIndex = TableItemServed.itemIndexInGroupFor(item, 0);
    final name = item['name']?.toString() ?? '';
    final qty = item['qty']?.toString() ?? '1';
    final remarks = item['remarks']?.toString() ?? '';
    return '$groupIndex~$itemIndex~$name~$qty~$remarks';
  }

  static List<Map<String, dynamic>> _flattenTableGroups(
    List<List<Map<String, dynamic>>> groups,
  ) {
    final flat = <Map<String, dynamic>>[];
    for (var gi = 0; gi < groups.length; gi++) {
      for (var ii = 0; ii < groups[gi].length; ii++) {
        final item = Map<String, dynamic>.from(groups[gi][ii]);
        item.putIfAbsent(
          '__firestoreGroupIndex',
          () => TableItemServed.firestoreGroupIndexFor(item, gi),
        );
        item.putIfAbsent(
          '__itemIndex',
          () => TableItemServed.itemIndexInGroupFor(item, ii),
        );
        flat.add(item);
      }
    }
    return flat;
  }
}
