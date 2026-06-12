import 'dart:typed_data';

import 'package:demo/features/zomato/repositories/zomato_orders_repository.dart';
import 'package:demo/features/zomato/services/imagekit_settings.dart';
import 'package:demo/features/zomato/services/imagekit_upload_service.dart';
import 'package:demo/features/zomato/utils/zomato_order_items_builder.dart';

class ZomatoScreenshotImportResult {
  const ZomatoScreenshotImportResult({
    required this.docId,
    required this.orderName,
    required this.createdNewOrder,
  });

  final String docId;
  final String orderName;
  final bool createdNewOrder;
}

class ZomatoScreenshotImportService {
  ZomatoScreenshotImportService(this._repository);

  final ZomatoOrdersRepository _repository;

  Future<ZomatoScreenshotImportResult> import({
    required Uint8List bytes,
    String? fileName,
    String? existingDocId,
    List<Map<String, dynamic>> tableItems = const [],
    String? zomatoOrderNumber,
  }) async {
    final configured = await ImageKitSettings.isConfigured();
    if (!configured) {
      throw Exception(
        'ImageKit is not configured. Open Settings → Zomato / ImageKit and save your keys.',
      );
    }

    final uploadName =
        fileName ?? 'zomato_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final upload = await ImageKitUploadService.uploadScreenshot(
      bytes: bytes,
      fileName: uploadName,
    );

    final flattenedItems = ZomatoOrderItemsBuilder.flattenForFirestore(tableItems);

    if (existingDocId != null && existingDocId.isNotEmpty) {
      await _repository.attachScreenshotToOrder(
        docId: existingDocId,
        screenshotUrl: upload.url,
        imagekitFileId: upload.fileId,
        items: flattenedItems.isNotEmpty ? flattenedItems : null,
        zomatoOrderNumber: zomatoOrderNumber,
      );
      final orderName =
          await _repository.getOrderName(existingDocId) ?? 'Zomato order';
      return ZomatoScreenshotImportResult(
        docId: existingDocId,
        orderName: orderName,
        createdNewOrder: false,
      );
    }

    final docId = await _repository.createFromScreenshot(
      screenshotUrl: upload.url,
      imagekitFileId: upload.fileId,
      items: flattenedItems,
      zomatoOrderNumber: zomatoOrderNumber,
    );
    final orderName = await _repository.getOrderName(docId) ?? 'Zomato order';
    return ZomatoScreenshotImportResult(
      docId: docId,
      orderName: orderName,
      createdNewOrder: true,
    );
  }
}
