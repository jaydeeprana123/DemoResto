import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardSettings {
  DashboardSettings._();

  static const _keyServeRingtoneEnabled = 'dashboard_serve_ringtone_enabled';
  static const _keyOrderCompletionNotificationEnabled =
      'dashboard_order_completion_notification_enabled';

  static final ValueNotifier<bool> serveRingtoneEnabled = ValueNotifier(true);
  static final ValueNotifier<bool> orderCompletionNotificationEnabled =
      ValueNotifier(false);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    serveRingtoneEnabled.value =
        prefs.getBool(_keyServeRingtoneEnabled) ?? true;
    orderCompletionNotificationEnabled.value =
        prefs.getBool(_keyOrderCompletionNotificationEnabled) ?? false;
  }

  static Future<bool> getServeRingtoneEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyServeRingtoneEnabled) ?? true;
  }

  static Future<void> setServeRingtoneEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyServeRingtoneEnabled, value);
    serveRingtoneEnabled.value = value;
  }

  static Future<bool> getOrderCompletionNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOrderCompletionNotificationEnabled) ?? false;
  }

  static Future<void> setOrderCompletionNotificationEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOrderCompletionNotificationEnabled, value);
    orderCompletionNotificationEnabled.value = value;
  }
}
