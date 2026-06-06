import 'package:cloud_firestore/cloud_firestore.dart';

class TablesRepository {
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTables() {
    return FirebaseFirestore.instance
        .collection('tables')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<void> deleteTable(String docId) {
    return FirebaseFirestore.instance.collection('tables').doc(docId).delete();
  }

  Future<void> updateTableItems({
    required String tableName,
    required List<List<Map<String, dynamic>>> groups,
    required bool isBillPaid,
    String overallRemarks = '',
  }) async {
    final tableQuery = await FirebaseFirestore.instance
        .collection('tables')
        .where('name', isEqualTo: tableName)
        .limit(1)
        .get();

    if (tableQuery.docs.isEmpty) return;

    final docId = tableQuery.docs.first.id;
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

    await FirebaseFirestore.instance
        .collection('tables')
        .doc(docId)
        .update(updateData);
  }
}
