import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/features/menu_setup/widgets/setup_page_layout.dart';
import 'package:demo/features/transactions/repositories/transactions_repository.dart';
import 'package:demo/features/transactions/widgets/add_menu_item_sheet.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class EditTransactionPage extends StatefulWidget {
  final String transactionId;
  final Map<String, dynamic> transaction;

  const EditTransactionPage({
    super.key,
    required this.transactionId,
    required this.transaction,
  });

  @override
  State<EditTransactionPage> createState() => _EditTransactionPageState();
}

class _EditTransactionPageState extends State<EditTransactionPage> {
  late TextEditingController subtotalController;
  late TextEditingController taxController;
  late TextEditingController discountController;
  late TextEditingController cashController;
  late TextEditingController onlineController;

  late List<Map<String, dynamic>> items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    subtotalController = TextEditingController();
    taxController = TextEditingController();
    discountController = TextEditingController();
    cashController = TextEditingController();
    onlineController = TextEditingController();

    items = List<Map<String, dynamic>>.from(widget.transaction['items'] ?? []);

    subtotalController.text =
        widget.transaction['subtotal']?.toString() ?? '0';
    taxController.text = widget.transaction['tax']?.toString() ?? '0';
    discountController.text =
        widget.transaction['discount']?.toString() ?? '0';
    cashController.text = widget.transaction['cashAmount']?.toString() ?? '0';
    onlineController.text =
        widget.transaction['onlineAmount']?.toString() ?? '0';

