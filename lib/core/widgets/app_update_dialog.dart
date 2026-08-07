import 'package:smartKitchen/Styles/my_font.dart';
import 'package:smartKitchen/core/services/app_update_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _navy = Color(0xFF1A3A5C);

/// Update prompt UI. Used as a Stack overlay (works above MaterialApp navigator).
class AppUpdatePrompt extends StatelessWidget {
  const AppUpdatePrompt({
    super.key,
    required this.updateInfo,
    this.onLater,
  });

  final AppUpdateInfo updateInfo;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final isForceUpdate = updateInfo.isForceUpdate;

    return PopScope(
      canPop: !isForceUpdate,
      child: Material(
        color: Colors.black54,
        child: Center(
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
                  onPressed: onLater,
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
                onPressed: () => openAppStoreUrl(updateInfo.storeUrl),
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
        ),
      ),
    );
  }
}

Future<void> openAppStoreUrl(String url) async {
  if (url.trim().isEmpty) return;

  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
