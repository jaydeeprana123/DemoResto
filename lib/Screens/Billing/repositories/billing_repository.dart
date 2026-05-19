import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// BillingRepository
/// 
/// Part of the GetX Repository Pattern.
/// This repository is responsible for querying and muting data in Cloud Firestore
/// regarding transactions, daily stats, global summaries, and table clearing after checkout.
class BillingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Saves the billing transaction to the 'transactions' Firestore collection,
  /// updates daily statistics in 'daily_stats', and updates global statistics in 'stats/summary'.
  /// Uses a Firestore batch write to ensure atomic execution.
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

    // 1️⃣ Add transaction document
    final txRef = _firestore.collection("transactions").doc();
    batch.set(txRef, {
      "table": tableName,
      "items": items
          .map(
            (e) => {
              "name": e["name"],
              "qty": e["qty"],
              "price": (e["price"]).round(), // convert to int
              "total": ((e["qty"]) * (e["price"])).round(),
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

    // 2️⃣ Update daily_stats document
    final dailyRef = _firestore.collection("daily_stats").doc(dateKey);
    batch.set(dailyRef, {
      "revenue": FieldValue.increment(total),
      "totalCash": FieldValue.increment(cashAmount),
      "totalOnline": FieldValue.increment(onlineAmount),
      "transactions": FieldValue.increment(1),
      "lastUpdated": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3️⃣ Update global summary stats document
    final summaryRef = _firestore.collection("stats").doc("summary");
    batch.set(summaryRef, {
      "totalRevenue": FieldValue.increment(total),
      "totalTransactions": FieldValue.increment(1),
      "lastUpdated": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 4️⃣ Commit batch
    await batch.commit();
  }

  /// Clears active items from a table or deletes take away table documents in Cloud Firestore.
  Future<void> clearOrDeleteTable(String tableName) async {
    final query = await _firestore
        .collection('tables')
        .where('name', isEqualTo: tableName)
        .get();

    for (var doc in query.docs) {
      if (!tableName.contains("Table")) {
        // Take Away tables are transient and deleted on completion
        await doc.reference.delete();
      } else {
        // Physical dining tables are cleared but kept in layout
        await doc.reference.update({
          'items': [],
          'isPaid': false,
          'remarks': FieldValue.delete(),
        });
      }
    }
  }
}
