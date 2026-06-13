import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/features/tables/repositories/table_item_served.dart';

class TableOrderSnapshot {
  const TableOrderSnapshot({
    required this.docId,
    required this.items,
    required this.isPaid,
  });

  final String docId;
  final List<Map<String, dynamic>> items;
  final bool isPaid;
}

class TablesRepository {
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTables() {
    return FirestorePaths
        .scoped('tables')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<void> deleteTable(String docId) {
    return FirestorePaths.scopedDoc('tables', docId).delete();
  }

  /// Loads the latest table order from Firestore (server first, cache fallback).
  Future<TableOrderSnapshot?> fetchTableOrderFresh(String tableName) async {
    final trimmed = tableName.trim();
    if (trimmed.isEmpty) return null;

    QuerySnapshot<Map<String, dynamic>> query;
    try {
      query = await FirestorePaths
          .scoped('tables')
          .where('name', isEqualTo: trimmed)
          .limit(1)
          .get(const GetOptions(source: Source.server));
    } catch (_) {
      query = await FirestorePaths
          .scoped('tables')
          .where('name', isEqualTo: trimmed)
          .limit(1)
          .get();
    }

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final data = doc.data();
    final items = mergeTableItemsForBilling(data['items']);
    return TableOrderSnapshot(
      docId: doc.id,
      items: items,
      isPaid: data['isPaid'] == true,
    );
  }

  /// Merges flattened Firestore items into one billable list per dish.
  static List<Map<String, dynamic>> mergeTableItemsForBilling(dynamic rawItems) {
    final parsed = TableItemServed.parseItemList(rawItems);
    final merged = <String, Map<String, dynamic>>{};

    for (final item in parsed) {
      final copy = Map<String, dynamic>.from(item);
      copy.remove('groupIndex');
      copy.remove('addedAt');
      copy.remove('isServed');
      copy.remove('__itemIndex');

      final key = '${copy['name']}_${copy['categoryId'] ?? ''}';
      if (merged.containsKey(key)) {
        final existingQty = (merged[key]!['qty'] as num?)?.toInt() ?? 0;
        final addQty = (copy['qty'] as num?)?.toInt() ?? 0;
        merged[key]!['qty'] = existingQty + addQty;
      } else {
        merged[key] = copy;
      }
    }

    return merged.values.toList();
  }

  static double orderItemsSubtotal(List<Map<String, dynamic>> items) {
    return items.fold<double>(
      0,
      (sum, item) =>
          sum +
          ((item['qty'] as num?)?.toInt() ?? 0) *
              ((item['price'] as num?)?.toDouble() ?? 0),
    );
  }

  Future<void> updateTableItems({
    required String tableName,
    required List<List<Map<String, dynamic>>> groups,
    required bool isBillPaid,
    String overallRemarks = '',
    String? docId,
    String? lastTransactionId,
    bool clearLastTransactionId = false,
  }) async {
    var resolvedDocId = docId?.trim();
    if (resolvedDocId == null || resolvedDocId.isEmpty) {
      final tableQuery = await FirestorePaths
          .scoped('tables')
          .where('name', isEqualTo: tableName)
          .limit(1)
          .get();

      if (tableQuery.docs.isEmpty) return;
      resolvedDocId = tableQuery.docs.first.id;
    }

    final flattenedItems = <Map<String, dynamic>>[];

    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final group = groups[groupIndex];
      Timestamp groupTimestamp;
      if (group.isNotEmpty && group.first.containsKey('addedAt')) {
        groupTimestamp = group.first['addedAt'];
      } else {
        groupTimestamp = Timestamp.now();
      }

      for (final item in group) {
        final itemWithMeta = Map<String, dynamic>.from(item);
        itemWithMeta['groupIndex'] = groupIndex;
        itemWithMeta['addedAt'] = groupTimestamp;
        flattenedItems.add(itemWithMeta);
      }
    }

    final updateData = <String, dynamic>{
      'items': flattenedItems,
      'isPaid': isBillPaid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (overallRemarks.isNotEmpty) {
      updateData['remarks'] = overallRemarks;
    }
    if (lastTransactionId != null && lastTransactionId.isNotEmpty) {
      updateData['lastTransactionId'] = lastTransactionId;
    } else if (clearLastTransactionId) {
      updateData['lastTransactionId'] = FieldValue.delete();
    }

    await FirestorePaths.scopedDoc('tables', resolvedDocId).update(updateData);
  }

  Future<void> markTableUnpaid(String docId) {
    return FirestorePaths.scopedDoc('tables', docId).update({
      'isPaid': false,
      'lastTransactionId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
