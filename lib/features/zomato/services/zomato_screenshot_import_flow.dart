import 'dart:typed_data';

import 'package:demo/Styles/my_font.dart';
import 'package:demo/features/menu_setup/services/menu_cache_service.dart';
import 'package:demo/features/zomato/models/zomato_extracted_order.dart';
import 'package:demo/features/zomato/repositories/zomato_orders_repository.dart';
import 'package:demo/features/zomato/services/imagekit_settings.dart';
import 'package:demo/features/zomato/services/zomato_screenshot_extraction_service.dart';
import 'package:demo/features/zomato/services/zomato_screenshot_import_service.dart';
import 'package:demo/features/zomato/utils/zomato_order_items_builder.dart';
import 'package:demo/features/zomato/views/imagekit_settings_page.dart';
import 'package:demo/features/zomato/views/zomato_extracted_order_review_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ZomatoScreenshotImportFlow {
  ZomatoScreenshotImportFlow._();

  static Future<bool> run(
    BuildContext context, {
    required Uint8List imageBytes,
    String? fileName,
    String? existingDocId,
  }) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final configured = await ImageKitSettings.isConfigured();
    if (!context.mounted) return false;
    if (!configured) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'ImageKit is not configured. Open Settings → Zomato / ImageKit and save your keys.',
          ),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => Get.to(() => const ImageKitSettingsPage()),
          ),
        ),
      );
      return false;
    }

    if (!context.mounted) return false;

    await _showBlockingDialog(
      context,
      message: 'Reading items from screenshot…',
    );

    ZomatoExtractedOrder extracted;
    List<Map<String, dynamic>> menuItems;
    try {
      menuItems = await Get.find<MenuCacheService>().ensureLoaded();
      extracted = await ZomatoScreenshotExtractionService().extractAndMatch(
        imageBytes: imageBytes,
        menuItems: menuItems,
        fileName: fileName,
      );
    } catch (e) {
      if (navigator.mounted) navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
      return false;
    }

    if (navigator.mounted) navigator.pop();

    if (!context.mounted) return false;

    final reviewResult = await Navigator.push<List<ZomatoExtractedItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => ZomatoExtractedOrderReviewPage(
          imageBytes: imageBytes,
          extracted: extracted,
          menuItems: menuItems,
        ),
      ),
    );

    if (reviewResult == null || !context.mounted) return false;

    final tableItems = _buildTableItems(reviewResult);
    await _showBlockingDialog(
      context,
      message: 'Uploading screenshot and saving order…',
    );

    try {
      final importService = ZomatoScreenshotImportService(
        Get.find<ZomatoOrdersRepository>(),
      );
      final result = await importService.import(
        bytes: imageBytes,
        fileName: fileName,
        existingDocId: existingDocId,
        tableItems: tableItems,
        zomatoOrderNumber: extracted.zomatoOrderNumber,
      );

      if (navigator.mounted) navigator.pop();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.createdNewOrder
                ? tableItems.isEmpty
                    ? '${result.orderName} added with screenshot.'
                    : '${result.orderName} added with ${tableItems.length} item(s).'
                : tableItems.isEmpty
                    ? 'Screenshot attached to ${result.orderName}.'
                    : 'Screenshot and ${tableItems.length} item(s) saved to ${result.orderName}.',
          ),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      return true;
    } catch (e) {
      if (navigator.mounted) navigator.pop();
      final message = e.toString().replaceFirst('Exception: ', '');
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          action: message.contains('ImageKit')
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: () => Get.to(() => const ImageKitSettingsPage()),
                )
              : null,
        ),
      );
      return false;
    }
  }

  static List<Map<String, dynamic>> _buildTableItems(
    List<ZomatoExtractedItem> rows,
  ) {
    return rows
        .where((item) => item.isMatched)
        .map(
          (item) => ZomatoOrderItemsBuilder.fromMenuMatch(
            menuItem: item.matchedMenuItem!,
            qty: item.quantity,
            remarks: item.remarks,
          ),
        )
        .toList();
  }

  static Future<void> _showBlockingDialog(
    BuildContext context, {
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: MyFont.regular(14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
