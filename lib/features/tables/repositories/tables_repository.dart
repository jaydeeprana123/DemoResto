import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/features/tables/repositories/table_item_served.dart';

class TableOrderSnapshot {
  const TableOrderSnapshot({
    required this.docId,
    required this.items,
    required this.isPaid,
    this.addedByUserIds = const [],
    this.addedByUserNames = const [],
  });

  final String docId;
  final List<Map<String, dynamic>> items;
  final bool isPaid;
  final List<String> addedByUserIds;
  final List<String> addedByUserNames;

  /// Comma-separated unique display names for billing UI.
  String? get addedByUserName {
    final names = addedByUserNames
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (names.isEmpty) return null;
    return names.join(', ');
  }
}

class TablesRepository {
  /// Parses list or legacy single-string Added By fields from a table doc.
  static List<String> parseAddedByList(dynamic listValue, dynamic legacyValue) {
    final result = <String>[];
    final seen = <String>{};

    void add(String? raw) {
      final value = raw?.trim() ?? '';
      if (value.isEmpty) return;
      if (!seen.add(value)) return;
      result.add(value);
    }

    if (listValue is List) {
      for (final entry in listValue) {
        add(entry?.toString());
      }
    } else if (listValue is String) {
      add(listValue);
    }

    if (result.isEmpty) {
      add(legacyValue?.toString());
    }

    return result;
  }

  static Map<String, List<String>> parseAddedByFromData(
    Map<String, dynamic> data,
  ) {
    return {
      'ids': parseAddedByList(data['addedByUserIds'], data['addedByUserId']),
      'names': parseAddedByList(
        data['addedByUserNames'],
        data['addedByUserName'],
      ),
    };
  }

  /// Appends [userId]/[userName] if the id is not already present.
  /// Returns updated parallel lists (may be unchanged).
  static ({List<String> ids, List<String> names}) appendAddedByUser({
    required List<String> existingIds,
    required List<String> existingNames,
    required String userId,
    required String userName,
  }) {
    final id = userId.trim();
    final name = userName.trim();
    if (id.isEmpty || name.isEmpty) {
      return (ids: List<String>.from(existingIds), names: List<String>.from(existingNames));
    }

    final ids = List<String>.from(existingIds);
    final names = List<String>.from(existingNames);

    // Align lengths if data was corrupted/legacy-mismatched.
    while (names.length < ids.length) {
      names.add('');
    }
    while (ids.length < names.length) {
      ids.add('');
    }

    final existingIndex = ids.indexOf(id);
    if (existingIndex >= 0) {
      // Same user again — keep first occurrence, no duplicate.
      return (ids: ids, names: names);
    }

    ids.add(id);
    names.add(name);
    return (ids: ids, names: names);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTables() {
    return FirestorePaths
        .scoped('tables')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Loads all table documents from Firestore (server first, cache fallback).
  Future<QuerySnapshot<Map<String, dynamic>>> fetchAllTablesFresh() async {
    try {
      return await FirestorePaths
          .scoped('tables')
          .orderBy('createdAt', descending: false)
          .get(const GetOptions(source: Source.server));
    } catch (_) {
      return FirestorePaths
          .scoped('tables')
          .orderBy('createdAt', descending: false)
          .get();
    }
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
    final addedBy = parseAddedByFromData(data);
    return TableOrderSnapshot(
      docId: doc.id,
      items: items,
      isPaid: data['isPaid'] == true,
      addedByUserIds: addedBy['ids'] ?? const [],
      addedByUserNames: addedBy['names'] ?? const [],
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
    List<String>? addedByUserIds,
    List<String>? addedByUserNames,
    bool clearAddedBy = false,
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

    final rawIds = addedByUserIds ?? const <String>[];
    final rawNames = addedByUserNames ?? const <String>[];
    if (rawIds.isNotEmpty && rawNames.isNotEmpty) {
      var syncedIds = <String>[];
      var syncedNames = <String>[];
      final limit =
          rawIds.length < rawNames.length ? rawIds.length : rawNames.length;
      for (var i = 0; i < limit; i++) {
        final next = appendAddedByUser(
          existingIds: syncedIds,
          existingNames: syncedNames,
          userId: rawIds[i],
          userName: rawNames[i],
        );
        syncedIds = next.ids;
        syncedNames = next.names;
      }

      if (syncedIds.isNotEmpty && syncedNames.isNotEmpty) {
        updateData['addedByUserIds'] = syncedIds;
        updateData['addedByUserNames'] = syncedNames;
        // Drop legacy single-value fields after migrating to lists.
        updateData['addedByUserId'] = FieldValue.delete();
        updateData['addedByUserName'] = FieldValue.delete();
      }
    } else if (clearAddedBy || flattenedItems.isEmpty) {
      updateData['addedByUserIds'] = FieldValue.delete();
      updateData['addedByUserNames'] = FieldValue.delete();
      updateData['addedByUserId'] = FieldValue.delete();
      updateData['addedByUserName'] = FieldValue.delete();
    }

    // Billing / clear resets any pending staff→admin completion ping.
    if (isBillPaid || flattenedItems.isEmpty) {
      updateData['orderCompletionNotifiedAt'] = FieldValue.delete();
      updateData['orderCompletionNotifiedBy'] = FieldValue.delete();
      updateData['orderCompletionNotifiedByUserId'] = FieldValue.delete();
    }

    await FirestorePaths.scopedDoc('tables', resolvedDocId).update(updateData);
  }

  /// Single write: staff signals admin that this order is ready for billing.
  Future<void> notifyOrderCompletion({
    required String docId,
    required String notifiedByName,
    String? notifiedByUserId,
  }) {
    final name = notifiedByName.trim();
    final data = <String, dynamic>{
      'orderCompletionNotifiedAt': FieldValue.serverTimestamp(),
      'orderCompletionNotifiedBy': name.isEmpty ? 'Staff' : name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final uid = notifiedByUserId?.trim();
    if (uid != null && uid.isNotEmpty) {
      data['orderCompletionNotifiedByUserId'] = uid;
    }
    return FirestorePaths.scopedDoc('tables', docId).update(data);
  }

  Future<void> clearOrderCompletionNotification(String docId) {
    return FirestorePaths.scopedDoc('tables', docId).update({
      'orderCompletionNotifiedAt': FieldValue.delete(),
      'orderCompletionNotifiedBy': FieldValue.delete(),
      'orderCompletionNotifiedByUserId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markTableUnpaid(String docId) {
    return FirestorePaths.scopedDoc('tables', docId).update({
      'isPaid': false,
      'lastTransactionId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
