import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartKitchen/core/firestore/firestore_paths.dart';
import 'package:smartKitchen/core/services/restaurant_session.dart';
import 'package:smartKitchen/features/tables/repositories/tables_repository.dart';
import 'package:smartKitchen/features/transactions/repositories/transactions_repository.dart';
import 'package:smartKitchen/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Admin-only: revert a paid order — delete its transaction and clear PAID status.
class ReverseBillingService {
  ReverseBillingService._();

  static bool get isAdmin =>
      Get.find<RestaurantSession>().profile.value?.isAdmin ?? false;

  static Future<void> showReverseBillingDialog(
    BuildContext context, {
    required String tableName,
    required String docId,
    String? transactionId,
  }) async {
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Admin can mark an order as unpaid.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Mark as UNPAID?',
          style: TextStyle(
            fontFamily: fontMulishSemiBold,
            fontSize: 18,
            color: Color(0xFF1A3A5C),
          ),
        ),
        content: Text(
          "This will delete the transaction for '$tableName' and remove the PAID tag. "
          'Order items will stay on the table.',
          style: TextStyle(
            fontFamily: fontMulishRegular,
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: fontMulishSemiBold),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'UNPAID',
              style: TextStyle(fontFamily: fontMulishSemiBold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await reverseBilling(
        tableName: tableName,
        docId: docId,
        transactionId: transactionId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$tableName" marked as unpaid.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not reverse billing: $e')),
        );
      }
    }
  }

  static Future<void> reverseBilling({
    required String tableName,
    required String docId,
    String? transactionId,
  }) async {
    var txId = transactionId?.trim();
    if (txId == null || txId.isEmpty) {
      txId = await findLatestTransactionIdForTable(tableName);
    }
    if (txId == null || txId.isEmpty) {
      throw Exception('No transaction found for this order.');
    }

    await Get.find<TransactionsRepository>().deleteTransaction(txId);
    await Get.find<TablesRepository>().markTableUnpaid(docId);
  }

  static Future<String?> findLatestTransactionIdForTable(String tableName) async {
    final snap = await FirestorePaths.scoped('transactions').get();
    String? latestId;
    Timestamp? latestTime;

    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['table']?.toString() != tableName) continue;
      final created = data['createdAt'];
      if (created is! Timestamp) continue;
      if (latestTime == null || created.compareTo(latestTime) > 0) {
        latestTime = created;
        latestId = doc.id;
      }
    }
    return latestId;
  }
}
