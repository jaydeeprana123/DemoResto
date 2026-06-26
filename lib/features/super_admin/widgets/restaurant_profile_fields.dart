import 'dart:typed_data';

import 'package:demo/features/ordering/widgets/whatsapp_share_phone_dialog.dart';
import 'package:demo/features/super_admin/controllers/super_admin_controller.dart';
import 'package:demo/features/zomato/services/imagekit_upload_service.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

const superAdminNavy = Color(0xFF1A3A5C);
const superAdminOrange = Color(0xFFf57c35);

class RestaurantLogoPicker extends StatelessWidget {
  const RestaurantLogoPicker({
    super.key,
    required this.logoBytes,
    required this.existingLogoUrl,
    required this.onPicked,
    required this.onClear,
  });

  final Uint8List? logoBytes;
  final String? existingLogoUrl;
  final ValueChanged<Uint8List> onPicked;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasPreview = logoBytes != null ||
        (existingLogoUrl != null && existingLogoUrl!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Restaurant Logo', style: MyFont.semiBold(14, color: superAdminNavy)),
        const SizedBox(height: 8),
        if (hasPreview) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: logoBytes != null
                ? Image.memory(logoBytes!, height: 96, fit: BoxFit.contain)
                : Image.network(
                    existingLogoUrl!,
                    height: 96,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: 96,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickLogo(context),
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(hasPreview ? 'Change Logo' : 'Pick Logo'),
            ),
            if (hasPreview) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onClear,
                child: const Text('Remove'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _pickLogo(BuildContext context) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;
      onPicked(bytes);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }
}

class RestaurantMobileFields extends StatelessWidget {
  const RestaurantMobileFields({
    super.key,
    required this.mobile1Controller,
    required this.mobile2Controller,
    this.mobile1Required = true,
  });

  final TextEditingController mobile1Controller;
  final TextEditingController mobile2Controller;
  final bool mobile1Required;

  String? _validateMobile(String? value, {required bool required}) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return required ? 'Mobile number is required.' : null;
    }
    return WhatsAppSharePhoneDialog.validatePhone(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: mobile1Controller,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Mobile Number 1 *',
            border: OutlineInputBorder(),
          ),
          validator: (value) => _validateMobile(value, required: mobile1Required),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: mobile2Controller,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Mobile Number 2 (optional)',
            border: OutlineInputBorder(),
          ),
          validator: (value) => _validateMobile(value, required: false),
        ),
      ],
    );
  }
}

Future<String?> uploadRestaurantLogo({
  required String restaurantId,
  required Uint8List bytes,
  String fileName = 'logo.png',
}) async {
  final upload = await ImageKitUploadService.uploadFile(
    bytes: bytes,
    fileName: fileName,
    folder: '/restaurant-logos/$restaurantId',
  );
  return upload.url;
}

String normalizeRestaurantMobile(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('91')) {
    return digits.substring(2);
  }
  return digits;
}

String? validateRestaurantForm({
  required String name,
  required String mobile1,
  String? mobile2,
}) {
  if (name.trim().isEmpty) return 'Restaurant name is required.';
  final mobile1Error = WhatsAppSharePhoneDialog.validatePhone(mobile1);
  if (mobile1Error != null) return mobile1Error;
  if (mobile2 != null && mobile2.trim().isNotEmpty) {
    final mobile2Error = WhatsAppSharePhoneDialog.validatePhone(mobile2);
    if (mobile2Error != null) return mobile2Error;
  }
  return null;
}

Widget superAdminSubmitButton({
  required SuperAdminController controller,
  required String label,
  required VoidCallback onPressed,
}) {
  return Obx(
    () => ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: superAdminOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: controller.isLoading.value ? null : onPressed,
      child: controller.isLoading.value
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label),
    ),
  );
}
