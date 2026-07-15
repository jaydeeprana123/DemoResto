import 'package:shared_preferences/shared_preferences.dart';

/// Remembers when the user dismissed the web install prompt.
class PwaInstallPromptSettings {
  PwaInstallPromptSettings._();

  static const _dismissedKey = 'pwa_install_prompt_dismissed';

  static Future<bool> wasDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dismissedKey) ?? false;
  }

  static Future<void> markDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }

  static Future<void> clearDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedKey);
  }
}
