import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:smartKitchen/features/kitchen/services/kitchen_background_alert_service.dart';
import 'package:smartKitchen/features/kitchen/services/kitchen_bell_sound.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Coordinates Admin order-completion alerts across Dashboard and Kitchen.
///
/// Foreground: callers show [OrderCompletionNotificationDialog] (sound plays there).
/// Background / locked screen: plays [complete_bell] via the same native/web
/// alert path used for kitchen bells, once per event.
class OrderCompletionAlertService extends GetxService
    with WidgetsBindingObserver {
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  String? _lastBackgroundEventKey;
  DateTime? _lastBackgroundPlayedAt;
  final AudioPlayer _fallbackPlayer = AudioPlayer();

  static const _dedupeWindow = Duration(seconds: 2);

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null) {
      _lifecycle = state;
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_fallbackPlayer.dispose());
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
  }

  bool get isInBackground =>
      _lifecycle == AppLifecycleState.paused ||
      _lifecycle == AppLifecycleState.inactive ||
      _lifecycle == AppLifecycleState.hidden;

  /// Returns `true` when the caller should show the foreground dialog.
  ///
  /// When the app is backgrounded, plays the completion sound (deduped) and
  /// returns `false` so no dialog is shown.
  Future<bool> handleNotify({
    required String eventKey,
    required String tableName,
    required String staffName,
    required bool dialogEligible,
  }) async {
    if (isInBackground) {
      await _playBackgroundAlertOnce(
        eventKey: eventKey,
        tableName: tableName,
        staffName: staffName,
      );
      return false;
    }

    return dialogEligible;
  }

  Future<void> _playBackgroundAlertOnce({
    required String eventKey,
    required String tableName,
    required String staffName,
  }) async {
    final now = DateTime.now();
    if (_lastBackgroundEventKey == eventKey &&
        _lastBackgroundPlayedAt != null &&
        now.difference(_lastBackgroundPlayedAt!) < _dedupeWindow) {
      return;
    }
    _lastBackgroundEventKey = eventKey;
    _lastBackgroundPlayedAt = now;

    final staff = staffName.trim().isEmpty ? 'Staff' : staffName.trim();

    if (kIsWeb) {
      await KitchenBackgroundAlertService.playAlert(
        KitchenBellSound.orderCompletion,
        title: 'Order completed',
        body: '$tableName order is completed. Notified by: $staff',
      );
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      await KitchenBackgroundAlertService.playAlert(
        KitchenBellSound.orderCompletion,
        title: 'Order completed',
        body: '$tableName order is completed. Notified by: $staff',
      );
      return;
    }

    await _playFallbackCompleteBell();
  }

  Future<void> _playFallbackCompleteBell() async {
    try {
      final context = AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.duckOthers,
          },
        ),
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gain,
        ),
      );
      await _fallbackPlayer.setAudioContext(context);
      await _fallbackPlayer.stop();
      await _fallbackPlayer.setReleaseMode(ReleaseMode.stop);
      await _fallbackPlayer.setPlaybackRate(1.0);
      await _fallbackPlayer.play(AssetSource('sounds/complete_bell.mp3'));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Order completion background bell failed: $e');
      }
    }
  }
}
