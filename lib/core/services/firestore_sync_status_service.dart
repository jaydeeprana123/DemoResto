import 'package:smartKitchen/core/firestore/firestore_sync_channel.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

/// Tracks live Firestore listener health per screen (display only).
class FirestoreSyncStatusService extends GetxService {
  final dashboard = FirestoreSyncState.connecting.obs;
  final kitchen = FirestoreSyncState.connecting.obs;

  final Map<FirestoreSyncChannel, FirestoreSyncState> _pending = {};
  bool _flushScheduled = false;

  void setStatus(FirestoreSyncChannel channel, FirestoreSyncState state) {
    if (_isBuilding) {
      _pending[channel] = state;
      _scheduleFlush();
      return;
    }
    _pending.remove(channel);
    _applyStatus(channel, state);
  }

  bool get _isBuilding {
    final phase = SchedulerBinding.instance.schedulerPhase;
    return phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
  }

  void _scheduleFlush() {
    if (_flushScheduled) return;
    _flushScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      if (_pending.isEmpty) return;
      final pending = Map<FirestoreSyncChannel, FirestoreSyncState>.from(
        _pending,
      );
      _pending.clear();
      for (final entry in pending.entries) {
        _applyStatus(entry.key, entry.value);
      }
    });
  }

  void _applyStatus(FirestoreSyncChannel channel, FirestoreSyncState state) {
    switch (channel) {
      case FirestoreSyncChannel.dashboard:
        if (dashboard.value != state) dashboard.value = state;
      case FirestoreSyncChannel.kitchen:
        if (kitchen.value != state) kitchen.value = state;
    }
  }

  Rx<FirestoreSyncState> stateFor(FirestoreSyncChannel channel) {
    switch (channel) {
      case FirestoreSyncChannel.dashboard:
        return dashboard;
      case FirestoreSyncChannel.kitchen:
        return kitchen;
    }
  }
}
