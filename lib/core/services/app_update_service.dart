import 'dart:io' show Platform;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Result of comparing the installed app version with Remote Config.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.isForceUpdate,
    required this.storeUrl,
  });

  final String latestVersion;
  final bool isForceUpdate;
  final String storeUrl;
}

/// Fetches version policy from Firebase Remote Config and compares it
/// with the version installed on the device (Android / iOS only).
class AppUpdateService {
  AppUpdateService._();

  static const _keyAndroidLatestVersion = 'android_latest_version';
  static const _keyIosLatestVersion = 'ios_latest_version';
  static const _keyAndroidForceUpdate = 'android_force_update';
  static const _keyIosForceUpdate = 'ios_force_update';
  static const _keyPlayStoreUrl = 'play_store_url';
  static const _keyAppStoreUrl = 'app_store_url';

  static const _defaultPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.innies.smartkitchenpos';

  static bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Returns [AppUpdateInfo] when an update is available, otherwise `null`.
  /// On failure or unsupported platforms, returns `null` so the app can load.
  static Future<AppUpdateInfo?> checkForUpdate() async {
    if (!isSupported) return null;

    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remoteConfig.setDefaults(const {
        _keyAndroidLatestVersion: '1.0.0',
        _keyIosLatestVersion: '1.0.0',
        _keyAndroidForceUpdate: false,
        _keyIosForceUpdate: false,
        _keyPlayStoreUrl: _defaultPlayStoreUrl,
        _keyAppStoreUrl: '',
      });
      await remoteConfig.fetchAndActivate();

      final packageInfo = await PackageInfo.fromPlatform();
      final installedVersion = packageInfo.version;

      final isAndroid = Platform.isAndroid;
      final latestVersion = remoteConfig.getString(
        isAndroid ? _keyAndroidLatestVersion : _keyIosLatestVersion,
      );
      final isForceUpdate = remoteConfig.getBool(
        isAndroid ? _keyAndroidForceUpdate : _keyIosForceUpdate,
      );
      final storeUrl = remoteConfig.getString(
        isAndroid ? _keyPlayStoreUrl : _keyAppStoreUrl,
      );

      if (latestVersion.trim().isEmpty) return null;
      if (!isVersionOlder(installedVersion, latestVersion)) return null;

      final resolvedStoreUrl = storeUrl.trim().isNotEmpty
          ? storeUrl.trim()
          : (isAndroid ? _defaultPlayStoreUrl : '');

      return AppUpdateInfo(
        latestVersion: latestVersion.trim(),
        isForceUpdate: isForceUpdate,
        storeUrl: resolvedStoreUrl,
      );
    } catch (e, st) {
      debugPrint('AppUpdateService.checkForUpdate failed: $e\n$st');
      return null;
    }
  }

  /// Returns `true` when [current] is strictly older than [latest].
  @visibleForTesting
  static bool isVersionOlder(String current, String latest) {
    final currentParts = _parseVersionParts(current);
    final latestParts = _parseVersionParts(latest);
    final length = currentParts.length > latestParts.length
        ? currentParts.length
        : latestParts.length;

    for (var i = 0; i < length; i++) {
      final c = i < currentParts.length ? currentParts[i] : 0;
      final l = i < latestParts.length ? latestParts[i] : 0;
      if (c < l) return true;
      if (c > l) return false;
    }
    return false;
  }

  static List<int> _parseVersionParts(String version) {
    return version
        .split('.')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList();
  }
}
