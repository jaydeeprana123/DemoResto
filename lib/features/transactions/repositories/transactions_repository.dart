import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/core/utils/platform_utils.dart';
import 'package:intl/intl.dart';

int transactionAsInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<Map<String, dynamic>> normalizeTransactionItems(
  List<Map<String, dynamic>> items,
) {
  return items
      .where((e) => transactionAsInt(e['qty']) > 0)
      .map((e) {
        final qty = transactionAsInt(e['qty']);
        final price = transactionAsInt(e['price']);
        final line = qty * price;
        return {
          'name': e['name']?.toString() ?? '-',
          'qty': qty,
          'price': price,
          'total': line,
          if ((e['remarks']?.toString() ?? '').isNotEmpty)
            'remarks': e['remarks'].toString(),
        };
      })
      .toList();
}

class TransactionsRepository {
  Future<({String documentId, String billId})?> createTransaction({
    required List<Map<String, dynamic>> items,
    required String tableName,
    required int subtotal,
    required int tax,
    required double cgstPercentage,
    required double sgstPercentage,
    required int cgstAmount,
    required int sgstAmount,
    required int discount,
    required int total,
    required int cashAmount,
    required int onlineAmount,
  }) async {
    try {
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      final billDateKey = DateFormat('yyyyMMdd').format(now);
      final txRef = FirestorePaths.scoped('transactions').doc();
      final counterRef = FirestorePaths.scopedDoc('bill_counters', billDateKey);
      final dailyRef = FirestorePaths.scopedDoc('daily_stats', dateKey);
      final summaryRef = FirestorePaths.scopedDoc('stats', 'summary');
      final normalizedItems = normalizeTransactionItems(items);
      if (normalizedItems.isEmpty) {
        throw Exception('Transaction must have at least one item with quantity.');
      }

      if (isDesktopPlatform) {
        return _createTransactionWithBatch(
          txRef: txRef,
          counterRef: counterRef,
          dailyRef: dailyRef,
          summaryRef: summaryRef,
          billDateKey: billDateKey,
          tableName: tableName,
          normalizedItems: normalizedItems,
          subtotal: subtotal,
          tax: tax,
          cgstPercentage: cgstPercentage,
          sgstPercentage: sgstPercentage,
          cgstAmount: cgstAmount,
          sgstAmount: sgstAmount,
          discount: discount,
          total: total,
          cashAmount: cashAmount,
          onlineAmount: onlineAmount,
        );
      }

      return await FirebaseFirestore.instance.runTransaction((transaction) async {
        final counterSnap = await transaction.get(counterRef);
        final next = ((counterSnap.data()?['seq'] as num?)?.toInt() ?? 0) + 1;
        final billId = 'BILL-$billDateKey-${next.toString().padLeft(4, '0')}';

        transaction.set(
          counterRef,
          {
            'seq': next,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        transaction.set(txRef, {
          'billId': billId,
          'table': tableName,
          'items': normalizedItems,
          'subtotal': subtotal,
          'tax': tax,
          'cgstPercentage': cgstPercentage,
          'sgstPercentage': sgstPercentage,
          'cgstAmount': cgstAmount,
          'sgstAmount': sgstAmount,
          'discount': discount,
          'total': total,
          'cashAmount': cashAmount,
          'onlineAmount': onlineAmount,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.set(
          dailyRef,
          {
            'revenue': FieldValue.increment(total),
            'totalCash': FieldValue.increment(cashAmount),
            'totalOnline': FieldValue.increment(onlineAmount),
            'transactions': FieldValue.increment(1),
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        transaction.set(
          summaryRef,
          {
            'totalRevenue': FieldValue.increment(total),
            'totalTransactions': FieldValue.increment(1),
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        return (documentId: txRef.id, billId: billId);
      });
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? 'Failed to save transaction (${e.code}).');
    } catch (e) {
      throw Exception('Failed to save transaction: $e');
    }
  }

  /// Batch write avoids [runTransaction] on desktop where it can crash the
  /// Firebase C++ plugin when query listeners are active.
  Future<({String documentId, String billId})> _createTransactionWithBatch({
    required DocumentReference<Map<String, dynamic>> txRef,
    required DocumentReference<Map<String, dynamic>> counterRef,
    required DocumentReference<Map<String, dynamic>> dailyRef,
    required DocumentReference<Map<String, dynamic>> summaryRef,
    required String billDateKey,
    required String tableName,
    required List<Map<String, dynamic>> normalizedItems,
    required int subtotal,
    required int tax,
    required double cgstPercentage,
    required double sgstPercentage,
    required int cgstAmount,
    required int sgstAmount,
    required int discount,
    required int total,
    required int cashAmount,
    required int onlineAmount,
  }) async {
    final counterSnap = await counterRef.get();
    final next = ((counterSnap.data()?['seq'] as num?)?.toInt() ?? 0) + 1;
    final billId = 'BILL-$billDateKey-${next.toString().padLeft(4, '0')}';

    final batch = FirebaseFirestore.instance.batch();

    batch.set(
      counterRef,
      {
        'seq': next,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(txRef, {
      'billId': billId,
      'table': tableName,
      'items': normalizedItems,
      'subtotal': subtotal,
      'tax': tax,
      'cgstPercentage': cgstPercentage,
      'sgstPercentage': sgstPercentage,
      'cgstAmount': cgstAmount,
      'sgstAmount': sgstAmount,
      'discount': discount,
      'total': total,
      'cashAmount': cashAmount,
      'onlineAmount': onlineAmount,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      dailyRef,
      {
        'revenue': FieldValue.increment(total),
        'totalCash': FieldValue.increment(cashAmount),
        'totalOnline': FieldValue.increment(onlineAmount),
        'transactions': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      summaryRef,
      {
        'totalRevenue': FieldValue.increment(total),
        'totalTransactions': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    return (documentId: txRef.id, billId: billId);
  }

  Future<void> updateTransaction({
    required String transactionId,
    required Map<String, dynamic> previous,
    required Map<String, dynamic> updated,
  }) async {
    final oldTotal = transactionAsInt(previous['total']);
    final oldCash = transactionAsInt(previous['cashAmount']);
    final oldOnline = transactionAsInt(previous['onlineAmount']);

    final newSubtotal = transactionAsInt(updated['subtotal']);
    final newTax = transactionAsInt(updated['tax']);
    final newDiscount = transactionAsInt(updated['discount']);
    final newTotal = transactionAsInt(updated['total']);
    final newCash = transactionAsInt(updated['cashAmount']);
    final newOnline = transactionAsInt(updated['onlineAmount']);

    final normalizedItems = normalizeTransactionItems(
      List<Map<String, dynamic>>.from(updated['items'] ?? []),
    );

    if (normalizedItems.isEmpty) {
      throw Exception('Transaction must have at least one item with quantity.');
    }

    final createdAt = previous['createdAt'];
    final DateTime txDate = createdAt is Timestamp
        ? createdAt.toDate()
        : DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(txDate);

    final batch = FirebaseFirestore.instance.batch();

    final txRef = FirestorePaths.scopedDoc('transactions', transactionId);
    batch.set(
      txRef,
      {
        'items': normalizedItems,
        'subtotal': newSubtotal,
        'tax': newTax,
        'discount': newDiscount,
        'total': newTotal,
        'cashAmount': newCash,
        'onlineAmount': newOnline,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final deltaTotal = newTotal - oldTotal;
    final deltaCash = newCash - oldCash;
    final deltaOnline = newOnline - oldOnline;

    if (deltaTotal != 0 || deltaCash != 0 || deltaOnline != 0) {
      final dailyRef = FirestorePaths.scopedDoc('daily_stats', dateKey);
      batch.set(
        dailyRef,
        {
          'revenue': FieldValue.increment(deltaTotal),
          'totalCash': FieldValue.increment(deltaCash),
          'totalOnline': FieldValue.increment(deltaOnline),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final summaryRef = FirestorePaths.scopedDoc('stats', 'summary');
      batch.set(
        summaryRef,
        {
          'totalRevenue': FieldValue.increment(deltaTotal),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? 'Failed to save transaction (${e.code}).');
    }

    updated['items'] = normalizedItems;
    updated['subtotal'] = newSubtotal;
    updated['tax'] = newTax;
    updated['discount'] = newDiscount;
    updated['total'] = newTotal;
    updated['cashAmount'] = newCash;
    updated['onlineAmount'] = newOnline;
  }
}
