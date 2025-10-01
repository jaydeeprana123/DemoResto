import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/AddCategoryPage.dart' hide AddTablePage;
import 'package:demo/AddMenuItemPage.dart';
import 'package:demo/Styles/my_font.dart';
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

import 'Styles/my_colors.dart';
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

  bool isFilterApplied = false;
  double grandTotal = 0.0;
  int totalTransactionsData = 0;

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions = [];
  bool isLoading = false;
  bool hasMore = true;
  QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;

  final ScrollController _scrollController = ScrollController();
  static const int pageSize = 10;

  @override
  void initState() {
    super.initState();
    getTotalRevenue(); // total revenue initially
    fetchTransactions(); // load first page
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50 &&
        !isLoading &&
        hasMore) {
      fetchTransactions();
    }
  }

  Future<void> _pickDate({
    required BuildContext context,
    required bool isFrom,
  }) async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (fromDate ?? now)
          : (toDate ?? fromDate ?? now),
      firstDate: isFrom ? DateTime(2023) : (fromDate ?? DateTime(2023)),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          // normalize to start of day
          fromDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
          fromController.text = DateFormat("dd-MM-yyyy").format(picked);

          // If toDate not selected, default to today's end-of-day
          if (toDate == null) {
            final today = DateTime.now();
            toDate =
                DateTime(today.year, today.month, today.day, 23, 59, 59, 999);
            toController.text = DateFormat("dd-MM-yyyy").format(today);
          }
        } else {
          // If user picks To date and From is null, treat as same-day filter
          if (fromDate == null) {
            fromDate =
                DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
            fromController.text = DateFormat("dd-MM-yyyy").format(picked);
          }
          // normalize to end of day
          toDate =
              DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999);
          toController.text = DateFormat("dd-MM-yyyy").format(picked);
        }
      });

      // apply filter automatically after selection
      _applyFilter();
    }
  }

  void _applyFilter() async {
    if (fromDate != null) {
      final now = DateTime.now();
      final effectiveFrom = DateTime(
        fromDate!.year,
        fromDate!.month,
        fromDate!.day,
        0,
        0,
        0,
      );
      final effectiveTo = (toDate != null)
          ? DateTime(toDate!.year, toDate!.month, toDate!.day, 23, 59, 59, 999)
          : DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      // fetch grand total from daily_stats
      final result = await getRevenueBetweenDates(effectiveFrom, effectiveTo);

      setState(() {
        isFilterApplied = true;
        grandTotal = result["totalRevenue"];
        totalTransactionsData = result["totalTransactions"];
        // reset pagination
        transactions.clear();
        lastDoc = null;
        hasMore = true;
      });

      // fetch first page for this filter
      fetchTransactions();
    }
  }

  Future<Map<String, dynamic>> getRevenueBetweenDates(
      DateTime from, DateTime to) async {
    final fromKey = DateFormat("yyyy-MM-dd").format(from);
    final toKey = DateFormat("yyyy-MM-dd").format(to);

    final snapshot = await FirebaseFirestore.instance
        .collection("daily_stats")
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: fromKey)
        .where(FieldPath.documentId, isLessThanOrEqualTo: toKey)
        .get();

    double totalRevenue = 0;
    int totalTransactions = 0;

    for (var doc in snapshot.docs) {
      totalRevenue += (doc["revenue"] as num?)?.toDouble() ?? 0.0;
      totalTransactions += (doc["transactions"] as int?) ?? 0;
    }

    return {
      "totalRevenue": totalRevenue,
      "totalTransactions": totalTransactions,
    };
  }

  Future<void> getTotalRevenue() async {
    final snapshot =
    await FirebaseFirestore.instance.collection("daily_stats").get();

    double totalRevenue = 0;
    int totalTransactions = 0;

    for (var doc in snapshot.docs) {
      totalRevenue += (doc["revenue"] as num?)?.toDouble() ?? 0.0;
      totalTransactions += (doc["transactions"] as int?) ?? 0;
    }

    setState(() {
      isFilterApplied = false;
      grandTotal = totalRevenue;
      totalTransactionsData = totalTransactions;
    });
  }

  Future<void> fetchTransactions() async {
    if (isLoading || !hasMore) return;

    setState(() => isLoading = true);

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection("transactions")
        .orderBy("createdAt", descending: true);

    if (isFilterApplied && fromDate != null) {
      final now = DateTime.now();
      final effectiveFrom = DateTime(
          fromDate!.year, fromDate!.month, fromDate!.day, 0, 0, 0, 0);
      final effectiveTo = (toDate != null)
          ? DateTime(toDate!.year, toDate!.month, toDate!.day, 23, 59, 59, 999)
          : DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      query = FirebaseFirestore.instance
          .collection("transactions")
          .where("createdAt", isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveFrom))
          .where("createdAt", isLessThanOrEqualTo: Timestamp.fromDate(effectiveTo))
          .orderBy("createdAt", descending: true)
      as Query<Map<String, dynamic>>;
    }

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc!) as Query<Map<String, dynamic>>;
    }

    query = query.limit(pageSize) as Query<Map<String, dynamic>>;

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        transactions.addAll(snapshot.docs);
        lastDoc = snapshot.docs.last;
        if (snapshot.docs.length < pageSize) {
          hasMore = false;
        }
      });
    } else {
      setState(() => hasMore = false);
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
            totalTransactionsData != 0
                ? "Transactions ($totalTransactionsData)"
                : "Transactions",
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'Mulish-SemiBold',
            ),
          )),
      body: Column(
        children: [
          // Filter UI
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
                    style: const TextStyle(fontSize: 14),
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
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Grouped list (unchanged layout, paginated)
          Expanded(
            child: transactions.isEmpty && isLoading
                ? const Center(child: CircularProgressIndicator())
                : transactions.isEmpty
                ? const Center(child: Text("No transactions found"))
                : ListView.builder(
              controller: _scrollController,
              itemCount: transactions.length + 1,
              itemBuilder: (context, index) {
                if (index < transactions.length) {
                  final data = transactions[index].data();
                  final tableName = data["table"] ?? "Unknown";
                  final total =
                      (data["total"] as num?)?.toDouble() ?? 0.0;
                  final dateTime =
                  (data["createdAt"] as Timestamp?)?.toDate();
                  final dateKey = dateTime != null
                      ? DateFormat("dd-MM-yyyy").format(dateTime)
                      : "Unknown Date";

                  // show date header for first item or when date changes
                  bool showDateHeader = true;
                  if (index > 0) {
                    final prevData = transactions[index - 1].data();
                    final prevDateTime =
                    (prevData["createdAt"] as Timestamp?)?.toDate();
                    final prevDateKey = prevDateTime != null
                        ? DateFormat("dd-MM-yyyy")
                        .format(prevDateTime)
                        : "Unknown Date";
                    if (prevDateKey == dateKey) {
                      showDateHeader = false;
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showDateHeader)
                        Container(
                          width: double.infinity,
                          color: primary_color.withOpacity(0.1),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 8,
                          ),
                          child: Text(
                            dateKey,
                            style: const TextStyle(
                              fontSize: 15,
                              fontFamily: 'Mulish-Bold',
                            ),
                          ),
                        ),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TransactionDetailsPage(
                                transaction: data,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "$tableName",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontFamily:
                                            'Mulish-SemiBold',
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          dateTime != null
                                              ? DateFormat('hh:mm a')
                                              .format(dateTime)
                                              : "-",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color:
                                            Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      "\$${total.toStringAsFixed(2)}",
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontFamily: 'Mulish-Bold',
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  // loader / no more
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: hasMore
                          ? const CircularProgressIndicator()
                          : const Text("No more transactions"),
                    ),
                  );
                }
              },
            ),
          ),

          // Grand Total (from daily_stats)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orangeAccent.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Grand Total:",
                  style: TextStyle(
                      fontSize: 16, fontFamily: 'Mulish-SemiBold', color: Colors.white),
                ),
                Text(
                  "\$${grandTotal.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontFamily: 'Mulish-Bold',
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


