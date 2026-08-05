import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartKitchen/core/firestore/firestore_paths.dart';
import 'package:smartKitchen/core/utils/zomato_order_utils.dart';
import 'package:smartKitchen/features/zomato/models/zomato_imagekit_cleanup_job.dart';
import 'package:smartKitchen/features/zomato/models/zomato_order_ref.dart';

class ZomatoOrdersRepository {
  Future<String> createFromScreenshot({
    required String screenshotUrl,
    String? imagekitFileId,
  }) async {
    final name = await _nextZomatoOrderName();
    final docRef = await FirestorePaths.scoped('tables').add({
      'name': name,
      'source': ZomatoOrderUtils.sourceZomato,
      'screenshotUrl': screenshotUrl,
      if (imagekitFileId != null && imagekitFileId.isNotEmpty)
        'imagekitFileId': imagekitFileId,
      'zomatoStatus': ZomatoOrderUtils.statuses.first,
      'items': <Map<String, dynamic>>[],
      'isPaid': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<List<ZomatoOrderRef>> listActiveOrdersMissingScreenshot() async {
    final snap = await FirestorePaths.scoped('tables').get();
    final results = <ZomatoOrderRef>[];

    for (final doc in snap.docs) {
      final data = doc.data();
      if (!ZomatoOrderUtils.isZomatoDoc(data)) continue;
      if (ZomatoOrderUtils.isCompletedStatus(data['zomatoStatus']?.toString())) {
        continue;
      }
      final screenshotUrl = data['screenshotUrl']?.toString().trim() ?? '';
      if (screenshotUrl.isNotEmpty) continue;

      results.add(
        ZomatoOrderRef(
          docId: doc.id,
          name: data['name']?.toString() ?? 'Zomato',
        ),
      );
    }

    results.sort((a, b) => a.name.compareTo(b.name));
    return results;
  }

  Future<void> attachScreenshotToOrder({
    required String docId,
    required String screenshotUrl,
    String? imagekitFileId,
  }) async {
    await FirestorePaths.scopedDoc('tables', docId).update({
      'screenshotUrl': screenshotUrl,
      if (imagekitFileId != null && imagekitFileId.isNotEmpty)
        'imagekitFileId': imagekitFileId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> getOrderName(String docId) async {
    final snap = await FirestorePaths.scopedDoc('tables', docId).get();
    if (!snap.exists) return null;
    return snap.data()?['name']?.toString();
  }

  Future<ZomatoScreenshotInfo?> readScreenshotInfo(String docId) async {
    final snap = await FirestorePaths.scopedDoc('tables', docId).get();
    if (!snap.exists) return null;

    final data = snap.data() ?? {};
    return ZomatoScreenshotInfo(
      docId: docId,
      fileId: data['imagekitFileId']?.toString(),
      screenshotUrl: data['screenshotUrl']?.toString(),
    );
  }

  Future<ZomatoOrderServeInfo?> readOrderForServe(String docId) async {
    final snap = await FirestorePaths.scopedDoc('tables', docId).get();
    if (!snap.exists) return null;

    final data = snap.data() ?? {};
    final name = data['name']?.toString().trim();
    return ZomatoOrderServeInfo(
      docId: docId,
      name: (name != null && name.isNotEmpty) ? name : 'Zomato',
      fileId: data['imagekitFileId']?.toString(),
      screenshotUrl: data['screenshotUrl']?.toString(),
    );
  }

  Future<void> deleteOrderDoc(String docId) async {
    await FirestorePaths.scopedDoc('tables', docId).delete();
  }

  Future<void> updateStatusOnly({
    required String docId,
    required String status,
  }) async {
    await FirestorePaths.scopedDoc('tables', docId).update({
      'zomatoStatus': ZomatoOrderUtils.normalizeStatus(status),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
