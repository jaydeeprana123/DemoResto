import 'package:audioplayers/audioplayers.dart';
import 'package:demo/features/kitchen/services/kitchen_web_bell_service.dart';
import 'package:demo/features/kitchen/services/kitchen_bell_sound.dart';
import 'package:demo/features/tables/repositories/table_item_served.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class _LocalServeSuppression {
  _LocalServeSuppression({
    required this.tokens,
    required this.expiresAt,
  });

  final Set<String> tokens;
  final DateTime expiresAt;
}

/// Plays one serving ringtone per serve event across Kitchen and Dashboard.
class ServeNotificationService extends GetxService {
  final AudioPlayer _servePlayer = AudioPlayer();
  final List<_LocalServeSuppression> _localSuppressions = [];
  String? _lastEventKey;
  DateTime? _lastPlayedAt;

  static const _suppressionTtl = Duration(seconds: 8);

  /// Call when this device taps Serve, before the Firestore write completes.
  void suppressLocalServe(Iterable<TableItemKey> keys) {
    final tokens = keys.map((key) => key.id).where((id) => id.isNotEmpty).toSet();
    if (tokens.isEmpty) return;

    _pruneExpiredSuppressions();
    _localSuppressions.add(
      _LocalServeSuppression(
        tokens: tokens,
        expiresAt: DateTime.now().add(_suppressionTtl),
      ),
    );
  }

  Future<void> tryPlayServeAlert({
    required String eventKey,
    required bool kitchenEligible,
    required bool dashboardEligible,
    Set<String> servedItemKeyIds = const {},
  }) async {
    if (!kitchenEligible && !dashboardEligible) return;
    if (shouldSkipServeSound(servedItemKeyIds)) return;

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

  bool shouldSkipServeSound(Set<String> servedItemKeyIds) {
    if (servedItemKeyIds.isEmpty) return false;

    _pruneExpiredSuppressions();
    for (final entry in _localSuppressions) {
      if (entry.tokens.intersection(servedItemKeyIds).isEmpty) continue;
      return true;
    }
    return false;
  }

  void _pruneExpiredSuppressions() {
    final now = DateTime.now();
    _localSuppressions.removeWhere((entry) => !now.isBefore(entry.expiresAt));
  }

  Future<void> _playServeSound() async {
    if (kIsWeb) {
      await KitchenWebBellService.play(KitchenBellSound.serve);
      return;
    }
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
