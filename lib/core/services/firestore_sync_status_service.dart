import 'package:demo/core/firestore/firestore_sync_channel.dart';
import 'package:get/get.dart';

/// Tracks live Firestore listener health per screen (display only).
class FirestoreSyncStatusService extends GetxService {
  final dashboard = FirestoreSyncState.connecting.obs;
  final kitchen = FirestoreSyncState.connecting.obs;

  void setStatus(FirestoreSyncChannel channel, FirestoreSyncState state) {
    switch (channel) {
      case FirestoreSyncChannel.dashboard:
        dashboard.value = state;
      case FirestoreSyncChannel.kitchen:
        kitchen.value = state;
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
