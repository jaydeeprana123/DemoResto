import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> _updateTableItemsInFirestore(
    String tableName, List<Map<String, dynamic>> items) async {
  try {
    final tableQuery = await FirebaseFirestore.instance
        .collection('tables')
        .where('name', isEqualTo: tableName)
        .limit(1)
        .get();

    if (tableQuery.docs.isNotEmpty) {
      final docId = tableQuery.docs.first.id;

      await FirebaseFirestore.instance.collection('tables').doc(docId).update({
        'items': items,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      print("Table $tableName not found in Firestore!");
    }
  } catch (e) {
    print("Error updating items in Firestore: $e");
  }
}