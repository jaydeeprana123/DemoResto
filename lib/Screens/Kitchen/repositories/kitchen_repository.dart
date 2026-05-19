import 'package:cloud_firestore/cloud_firestore.dart';

/// KitchenRepository
/// 
/// Part of the GetX Repository Pattern.
/// This repository acts as the single source of truth for Firestore database reads and writes
/// related to dining tables, menus, order completions, and takeaway deliveries.
class KitchenRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns a real-time stream of all dining table/order documents sorted by creation date.
  Stream<List<Map<String, dynamic>>> getTablesStream() {
    return _firestore
        .collection('tables')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  /// Returns a real-time stream of all category documents ordered by creation date.
  Stream<List<Map<String, dynamic>>> getCategoriesStream() {
    return _firestore
        .collection('menus')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  /// Deletes a dining table/takeaway document from Firestore.
  Future<void> deleteTable(String docId) async {
    await _firestore.collection('tables').doc(docId).delete();
  }

  /// Clears active items from a dining table or marks a table's paid state in Cloud Firestore.
  Future<void> updateTableItems(
    String tableName,
    List<Map<String, dynamic>> items,
    bool isPaid,
  ) async {
    final tableQuery = await _firestore
        .collection('tables')
        .where('name', isEqualTo: tableName)
        .limit(1)
        .get();

    if (tableQuery.docs.isEmpty) return;

    final docId = tableQuery.docs.first.id;
    await _firestore.collection('tables').doc(docId).update({
      'items': items,
      'isPaid': isPaid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
