import 'dart:async';

import 'package:demo/core/utils/zomato_order_utils.dart';
import 'package:demo/features/zomato/models/zomato_imagekit_cleanup_job.dart';
import 'package:demo/features/zomato/repositories/zomato_orders_repository.dart';
import 'package:demo/features/zomato/services/imagekit_upload_service.dart';
import 'package:demo/features/zomato/services/zomato_imagekit_cleanup_queue.dart';

/// Serves Zomato orders: remove from Firestore immediately, delete ImageKit in background.
class ZomatoOrderServeService {
  ZomatoOrderServeService(this._repository);

  final ZomatoOrdersRepository _repository;

  static bool _processingQueue = false;

  Future<void> serveOrder({required String docId}) async {
    final screenshot = await _repository.readScreenshotInfo(docId);
    if (screenshot == null) return;

    await _repository.deleteOrderDoc(docId);

    final hasImage = screenshot.fileId?.trim().isNotEmpty == true ||
        screenshot.screenshotUrl?.trim().isNotEmpty == true;
    if (!hasImage) return;

    final job = ZomatoImageKitCleanupJob(
      id: docId,
      fileId: screenshot.fileId,
      screenshotUrl: screenshot.screenshotUrl,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await ZomatoImageKitCleanupQueue.enqueue(job);
    unawaited(_processCleanupJob(job));
  }

  Future<void> updateStatus({
    required String docId,
    required String status,
  }) async {
    final normalized = ZomatoOrderUtils.normalizeStatus(status);
    if (ZomatoOrderUtils.isCompletedStatus(normalized)) {
      await serveOrder(docId: docId);
      return;
    }
    await _repository.updateStatusOnly(docId: docId, status: normalized);
  }

  /// Retries any ImageKit deletes that were interrupted (e.g. app closed mid-cleanup).
  Future<void> processPendingCleanups() async {
    if (_processingQueue) return;
    _processingQueue = true;
    try {
      final jobs = await ZomatoImageKitCleanupQueue.listAll();
      for (final job in jobs) {
        await _processCleanupJob(job);
      }
    } finally {
      _processingQueue = false;
    }
  }

  Future<void> _processCleanupJob(ZomatoImageKitCleanupJob job) async {
    if (job.attempts >= ZomatoImageKitCleanupQueue.maxAttempts) {
      await ZomatoImageKitCleanupQueue.remove(job.id);
      return;
    }

    final deleted = await ImageKitUploadService.deleteScreenshot(
      fileId: job.fileId,
      screenshotUrl: job.screenshotUrl,
    );
    if (deleted) {
      await ZomatoImageKitCleanupQueue.remove(job.id);
      return;
    }

    await ZomatoImageKitCleanupQueue.recordFailedAttempt(job.id);
  }
}
