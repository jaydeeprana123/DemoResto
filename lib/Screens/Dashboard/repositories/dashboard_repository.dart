import 'package:cloud_firestore/cloud_firestore.dart';

/// DashboardRepository
/// 
/// Part of the GetX Repository Pattern.
/// This repository is responsible for querying and muting data in Cloud Firestore
/// regarding table layouts, ordering groups, and catalog menus.
class DashboardRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of tables collection ordered by creation date.
  Stream<QuerySnapshot<Map<String, dynamic>>> getTablesStream() {
    return _firestore
        .collection('tables')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Load catalog menus and their child items from Cloud Firestore.
  Future<List<Map<String, dynamic>>> loadMenu() async {
    final List<Map<String, dynamic>> loadedMenu = [];
    final menuSnapshot = await _firestore.collection('menus').get();

    for (var categoryDoc in menuSnapshot.docs) {
      final categoryId = categoryDoc.id;
      final categoryName = categoryDoc['name'];

      final itemsSnapshot = await _firestore
          .collection('menus')
          .doc(categoryId)
          .collection('items')
          .get();

      for (var itemDoc in itemsSnapshot.docs) {
        loadedMenu.add({
          "category": categoryName,
          "name": itemDoc['name'],
          "price": itemDoc['price'],
          "categoryId": categoryId,
          "itemId": itemDoc.id,
          "qty": 1,
        });
      }
    }
    return loadedMenu;
  }

  /// Update table ordering groups in Firestore.
  /// Reconstructs, flattens, and uploads the nested order groups.
  Future<void> updateTableItems({
    required String tableName,
    required List<List<Map<String, dynamic>>> groups,
    required bool isBillPaid,
    String overallRemarks = '',
  }) async {
    final tableQuery = await _firestore
        .collection('tables')
        .where('name', isEqualTo: tableName)
        .limit(1)
        .get();

    if (tableQuery.docs.isEmpty) {
      throw Exception("Table $tableName not found in database.");
    }

    final docId = tableQuery.docs.first.id;
    final List<Map<String, dynamic>> flattenedItems = [];

    for (int groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final group = groups[groupIndex];
      final Timestamp groupTimestamp = (group.isNotEmpty && group[0].containsKey('addedAt'))
          ? group[0]['addedAt']
          : Timestamp.now();

      for (var item in group) {
        final itemWithMeta = Map<String, dynamic>.from(item);
        itemWithMeta['groupIndex'] = groupIndex;
        itemWithMeta['addedAt'] = groupTimestamp;
        flattenedItems.add(itemWithMeta);
      }
    }

    final Map<String, dynamic> updateData = {
      'items': flattenedItems,
      'isPaid': isBillPaid,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (overallRemarks.isNotEmpty) {
      updateData['remarks'] = overallRemarks;
    }

    await _firestore.collection('tables').doc(docId).update(updateData);
  }

  /// Add a brand new table with empty items.
  Future<bool> addTable(String tableName) async {
    final existing = await _firestore
        .collection('tables')
        .where('name', isEqualTo: tableName)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return false; // Already exists
    }

    await _firestore.collection('tables').add({
      'name': tableName,
      'items': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  /// Create a new table (e.g. for Take Away) and save initial items immediately.
  Future<void> addTableAndUpdateItems({
    required String tableName,
    required List<Map<String, dynamic>> selectedItems,
    required bool isBillPaid,
    String overallRemarks = '',
  }) async {
    final existing = await _firestore
        .collection('tables')
        .where('name', isEqualTo: tableName)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception("Table already exists: $tableName");
    }

    final List<Map<String, dynamic>> flattenedItems = [];
    final Timestamp groupTimestamp = Timestamp.now();

    for (var item in selectedItems) {
      final itemWithMeta = Map<String, dynamic>.from(item);
      itemWithMeta['groupIndex'] = 0; // single group
      itemWithMeta['addedAt'] = groupTimestamp;
      flattenedItems.add(itemWithMeta);
    }

    final Map<String, dynamic> tableData = {
      'name': tableName,
      'items': flattenedItems,
      'isPaid': isBillPaid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (overallRemarks.isNotEmpty) {
      tableData['remarks'] = overallRemarks;
    }

    await _firestore.collection('tables').add(tableData);
  }

  /// Delete a table document from Firestore.
  Future<void> deleteTable(String docId) async {
    await _firestore.collection('tables').doc(docId).delete();
  }
}
