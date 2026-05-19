import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// CartRepository
/// 
/// Part of the GetX Repository Pattern.
/// Abstracts all Firestore write operations, such as saving transactional details,
/// updating daily status aggregations, and incrementing overall statistic counts.
class CartRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Commits a batch write to save a transaction and update stats.
  Future<void> addTransactionToFirestore({
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

    // 1️⃣ Add transaction details
    final txRef = _firestore.collection("transactions").doc();
    batch.set(txRef, {
      "table": tableName,
      "items": items
          .map(
            (e) => {
              "name": e["name"],
              "qty": e["qty"],
              "price": (e["price"] as num).round(), // convert safely to int
              "total": ((e["qty"] as int) * (e["price"] as num)).round(),
            },
          )
          .toList(),
      "subtotal": subtotal,
      "tax": tax,
      "discount": discount,
      "total": total,
      "cashAmount": cashAmount,
      "onlineAmount": onlineAmount,
      "createdAt": FieldValue.serverTimestamp(),
    });

    // 2️⃣ Update daily_stats reference
    final dailyRef = _firestore
        .collection("daily_stats")
        .doc(dateKey);
    batch.set(dailyRef, {
      "revenue": FieldValue.increment(total),
      "totalCash": FieldValue.increment(cashAmount),
      "totalOnline": FieldValue.increment(onlineAmount),
      "transactions": FieldValue.increment(1),
      "lastUpdated": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3️⃣ Update overall summary reference
    final summaryRef = _firestore
        .collection("stats")
        .doc("summary");
    batch.set(summaryRef, {
      "totalRevenue": FieldValue.increment(total),
      "totalTransactions": FieldValue.increment(1),
      "lastUpdated": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 4️⃣ Commit the atomic batch
    await batch.commit();
  }

  /// Creates/inserts a new table or updates groups within an existing table in Firestore.
  /// Standardizes active table writes to execute directly within the Cart module.
  Future<void> updateTableOrAddGroup({
    required String tableName,
    required List<Map<String, dynamic>> items,
    required bool isEditMode,
    required bool isBillPaid,
    String overallRemarks = '',
  }) async {
    // Check if the table already exists in the collection
    final existing = await _firestore
        .collection('tables')
        .where('name', isEqualTo: tableName)
        .limit(1)
        .get();

    if (existing.docs.isEmpty) {
      // Table doesn't exist, create it as a brand new table (Case 1: e.g. Take Away)
      final List<Map<String, dynamic>> flattenedItems = [];
      final Timestamp groupTimestamp = Timestamp.now();

      for (var item in items) {
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
    } else {
      // Table exists in Firestore. Reconstruct the groups list to manipulate correctly.
      final doc = existing.docs.first;
      final docId = doc.id;
      final List<dynamic> itemsFromDb = doc.data().containsKey('items') ? doc['items'] : [];

      // Group items from database by groupIndex
      final Map<int, List<Map<String, dynamic>>> groupMap = {};
      for (var item in itemsFromDb) {
        if (item is Map) {
          final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
          final int groupIndex = itemMap['groupIndex'] ?? 0;
          
          if (!groupMap.containsKey(groupIndex)) {
            groupMap[groupIndex] = [];
          }
          groupMap[groupIndex]!.add(itemMap);
        }
      }

      // Reconstruct sorted groups list
      final List<List<Map<String, dynamic>>> groups = [];
      final List<int> sortedIndices = groupMap.keys.toList()..sort();
      for (int gi in sortedIndices) {
        groups.add(groupMap[gi]!);
      }

      // Prepare updated groups
      final List<List<Map<String, dynamic>>> newGroups = List.from(groups);

      if (isEditMode) {
        if (newGroups.isNotEmpty) {
          // Edit the last group
          newGroups[newGroups.length - 1] = items;
        } else {
          // If groups are empty, add items as a new group
          newGroups.add(items);
        }
      } else {
        // Append a new group of items
        newGroups.add(items);
      }

      // Flatten newGroups back to the Firestore flattened format
      final List<Map<String, dynamic>> flattenedItems = [];
      for (int gi = 0; gi < newGroups.length; gi++) {
        final group = newGroups[gi];
        final Timestamp groupTimestamp = (group.isNotEmpty && group[0].containsKey('addedAt'))
            ? (group[0]['addedAt'] is Timestamp ? group[0]['addedAt'] as Timestamp : Timestamp.now())
            : Timestamp.now();

        for (var item in group) {
          final itemWithMeta = Map<String, dynamic>.from(item);
          itemWithMeta['groupIndex'] = gi;
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
  }
}
