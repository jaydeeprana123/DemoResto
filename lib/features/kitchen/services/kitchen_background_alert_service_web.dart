import 'package:demo/features/kitchen/services/kitchen_bell_sound.dart';

/// No-op on web — kitchen background alerts are Android-only.
class KitchenBackgroundAlertService {
  KitchenBackgroundAlertService._();

  static Future<void> initialize() async {}

  static Future<void> syncMonitoringEnabled(bool enabled) async {}

  static Future<void> playAlert(KitchenBellSound sound) async {}
}
