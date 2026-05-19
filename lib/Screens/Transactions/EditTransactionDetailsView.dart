import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';

/// EditTransactionView
/// 
/// Part of the GetX Repository Pattern presentation layer.
/// Displays editable properties of a transaction (quantities, discount, cash, online amounts) 
/// and notifies the caller via [onSave] when changes are saved.
class EditTransactionView extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final void Function(Map<String, dynamic> updatedTransaction)? onSave;

  const EditTransactionView({
    super.key,
    required this.transaction,
    this.onSave,
  });

  @override
  State<EditTransactionView> createState() => _EditTransactionViewState();
}

class _EditTransactionViewState extends State<EditTransactionView> {
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

    items = List<Map<String, dynamic>>.from(
      (widget.transaction["items"] as List<dynamic>? ?? []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );

    subtotalController.text = widget.transaction["subtotal"]?.toString() ?? "0";
    taxController.text = widget.transaction["tax"]?.toString() ?? "0";
    discountController.text = widget.transaction["discount"]?.toString() ?? "0";
    cashController.text = widget.transaction["cashAmount"]?.toString() ?? "0";
    onlineController.text = widget.transaction["onlineAmount"]?.toString() ?? "0";

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

  /// Recalculates line item values, subtotals, and tax percentages.
  void _recalculateTotals() {
    int subtotal = 0;
    for (var item in items) {
      final int qty = (item['qty'] as num?)?.toInt() ?? 0;
      final int price = (item['price'] as num?)?.toInt() ?? 0;
      subtotal += qty * price;
    }

    const taxPercent = 8.5;
    final tax = (subtotal * taxPercent / 100).round();
    final discount = int.tryParse(discountController.text) ?? 0;

    setState(() {
      subtotalController.text = subtotal.toString();
      taxController.text = tax.toString();
    });
  }

  /// Adjusts quantity value for a transaction line item.
  void updateItemQty(int index, int change) {
    setState(() {
      final int currentQty = (items[index]['qty'] as num?)?.toInt() ?? 0;
      final newQty = currentQty + change;
      items[index]['qty'] = newQty < 0 ? 0 : newQty;
      
      // Update item line total as well
      final int price = (items[index]['price'] as num?)?.toInt() ?? 0;
      items[index]['total'] = items[index]['qty'] * price;
      
      _recalculateTotals();
    });
  }

  /// Validates inputs and triggers the save callback for modifications.
  void saveChanges() {
    final subtotal = int.tryParse(subtotalController.text) ?? 0;
    final tax = int.tryParse(taxController.text) ?? 0;
    final discount = int.tryParse(discountController.text) ?? 0;
    final total = subtotal + tax - discount;
    final cashAmount = int.tryParse(cashController.text) ?? 0;
    final onlineAmount = int.tryParse(onlineController.text) ?? 0;

    final updatedTransaction = {
      ...widget.transaction,
      "items": items,
      "subtotal": subtotal,
      "tax": tax,
      "discount": discount,
      "total": total,
      "cashAmount": cashAmount,
      "onlineAmount": onlineAmount,
    };

    widget.onSave?.call(updatedTransaction);
    Navigator.pop(context, updatedTransaction);
  }

  @override
  Widget build(BuildContext context) {
    final dateTime = widget.transaction["createdAt"] != null
        ? DateFormat("dd-MM-yyyy | hh:mm a").format((widget.transaction["createdAt"] as Timestamp).toDate())
        : "-";

    final total = (int.tryParse(subtotalController.text) ?? 0) +
        (int.tryParse(taxController.text) ?? 0) -
        (int.tryParse(discountController.text) ?? 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Edit Transaction",
          style: TextStyle(
            fontSize: 16,
            fontFamily: fontMulishBold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined, color: Colors.greenAccent),
            onPressed: saveChanges,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Details Header Card
            Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.transaction["table"] ?? "Unknown Table",
                      style: const TextStyle(
                        fontSize: 15,
                        fontFamily: fontMulishBold,
                        color: Color(0xFF1A3A5C),
                      ),
                    ),
                    Text(
                      dateTime,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: fontMulishRegular,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Items List Card
            Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Items Ledger",
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: fontMulishBold,
                        color: Color(0xFF1A3A5C),
                      ),
                    ),
                    const Divider(height: 24),
                    ...items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final qty = (item['qty'] as num?)?.toInt() ?? 0;
                      final price = (item['price'] as num?)?.toInt() ?? 0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item['name'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontFamily: fontMulishSemiBold,
                                  color: Color(0xFF1A3A5C),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline_rounded,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  onPressed: () => updateItemQty(i, -1),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    qty.toString(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontFamily: fontMulishBold,
                                      color: Color(0xFF1A3A5C),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                  onPressed: () => updateItemQty(i, 1),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "₹${qty * price}",
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
            ),

            const SizedBox(height: 16),

            // Financial Summary Input Card
            Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    buildEditableRow("Subtotal", subtotalController, readOnly: true, icon: Icons.restaurant_menu_outlined),
                    buildEditableRow("Tax (8.5%)", taxController, readOnly: true, icon: Icons.pie_chart_outline),
                    buildEditableRow(
                      "Discount",
                      discountController,
                      icon: Icons.local_offer_outlined,
                      onChanged: (_) => _recalculateTotals(),
                    ),
                    buildEditableRow("Cash Payment", cashController, icon: Icons.currency_rupee),
                    buildEditableRow("Online Payment", onlineController, icon: Icons.phone_android),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Total Amount",
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: fontMulishBold,
                            color: Color(0xFF1A3A5C),
                          ),
                        ),
                        Text(
                          "₹$total",
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: fontMulishBold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: saveChanges,
              icon: const Icon(Icons.save_outlined, color: Colors.white, size: 18),
              label: const Text(
                "SAVE CHANGES",
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: fontMulishBold,
                  color: Colors.white,
                  letterSpacing: 1.1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: const Color(0xFFf57c35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEditableRow(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
    required IconData icon,
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF1A3A5C)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: fontMulishSemiBold,
                  color: Color(0xFF1A3A5C),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              onChanged: onChanged,
              textAlign: TextAlign.end,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 10,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFf57c35)),
                ),
                fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
                filled: true,
              ),
              style: const TextStyle(
                fontSize: 13,
                fontFamily: fontMulishBold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
