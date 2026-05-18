import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Repository responsible for direct data operations with Firestore.
/// It separates database logic from UI and Controllers.
class OrderRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Establishes a real-time stream of all tables in Firestore.
  Stream<QuerySnapshot<Map<String, dynamic>>> listenToTables() {
    return _firestore
        .collection('tables')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Loads all categories and menu items from Firestore database.
  Future<List<Map<String, dynamic>>> loadMenu() async {
    List<Map<String, dynamic>> loadedMenu = [];
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

  /// Updates active items of an existing table or takeaway in Firestore.
  Future<void> updateTableItems({
    required String tableName,
    required List<List<Map<String, dynamic>>> groups,
    required bool isPaid,
    String overallRemarks = '',
  }) async {
    final tableQuery = await _firestore
        .collection('tables')
        .where('name', isEqualTo: tableName)
        .limit(1)
        .get();

    if (tableQuery.docs.isEmpty) return;

    final docId = tableQuery.docs.first.id;
    List<Map<String, dynamic>> flattenedItems = [];

    for (int groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      var group = groups[groupIndex];
      Timestamp groupTimestamp = group.isNotEmpty && group[0].containsKey('addedAt')
          ? group[0]['addedAt']
          : Timestamp.now();

      for (var item in group) {
        final itemWithMeta = Map<String, dynamic>.from(item);
        itemWithMeta['groupIndex'] = groupIndex;
        itemWithMeta['addedAt'] = groupTimestamp;
        flattenedItems.add(itemWithMeta);
      }
    }

    final updateData = {
      'items': flattenedItems,
      "isPaid": isPaid,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (overallRemarks.isNotEmpty) {
      updateData['remarks'] = overallRemarks;
    }

    await _firestore.collection('tables').doc(docId).update(updateData);
  }

  /// Checks if a table name exists in Firestore.
  Future<bool> checkTableExists(String tableName) async {
    final existing = await _firestore
        .collection('tables')
        .where('name', isEqualTo: tableName)
        .limit(1)
        .get();
    return existing.docs.isNotEmpty;
  }

  /// Adds a new table (dine-in or take away) with its initial items list to Firestore.
  Future<void> addNewTable({
    required String tableName,
    required List<Map<String, dynamic>> selectedItems,
    required bool isPaid,
    String overallRemarks = '',
  }) async {
    final Timestamp groupTimestamp = Timestamp.now();
    List<Map<String, dynamic>> flattenedItems = [];

    for (var item in selectedItems) {
      final itemWithMeta = Map<String, dynamic>.from(item);
      itemWithMeta['groupIndex'] = 0;
      itemWithMeta['addedAt'] = groupTimestamp;
      flattenedItems.add(itemWithMeta);
    }

    final tableData = {
      'name': tableName,
      'items': flattenedItems,
      "isPaid": isPaid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (overallRemarks.isNotEmpty) {
      tableData['remarks'] = overallRemarks;
    }

    await _firestore.collection('tables').add(tableData);
  }

  /// Deletes a table document (typically used for take aways after delivery).
  Future<void> deleteTable(String docId) async {
    await _firestore.collection('tables').doc(docId).delete();
  }

  /// Saves the final billing transaction to database and updates revenue stats.
  Future<void> saveTransaction({
    required List<Map<String, dynamic>> items,
    required String tableName,
    required int subtotal,
    required int tax,
    required int discount,
    required int total,
    required int cashAmount,
    required int onlineAmount,
  }) async {
    final now = DateTime.now();
    final dateKey = DateFormat("yyyy-MM-dd").format(now);
    final batch = _firestore.batch();

    // 1. Add transaction record
    final txRef = _firestore.collection("transactions").doc();
    batch.set(txRef, {
      "table": tableName,
      "items": items.map((e) => {
        "name": e["name"],
        "qty": e["qty"],
        "price": (e["price"]).round(),
        "total": ((e["qty"]) * (e["price"])).round(),
      }).toList(),
      "subtotal": subtotal,
      "tax": tax,
      "discount": discount,
      "total": total,
      "cashAmount": cashAmount,
      "onlineAmount": onlineAmount,
      "createdAt": FieldValue.serverTimestamp(),
    });

    // 2. Update daily statistics
    final dailyRef = _firestore.collection("daily_stats").doc(dateKey);
    batch.set(dailyRef, {
      "revenue": FieldValue.increment(total),
      "totalCash": FieldValue.increment(cashAmount),
      "totalOnline": FieldValue.increment(onlineAmount),
      "transactions": FieldValue.increment(1),
      "lastUpdated": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. Update global summary
    final summaryRef = _firestore.collection("stats").doc("summary");
    batch.set(summaryRef, {
      "totalRevenue": FieldValue.increment(total),
      "totalTransactions": FieldValue.increment(1),
      "lastUpdated": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
