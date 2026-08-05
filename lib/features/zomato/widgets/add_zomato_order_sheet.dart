import 'dart:typed_data';

import 'package:smartKitchen/Styles/my_font.dart';
import 'package:smartKitchen/core/utils/zomato_order_utils.dart';
import 'package:smartKitchen/features/zomato/repositories/zomato_orders_repository.dart';
import 'package:smartKitchen/features/zomato/services/imagekit_settings.dart';
import 'package:smartKitchen/features/zomato/services/imagekit_upload_service.dart';
import 'package:smartKitchen/features/zomato/views/imagekit_settings_page.dart';
import 'package:smartKitchen/features/zomato/widgets/zomato_screenshot_viewer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

const _navy = Color(0xFF1A3A5C);
const _orange = Color(0xFFf57c35);

class AddZomatoOrderSheet extends StatefulWidget {
  const AddZomatoOrderSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddZomatoOrderSheet(),
    );
  }

  @override
  State<AddZomatoOrderSheet> createState() => _AddZomatoOrderSheetState();
}

class _AddZomatoOrderSheetState extends State<AddZomatoOrderSheet> {
  final _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _fileName;
  bool _submitting = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _fileName = picked.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }

  Future<void> _submit() async {
    final bytes = _imageBytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload or capture a screenshot.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final configured = await ImageKitSettings.isConfigured();
      if (!configured) {
        if (!mounted) return;
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

      final uploadName =
          _fileName ?? 'zomato_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final upload = await ImageKitUploadService.uploadScreenshot(
        bytes: bytes,
        fileName: uploadName,
      );
      await Get.find<ZomatoOrdersRepository>().createFromScreenshot(
        screenshotUrl: upload.url,
        imagekitFileId: upload.fileId,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zomato order added.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delivery_dining, color: Color(0xFFE53935)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Zomato Order',
                            style: MyFont.bold(18, color: _navy),
                          ),
                          Text(
                            'Upload a Zomato order screenshot',
                            style: MyFont.regular(13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_imageBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GestureDetector(
                      onTap: () => ZomatoScreenshotViewer.show(
                        context,
                        imageBytes: _imageBytes,
                      ),
                      child: Image.memory(
                        _imageBytes!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else
                  Container(
                    height: 140,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined, size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'No screenshot selected',
                          style: MyFont.regular(13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Gallery'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _submitting || kIsWeb
                            ? null
                            : () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Camera'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _navy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Create ${ZomatoOrderUtils.sourceZomato} Order',
                          style: const TextStyle(fontFamily: fontMulishBold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
