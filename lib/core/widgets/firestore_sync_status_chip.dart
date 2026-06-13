import 'package:demo/core/firestore/firestore_sync_channel.dart';
import 'package:demo/core/services/firestore_sync_status_service.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Small status chip shown only while Firestore is connecting or reconnecting.
class FirestoreSyncStatusChip extends StatelessWidget {
  const FirestoreSyncStatusChip({
    required this.channel,
    super.key,
  });

  final FirestoreSyncChannel channel;

  @override
  Widget build(BuildContext context) {
    final service = Get.find<FirestoreSyncStatusService>();
    final state = service.stateFor(channel);

    return Obx(() {
      final value = state.value;
      if (value == FirestoreSyncState.live) {
        return const SizedBox.shrink();
      }

      final label = value == FirestoreSyncState.connecting
          ? 'Connecting…'
          : 'Reconnecting…';
      final color = value == FirestoreSyncState.connecting
          ? Colors.white70
          : const Color(0xFFFFC107);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: fontMulishSemiBold,
                  fontSize: 11,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