    _syncTotalsFromItems();
    _alignPaymentFieldsToTotal();
  }

  int get _computedTotal {
    final subtotal = int.tryParse(subtotalController.text) ?? 0;
    final tax = int.tryParse(taxController.text) ?? 0;
    final discount = int.tryParse(discountController.text) ?? 0;
    return subtotal + tax - discount;
  }

  /// Keeps cash/online in sync when subtotal, tax, or discount change.
  void _alignPaymentFieldsToTotal() {
    final total = _computedTotal;
    if (total < 0) return;

    final cash = int.tryParse(cashController.text) ?? 0;
    final online = int.tryParse(onlineController.text) ?? 0;
    if (cash + online == total) return;

    if (online == 0) {
      cashController.text = total.toString();
    } else if (cash == 0) {
      onlineController.text = total.toString();
    } else {
      cashController.text = (total - online).toString();
    }
  }

  @override
  void dispose() {
    subtotalController.dispose();
    taxController.dispose();
    discountController.dispose();
    cashController.dispose();
    onlineController.dispose();
    super.dispose();
  }

  void _syncTotalsFromItems() {
    var subtotal = 0;
    for (var item in items) {
      final qty = transactionAsInt(item['qty']);
      final price = transactionAsInt(item['price']);
      subtotal += qty * price;
    }

    const taxPercent = 8.5;
    final tax = (subtotal * taxPercent / 100).round();

    subtotalController.text = subtotal.toString();
    taxController.text = tax.toString();
  }

  void _recalculateTotals() {
    setState(_syncTotalsFromItems);
  }

  void updateItemQty(int index, int change) {
    setState(() {
      final newQty = transactionAsInt(items[index]['qty']) + change;
      items[index]['qty'] = newQty < 0 ? 0 : newQty;
      _recalculateTotals();
    });
  }

  void _addItemFromMenu(Map<String, dynamic> menuItem) {
    final name = menuItem['name']?.toString() ?? '';
    if (name.isEmpty) return;

    final price = transactionAsInt(menuItem['price']);
    setState(() {
      final existingIndex = items.indexWhere(
        (e) => e['name']?.toString() == name,
      );
      if (existingIndex >= 0) {
        items[existingIndex]['qty'] =
            transactionAsInt(items[existingIndex]['qty']) + 1;
      } else {
        items.add({'name': name, 'qty': 1, 'price': price});
      }
      _recalculateTotals();
    });
  }

  Future<void> _openAddFromMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SetupPageColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => AddMenuItemSheet(
        onItemSelected: (item) {
          _addItemFromMenu(item);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showMessage(String msg, {bool isError = true}) {
    Get.closeAllSnackbars();
    Get.snackbar(
      isError ? 'Could not save' : 'Saved',
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> saveChanges() async {
    if (_saving) return;

    if (widget.transactionId.trim().isEmpty) {
      _showMessage('Missing transaction id. Go back and open the transaction again.');
      return;
    }

    _syncTotalsFromItems();
    _alignPaymentFieldsToTotal();

    final subtotal = int.tryParse(subtotalController.text) ?? 0;
    final tax = int.tryParse(taxController.text) ?? 0;
    final discount = int.tryParse(discountController.text) ?? 0;
    final total = _computedTotal;
    final cashAmount = int.tryParse(cashController.text) ?? 0;
    final onlineAmount = int.tryParse(onlineController.text) ?? 0;

    if (total < 0) {
      _showMessage('Total cannot be negative.');
      return;
    }
    if (cashAmount + onlineAmount != total) {
      _showMessage(
        'Cash (₹$cashAmount) + Online (₹$onlineAmount) must equal total (₹$total).',
      );
      return;
    }

    final activeItems = items
        .where((e) => transactionAsInt(e['qty']) > 0)
        .toList();
    if (activeItems.isEmpty) {
      _showMessage('Keep at least one item with quantity greater than 0.');
      return;
    }

    final updatedTransaction = {
      ...widget.transaction,
      'items': activeItems,
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'total': total,
      'cashAmount': cashAmount,
      'onlineAmount': onlineAmount,
    };

    setState(() => _saving = true);
    try {
      await Get.find<TransactionsRepository>().updateTransaction(
        transactionId: widget.transactionId,
        previous: widget.transaction,
        updated: updatedTransaction,
      );
      if (!mounted) return;
      Navigator.pop(context, updatedTransaction);
    } catch (e) {
      if (mounted) {
        final msg = e is FirebaseException
            ? (e.message ?? 'Failed to save transaction.')
            : e.toString().replaceFirst('Exception: ', '');
        _showMessage(msg);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int get _total =>
      (int.tryParse(subtotalController.text) ?? 0) +
      (int.tryParse(taxController.text) ?? 0) -
      (int.tryParse(discountController.text) ?? 0);

  String get _dateTime {
    final createdAt = widget.transaction['createdAt'];
    if (createdAt is Timestamp) {
      return DateFormat('dd MMM yyyy  hh:mm a').format(createdAt.toDate());
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final tableName = widget.transaction['table']?.toString() ?? 'Unknown Table';

    return Scaffold(
      backgroundColor: SetupPageColors.bg,
      appBar: AppBar(
        backgroundColor: SetupPageColors.navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Edit Transaction',
          style: TextStyle(
            fontSize: 16,
            fontFamily: fontMulishBold,
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : saveChanges,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text(
              'Save',
              style: TextStyle(
                fontFamily: fontMulishSemiBold,
                fontSize: 13,
              ),
            ),
            style: TextButton.styleFrom(foregroundColor: SetupPageColors.orange),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(tableName),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildItemsSection(),
                  const SizedBox(height: 16),
                  _buildSummaryCard(),
                  const SizedBox(height: 16),
                  _saving
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : SetupPageStyle.primaryButton(
                          label: 'Save Changes',
                          icon: Icons.check_rounded,
                          onTap: saveChanges,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String tableName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: SetupPageColors.navy,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.table_restaurant_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tableName,
              style: const TextStyle(
                fontSize: 16,
                fontFamily: fontMulishBold,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            _dateTime,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: fontMulishRegular,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    return SetupPageStyle.listCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Items',
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily: fontMulishBold,
                      color: SetupPageColors.navy,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _openAddFromMenu,
                  icon: const Icon(
                    Icons.restaurant_menu_outlined,
                    size: 18,
                    color: SetupPageColors.orange,
                  ),
                  label: const Text(
                    'Add from menu',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: fontMulishSemiBold,
                      color: SetupPageColors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No items in this transaction',
                  style: TextStyle(
                    fontFamily: fontMulishRegular,
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              )
            else
              ...items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final qty = transactionAsInt(item['qty']);
                final price = transactionAsInt(item['price']);
                final lineTotal = qty * price;
                final remarks = item['remarks']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SetupPageColors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name']?.toString() ?? '-',
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: fontMulishBold,
                                color: SetupPageColors.navy,
                              ),
                            ),
                            if (remarks.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                remarks,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: SetupPageColors.orange,
                                  fontFamily: fontMulishRegular,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red,
                          size: 22,
                        ),
                        onPressed: () => updateItemQty(i, -1),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: SetupPageColors.navy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '×$qty',
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: fontMulishBold,
                            color: SetupPageColors.navy,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: SetupPageColors.green,
                          size: 22,
                        ),
                        onPressed: () => updateItemQty(i, 1),
                      ),
                      Text(
                        '₹$lineTotal',
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: fontMulishBold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return SetupPageStyle.listCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Payment Summary',
              style: TextStyle(
                fontSize: 15,
                fontFamily: fontMulishBold,
                color: SetupPageColors.navy,
              ),
            ),
            const SizedBox(height: 14),
            _buildReadOnlyRow('Subtotal', subtotalController),
            const SizedBox(height: 10),
            _buildReadOnlyRow('Tax (8.5%)', taxController),
            const SizedBox(height: 10),
            _buildEditableRow(
              'Discount',
              discountController,
              onChanged: (_) {
                _alignPaymentFieldsToTotal();
                setState(() {});
              },
            ),
            const SizedBox(height: 10),
            _buildEditableRow(
              'Cash',
              cashController,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            _buildEditableRow(
              'Online',
              onlineController,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            DottedLine(
              dashLength: 4,
              dashGapLength: 6,
              lineThickness: 1,
              dashColor: Colors.grey.shade300,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: fontMulishBold,
                    color: SetupPageColors.navy,
                  ),
                ),
                Text(
                  '₹$_total',
                  style: const TextStyle(
                    fontSize: 18,
                    fontFamily: fontMulishBold,
                    color: SetupPageColors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyRow(String label, TextEditingController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontFamily: fontMulishRegular,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          '₹${controller.text}',
          style: const TextStyle(
            fontSize: 13,
            fontFamily: fontMulishSemiBold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildEditableRow(
    String label,
    TextEditingController controller, {
    Function(String)? onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SetupPageStyle.label(label),
        ),
        Expanded(
          flex: 1,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textAlign: TextAlign.end,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: fontMulishSemiBold,
              color: SetupPageColors.navy,
            ),
            decoration: SetupPageStyle.inputDecoration(
              hint: '0',
              icon: Icons.currency_rupee_rounded,
            ).copyWith(
              prefixIcon: null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
