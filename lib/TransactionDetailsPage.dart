import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/AddCategoryPage.dart' hide AddTablePage;
import 'package:demo/AddMenuItemPage.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'AddTablePage.dart';
import 'AllOrdersPage.dart';
import 'CartPage.dart';
import 'FinalCartPage.dart';
import 'MenuPage.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:flutter/material.dart';
import 'MenuPage.dart';
import 'package:get/get.dart';

import 'package:flutter/material.dart';
import 'MenuPage.dart';
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TransactionDetailsPage extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailsPage({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final items = (transaction["items"] as List<dynamic>? ?? []);
    final subtotal = (transaction["subtotal"] as num?)?.toDouble() ?? 0.0;
    final tax = (transaction["tax"] as num?)?.toDouble() ?? 0.0;
    final tip = (transaction["tip"] as num?)?.toDouble() ?? 0.0;
    final total = (transaction["total"] as num?)?.toDouble() ?? 0.0;
    final tableName = transaction["table"] ?? "Unknown";
    final dateTime = (transaction["createdAt"] as Timestamp?)?.toDate();

    return Scaffold(
      appBar: AppBar(title: const Text("Transaction Details")),
      body: Column(
        children: [
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text("No items in this transaction"))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      headingRowColor: MaterialStateColor.resolveWith(
                        (states) => Colors.orange.shade100,
                      ),
                      columns: const [
                        DataColumn(label: Text("Item")),
                        DataColumn(label: Text("Qty")),
                        DataColumn(label: Text("Total")),
                      ],
                      rows: items.map((item) {
                        final qty = item['qty'] as int? ?? 0;
                        final price =
                            (item['price'] as num?)?.toDouble() ?? 0.0;
                        final total = (qty * price);

                        return DataRow(
                          cells: [
                            DataCell(Text(item['name'] ?? "-")),
                            DataCell(
                              Text(
                                "×$qty",
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(Text("\$${total.toStringAsFixed(2)}")),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "$tableName",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dateTime != null
                          ? DateFormat("dd-MM-yyyy | hh:mm a").format(dateTime)
                          : "-",

                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(),
                _buildRow("Subtotal", subtotal),
                _buildRow("Tax (8.5%)", tax),
                _buildRow("Tip", tip),
                const Divider(),
                _buildRow("Total", total, isTotal: true),
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
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            "\$${value.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
