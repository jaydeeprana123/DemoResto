import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// TransactionsRepository
/// 
/// Part of the GetX Repository Pattern.
/// Abstracts Firestore read/write operations for transactions and daily stats.
class TransactionsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches daily statistics/revenue between two dates.
  Future<Map<String, dynamic>> getRevenueBetweenDates(DateTime from, DateTime to) async {
    final fromKey = DateFormat("yyyy-MM-dd").format(from);
    final toKey = DateFormat("yyyy-MM-dd").format(to);

    final snapshot = await _firestore
        .collection("daily_stats")
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: fromKey)
        .where(FieldPath.documentId, isLessThanOrEqualTo: toKey)
        .get();

    double totalRevenue = 0;
    double totalCash = 0;
    double totalOnline = 0;
    int totalTransactions = 0;

    for (var doc in snapshot.docs) {
      totalRevenue += (doc["revenue"] as num?)?.toDouble() ?? 0.0;
      totalCash += (doc["totalCash"] as num?)?.toDouble() ?? 0.0;
      totalOnline += (doc["totalOnline"] as num?)?.toDouble() ?? 0.0;
      totalTransactions += (doc["transactions"] as int?) ?? 0;
    }

    return {
      "totalRevenue": totalRevenue,
      "totalCash": totalCash,
      "totalOnline": totalOnline,
      "totalTransactions": totalTransactions,
    };
  }

  /// Fetches all-time total statistics/revenue from daily_stats.
  Future<Map<String, dynamic>> getTotalRevenue() async {
    final snapshot = await _firestore.collection("daily_stats").get();

    double totalRevenue = 0;
    double totalCash = 0;
    double totalOnline = 0;
    int totalTransactions = 0;

    for (var doc in snapshot.docs) {
      totalRevenue += (doc["revenue"] as num?)?.toDouble() ?? 0.0;
      totalOnline += (doc["totalOnline"] as num?)?.toDouble() ?? 0.0;
      totalCash += (doc["totalCash"] as num?)?.toDouble() ?? 0.0;
      totalTransactions += (doc["transactions"] as int?) ?? 0;
    }

    return {
      "totalRevenue": totalRevenue,
      "totalCash": totalCash,
      "totalOnline": totalOnline,
      "totalTransactions": totalTransactions,
    };
  }

  /// Queries the transactions collection with pagination and optional date filter.
  Future<QuerySnapshot<Map<String, dynamic>>> fetchTransactions({
    DateTime? fromDate,
    DateTime? toDate,
    bool isFilterApplied = false,
    DocumentSnapshot? lastDoc,
    required int limit,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection("transactions")
        .orderBy("createdAt", descending: true);

    if (isFilterApplied && fromDate != null) {
      final now = DateTime.now();
      final effectiveFrom = DateTime(
        fromDate.year,
        fromDate.month,
        fromDate.day,
        0,
        0,
        0,
        0,
      );
      final effectiveTo = (toDate != null)
          ? DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59, 999)
          : DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      query = _firestore
          .collection("transactions")
          .where(
            "createdAt",
            isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveFrom),
          )
          .where(
            "createdAt",
            isLessThanOrEqualTo: Timestamp.fromDate(effectiveTo),
          )
          .orderBy("createdAt", descending: true);
    }

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    query = query.limit(limit);

    return await query.get();
  }

  /// Updates an existing transaction in Firestore and synchronizes changes with daily and global stats documents.
  Future<void> updateTransaction(String docId, Map<String, dynamic> oldTx, Map<String, dynamic> newTx) async {
    final batch = _firestore.batch();
    final docRef = _firestore.collection("transactions").doc(docId);

    // Update the transaction document
    batch.update(docRef, {
      "items": newTx["items"],
      "subtotal": newTx["subtotal"],
      "tax": newTx["tax"],
      "discount": newTx["discount"],
      "total": newTx["total"],
      "cashAmount": newTx["cashAmount"],
      "onlineAmount": newTx["onlineAmount"],
    });

    // Recalculate stats differences if amounts changed
    final timestamp = oldTx["createdAt"] as Timestamp?;
    if (timestamp != null) {
      final txDate = timestamp.toDate();
      final dateKey = DateFormat("yyyy-MM-dd").format(txDate);
      final dailyRef = _firestore.collection("daily_stats").doc(dateKey);

      final diffTotal = (newTx["total"] as num) - (oldTx["total"] as num);
      final diffCash = (newTx["cashAmount"] as num) - (oldTx["cashAmount"] as num);
      final diffOnline = (newTx["onlineAmount"] as num) - (oldTx["onlineAmount"] as num);

      batch.set(dailyRef, {
        "revenue": FieldValue.increment(diffTotal),
        "totalCash": FieldValue.increment(diffCash),
        "totalOnline": FieldValue.increment(diffOnline),
        "lastUpdated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update global summary stats document
      final summaryRef = _firestore.collection("stats").doc("summary");
      batch.set(summaryRef, {
        "totalRevenue": FieldValue.increment(diffTotal),
        "lastUpdated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }
}
