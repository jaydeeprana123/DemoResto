import 'package:cloud_firestore/cloud_firestore.dart';
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

/// Updates a transaction and adjusts daily_stats / global summary by deltas.
Future<void> updateTransactionInFirestore({
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

  final normalizedItems =
      normalizeTransactionItems(List<Map<String, dynamic>>.from(updated['items'] ?? []));

  if (normalizedItems.isEmpty) {
    throw Exception('Transaction must have at least one item with quantity.');
  }

  final createdAt = previous['createdAt'];
  final DateTime txDate = createdAt is Timestamp
      ? createdAt.toDate()
      : DateTime.now();
  final dateKey = DateFormat('yyyy-MM-dd').format(txDate);

  final batch = FirebaseFirestore.instance.batch();

  final txRef =
      FirebaseFirestore.instance.collection('transactions').doc(transactionId);
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
    final dailyRef =
        FirebaseFirestore.instance.collection('daily_stats').doc(dateKey);
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

    final summaryRef =
        FirebaseFirestore.instance.collection('stats').doc('summary');
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
