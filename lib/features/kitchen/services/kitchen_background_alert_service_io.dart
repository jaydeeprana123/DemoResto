import 'package:demo/features/kitchen/services/kitchen_bell_sound.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps kitchen order monitoring alive on Android and plays alarm notifications
/// when the screen is locked (required on Android 14+).
class KitchenBackgroundAlertService {
  KitchenBackgroundAlertService._();

  static const _channel = MethodChannel('com.innies.demo/kitchen_alerts');

  static bool _initialized = false;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> initialize() async {
    if (_initialized || !_isAndroid) return;

    FlutterForegroundTask.initCommunicationPort();
    await _channel.invokeMethod<void>('ensureChannels');

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'kitchen_monitor_service',
        channelName: 'Kitchen monitoring',
        channelDescription:
            'Keeps Flavor Flow listening for kitchen orders while the screen is off',
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

  static Future<void> syncMonitoringEnabled(bool enabled) async {
    if (!_isAndroid) return;
    await initialize();

    if (enabled) {
      await _ensureAndroidPermissions();
      await _startMonitoringService();
    } else {
      await _stopMonitoringService();
    }
  }

  static Future<void> playAlert(KitchenBellSound sound) async {
    if (!_isAndroid) return;
    await initialize();

    final config = _alertConfig(sound);
    await _channel.invokeMethod<void>('showAlert', {
      'soundKey': config.rawSound,
      'title': config.title,
      'body': config.body,
    });
  }

  static Future<void> _ensureAndroidPermissions() async {
    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  static Future<void> _startMonitoringService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: 256,
      serviceTypes: const [
        ForegroundServiceTypes.dataSync,
        ForegroundServiceTypes.remoteMessaging,
      ],
      notificationTitle: 'Kitchen orders active',
      notificationText: 'Listening for new orders while the screen is locked',
      callback: kitchenMonitorStartCallback,
    );
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
