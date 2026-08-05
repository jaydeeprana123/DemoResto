import 'dart:async';

import 'package:smartKitchen/core/firestore/firestore_sync_channel.dart';
import 'package:flutter/foundation.dart';

/// Reconnects a Firestore snapshot stream after errors without changing data handling.
class ResilientFirestoreListener<T> {
  ResilientFirestoreListener({
    required this.streamFactory,
    required this.onData,
    required this.onStatus,
    this.debugLabel,
  });

  final Stream<T> Function() streamFactory;
  final void Function(T event) onData;
  final void Function(FirestoreSyncState status) onStatus;
  final String? debugLabel;

  StreamSubscription<T>? _subscription;
  Timer? _reconnectTimer;
  bool _stopped = true;
  int _retryAttempt = 0;

  void start() {
    _stopped = false;
    _retryAttempt = 0;
    _connect();
  }

  void stop() {
    _stopped = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
  }

  /// Refreshes the live listener (e.g. when app returns to foreground).
  void restart() {
    if (_stopped) return;
    _retryAttempt = 0;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _connect();
  }

  void _connect() {
    if (_stopped) return;

    onStatus(
      _retryAttempt == 0
          ? FirestoreSyncState.connecting
          : FirestoreSyncState.reconnecting,
    );

    _subscription?.cancel();
    _subscription = streamFactory().listen(
      (event) {
        _retryAttempt = 0;
        onStatus(FirestoreSyncState.live);
        onData(event);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (kDebugMode) {
          debugPrint(
            '[ResilientFirestoreListener${debugLabel != null ? ' $debugLabel' : ''}] $error',
          );
        }
        _scheduleReconnect();
      },
      onDone: () {
        if (!_stopped) _scheduleReconnect();
      },
      cancelOnError: false,
    );
  }

  void _scheduleReconnect() {
    if (_stopped) return;
    onStatus(FirestoreSyncState.reconnecting);
    _reconnectTimer?.cancel();
    final seconds = 1 << _retryAttempt.clamp(0, 4);
    _retryAttempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds.clamp(1, 30)), _connect);
  }
}
