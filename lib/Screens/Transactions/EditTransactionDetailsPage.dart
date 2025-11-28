import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/AddCategoryPage.dart' hide AddTablePage;
import 'package:demo/AddMenuItemPage.dart';
import 'package:demo/Styles/my_colors.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Styles/my_font.dart';

import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';

// Import your AddTablePage, AddCategoryPage, MenuPage, FinalCartPage here
// import 'add_table_page.dart';
// import 'add_category_page.dart';
// import 'menu_page.dart';
// import 'final_cart_page.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

    items = List<Map<String, dynamic>>.from(widget.transaction["items"] ?? []);

    subtotalController.text = widget.transaction["subtotal"]?.toString() ?? "0";
    taxController.text = widget.transaction["tax"]?.toString() ?? "0";
    discountController.text = widget.transaction["discount"]?.toString() ?? "0";
    cashController.text = widget.transaction["cashAmount"]?.toString() ?? "0";
    onlineController.text =
        widget.transaction["onlineAmount"]?.toString() ?? "0";

    _recalculateTotals(); // initialize totals
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

    final taxPercent = 8.5; // you can modify this if dynamic
    final tax = (subtotal * taxPercent / 100).round();
    final discount = int.tryParse(discountController.text) ?? 0;
    final total = subtotal + tax - discount;

    setState(() {
      subtotalController.text = subtotal.toString();
      taxController.text = tax.toString();
      // total is derived, no controller needed
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
        ? DateFormat(
            "dd-MM-yyyy | hh:mm a",
          ).format((widget.transaction["createdAt"]).toDate())
        : "-";

    final total =
        (int.tryParse(subtotalController.text) ?? 0) +
        (int.tryParse(taxController.text) ?? 0) -
        (int.tryParse(discountController.text) ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Transaction"),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: saveChanges),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.transaction["table"] ?? "Unknown Table",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  dateTime,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Items list
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Items",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                ...items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final qty = item['qty'] ?? 0;
                  final price = item['price'] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['name'] ?? '-',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => updateItemQty(i, -1),
                            ),
                            Text(
                              qty.toString(),
                              style: const TextStyle(fontSize: 15),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.green,
                              ),
                              onPressed: () => updateItemQty(i, 1),
                            ),
                          ],
                        ),
                        Text(
                          "₹${qty * price}",
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),

            const Divider(height: 32),

            buildEditableRow("Subtotal", subtotalController, readOnly: true),
            buildEditableRow("Tax (8.5%)", taxController, readOnly: true),
            buildEditableRow(
              "Discount",
              discountController,
              onChanged: (_) => _recalculateTotals(),
            ),
            buildEditableRow("Cash", cashController),
            buildEditableRow("Online", onlineController),

            const SizedBox(height: 12),
            const Divider(),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Total",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  "₹$total",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: saveChanges,
              icon: const Icon(Icons.save),
              label: Text(
                "Save Changes",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: primary_color,
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
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 1,
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              onChanged: onChanged,
              textAlign: TextAlign.end,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 8,
                ),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
