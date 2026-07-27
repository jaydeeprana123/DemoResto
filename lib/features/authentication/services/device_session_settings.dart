import 'package:shared_preferences/shared_preferences.dart';

/// Local storage for single-device login session ID and post-logout messages.
class DeviceSessionSettings {
  DeviceSessionSettings._();

  static const _keySessionId = 'device_active_session_id';
  static const _keyPendingMessage = 'device_session_pending_login_message';

  static Future<String?> loadSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySessionId);
  }

  static Future<void> saveSessionId(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySessionId, sessionId);
  }

  static Future<void> clearSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySessionId);
  }

  static Future<void> setPendingLoginMessage(String message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPendingMessage, message);
  }

  static Future<String?> takePendingLoginMessage() async {
    final prefs = await SharedPreferences.getInstance();
    final message = prefs.getString(_keyPendingMessage);
    if (message != null) {
      await prefs.remove(_keyPendingMessage);
    }
    return message;
  }
}
