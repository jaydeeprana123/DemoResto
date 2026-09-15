import 'package:smartKitchen/features/kitchen/services/kitchen_bell_sound.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps kitchen order monitoring alive on Android and plays alarm notifications
/// when the screen is locked (required on Android 14+).
class KitchenBackgroundAlertService {
  KitchenBackgroundAlertService._();

  static const _channel = MethodChannel('com.innies.smartkitchenpos/kitchen_alerts');

  static bool _initialized = false;
  static bool _startedThisProcess = false;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> initialize() async {
    if (_initialized || !_isAndroid) return;

    FlutterForegroundTask.initCommunicationPort();
    try {
      await _channel.invokeMethod<void>('ensureChannels');
    } catch (_) {
      // Channel may not be ready until MainActivity binds.
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'kitchen_monitor_service',
        channelName: 'Kitchen monitoring',
        channelDescription:
            'Keeps Smart Kitchen listening for kitchen orders while the screen is off',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _initialized = true;
  }

  /// Starts or stops the keep-alive service.
  ///
  /// [promptIfNeeded] should be true after the first frame / a settings toggle
  /// (an Activity exists). Pass false on resume so denied permissions are not
  /// re-prompted every time the app returns to the foreground.
  static Future<void> syncMonitoringEnabled(
    bool enabled, {
    bool promptIfNeeded = true,
  }) async {
    if (!_isAndroid) return;
    await initialize();

    if (enabled) {
      await _ensureAndroidPermissions(promptIfNeeded: promptIfNeeded);
      await _startMonitoringService();
    } else {
      _startedThisProcess = false;
      await _stopMonitoringService();
    }
  }

  /// Returns `true` when a system notification was posted (sound may play).
  static Future<bool> playAlert(
    KitchenBellSound sound, {
    String? title,
    String? body,
  }) async {
    if (!_isAndroid) return false;
    await initialize();

    final config = _alertConfig(sound);
    try {
      final posted = await _channel.invokeMethod<bool>('showAlert', {
        'soundKey': config.rawSound,
        'title': title ?? config.title,
        'body': body ?? config.body,
      });
      return posted == true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Kitchen background alert failed: $e');
      }
      return false;
    }
  }

  static Future<void> _ensureAndroidPermissions({
    required bool promptIfNeeded,
  }) async {
    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted &&
        promptIfNeeded) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (promptIfNeeded &&
        !await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  static Future<void> _startMonitoringService() async {
    if (await FlutterForegroundTask.isRunningService) {
      if (_startedThisProcess) return;
      await FlutterForegroundTask.stopService();
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      serviceTypes: const [
        ForegroundServiceTypes.mediaPlayback,
        ForegroundServiceTypes.dataSync,
      ],
      notificationTitle: 'Kitchen orders active',
      notificationText: 'Listening for new orders while the screen is locked',
      callback: kitchenMonitorStartCallback,
    );
    _startedThisProcess = result is ServiceRequestSuccess;
    if (result is ServiceRequestFailure && kDebugMode) {
      debugPrint('Kitchen monitor service failed to start: ${result.error}');
    }
  }

  static Future<void> _stopMonitoringService() async {
    if (!await FlutterForegroundTask.isRunningService) {
      return;
    }
    await FlutterForegroundTask.stopService();
  }

  static _AlertConfig _alertConfig(KitchenBellSound sound) {
    switch (sound) {
      case KitchenBellSound.newOrder:
        return const _AlertConfig(
          rawSound: 'phone_bell',
          title: 'New kitchen order',
          body: 'A new order arrived in the kitchen',
        );
      case KitchenBellSound.update:
        return const _AlertConfig(
          rawSound: 'update_bell',
          title: 'Kitchen order updated',
          body: 'An order was changed in the kitchen',
        );
      case KitchenBellSound.delete:
        return const _AlertConfig(
          rawSound: 'delete_bell',
          title: 'Kitchen order removed',
          body: 'An order was removed from the kitchen list',
        );
      case KitchenBellSound.serve:
        return const _AlertConfig(
          rawSound: 'serve_bell',
          title: 'Items served',
          body: 'Kitchen items were marked as served',
        );
      case KitchenBellSound.orderCompletion:
        return const _AlertConfig(
          rawSound: 'complete_bell',
          title: 'Order completed',
          body: 'Staff notified that an order is ready for billing',
        );
    }
  }
}

class _AlertConfig {
  const _AlertConfig({
    required this.rawSound,
    required this.title,
    required this.body,
  });

  final String rawSound;
  final String title;
  final String body;
}

@pragma('vm:entry-point')
void kitchenMonitorStartCallback() {
  FlutterForegroundTask.setTaskHandler(KitchenMonitorTaskHandler());
}

class KitchenMonitorTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationDismissed() {}
}
