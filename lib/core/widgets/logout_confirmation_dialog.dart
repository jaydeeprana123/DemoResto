import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:demo/Styles/my_font.dart';

const _navy = Color(0xFF1A3A5C);

/// Shows a "Are you sure you want to log out?" confirmation dialog.
///
/// Returns `true` only when the user explicitly taps Logout. Uses [Get.dialog]
/// so it can be invoked from controllers that have no [BuildContext].
Future<bool> confirmLogout() async {
  final confirmed = await Get.dialog<bool>(
    AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Log out?',
        style: TextStyle(
          fontFamily: fontMulishBold,
          fontSize: 18,
          color: _navy,
        ),
      ),
      content: const Text(
        'Are you sure you want to log out?',
        style: TextStyle(fontFamily: fontMulishRegular, fontSize: 15),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontFamily: fontMulishSemiBold,
              color: Colors.grey,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => Get.back(result: true),
          child: const Text(
            'Logout',
            style: TextStyle(
              fontFamily: fontMulishSemiBold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
    barrierDismissible: false,
  );
  return confirmed == true;
}
