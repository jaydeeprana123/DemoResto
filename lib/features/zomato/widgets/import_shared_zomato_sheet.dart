import 'dart:typed_data';

import 'package:demo/Styles/my_font.dart';
import 'package:demo/core/utils/zomato_order_utils.dart';
import 'package:demo/features/zomato/models/zomato_order_ref.dart';
import 'package:demo/features/zomato/repositories/zomato_orders_repository.dart';
import 'package:demo/features/zomato/services/zomato_screenshot_import_service.dart';
import 'package:demo/features/zomato/views/imagekit_settings_page.dart';
import 'package:demo/features/zomato/widgets/zomato_screenshot_viewer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

const _navy = Color(0xFF1A3A5C);
const _orange = Color(0xFFf57c35);

class ImportSharedZomatoSheet extends StatefulWidget {
  const ImportSharedZomatoSheet({
    required this.imageBytes,
    this.fileName,
    super.key,
  });

  final Uint8List imageBytes;
  final String? fileName;

  static Future<bool> show(
    BuildContext context, {
    required Uint8List imageBytes,
    String? fileName,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ImportSharedZomatoSheet(
        imageBytes: imageBytes,
        fileName: fileName,
      ),
    ).then((value) => value ?? false);
  }

  @override
  State<ImportSharedZomatoSheet> createState() => _ImportSharedZomatoSheetState();
}

class _ImportSharedZomatoSheetState extends State<ImportSharedZomatoSheet> {
  final _importService = ZomatoScreenshotImportService(
    Get.find<ZomatoOrdersRepository>(),
  );

  List<ZomatoOrderRef> _pendingOrders = [];
  bool _loadingOrders = true;
  bool _submitting = false;
  String? _selectedDocId;
  bool _createNew = true;

  @override
  void initState() {
    super.initState();
    _loadPendingOrders();
  }

  Future<void> _loadPendingOrders() async {
    try {
      final orders =
          await Get.find<ZomatoOrdersRepository>().listActiveOrdersMissingScreenshot();
      if (!mounted) return;
      setState(() {
        _pendingOrders = orders;
        _loadingOrders = false;
        if (orders.length == 1) {
          _createNew = false;
          _selectedDocId = orders.first.docId;
        } else {
          _createNew = orders.isEmpty;
          _selectedDocId = orders.isNotEmpty ? orders.first.docId : null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingOrders = false);
    }
  }

  Future<void> _submit() async {
    if (!_createNew && (_selectedDocId == null || _selectedDocId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a Zomato order to attach to.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _importService.import(
        bytes: widget.imageBytes,
        fileName: widget.fileName,
        existingDocId: _createNew ? null : _selectedDocId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.createdNewOrder
                ? '${result.orderName} added with screenshot.'
                : 'Screenshot attached to ${result.orderName}.',
          ),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
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
                      child: const Icon(
                        Icons.ios_share_rounded,
                        color: Color(0xFFE53935),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Import Zomato Screenshot',
                            style: MyFont.bold(18, color: _navy),
                          ),
                          Text(
                            'Attach this image to a Zomato order',
                            style: MyFont.regular(13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GestureDetector(
                    onTap: () => ZomatoScreenshotViewer.show(
                      context,
                      imageBytes: widget.imageBytes,
                    ),
                    child: Image.memory(
                      widget.imageBytes,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_loadingOrders)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else ...[
                  Text(
                    'Attach to',
                    style: MyFont.semiBold(14, color: _navy),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<bool>(
                    value: true,
                    groupValue: _createNew,
                    activeColor: _orange,
                    title: Text(
                      'Create new ${ZomatoOrderUtils.sourceZomato} order',
                      style: const TextStyle(fontFamily: fontMulishSemiBold),
                    ),
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _createNew = true),
                  ),
                  if (_pendingOrders.isNotEmpty)
                    RadioListTile<bool>(
                      value: false,
                      groupValue: _createNew,
                      activeColor: _orange,
                      title: const Text(
                        'Existing order without screenshot',
                        style: TextStyle(fontFamily: fontMulishSemiBold),
                      ),
                      onChanged: _submitting
                          ? null
                          : (value) => setState(() => _createNew = false),
                    ),
                  if (!_createNew && _pendingOrders.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _selectedDocId,
                      decoration: const InputDecoration(
                        labelText: 'Zomato order',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _pendingOrders
                          .map(
                            (order) => DropdownMenuItem(
                              value: order.docId,
                              child: Text(order.name),
                            ),
                          )
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (value) => setState(() => _selectedDocId = value),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _navy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _submitting || _loadingOrders ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Import screenshot',
                          style: TextStyle(fontFamily: fontMulishBold),
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
