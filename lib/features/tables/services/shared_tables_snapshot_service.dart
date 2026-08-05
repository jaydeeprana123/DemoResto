import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartKitchen/core/firestore/firestore_sync_channel.dart';
import 'package:smartKitchen/core/firestore/resilient_firestore_listener.dart';
import 'package:smartKitchen/core/services/firestore_sync_status_service.dart';
import 'package:smartKitchen/features/tables/repositories/tables_repository.dart';
import 'package:get/get.dart';

typedef TablesSnapshotHandler =
    void Function(QuerySnapshot<Map<String, dynamic>> snapshot);

/// Single Firestore `tables` listener shared by Dashboard and Kitchen.
class SharedTablesSnapshotService extends GetxService {
  SharedTablesSnapshotService(this._tablesRepository);

  final TablesRepository _tablesRepository;
  final Map<Object, TablesSnapshotHandler> _subscribers = {};
  ResilientFirestoreListener<QuerySnapshot<Map<String, dynamic>>>? _listener;
  QuerySnapshot<Map<String, dynamic>>? _lastSnapshot;

  void subscribe(Object token, TablesSnapshotHandler handler) {
    _subscribers[token] = handler;
    _ensureListener();

    final cached = _lastSnapshot;
    if (cached != null) {
      handler(cached);
    }
  }

  void unsubscribe(Object token) {
    _subscribers.remove(token);
    if (_subscribers.isEmpty) {
      _listener?.stop();
      _listener = null;
      _lastSnapshot = null;
    }
  }

  void restart() {
    _listener?.restart();
  }

  void _ensureListener() {
    if (_listener != null) return;

    _listener =
        ResilientFirestoreListener<QuerySnapshot<Map<String, dynamic>>>(
          debugLabel: 'tables-shared',
          streamFactory: _tablesRepository.watchTables,
          onStatus: _onSyncStatus,
          onData: _fanOut,
        )..start();
  }

  void _onSyncStatus(FirestoreSyncState state) {
    if (!Get.isRegistered<FirestoreSyncStatusService>()) return;
    final syncStatus = Get.find<FirestoreSyncStatusService>();
    syncStatus.setStatus(FirestoreSyncChannel.dashboard, state);
    syncStatus.setStatus(FirestoreSyncChannel.kitchen, state);
  }

  void _fanOut(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _lastSnapshot = snapshot;
    for (final handler in _subscribers.values) {
      handler(snapshot);
    }
  }

  @override
  void onClose() {
    _listener?.stop();
    _subscribers.clear();
    _lastSnapshot = null;
    super.onClose();
  }
}
