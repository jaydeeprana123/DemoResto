import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTabMode {
  dashboardOnly,
  kitchenOnly,
  dashboardAndKitchen,
}

extension AppTabModeLabel on AppTabMode {
  String get label => switch (this) {
        AppTabMode.dashboardOnly => 'Dashboard Only',
        AppTabMode.kitchenOnly => 'Kitchen Only',
        AppTabMode.dashboardAndKitchen => 'Dashboard + Kitchen',
      };

  String get subtitle => switch (this) {
        AppTabMode.dashboardOnly => 'Kitchen tab will be hidden',
        AppTabMode.kitchenOnly => 'Dashboard tab will be hidden',
        AppTabMode.dashboardAndKitchen => 'Both tabs will be visible',
      };
}

class AppTabSettings {
  static const _keyAppTabMode = 'app_tab_mode';

  static final ValueNotifier<AppTabMode> mode =
      ValueNotifier(AppTabMode.dashboardAndKitchen);

  static Future<void> load() async {
    mode.value = await getMode();
  }

  static Future<AppTabMode> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    return _parseMode(prefs.getString(_keyAppTabMode));
  }

  static Future<void> setMode(AppTabMode value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppTabMode, value.name);
    mode.value = value;
  }

  static AppTabMode _parseMode(String? raw) {
    return AppTabMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => AppTabMode.dashboardAndKitchen,
    );
  }
}
