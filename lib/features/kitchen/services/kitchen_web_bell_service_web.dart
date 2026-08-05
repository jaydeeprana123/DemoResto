import 'dart:async';
import 'dart:js' as js;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:smartKitchen/features/kitchen/services/kitchen_bell_sound.dart';

/// Reliable kitchen bells on mobile Safari / installed PWAs via HTML Audio.
class KitchenWebBellService {
  KitchenWebBellService._();

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    js.context.callMethod('kitchenBellsInit');
  }

  static Future<void> unlock() async {
    await ensureInitialized();
    js.context.callMethod('kitchenBellsUnlock');
  }

  static Future<bool> play(KitchenBellSound sound) async {
    await ensureInitialized();
    try {
      final result = js.context.callMethod('kitchenBellsPlay', [_soundKey(sound)]);
      if (result is bool) return result;
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> showAlertNotification(KitchenBellSound sound) async {
    await ensureInitialized();
    final config = _notificationCopy(sound);
    js.context.callMethod('kitchenBellsNotify', [
      config.$1,
      config.$2,
      _soundKey(sound),
    ]);
  }

  static String _soundKey(KitchenBellSound sound) {
    switch (sound) {
      case KitchenBellSound.newOrder:
        return 'phone_bell';
      case KitchenBellSound.update:
        return 'update_bell';
      case KitchenBellSound.delete:
        return 'delete_bell';
      case KitchenBellSound.serve:
        return 'serve_bell';
    }
  }

  static (String, String) _notificationCopy(KitchenBellSound sound) {
    switch (sound) {
      case KitchenBellSound.newOrder:
        return ('New kitchen order', 'A new order arrived in the kitchen');
      case KitchenBellSound.update:
        return ('Kitchen order updated', 'An order was changed in the kitchen');
      case KitchenBellSound.delete:
        return ('Kitchen order removed', 'An order was removed from the kitchen');
      case KitchenBellSound.serve:
        return ('Items served', 'Kitchen items were marked as served');
    }
  }
}
