import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/features/settings/repositories/expenses_repository.dart';
import 'package:demo/features/settings/views/AddExpensePage.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  static const _navy = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);

  DateTime? fromDate;
  DateTime? toDate;

  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();

  bool isFilterApplied = false;

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _expensesStream() {
    return Get.find<ExpensesRepository>().watchExpenses(
      isFilterApplied: isFilterApplied,
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  Future<void> _pickDate({
    required BuildContext context,
    required bool isFrom,
  }) async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (fromDate ?? now) : (toDate ?? fromDate ?? now),
      firstDate: isFrom ? DateTime(2023) : (fromDate ?? DateTime(2023)),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
          fromController.text = DateFormat('dd-MM-yyyy').format(picked);

          if (toDate == null) {
            final today = DateTime.now();
            toDate = DateTime(
              today.year,
              today.month,
              today.day,
              23,
              59,
              59,
              999,
            );
            toController.text = DateFormat('dd-MM-yyyy').format(today);
          }
        } else {
          if (fromDate == null) {
            fromDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
            fromController.text = DateFormat('dd-MM-yyyy').format(picked);
          }
          toDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            23,
            59,
            59,
            999,
          );
          toController.text = DateFormat('dd-MM-yyyy').format(picked);
        }
      });

      _applyFilter();
    }
  }

  void _applyFilter() {
    if (fromDate != null) {
      setState(() => isFilterApplied = true);
    }
  }

  Future<void> _deleteExpense(String docId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text("Are you sure you want to delete '$title'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await Get.find<ExpensesRepository>().deleteExpense(docId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete expense: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        title: const Text(
          'Expenses',
          style: TextStyle(
            fontSize: 16,
            fontFamily: fontMulishBold,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.to(() => const AddExpensePage()),
        backgroundColor: _orange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Expense',
          style: TextStyle(
            fontFamily: fontMulishSemiBold,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: fromController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'From Date',
                      labelStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontFamily: fontMulishRegular,
                      ),
                      prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _navy, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _orange, width: 1.5),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: fontMulishSemiBold,
                    ),
                    onTap: () => _pickDate(context: context, isFrom: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: toController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'To Date',
                      labelStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontFamily: fontMulishRegular,
                      ),
                      prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _navy, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _orange, width: 1.5),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: fontMulishSemiBold,
                    ),
                    onTap: () => _pickDate(context: context, isFrom: false),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _expensesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _orange),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading expenses',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isFilterApplied
                              ? 'No expenses found'
                              : 'No expenses yet',
                          style: TextStyle(
                            fontFamily: fontMulishSemiBold,
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isFilterApplied
                              ? 'Try a different date range'
                              : 'Tap Add Expense to record one',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                double total = 0;
                for (final doc in docs) {
                  total += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
                }

                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _navy,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isFilterApplied ? 'Filtered Expenses' : 'Total Expenses',
                            style: const TextStyle(
                              fontFamily: fontMulishSemiBold,
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontFamily: fontMulishBold,
                              fontSize: 24,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${docs.length} record${docs.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          final title = data['title'] as String? ?? 'Expense';
                          final amount =
                              (data['amount'] as num?)?.toDouble() ?? 0;
                          final category = data['category'] as String? ?? '';
                          final note = data['note'] as String? ?? '';
                          final createdAt =
                              (data['createdAt'] as Timestamp?)?.toDate();
                          final dateStr = createdAt != null
                              ? DateFormat('dd MMM yyyy, hh:mm a')
                                  .format(createdAt)
                              : '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: _orange.withOpacity(0.15),
                                child: const Icon(
                                  Icons.payments_outlined,
                                  color: _orange,
                                ),
                              ),
                              title: Text(
                                title,
                                style: const TextStyle(
                                  fontFamily: fontMulishSemiBold,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (category.isNotEmpty)
                                    Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  if (note.isNotEmpty)
                                    Text(
                                      note,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  if (dateStr.isNotEmpty)
                                    Text(
                                      dateStr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹${amount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontFamily: fontMulishBold,
                                      fontSize: 16,
                                      color: _navy,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Delete expense',
                                    onPressed: () =>
                                        _deleteExpense(doc.id, title),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

