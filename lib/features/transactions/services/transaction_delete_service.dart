import 'package:smartKitchen/core/firestore/firestore_paths.dart';
import 'package:smartKitchen/core/services/restaurant_session.dart';
import 'package:smartKitchen/features/tables/repositories/tables_repository.dart';
import 'package:smartKitchen/features/transactions/repositories/transactions_repository.dart';
import 'package:smartKitchen/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Admin-only: delete a transaction from the Transactions screen.
class TransactionDeleteService {
  TransactionDeleteService._();

  static bool get isAdmin =>
      Get.find<RestaurantSession>().profile.value?.isAdmin ?? false;

  static Future<bool> showDeleteDialog(
    BuildContext context, {
    required String transactionId,
    required String tableName,
    required String billId,
  }) async {
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Admin can delete transactions.'),
        ),
      );
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete transaction?',
          style: TextStyle(
            fontFamily: fontMulishSemiBold,
            fontSize: 18,
            color: Color(0xFF1A3A5C),
          ),
        ),
        content: Text(
          "This will permanently delete bill '$billId' for '$tableName' "
          'and adjust revenue totals. If the table is still marked PAID for '
          'this bill, the PAID tag will be removed.',
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
              'Delete',
              style: TextStyle(fontFamily: fontMulishSemiBold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return false;

    try {
      await deleteTransaction(
        transactionId: transactionId,
        tableName: tableName,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bill "$billId" deleted.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete transaction: $e')),
        );
      }
      return false;
    }
  }

  static Future<void> deleteTransaction({
    required String transactionId,
    required String tableName,
  }) async {
    await Get.find<TransactionsRepository>().deleteTransaction(transactionId);
    await _unlinkTableIfNeeded(transactionId, tableName);
  }

  static Future<void> _unlinkTableIfNeeded(
    String transactionId,
    String tableName,
  ) async {
    final tableQuery = await FirestorePaths
        .scoped('tables')
        .where('name', isEqualTo: tableName)
        .limit(1)
        .get();
    if (tableQuery.docs.isEmpty) return;

    final doc = tableQuery.docs.first;
    final data = doc.data();
    if (data['isPaid'] == true &&
        data['lastTransactionId']?.toString() == transactionId) {
      await Get.find<TablesRepository>().markTableUnpaid(doc.id);
    }
  }
}
