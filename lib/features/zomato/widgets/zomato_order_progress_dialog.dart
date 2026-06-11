import 'package:flutter/material.dart';

import 'package:demo/Styles/my_font.dart';

class ZomatoOrderProgressDialog {
  ZomatoOrderProgressDialog._();

  static int _openCount = 0;

  static void show(
    BuildContext context, {
    String message = 'Marking Zomato order as served...',
    String subtitle = 'Removing screenshot and closing order',
  }) {
    if (_openCount > 0) return;

    _openCount++;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFFE53935)),
                const SizedBox(height: 20),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontFamily: fontMulishSemiBold,
                    color: Color(0xFF1A3A5C),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: fontMulishRegular,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                const LinearProgressIndicator(
                  color: Color(0xFFE53935),
                  backgroundColor: Color(0xFFE5E7EB),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (_openCount > 0) _openCount--;
    });
  }

  static void hide(BuildContext context) {
    if (_openCount <= 0) return;

    try {
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) {
        navigator.pop();
        _openCount--;
      }
    } catch (_) {
      _openCount = 0;
    }
  }

  static Future<T> run<T>(
    BuildContext context, {
    required Future<T> Function() action,
    String message = 'Marking Zomato order as served...',
    String subtitle = 'Removing screenshot and closing order',
  }) async {
    show(context, message: message, subtitle: subtitle);
    try {
      return await action();
    } finally {
      if (context.mounted) {
        hide(context);
      }
    }
  }
}
