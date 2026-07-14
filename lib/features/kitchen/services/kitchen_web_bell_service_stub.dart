import 'package:demo/features/kitchen/services/kitchen_bell_sound.dart';

/// No-op outside Flutter web.
class KitchenWebBellService {
  KitchenWebBellService._();

  static Future<void> ensureInitialized() async {}

  static Future<void> unlock() async {}

  static Future<bool> play(KitchenBellSound sound) async => false;

  static Future<void> showAlertNotification(KitchenBellSound sound) async {}
}
