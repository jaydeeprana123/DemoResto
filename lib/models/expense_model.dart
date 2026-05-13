import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String? id;
  final String description;
  final String category;
  final double amount;
  final DateTime date;
  final DateTime createdAt;

  ExpenseModel({
    this.id,
    required this.description,
    required this.category,
    required this.amount,
    required this.date,
    required this.createdAt,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String docId) {
    return ExpenseModel(
      id: docId,
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'category': category,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
