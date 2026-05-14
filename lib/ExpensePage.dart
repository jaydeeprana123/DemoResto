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

  // New Brand Colors
  static const Color _navy = Color(0xFF1A3A5C);
  static const Color _orange = Color(0xFFf57c35);

  @override
  void initState() {
    super.initState();
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _orange,
              onPrimary: Colors.white,
              onSurface: _navy,
            ),
          ),
          child: child!,
        );
      },
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
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'New Expense',
                style: TextStyle(fontFamily: fontMulishBold, color: _navy, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _dialogField(
                        controller: _amountController,
                        label: 'Amount (₹)',
                        icon: Icons.currency_rupee,
                        kbType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          if (double.tryParse(val) == null) return 'Invalid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _dialogField(
                        controller: _descController,
                        label: 'Description',
                        icon: Icons.description_outlined,
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      _dialogField(
                        controller: _categoryController,
                        label: 'Category (e.g. Utility)',
                        icon: Icons.category_outlined,
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2023),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(primary: _orange),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey.shade500),
                              const SizedBox(width: 12),
                              Text(
                                "Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}",
                                style: const TextStyle(fontFamily: fontMulishMedium, fontSize: 14, color: _navy),
                              ),
                              const Spacer(),
                              Icon(Icons.edit_outlined, size: 16, color: _orange),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontFamily: fontMulishSemiBold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      Navigator.pop(context);
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
                  child: const Text('Save Expense', style: TextStyle(fontFamily: fontMulishBold)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType kbType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: kbType,
      style: const TextStyle(fontFamily: fontMulishSemiBold, fontSize: 14, color: _navy),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _orange, width: 1.5)),
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      ),
    );
  }

  Future<void> _exportToCsv() async {
    if (fromDate == null || toDate == null || expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses to export')),
      );
      return;
    }
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating CSV...')));
      await _expenseService.exportExpensesToCsv(fromDate!, toDate!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: _navy),
        title: const Text(
          "Manage Expenses",
          style: TextStyle(fontFamily: fontMulishBold, color: _navy, fontSize: 18),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, size: 22),
            tooltip: 'Export CSV',
            onPressed: _exportToCsv,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _orange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Expense", style: TextStyle(color: Colors.white, fontFamily: fontMulishBold)),
        onPressed: _showAddExpenseDialog,
      ),
      body: Column(
        children: [
          // Filter Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(child: _dateFilterField(controller: fromController, label: "From Date", onTap: () => _pickDate(isFrom: true))),
                const SizedBox(width: 12),
                Expanded(child: _dateFilterField(controller: toController, label: "To Date", onTap: () => _pickDate(isFrom: false))),
              ],
            ),
          ),
          
          // Summary Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_navy, Color(0xFF2C537D)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: _navy.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Period Expenses", style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: fontMulishMedium)),
                    SizedBox(height: 4),
                    Text("Current Summary", style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: fontMulishBold)),
                  ],
                ),
                Text(
                  "₹${totalExpenses.toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 24, fontFamily: fontMulishBold, color: Colors.white),
                ),
              ],
            ),
          ),

          // Expenses List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: _orange))
                : expenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text("No expenses recorded", style: TextStyle(color: Colors.grey.shade400, fontFamily: fontMulishSemiBold)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.outbound_rounded, color: Colors.redAccent, size: 22),
                              ),
                              title: Text(expense.description, style: const TextStyle(fontFamily: fontMulishBold, fontSize: 15, color: _navy)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text("${expense.category} • ${DateFormat('dd MMM').format(expense.date)}", 
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontFamily: fontMulishRegular)),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("₹${expense.amount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.redAccent, fontFamily: fontMulishBold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () => _deleteExpense(expense),
                                    child: Icon(Icons.delete_outline_rounded, color: Colors.grey.shade400, size: 18),
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

  Widget _dateFilterField({required TextEditingController controller, required String label, required VoidCallback onTap}) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      style: const TextStyle(fontSize: 13, fontFamily: fontMulishSemiBold, color: _navy),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
        filled: true,
        fillColor: Colors.grey.shade50,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _orange, width: 1.5)),
      ),
    );
  }

  Future<void> _deleteExpense(ExpenseModel expense) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Expense', style: TextStyle(fontFamily: fontMulishBold, color: _navy)),
        content: Text('Remove expense of ₹${expense.amount}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('No', style: TextStyle(color: Colors.grey.shade600))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete')
          ),
        ],
      )
    );
    if (confirm == true && expense.id != null) {
      setState(() => isLoading = true);
      await _expenseService.deleteExpense(expense.id!);
      await fetchExpenses();
    }
  }
}

  }
}
