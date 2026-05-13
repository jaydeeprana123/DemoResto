import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'Styles/my_font.dart';
import 'models/expense_model.dart';
import 'services/expense_service.dart';

class ExpensePage extends StatefulWidget {
  const ExpensePage({Key? key}) : super(key: key);

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  final ExpenseService _expenseService = ExpenseService();
  
  DateTime? fromDate;
  DateTime? toDate;

  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();

  List<ExpenseModel> expenses = [];
  bool isLoading = false;
  double totalExpenses = 0.0;

  @override
  void initState() {
    super.initState();
    // Default to current month
    final now = DateTime.now();
    fromDate = DateTime(now.year, now.month, 1);
    toDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    fromController.text = DateFormat("dd-MM-yyyy").format(fromDate!);
    toController.text = DateFormat("dd-MM-yyyy").format(toDate!);
    
    fetchExpenses();
  }

  Future<void> fetchExpenses() async {
    if (fromDate == null || toDate == null) return;
    
    setState(() {
      isLoading = true;
    });

    try {
      final fetched = await _expenseService.getExpenses(fromDate!, toDate!);
      double total = 0;
      for (var exp in fetched) {
        total += exp.amount;
      }

      setState(() {
        expenses = fetched;
        totalExpenses = total;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load expenses: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom ? (fromDate ?? now) : (toDate ?? fromDate ?? now);
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2023),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
          fromController.text = DateFormat("dd-MM-yyyy").format(picked);

          if (toDate == null || toDate!.isBefore(fromDate!)) {
            toDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
            toController.text = DateFormat("dd-MM-yyyy").format(toDate!);
          }
        } else {
          if (fromDate == null || fromDate!.isAfter(picked)) {
            fromDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
            fromController.text = DateFormat("dd-MM-yyyy").format(fromDate!);
          }
          toDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
          toController.text = DateFormat("dd-MM-yyyy").format(picked);
        }
      });
      fetchExpenses();
    }
  }

  void _showAddExpenseDialog() {
    final _formKey = GlobalKey<FormState>();
    final _amountController = TextEditingController();
    final _descController = TextEditingController();
    final _categoryController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Add Expense',
                style: TextStyle(fontFamily: fontMulishBold, color: Color(0xFF1A3A5C)),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount (₹)',
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Enter amount';
                          if (double.tryParse(val) == null) return 'Invalid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Enter description' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Category (e.g. Utilities, Rent)',
                          prefixIcon: Icon(Icons.category),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Enter category' : null,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text("Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}"),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2023),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFf57c35)),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      Navigator.pop(context); // Close dialog
                      setState(() => isLoading = true);
                      try {
                        final expense = ExpenseModel(
                          description: _descController.text.trim(),
                          category: _categoryController.text.trim(),
                          amount: double.parse(_amountController.text.trim()),
                          date: selectedDate,
                          createdAt: DateTime.now(),
                        );
                        await _expenseService.addExpense(expense);
                        await fetchExpenses();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error adding expense: $e')),
                        );
                        setState(() => isLoading = false);
                      }
                    }
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _exportToCsv() async {
    if (fromDate == null || toDate == null || expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses to export in this date range')),
      );
      return;
    }
    
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating CSV...')),
      );
      
      await _expenseService.exportExpensesToCsv(fromDate!, toDate!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C),
        elevation: 0,
        title: const Text(
          "Expenses",
          style: TextStyle(fontFamily: fontMulishBold, color: Colors.white, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: 'Export CSV',
            onPressed: _exportToCsv,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFf57c35),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: _showAddExpenseDialog,
      ),
      body: Column(
        children: [
          // Date Filter Row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: fromController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "From Date",
                      labelStyle: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13, fontFamily: fontMulishRegular,
                      ),
                      prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1A3A5C))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFf57c35), width: 1.5)),
                      isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      filled: true, fillColor: Colors.white,
                    ),
                    style: const TextStyle(fontSize: 14, fontFamily: fontMulishSemiBold),
                    onTap: () => _pickDate(isFrom: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: toController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "To Date",
                      labelStyle: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13, fontFamily: fontMulishRegular,
                      ),
                      prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1A3A5C))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFf57c35), width: 1.5)),
                      isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      filled: true, fillColor: Colors.white,
                    ),
                    style: const TextStyle(fontSize: 14, fontFamily: fontMulishSemiBold),
                    onTap: () => _pickDate(isFrom: false),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),

          // Total Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Total Expenses",
                  style: TextStyle(fontSize: 15, fontFamily: fontMulishSemiBold, color: Color(0xFF1A3A5C)),
                ),
                Text(
                  "₹${totalExpenses.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 18, fontFamily: fontMulishBold, color: Colors.redAccent),
                ),
              ],
            ),
          ),

          // Expenses List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : expenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 10),
                            Text("No expenses found", style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF1A3A5C).withOpacity(0.1),
                                child: const Icon(Icons.money_off, color: Color(0xFF1A3A5C)),
                              ),
                              title: Text(
                                expense.description,
                                style: const TextStyle(fontFamily: fontMulishBold, fontSize: 16),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    expense.category,
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('dd MMM yyyy, hh:mm a').format(expense.date),
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "₹${expense.amount.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontFamily: fontMulishBold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () async {
                                      // Delete confirmation
                                      bool? confirm = await showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Expense?'),
                                          content: const Text('Are you sure you want to delete this expense?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true), 
                                              child: const Text('Yes', style: TextStyle(color: Colors.red))
                                            ),
                                          ],
                                        )
                                      );
                                      if (confirm == true && expense.id != null) {
                                        setState(() => isLoading = true);
                                        await _expenseService.deleteExpense(expense.id!);
                                        await fetchExpenses();
                                      }
                                    },
                                    child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
