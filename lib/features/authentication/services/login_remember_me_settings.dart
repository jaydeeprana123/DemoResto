import 'package:shared_preferences/shared_preferences.dart';

class LoginRememberedCredentials {
  const LoginRememberedCredentials({
    required this.rememberMe,
    this.email,
  });

  final bool rememberMe;
  final String? email;
}

class LoginRememberMeSettings {
  LoginRememberMeSettings._();

  static const _keyRememberMe = 'login_remember_me';
  static const _keyEmail = 'login_saved_email';
  static const _keyPassword = 'login_saved_password';

  static Future<LoginRememberedCredentials> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
    // Security hardening: do not persist passwords locally.
    await prefs.remove(_keyPassword);
    return LoginRememberedCredentials(
      rememberMe: rememberMe,
      email: prefs.getString(_keyEmail),
    );
  }

  static Future<void> save({
    required bool rememberMe,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberMe, rememberMe);
    // Security hardening: ensure password key is always removed.
    await prefs.remove(_keyPassword);
    if (rememberMe) {
      await prefs.setString(_keyEmail, email.trim());
    } else {
      await prefs.remove(_keyEmail);
    }
  }
}
