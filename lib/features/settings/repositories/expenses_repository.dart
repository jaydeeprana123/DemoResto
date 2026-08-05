import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartKitchen/core/firestore/firestore_paths.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpensesRepository {
  Stream<QuerySnapshot<Map<String, dynamic>>> watchExpenses({
    required bool isFilterApplied,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    if (!isFilterApplied || fromDate == null) {
      return FirestorePaths
          .scoped('expenses')
          .orderBy('createdAt', descending: true)
          .snapshots();
    }

    final now = DateTime.now();
    final effectiveFrom = DateTime(
      fromDate.year,
      fromDate.month,
      fromDate.day,
    );
    final effectiveTo = toDate != null
        ? DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59, 999)
        : DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    return FirestorePaths
        .scoped('expenses')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveFrom),
        )
        .where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(effectiveTo),
        )
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteExpense(String docId) {
    return FirestorePaths.scopedDoc('expenses', docId).delete();
  }

  Future<void> addExpense({
    required String title,
    required double amount,
    required String category,
    required String note,
    required DateTime expenseDate,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    return FirestorePaths.scoped('expenses').add({
      'title': title,
      'amount': amount,
      'category': category,
      'note': note,
      'createdBy': user?.uid,
      'createdAt': Timestamp.fromDate(
        DateTime(expenseDate.year, expenseDate.month, expenseDate.day, 12),
      ),
    });
  }
}
