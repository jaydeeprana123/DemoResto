import 'package:cloud_firestore/cloud_firestore.dart';

/// TableManagementRepository
///
/// Part of the GetX Repository Pattern.
/// Abstracts Firestore read/write operations for tables.
class TableManagementRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Retrieves a real-time stream of all tables, ordered by creation date.
  Stream<QuerySnapshot<Map<String, dynamic>>> getTablesStream() {
    return _firestore
        .collection('tables')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Adds a new table to the 'tables' collection in Firestore.
  /// Sets initial values such as an empty list of items and a timestamp.
  Future<void> createTable(String tableName) async {
    await _firestore.collection('tables').add({
      'name': tableName,
      'items': [], // Added empty items array for dashboard compatibility
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a specific table document from Firestore using its document ID.
  Future<void> removeTable(String docId) async {
    await _firestore.collection('tables').doc(docId).delete();
  }
}
