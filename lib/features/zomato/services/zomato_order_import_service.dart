import 'dart:typed_data';

import 'package:demo/features/zomato/repositories/zomato_orders_repository.dart';
import 'package:demo/features/zomato/services/imagekit_settings.dart';
import 'package:demo/features/zomato/services/imagekit_upload_service.dart';
import 'package:demo/features/zomato/views/imagekit_settings_page.dart';
import 'package:demo/features/zomato/widgets/zomato_order_progress_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ZomatoOrderImportService {
  ZomatoOrderImportService._();

  static Future<void> createOrderFromImage({
    required BuildContext context,
    required Uint8List bytes,
    required String fileName,
    String progressMessage = 'Creating Zomato order from shared image...',
    String progressSubtitle = 'Uploading screenshot and saving order',
  }) async {
    final configured = await ImageKitSettings.isConfigured();
    if (!configured) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'ImageKit is not configured. Open Settings → Zomato / ImageKit and save your keys.',
          ),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: () => Get.to(() => const ImageKitSettingsPage()),
          ),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    await ZomatoOrderProgressDialog.run(
      context,
      message: progressMessage,
      subtitle: progressSubtitle,
      action: () async {
        final uploadName = fileName.isNotEmpty
            ? fileName
            : 'zomato_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final upload = await ImageKitUploadService.uploadScreenshot(
          bytes: bytes,
          fileName: uploadName,
        );
        await Get.find<ZomatoOrdersRepository>().createFromScreenshot(
          screenshotUrl: upload.url,
          imagekitFileId: upload.fileId,
        );
      },
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Zomato order added from shared image.'),
        backgroundColor: Color(0xFF2E7D32),
      ),
    );
  }
}
