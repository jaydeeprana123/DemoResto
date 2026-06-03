import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/Widgets/setup_page_layout.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../Styles/my_font.dart';

class EditTransactionPage extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final void Function(Map<String, dynamic> updatedTransaction)? onSave;

  const EditTransactionPage({
    super.key,
    required this.transaction,
    this.onSave,
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

    _recalculateTotals();
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

  void _recalculateTotals() {
    int subtotal = 0;
    for (var item in items) {
      final int qty = item['qty'] ?? 0;
      final int price = item['price'] ?? 0;
      subtotal += qty * price;
    }

    const taxPercent = 8.5;
    final tax = (subtotal * taxPercent / 100).round();

    setState(() {
      subtotalController.text = subtotal.toString();
      taxController.text = tax.toString();
    });
  }

  void updateItemQty(int index, int change) {
    setState(() {
      final newQty = (items[index]['qty'] ?? 0) + change;
      items[index]['qty'] = newQty < 0 ? 0 : newQty;
      _recalculateTotals();
    });
  }

  void saveChanges() {
    final subtotal = int.tryParse(subtotalController.text) ?? 0;
    final tax = int.tryParse(taxController.text) ?? 0;
    final discount = int.tryParse(discountController.text) ?? 0;
    final total = subtotal + tax - discount;
    final cashAmount = int.tryParse(cashController.text) ?? 0;
    final onlineAmount = int.tryParse(onlineController.text) ?? 0;

    final updatedTransaction = {
      ...widget.transaction,
      'items': items,
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'total': total,
      'cashAmount': cashAmount,
      'onlineAmount': onlineAmount,
    };

    widget.onSave?.call(updatedTransaction);
    Navigator.pop(context, updatedTransaction);
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
            onPressed: saveChanges,
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
                  SetupPageStyle.primaryButton(
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
            const Text(
              'Items',
              style: TextStyle(
                fontSize: 15,
                fontFamily: fontMulishBold,
                color: SetupPageColors.navy,
              ),
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
                final qty = item['qty'] ?? 0;
                final price = item['price'] ?? 0;
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
              onChanged: (_) => _recalculateTotals(),
            ),
            const SizedBox(height: 10),
            _buildEditableRow('Cash', cashController),
            const SizedBox(height: 10),
            _buildEditableRow('Online', onlineController),
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
