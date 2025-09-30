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

import 'TransactionDetailsPage.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  DateTime? fromDate;
  DateTime? toDate;

  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();

  bool isFilterApplied = false; // apply filter only after submit

  Future<void> _pickDate({
    required BuildContext context,
    required bool isFrom,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
          fromController.text = DateFormat("dd-MM-yyyy").format(picked);
        } else {
          toDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
          toController.text = DateFormat("dd-MM-yyyy").format(picked);
        }
      });
    }
  }

  void _applyFilter() {
    if (fromDate != null && toDate != null) {
      setState(() {
        isFilterApplied = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Transactions")),
      body: Column(
        children: [
          // 🔹 Filter UI
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: fromController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: "From Date",
                      border: OutlineInputBorder(),
                    ),
                    onTap: () => _pickDate(context: context, isFrom: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: toController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: "To Date",
                      border: OutlineInputBorder(),
                    ),
                    onTap: () => _pickDate(context: context, isFrom: false),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _applyFilter,
                  child: const Text("Submit"),
                ),
              ],
            ),
          ),

          const Divider(),

          // 🔹 Transaction List
          Expanded(child: buildTransactionList()),
        ],
      ),
    );
  }

  Widget buildTransactionList() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      "transactions",
    );

    if (isFilterApplied && fromDate != null && toDate != null) {
      query = query
          .where("createdAt", isGreaterThanOrEqualTo: fromDate)
          .where("createdAt", isLessThanOrEqualTo: toDate);
    }

    query = query.orderBy("createdAt", descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No transactions found"));
        }

        final transactions = snapshot.data!.docs;

        // 🔹 Group transactions by date
        final Map<String, List<Map<String, dynamic>>> groupedData = {};
        double grandTotal = 0.0;

        for (var doc in transactions) {
          final data = doc.data() as Map<String, dynamic>;
          final total = (data["total"] as num?)?.toDouble() ?? 0.0;
          grandTotal += total;

          final dateTime = (data["createdAt"] as Timestamp?)?.toDate();
          final dateKey = dateTime != null
              ? DateFormat("dd-MM-yyyy").format(dateTime)
              : "Unknown Date";

          groupedData.putIfAbsent(dateKey, () => []);
          groupedData[dateKey]!.add(data);
        }

        return Column(
          children: [
            Expanded(
              child: ListView(
                children: groupedData.entries.map((entry) {
                  final date = entry.key;
                  final dateTransactions = entry.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔹 Date Heading
                      Container(
                        width: double.infinity,
                        color: Colors.orange.shade100,
                        margin: EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 8,
                        ),
                        child: Text(
                          date,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // 🔹 Transactions under this date
                      ...dateTransactions.map((data) {
                        final tableName = data["table"] ?? "Unknown";
                        final total = data["total"] ?? 0.0;
                        final dateTime = (data["createdAt"] as Timestamp?)
                            ?.toDate();

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TransactionDetailsPage(transaction: data),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            // decoration: BoxDecoration(
                            //   color: Colors.white,
                            //   borderRadius: BorderRadius.circular(8),
                            //   boxShadow: [
                            //     BoxShadow(
                            //       color: Colors.grey.withOpacity(0.2),
                            //       blurRadius: 4,
                            //       offset: const Offset(0, 2),
                            //     ),
                            //   ],
                            // ),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 🔹 Table Name
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "$tableName",
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),

                                          // 🔹 Time
                                          Text(
                                            dateTime != null
                                                ? DateFormat(
                                                    'hh:mm a',
                                                  ).format(dateTime)
                                                : "-",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // 🔹 Total
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        "\$${(total as num).toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                Divider(),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                }).toList(),
              ),
            ),

            // 🔹 Grand Total Section
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Grand Total:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "\$${grandTotal.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
