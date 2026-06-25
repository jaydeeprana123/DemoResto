import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Plays one serving ringtone per serve event across Kitchen and Dashboard.
class ServeNotificationService extends GetxService {
  final AudioPlayer _servePlayer = AudioPlayer();
  String? _lastEventKey;
  DateTime? _lastPlayedAt;

  Future<void> tryPlayServeAlert({
    required String eventKey,
    required bool kitchenEligible,
    required bool dashboardEligible,
  }) async {
    if (!kitchenEligible && !dashboardEligible) return;

    final now = DateTime.now();
    if (_lastEventKey == eventKey &&
        _lastPlayedAt != null &&
        now.difference(_lastPlayedAt!) < const Duration(seconds: 2)) {
      return;
    }

    _lastEventKey = eventKey;
    _lastPlayedAt = now;
    await _playServeSound();
  }

  Future<void> _playServeSound() async {
    try {
      await _servePlayer.stop();
      await _servePlayer.setReleaseMode(ReleaseMode.stop);
      if (await _hasServeBellAsset()) {
        await _servePlayer.setPlaybackRate(1.0);
        await _servePlayer.play(AssetSource('sounds/serve_bell.mp3'));
      } else {
        await _servePlayer.setPlaybackRate(0.82);
        await _servePlayer.play(AssetSource('sounds/phone_bell.mp3'));
        await _servePlayer.setPlaybackRate(1.0);
      }
    } catch (_) {
      // ignore audio errors
    }
  }

  Future<bool> _hasServeBellAsset() async {
    try {
      await rootBundle.load('assets/sounds/serve_bell.mp3');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void onClose() {
    _servePlayer.dispose();
    super.onClose();
  }
}
