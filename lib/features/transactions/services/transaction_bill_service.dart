import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartKitchen/core/firestore/firestore_paths.dart';
import 'package:smartKitchen/core/utils/platform_utils.dart';
import 'package:intl/intl.dart';

class TransactionBillService {
  TransactionBillService._();

  static Future<String> generateBillId() async {
    final now = DateTime.now();
    final dateKey = DateFormat('yyyyMMdd').format(now);
    final counterRef = FirestorePaths.scopedDoc('bill_counters', dateKey);

    if (isDesktopPlatform) {
      final snap = await counterRef.get();
      final next = ((snap.data()?['seq'] as num?)?.toInt() ?? 0) + 1;
      await counterRef.set(
        {
          'seq': next,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return 'BILL-$dateKey-${next.toString().padLeft(4, '0')}';
    }

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(counterRef);
      final next = ((snap.data()?['seq'] as num?)?.toInt() ?? 0) + 1;
      transaction.set(
        counterRef,
        {
          'seq': next,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return 'BILL-$dateKey-${next.toString().padLeft(4, '0')}';
    });
  }

  static String displayBillId(
    Map<String, dynamic>? data, {
    String? documentId,
  }) {
    final billId = data?['billId']?.toString().trim();
    if (billId != null && billId.isNotEmpty) return billId;
    if (documentId != null && documentId.isNotEmpty) {
      return documentId.length > 8
          ? documentId.substring(0, 8).toUpperCase()
          : documentId.toUpperCase();
    }
    return '-';
  }
}
