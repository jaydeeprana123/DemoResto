import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:demo/Styles/my_font.dart';
import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Screens/Transactions/TransactionDetailsView.dart';
import 'package:demo/Screens/Transactions/controllers/transactions_controller.dart';

/// TransactionsView
/// 
/// Part of the GetX Repository Pattern.
/// Refactored to act as a reactive presentation layer that displays transactions 
/// and daily statistics by observing [TransactionsController].
class TransactionsView extends StatelessWidget {
  const TransactionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final TransactionsController controller = Get.put(TransactionsController());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C),
        elevation: 0,
        titleSpacing: 16,
        title: Obx(() {
          final count = controller.totalTransactionsData.value;
          return Row(
            children: [
              Expanded(
                child: Text(
                  count != 0 ? "Transactions ($count)" : "Transactions",
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: fontMulishBold,
                    color: Colors.white,
                  ),
                ),
              ),
              // Online total pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_android,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "₹${controller.grandTotalOnline.value.toStringAsFixed(0)}",
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
              // Cash total pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.currency_rupee,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      controller.grandTotalCash.value.toStringAsFixed(0),
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
          );
        }),
      ),
      body: Column(
        children: [
          // Date Filter section
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.fromController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "From Date",
                      labelStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontFamily: fontMulishRegular,
                      ),
                      prefixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF1A3A5C),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFf57c35),
                          width: 1.5,
                        ),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: fontMulishSemiBold,
                    ),
                    onTap: () => controller.pickDate(context: context, isFrom: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller.toController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "To Date",
                      labelStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontFamily: fontMulishRegular,
                      ),
                      prefixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF1A3A5C),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFf57c35),
                          width: 1.5,
                        ),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: fontMulishSemiBold,
                    ),
                    onTap: () => controller.pickDate(context: context, isFrom: false),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Reactive Grouped List of transactions
          Expanded(
            child: Obx(() {
              final list = controller.transactions;
              final isLoad = controller.isLoading.value;
              final more = controller.hasMore.value;

              if (list.isEmpty && isLoad) {
                return const Center(child: CircularProgressIndicator());
              }
              if (list.isEmpty) {
                return const Center(child: Text("No transactions found"));
              }

              return ListView.builder(
                controller: controller.scrollController,
                itemCount: list.length + 1,
                itemBuilder: (context, index) {
                  if (index < list.length) {
                    final data = list[index];
                    final tableName = data["table"] ?? "Unknown";
                    final cashAmount = (data["cashAmount"] as int?) ?? 0;
                    final onlineAmount = (data["onlineAmount"] as int?) ?? 0;
                    final total = (data["total"] as num?)?.toDouble() ?? 0.0;
                    final dateTime = (data["createdAt"] as Timestamp?)?.toDate();
                    final dateKey = dateTime != null
                        ? DateFormat("dd-MM-yyyy").format(dateTime)
                        : "Unknown Date";

                    // show date header for first item or when date changes
                    bool showDateHeader = true;
                    if (index > 0) {
                      final prevData = list[index - 1];
                      final prevDateTime = (prevData["createdAt"] as Timestamp?)?.toDate();
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
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A3A5C),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        color: Colors.white70,
                                        size: 12,
                                      ),
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
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        InkWell(
                          onTap: () {
                            Get.to(() => TransactionDetailsView(transaction: data));
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
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
                                      // Payment method pills
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          if (onlineAmount > 0)
                                            Container(
                                              margin: const EdgeInsets.only(right: 6),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
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
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
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
                    // bottom loader
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: more
                            ? const CircularProgressIndicator()
                            : const Text("No more transactions"),
                      ),
                    );
                  }
                },
              );
            }),
          ),

          // Grand Total bar at the bottom
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
                Obx(() => Text(
                  "₹${controller.grandTotal.value.toStringAsFixed(0)}",
                  style: const TextStyle(
                    fontSize: 22,
                    fontFamily: fontMulishBold,
                    color: Color(0xFFf57c35),
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
