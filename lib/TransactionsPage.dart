import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/AddCategoryPage.dart' hide AddTablePage;
import 'package:demo/AddMenuItemPage.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/Styles/my_icons.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'AddTablePage.dart';
import 'KitchenOrdersListView.dart';
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
  double grandTotalOnline = 0.0;
  double grandTotalCash = 0.0;
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
      initialDate: isFrom ? (fromDate ?? now) : (toDate ?? fromDate ?? now),
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
            toDate = DateTime(
              today.year,
              today.month,
              today.day,
              23,
              59,
              59,
              999,
            );
            toController.text = DateFormat("dd-MM-yyyy").format(today);
          }
        } else {
          // If user picks To date and From is null, treat as same-day filter
          if (fromDate == null) {
            fromDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
            fromController.text = DateFormat("dd-MM-yyyy").format(picked);
          }
          // normalize to end of day
          toDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            23,
            59,
            59,
            999,
          );
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
        grandTotalOnline = result["totalOnline"];
        grandTotalCash = result["totalCash"];
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
    DateTime from,
    DateTime to,
  ) async {
    final fromKey = DateFormat("yyyy-MM-dd").format(from);
    final toKey = DateFormat("yyyy-MM-dd").format(to);

    final snapshot = await FirebaseFirestore.instance
        .collection("daily_stats")
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: fromKey)
        .where(FieldPath.documentId, isLessThanOrEqualTo: toKey)
        .get();

    double totalRevenue = 0;
    double totalCash = 0;
    double totalOnline = 0;
    int totalTransactions = 0;

    for (var doc in snapshot.docs) {
      totalRevenue += (doc["revenue"] as num?)?.toDouble() ?? 0.0;
      totalCash += (doc["totalCash"] as num?)?.toDouble() ?? 0.0;
      totalOnline += (doc["totalOnline"] as num?)?.toDouble() ?? 0.0;
      totalTransactions += (doc["transactions"] as int?) ?? 0;
    }

    return {
      "totalRevenue": totalRevenue,
      "totalCash": totalCash,
      "totalOnline": totalOnline,
      "totalTransactions": totalTransactions,
    };
  }

  Future<void> getTotalRevenue() async {
    final snapshot = await FirebaseFirestore.instance
        .collection("daily_stats")
        .get();

    double totalRevenue = 0;
    double totalCash = 0;
    double totalOnline = 0;
    int totalTransactions = 0;

    for (var doc in snapshot.docs) {
      totalRevenue += (doc["revenue"] as num?)?.toDouble() ?? 0.0;
      totalOnline += (doc["totalOnline"] as num?)?.toDouble() ?? 0.0;
      totalCash += (doc["totalCash"] as num?)?.toDouble() ?? 0.0;
      totalTransactions += (doc["transactions"] as int?) ?? 0;
    }

    setState(() {
      isFilterApplied = false;
      grandTotal = totalRevenue;
      grandTotalOnline = totalOnline;
      grandTotalCash = totalCash;
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
        fromDate!.year,
        fromDate!.month,
        fromDate!.day,
        0,
        0,
        0,
        0,
      );
      final effectiveTo = (toDate != null)
          ? DateTime(toDate!.year, toDate!.month, toDate!.day, 23, 59, 59, 999)
          : DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      query =
          FirebaseFirestore.instance
                  .collection("transactions")
                  .where(
                    "createdAt",
                    isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveFrom),
                  )
                  .where(
                    "createdAt",
                    isLessThanOrEqualTo: Timestamp.fromDate(effectiveTo),
                  )
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
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C),
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Expanded(
              child: Text(
                totalTransactionsData != 0
                    ? "Transactions ($totalTransactionsData)"
                    : "Transactions",
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: fontMulishBold,
                  color: Colors.white,
                ),
              ),
            ),
            // Online total
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_android, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    "₹${grandTotalOnline.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: fontMulishSemiBold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Cash total
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.currency_rupee, color: Colors.white70, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    grandTotalCash.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: fontMulishSemiBold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date filter row
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
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontFamily: fontMulishRegular,
                      ),
                      prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF1A3A5C), width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFf57c35), width: 1.5),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: const TextStyle(fontSize: 14, fontFamily: fontMulishSemiBold),
                    onTap: () => _pickDate(context: context, isFrom: true),
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
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontFamily: fontMulishRegular,
                      ),
                      prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF1A3A5C), width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFf57c35), width: 1.5),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: const TextStyle(fontSize: 14, fontFamily: fontMulishSemiBold),
                    onTap: () => _pickDate(context: context, isFrom: false),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

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
                        final cashAmount = (data["cashAmount"] as int?) ?? 0;
                        final onlineAmount =
                            (data["onlineAmount"] as int?) ?? 0;
                        final total =
                            (data["total"] as num?)?.toDouble() ?? 0.0;
                        final dateTime = (data["createdAt"] as Timestamp?)
                            ?.toDate();
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
                              ? DateFormat("dd-MM-yyyy").format(prevDateTime)
                              : "Unknown Date";
                          if (prevDateKey == dateKey) {
                            showDateHeader = false;
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date group header
                            if (showDateHeader)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A3A5C),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.calendar_today,
                                              color: Colors.white70, size: 12),
                                          const SizedBox(width: 6),
                                          Text(
                                            dateKey,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontFamily: fontMulishBold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Divider(
                                          color: Colors.grey.shade300,
                                          thickness: 1),
                                    ),
                                  ],
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
                                  horizontal: 10, vertical: 4,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border(
                                    left: BorderSide(
                                      color: cashAmount > 0 && onlineAmount > 0
                                          ? Colors.purple.shade300
                                          : onlineAmount > 0
                                              ? Colors.blue.shade400
                                              : const Color(0xFFf57c35),
                                      width: 4,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Table icon
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A3A5C).withOpacity(0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.table_restaurant_outlined,
                                        size: 18,
                                        color: Color(0xFF1A3A5C),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tableName,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontFamily: fontMulishBold,
                                              color: Color(0xFF1A3A5C),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            dateTime != null
                                                ? DateFormat('hh:mm a').format(dateTime)
                                                : "-",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade500,
                                              fontFamily: fontMulishRegular,
                                            ),
                                          ),
                                          // Payment pills
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              if (onlineAmount > 0)
                                                Container(
                                                  margin: const EdgeInsets.only(right: 6),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade50,
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: Colors.blue.shade200),
                                                  ),
                                                  child: Text(
                                                    "Online ₹$onlineAmount",
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontFamily: fontMulishSemiBold,
                                                      color: Colors.blue.shade700,
                                                    ),
                                                  ),
                                                ),
                                              if (cashAmount > 0)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade50,
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: Colors.green.shade200),
                                                  ),
                                                  child: Text(
                                                    "Cash ₹$cashAmount",
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontFamily: fontMulishSemiBold,
                                                      color: Colors.green.shade700,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Total amount
                                    Text(
                                      "₹${total.toStringAsFixed(0)}",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontFamily: fontMulishBold,
                                        color: Colors.green,
                                      ),
                                    ),
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

          // Grand Total bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF1A3A5C),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Grand Total",
                  style: TextStyle(
                    fontSize: 15,
                    fontFamily: fontMulishSemiBold,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  "₹${grandTotal.toStringAsFixed(0)}",
                  style: const TextStyle(
                    fontSize: 22,
                    fontFamily: fontMulishBold,
                    color: Color(0xFFf57c35),
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
