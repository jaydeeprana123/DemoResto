import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense_model.dart';

class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'expenses';

  // Add a new expense
  Future<void> addExpense(ExpenseModel expense) async {
    await _firestore.collection(_collectionPath).add(expense.toMap());
  }

  // Delete an expense
  Future<void> deleteExpense(String id) async {
    await _firestore.collection(_collectionPath).doc(id).delete();
  }

  // Get expenses between dates
  Future<List<ExpenseModel>> getExpenses(DateTime from, DateTime to) async {
    final effectiveFrom = DateTime(from.year, from.month, from.day, 0, 0, 0);
    final effectiveTo = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);

    final snapshot = await _firestore
        .collection(_collectionPath)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveFrom))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(effectiveTo))
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Export to CSV and share
  Future<void> exportExpensesToCsv(DateTime from, DateTime to) async {
    try {
      final expenses = await getExpenses(from, to);

      List<List<dynamic>> csvData = [
        ['Date', 'Category', 'Description', 'Amount'],
      ];

      double totalAmount = 0;

      for (var expense in expenses) {
        csvData.add([
          DateFormat('dd-MM-yyyy hh:mm a').format(expense.date),
          expense.category,
          expense.description,
          expense.amount.toStringAsFixed(2),
        ]);
        totalAmount += expense.amount;
      }

      // Add a total row at the end
      csvData.add(['', '', 'Total', totalAmount.toStringAsFixed(2)]);

      String csv = const ListToCsvConverter().convert(csvData);

      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/expenses_${DateFormat('dd_MM_yyyy').format(from)}_to_${DateFormat('dd_MM_yyyy').format(to)}.csv";
      final file = File(path);
      
      await file.writeAsString(csv);

      // Share the file
      await Share.shareXFiles([XFile(path)], text: 'Expense Report');
      
    } catch (e) {
      print("Error exporting CSV: $e");
      rethrow;
    }
  }
}
