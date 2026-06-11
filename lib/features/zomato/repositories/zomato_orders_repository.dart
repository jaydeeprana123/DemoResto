import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/core/utils/zomato_order_utils.dart';

class ZomatoOrdersRepository {
  Future<String> createFromScreenshot({
    required String screenshotUrl,
  }) async {
    final name = await _nextZomatoOrderName();
    final docRef = await FirestorePaths.scoped('tables').add({
      'name': name,
      'source': ZomatoOrderUtils.sourceZomato,
      'screenshotUrl': screenshotUrl,
      'zomatoStatus': ZomatoOrderUtils.statuses.first,
      'items': <Map<String, dynamic>>[],
      'isPaid': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateStatus({
    required String docId,
    required String status,
  }) async {
    final normalized = ZomatoOrderUtils.normalizeStatus(status);
    if (ZomatoOrderUtils.isCompletedStatus(normalized)) {
      await removeOrder(docId: docId);
      return;
    }
    await FirestorePaths.scopedDoc('tables', docId).update({
      'zomatoStatus': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes a Zomato order after it has been served / completed.
  Future<void> removeOrder({required String docId}) async {
    await FirestorePaths.scopedDoc('tables', docId).delete();
  }

  Future<String> _nextZomatoOrderName() async {
    final snap = await FirestorePaths.scoped('tables').get();
    var maxNum = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      if (!ZomatoOrderUtils.isZomatoDoc(data)) continue;
      final name = data['name']?.toString() ?? '';
      final match = RegExp(r'(\d+)$').firstMatch(name.trim());
      if (match != null) {
        final num = int.tryParse(match.group(1)!) ?? 0;
        if (num > maxNum) maxNum = num;
      }
    }
    return 'Zomato ${maxNum + 1}';
  }
}
