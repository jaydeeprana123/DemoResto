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

  static Future<void> syncMonitoringEnabled(bool enabled) async {
    if (enabled) {
      await KitchenWebBellService.ensureInitialized();
    }
  }

  static Future<void> playAlert(KitchenBellSound sound) async {
    await KitchenWebBellService.ensureInitialized();

    if (html.document.hidden == true) {
      await KitchenWebBellService.showAlertNotification(sound);
      await KitchenWebBellService.play(sound);
      return;
    }

    final played = await KitchenWebBellService.play(sound);
    if (!played) {
      await KitchenWebBellService.showAlertNotification(sound);
    }
  }
}
