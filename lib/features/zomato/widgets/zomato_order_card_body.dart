import 'package:demo/Styles/my_font.dart';
import 'package:demo/core/utils/zomato_order_utils.dart';
import 'package:demo/features/zomato/repositories/zomato_orders_repository.dart';
import 'package:demo/features/zomato/widgets/zomato_screenshot_viewer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ZomatoOrderCardBody extends StatelessWidget {
  const ZomatoOrderCardBody({
    super.key,
    required this.docId,
    required this.screenshotUrl,
    required this.status,
    this.compact = false,
    this.onStatusChanged,
  });

  final String docId;
  final String screenshotUrl;
  final String status;
  final bool compact;
  final ValueChanged<String>? onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final normalized = ZomatoOrderUtils.normalizeStatus(status);
    final statusColor = _statusColor(normalized);

    return Padding(
      padding: EdgeInsets.all(compact ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE53935)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delivery_dining, size: compact ? 14 : 16, color: Color(0xFFE53935)),
                    const SizedBox(width: 4),
                    Text(
                      'ZOMATO',
                      style: TextStyle(
                        fontFamily: fontMulishBold,
                        fontSize: compact ? 10 : 11,
                        color: Color(0xFFE53935),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  normalized,
                  style: TextStyle(
                    fontFamily: fontMulishBold,
                    fontSize: compact ? 10 : 11,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => ZomatoScreenshotViewer.show(
              context,
              imageUrl: screenshotUrl,
              title: 'Zomato Order',
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.network(
                  screenshotUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap screenshot to view full order details',
            textAlign: TextAlign.center,
            style: MyFont.regular(11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: normalized,
            decoration: InputDecoration(
              labelText: 'Order status',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: ZomatoOrderUtils.statuses
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value, style: MyFont.semiBold(14)),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value == null || value == normalized) return;
              try {
                await Get.find<ZomatoOrdersRepository>().updateStatus(
                  docId: docId,
                  status: value,
                );
                onStatusChanged?.call(value);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not update status: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Preparing':
        return const Color(0xFFf57c35);
      case 'Ready':
        return const Color(0xFF2E7D32);
      case 'Completed':
        return Colors.grey.shade700;
      default:
        return const Color(0xFFE53935);
    }
  }
}
