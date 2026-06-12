import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/core/utils/zomato_order_utils.dart';
import 'package:demo/features/zomato/models/zomato_order_ref.dart';
import 'package:demo/features/zomato/services/imagekit_upload_service.dart';

class ZomatoOrdersRepository {
  Future<String> createFromScreenshot({
    required String screenshotUrl,
    String? imagekitFileId,
    List<Map<String, dynamic>> items = const [],
    String? zomatoOrderNumber,
  }) async {
    final name = await _nextZomatoOrderName();
    final docRef = await FirestorePaths.scoped('tables').add({
      'name': name,
      'source': ZomatoOrderUtils.sourceZomato,
      'screenshotUrl': screenshotUrl,
      if (imagekitFileId != null && imagekitFileId.isNotEmpty)
        'imagekitFileId': imagekitFileId,
      if (zomatoOrderNumber != null && zomatoOrderNumber.isNotEmpty)
        'zomatoOrderNumber': zomatoOrderNumber,
      'zomatoStatus': ZomatoOrderUtils.statuses.first,
      'items': items,
      'isPaid': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Active Zomato orders that do not have a screenshot yet.
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
    List<Map<String, dynamic>>? items,
    String? zomatoOrderNumber,
  }) async {
    await FirestorePaths.scopedDoc('tables', docId).update({
      'screenshotUrl': screenshotUrl,
      if (imagekitFileId != null && imagekitFileId.isNotEmpty)
        'imagekitFileId': imagekitFileId,
      if (items != null) 'items': items,
      if (zomatoOrderNumber != null && zomatoOrderNumber.isNotEmpty)
        'zomatoOrderNumber': zomatoOrderNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> getOrderName(String docId) async {
    final snap = await FirestorePaths.scopedDoc('tables', docId).get();
    if (!snap.exists) return null;
    return snap.data()?['name']?.toString();
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

  /// Removes a Zomato order and deletes its screenshot from ImageKit.
  Future<void> removeOrder({required String docId}) async {
    final docRef = FirestorePaths.scopedDoc('tables', docId);
    final snap = await docRef.get();
    if (snap.exists) {
      final data = snap.data() ?? {};
      await ImageKitUploadService.deleteScreenshot(
        fileId: data['imagekitFileId']?.toString(),
        screenshotUrl: data['screenshotUrl']?.toString(),
      );
    }
    await docRef.delete();
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
