import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/core/repositories/user_repository.dart';
import 'package:demo/features/authentication/services/device_session_settings.dart';
import 'package:get/get.dart';

/// Enforces one active device per user via `users/{uid}.activeSessionId`.
///
/// On login (or first watch without a local session), a new session ID is
/// written. Other devices listening to the same user doc are signed out.
class DeviceSessionService extends GetxService {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  bool _handlingKick = false;
  bool _claiming = false;
  String? _watchedUid;

  static const kickMessage =
      'This account has been logged in from another device. '
      'Please sign in again.';

  /// Creates a new session for [uid] and stores it locally + in Firestore.
  Future<void> claimNewSession(String uid) async {
    final sessionId = _generateSessionId();
    await DeviceSessionSettings.saveSessionId(sessionId);
    await FirestorePaths.user(uid).set(
      {
        'activeSessionId': sessionId,
        'activeSessionUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Starts watching the user doc. Claims a session if this device has none.
  Future<void> startWatching(String uid) async {
    if (_handlingKick) return;

    await stopWatching();
    _watchedUid = uid;

    final local = await DeviceSessionSettings.loadSessionId();
    if (local == null || local.isEmpty) {
      await claimNewSession(uid);
    }

    _subscription = FirestorePaths.user(uid).snapshots().listen(
      _onUserSnapshot,
      onError: (_) {},
    );
  }

  Future<void> stopWatching() async {
    await _subscription?.cancel();
    _subscription = null;
    _watchedUid = null;
  }

  /// Manual logout: stop listener and clear this device's session if it still
  /// owns the Firestore session (does not wipe a newer device's session).
  Future<void> clearOwnedSession(String? uid) async {
    await stopWatching();
    final local = await DeviceSessionSettings.loadSessionId();
    if (uid != null && uid.isNotEmpty && local != null && local.isNotEmpty) {
      try {
        final doc = await FirestorePaths.user(uid).get();
        final remote = doc.data()?['activeSessionId']?.toString();
        if (remote == local) {
          await FirestorePaths.user(uid).set(
            {
              'activeSessionId': '',
              'activeSessionUpdatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      } catch (_) {
        // Best-effort cleanup; local clear still proceeds.
      }
    }
    await DeviceSessionSettings.clearSessionId();
  }

  Future<void> _onUserSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) async {
    if (_handlingKick || _claiming) return;
    if (!snap.exists) return;

    final uid = snap.id;
    if (_watchedUid != null && uid != _watchedUid) return;

    final remote = snap.data()?['activeSessionId']?.toString();
    final local = await DeviceSessionSettings.loadSessionId();

    if (remote == null || remote.isEmpty) {
      // Session missing (manual logout elsewhere, or pre-feature user).
      // Re-claim only if this device still has a local session.
      if (local != null && local.isNotEmpty) {
        _claiming = true;
        try {
          await FirestorePaths.user(uid).set(
            {
              'activeSessionId': local,
              'activeSessionUpdatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        } finally {
          _claiming = false;
        }
      }
      return;
    }

    if (local == null || local.isEmpty || local != remote) {
      await _forceLogoutDueToOtherDevice();
    }
  }

  Future<void> _forceLogoutDueToOtherDevice() async {
    if (_handlingKick) return;
    _handlingKick = true;
    try {
      await stopWatching();
      await DeviceSessionSettings.clearSessionId();
      await DeviceSessionSettings.setPendingLoginMessage(kickMessage);
      if (Get.isRegistered<UserRepository>()) {
        await Get.find<UserRepository>().signOut(
          dueToOtherDeviceLogin: true,
        );
      }
    } finally {
      _handlingKick = false;
    }
  }

  String _generateSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${DateTime.now().microsecondsSinceEpoch}_$hex';
  }
}
