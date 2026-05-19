import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';

import 'package:demo/Screens/Transactions/EditTransactionDetailsView.dart';
import 'package:demo/Screens/Transactions/controllers/transactions_controller.dart';
import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';

/// TransactionDetailsView
/// 
/// Part of the GetX Repository Pattern.
/// Renders transaction items, subtotals, discounts, and payment breakdown reactively
/// styled with the application's premium theme.
class TransactionDetailsView extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailsView({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final TransactionsController controller = Get.find<TransactionsController>();
    final String docId = transaction['id'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Transaction Details',
          style: TextStyle(
            fontSize: 16,
            fontFamily: fontMulishBold,
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              final currentTx = controller.transactions.firstWhere(
                (t) => t['id'] == docId,
                orElse: () => transaction,
              );

              Get.to(() => EditTransactionView(
                transaction: currentTx,
                onSave: (updated) {
                  controller.updateTransactionRecord(docId, currentTx, updated);
                },
              ));
            },
            icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFFf57c35)),
            label: const Text(
              "Edit",
              style: TextStyle(
                fontFamily: fontMulishSemiBold,
                color: Color(0xFFf57c35),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        final tx = controller.transactions.firstWhere(
          (element) => element['id'] == docId,
          orElse: () => transaction,
        );

        final items = (tx['items'] as List<dynamic>? ?? []);
        final subtotal = (tx['subtotal'] as num?)?.toInt() ?? 0;
        final tax = (tx['tax'] as num?)?.toInt() ?? 0;
        final discount = (tx['discount'] as num?)?.toInt() ?? 0;
        final total = (tx['total'] as num?)?.toInt() ?? 0;
        final cashAmount = (tx['cashAmount'] as num?)?.toInt() ?? 0;
        final onlineAmount = (tx['onlineAmount'] as num?)?.toInt() ?? 0;
        final tableName = tx['table'] ?? 'Unknown';
        final dateTime = (tx['createdAt'] as Timestamp?)?.toDate();

        return Column(
          children: [
            // ── Beautiful Card Header ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Card(
                color: const Color(0xFF1A3A5C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: Colors.black12,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
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
                      if (dateTime != null)
                        Text(
                          DateFormat('dd MMM yyyy | hh:mm a').format(dateTime),
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: fontMulishRegular,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Item List ────────────────────────────────────────────────
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('No items in this transaction'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final qty = (item['qty'] as int?) ?? 0;
                        final price = (item['price'] as num?)?.toDouble() ?? 0;
                        final lineTotal = (qty * price).round();
                        final remarks = (item['remarks'] ?? '').toString();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'] ?? '-',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontFamily: fontMulishBold,
                                        color: Color(0xFF1A3A5C),
                                      ),
                                    ),
                                    if (remarks.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.notes,
                                              size: 12,
                                              color: Colors.orange.shade500),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              remarks,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.orange.shade700,
                                                fontFamily: fontMulishRegular,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Qty Badge
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 10),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A3A5C).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '×$qty',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontFamily: fontMulishBold,
                                    color: Color(0xFF1A3A5C),
                                  ),
                                ),
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
                      },
                    ),
            ),

            // ── Summary Card ─────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _summaryRow('Subtotal', '₹$subtotal'),
                  const SizedBox(height: 6),
                  _summaryRow('Tax (8.5%)', '₹$tax'),
                  if (discount > 0) ...[
                    const SizedBox(height: 6),
                    _summaryRow('Discount', '-₹$discount',
                        valueColor: Colors.green.shade700),
                  ],
                  const SizedBox(height: 12),
                  DottedLine(
                    dashLength: 4,
                    dashGapLength: 6,
                    lineThickness: 1,
                    dashColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: fontMulishBold,
                          color: Color(0xFF1A3A5C),
                        ),
                      ),
                      Text(
                        '₹$total',
                        style: const TextStyle(
                          fontSize: 18,
                          fontFamily: fontMulishBold,
                          color: Color(0xFFf57c35),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Payment method breakdown pills
                  Row(
                    children: [
                      if (cashAmount > 0)
                        _paymentPill(Icons.currency_rupee, 'Cash: ₹$cashAmount',
                            Colors.green),
                      if (cashAmount > 0 && onlineAmount > 0)
                        const SizedBox(width: 8),
                      if (onlineAmount > 0)
                        _paymentPill(Icons.phone_android, 'Online: ₹$onlineAmount',
                            Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
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
          value,
          style: TextStyle(
            fontSize: 13,
            fontFamily: fontMulishSemiBold,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _paymentPill(IconData icon, String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.shade700),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontFamily: fontMulishSemiBold,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
