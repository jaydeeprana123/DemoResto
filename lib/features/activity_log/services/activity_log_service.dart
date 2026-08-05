import 'dart:async';

import 'package:smartKitchen/core/services/restaurant_session.dart';
import 'package:smartKitchen/features/activity_log/models/activity_log_entry.dart';
import 'package:smartKitchen/features/activity_log/repositories/activity_log_repository.dart';
import 'package:get/get.dart';

/// Fire-and-forget activity log writes (one write per action; no reads).
class ActivityLogService {
  ActivityLogService({ActivityLogRepository? repository})
      : _repository = repository ?? ActivityLogRepository();

  final ActivityLogRepository _repository;

  static ActivityLogService get instance {
    if (Get.isRegistered<ActivityLogService>()) {
      return Get.find<ActivityLogService>();
    }
    final service = ActivityLogService();
    Get.put<ActivityLogService>(service, permanent: true);
    return service;
  }

  static ({String userId, String userName})? currentActor() {
    if (!Get.isRegistered<RestaurantSession>()) return null;
    final profile = Get.find<RestaurantSession>().profile.value;
    if (profile == null) return null;
    final name = profile.name?.trim();
    final displayName = (name != null && name.isNotEmpty)
        ? name
        : profile.email.trim();
    if (displayName.isEmpty) return null;
    return (userId: profile.uid, userName: displayName);
  }

  /// Logs an action without blocking the caller on failure.
  void log({
    required String action,
    String? tableName,
    String? tableDocId,
    String? details,
    String? source,
    List<Map<String, dynamic>>? items,
  }) {
    unawaited(
      _write(
        action: action,
        tableName: tableName,
        tableDocId: tableDocId,
        details: details,
        source: source,
        items: items,
      ),
    );
  }

  Future<void> _write({
    required String action,
    String? tableName,
    String? tableDocId,
    String? details,
    String? source,
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final actor = currentActor();
      await _repository.createLog(
        action: action,
        userName: actor?.userName ?? 'Unknown',
        userId: actor?.userId,
        tableName: tableName,
        tableDocId: tableDocId,
        details: details,
        source: source,
        items: items,
      );
    } catch (_) {
      // Audit logging must not break delete flows.
    }
  }

  void logDeleteItems({
    required String? tableName,
    required String tableDocId,
    required List<Map<String, dynamic>> items,
    String source = 'order_items',
  }) {
    if (items.isEmpty) return;
    log(
      action: ActivityLogActions.deleteItems,
      tableName: tableName,
      tableDocId: tableDocId,
      items: items,
      source: source,
      details: items.length == 1
          ? items.first['name']?.toString()
          : '${items.length} items deleted',
    );
  }

  void logDeleteMenuItems({
    required String tableName,
    String? tableDocId,
    required List<Map<String, dynamic>> items,
    required bool isTakeAway,
  }) {
    log(
      action: ActivityLogActions.deleteMenuItems,
      tableName: tableName,
      tableDocId: tableDocId,
      items: items,
      source: 'menu_page',
      details: isTakeAway
          ? 'Take away order deleted'
          : 'Table items cleared',
    );
  }

  void logDeleteTable({
    required String tableName,
    required String tableDocId,
  }) {
    log(
      action: ActivityLogActions.deleteTable,
      tableName: tableName,
      tableDocId: tableDocId,
      source: 'add_table_page',
      details: 'Table deleted',
    );
  }
}
