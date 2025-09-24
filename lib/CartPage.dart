import 'package:flutter/material.dart';
import 'dart:math'; // ⬅️ add this at the top

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

/// Cart Page
class CartPage extends StatelessWidget {
  final List<Map<String, dynamic>> menuData;
  final void Function(List<Map<String, dynamic>> selectedItems) onConfirm;

  CartPage({required this.menuData, required this.onConfirm});

  double get subtotal {
    double total = 0;
    for (var item in menuData) {
      total += (item['qty'] as int) * (item['price'] as double);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final tax = subtotal * 0.085;
    final tip = subtotal * 0.15;
    final total = subtotal + tax + tip;

    return Scaffold(
      appBar: AppBar(title: Text("Cart")),
      body: Column(
        children: [
          Expanded(
            child: menuData.isEmpty
                ? Center(child: Text("No items in cart"))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      headingRowColor: MaterialStateColor.resolveWith(
                        (states) => Colors.orange.shade100,
                      ),
                      columns: const [
                        DataColumn(label: Text("Item")),
                        DataColumn(label: Text("Qty")),
                        // DataColumn(label: Text("Price")),
                        DataColumn(label: Text("Total")),
                      ],
                      rows: menuData.map((item) {
                        final qty = item['qty'] as int;
                        final price = item['price'] as double;
                        return DataRow(
                          cells: [
                            DataCell(Text(item['name'])),
                            DataCell(
                              Row(
                                children: [
                                  Text(
                                    "\u00D7$qty",
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // DataCell(Text("\$${price.toStringAsFixed(2)}")),
                            DataCell(
                              Text("\$${(qty * price).toStringAsFixed(2)}"),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                _buildRow("Subtotal", subtotal),
                _buildRow("Tax (8.5%)", tax),
                _buildRow("Tip", tip),
                Divider(),
                _buildRow("Total", total, isTotal: true),
                SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      onConfirm(menuData);
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: Text(
                      "Confirm & Add to Table (\$${total.toStringAsFixed(2)})",
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            "\$${value.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
