import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpensesRepository {
  Stream<QuerySnapshot<Map<String, dynamic>>> watchExpenses({
    required bool isFilterApplied,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    if (!isFilterApplied || fromDate == null) {
      return FirebaseFirestore.instance
          .collection('expenses')
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

    return FirebaseFirestore.instance
        .collection('expenses')
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
    return FirebaseFirestore.instance.collection('expenses').doc(docId).delete();
  }

  Future<void> addExpense({
    required String title,
    required double amount,
    required String category,
    required String note,
    required DateTime expenseDate,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    return FirebaseFirestore.instance.collection('expenses').add({
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
