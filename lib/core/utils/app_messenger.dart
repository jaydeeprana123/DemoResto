import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shows user feedback without requiring GetX overlay (safe after route changes).
class AppMessenger {
  AppMessenger._();

  static void show(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    final rootContext = Get.key.currentContext;
    if (rootContext != null && rootContext.mounted) {
      final messenger = ScaffoldMessenger.maybeOf(rootContext);
      if (messenger != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
              duration: duration,
              behavior: SnackBarBehavior.floating,
            ),
          );
        return;
      }
    }

    final overlayContext = Get.overlayContext;
    if (overlayContext != null) {
      try {
        Get.snackbar(title, message, duration: duration);
        return;
      } catch (e) {
        debugPrint('[AppMessenger] Get.snackbar failed: $e');
      }
    }

    debugPrint('[AppMessenger] $title: $message');
  }
}
