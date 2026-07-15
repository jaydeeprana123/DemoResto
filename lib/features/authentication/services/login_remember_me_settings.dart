import 'package:shared_preferences/shared_preferences.dart';

class LoginRememberedCredentials {
  const LoginRememberedCredentials({
    required this.rememberMe,
    this.email,
    this.password,
  });

  final bool rememberMe;
  final String? email;
  final String? password;
}

class LoginRememberMeSettings {
  LoginRememberMeSettings._();

  static const _keyRememberMe = 'login_remember_me';
  static const _keyEmail = 'login_saved_email';
  static const _keyPassword = 'login_saved_password';

  static Future<LoginRememberedCredentials> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
    return LoginRememberedCredentials(
      rememberMe: rememberMe,
      email: prefs.getString(_keyEmail),
      password: prefs.getString(_keyPassword),
    );
  }

  static Future<void> save({
    required bool rememberMe,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberMe, rememberMe);
    if (rememberMe) {
      await prefs.setString(_keyEmail, email.trim());
      await prefs.setString(_keyPassword, password);
    } else {
      await prefs.remove(_keyEmail);
      await prefs.remove(_keyPassword);
    }
  }
}
