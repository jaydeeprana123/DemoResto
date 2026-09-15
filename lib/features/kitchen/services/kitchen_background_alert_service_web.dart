// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:smartKitchen/features/kitchen/services/kitchen_bell_sound.dart';
import 'package:smartKitchen/features/kitchen/services/kitchen_web_bell_service.dart';

/// Web/PWA kitchen alerts: HTML Audio bells + optional notifications when hidden.
class KitchenBackgroundAlertService {
  KitchenBackgroundAlertService._();

  static Future<void> initialize() async {
    await KitchenWebBellService.ensureInitialized();
  }

  static Future<void> syncMonitoringEnabled(
    bool enabled, {
    bool promptIfNeeded = true,
  }) async {
    if (enabled) {
      await KitchenWebBellService.ensureInitialized();
    }
  }

  static Future<bool> playAlert(
    KitchenBellSound sound, {
    String? title,
    String? body,
  }) async {
    await KitchenWebBellService.ensureInitialized();

    if (html.document.hidden == true) {
      await KitchenWebBellService.showAlertNotification(
        sound,
        title: title,
        body: body,
      );
      await KitchenWebBellService.play(sound);
      return true;
    }

    final played = await KitchenWebBellService.play(sound);
    if (!played) {
      await KitchenWebBellService.showAlertNotification(
        sound,
        title: title,
        body: body,
      );
    }
    return true;
  }
}
