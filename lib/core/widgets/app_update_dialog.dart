import 'package:smartKitchen/Styles/my_font.dart';
import 'package:smartKitchen/core/services/app_update_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _navy = Color(0xFF1A3A5C);

/// Update prompt shown when Remote Config reports a newer store version.
Future<void> showAppUpdateDialog(
  BuildContext context, {
  required AppUpdateInfo updateInfo,
}) {
  final isForceUpdate = updateInfo.isForceUpdate;

  return showDialog<void>(
    context: context,
    barrierDismissible: !isForceUpdate,
    builder: (dialogContext) {
      return PopScope(
        canPop: !isForceUpdate,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Update available',
            style: TextStyle(
              fontFamily: fontMulishBold,
              fontSize: 18,
              color: _navy,
            ),
          ),
          content: Text(
            isForceUpdate
                ? 'A new version (${updateInfo.latestVersion}) is required to '
                    'continue using Smart Kitchen. Please update the app.'
                : 'A new version (${updateInfo.latestVersion}) is available. '
                    'Update now for the latest features and fixes.',
            style: const TextStyle(
              fontFamily: fontMulishRegular,
              fontSize: 15,
            ),
          ),
          actions: [
            if (!isForceUpdate)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Later',
                  style: TextStyle(
                    fontFamily: fontMulishSemiBold,
                    color: Colors.grey,
                  ),
                ),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _openStore(updateInfo.storeUrl),
              child: const Text(
                'Update',
                style: TextStyle(
                  fontFamily: fontMulishSemiBold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _openStore(String url) async {
  if (url.trim().isEmpty) return;

  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
