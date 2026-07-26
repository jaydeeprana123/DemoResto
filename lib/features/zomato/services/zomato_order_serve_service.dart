import 'dart:async';

import 'package:demo/core/utils/zomato_order_utils.dart';
import 'package:demo/features/transactions/repositories/transactions_repository.dart';
import 'package:demo/features/zomato/models/zomato_imagekit_cleanup_job.dart';
import 'package:demo/features/zomato/repositories/zomato_orders_repository.dart';
import 'package:demo/features/zomato/services/imagekit_upload_service.dart';
import 'package:demo/features/zomato/services/zomato_imagekit_cleanup_queue.dart';
import 'package:get/get.dart';

/// Serves Zomato orders: create a ₹0 transaction, remove from Firestore,
/// then delete ImageKit in background.
class ZomatoOrderServeService {
  ZomatoOrderServeService(this._repository);

  final ZomatoOrdersRepository _repository;

  static bool _processingQueue = false;

  TransactionsRepository get _transactions {
    if (!Get.isRegistered<TransactionsRepository>()) {
      Get.put(TransactionsRepository(), permanent: false);
    }
    return Get.find<TransactionsRepository>();
  }

  Future<void> serveOrder({
    required String docId,
    String? completedBy,
  }) async {
    final order = await _repository.readOrderForServe(docId);
    if (order == null) return;

    await _transactions.createTransaction(
      items: [
        {'name': 'Zomato Order', 'qty': 1, 'price': 0},
      ],
      tableName: order.name,
      subtotal: 0,
      tax: 0,
      cgstPercentage: 0,
      sgstPercentage: 0,
      cgstAmount: 0,
      sgstAmount: 0,
      discount: 0,
      total: 0,
      cashAmount: 0,
      onlineAmount: 0,
      completedBy: completedBy,
    );

    await _repository.deleteOrderDoc(docId);

    final hasImage = order.fileId?.trim().isNotEmpty == true ||
        order.screenshotUrl?.trim().isNotEmpty == true;
    if (!hasImage) return;

    final job = ZomatoImageKitCleanupJob(
      id: docId,
      fileId: order.fileId,
      screenshotUrl: order.screenshotUrl,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await ZomatoImageKitCleanupQueue.enqueue(job);
    unawaited(_processCleanupJob(job));
  }

  Future<void> updateStatus({
    required String docId,
    required String status,
    String? completedBy,
  }) async {
    final normalized = ZomatoOrderUtils.normalizeStatus(status);
    if (ZomatoOrderUtils.isCompletedStatus(normalized)) {
      await serveOrder(docId: docId, completedBy: completedBy);
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
