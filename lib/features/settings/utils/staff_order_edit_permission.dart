import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/services/restaurant_session.dart';
import 'package:get/get.dart';

/// Shared Staff edit/delete time-limit checks for Table Dashboard and Menu Page.
///
/// Admins are never restricted. A limit of `0` means Staff have no time
/// restriction. The window is measured from the latest order group's `addedAt`.
class StaffOrderEditPermission {
  const StaffOrderEditPermission._();

  static RestaurantSession get _session => Get.find<RestaurantSession>();

  static bool get isAdmin => _session.profile.value?.isAdmin ?? false;

  /// Minutes Staff may edit/delete after the latest order was placed.
  /// `0` = no restriction.
  static int get limitMinutes =>
      _session.activeRestaurant.value?.staffEditDeleteLimitMinutes ?? 0;

  static DateTime? parseAddedAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  /// Latest `addedAt` among [items], or null if none are present.
  static DateTime? latestAddedAtFromItems(
    Iterable<Map<String, dynamic>> items,
  ) {
    DateTime? latest;
    for (final item in items) {
      final at = parseAddedAt(item['addedAt']);
      if (at == null) continue;
      if (latest == null || at.isAfter(latest)) latest = at;
    }
    return latest;
  }

  static bool canModify({DateTime? addedAt}) {
    if (isAdmin) return true;
    final limit = limitMinutes;
    if (limit <= 0) return true;
    if (addedAt == null) return true;
    return DateTime.now().difference(addedAt) <= Duration(minutes: limit);
  }

  /// Whether Staff may still edit/delete the latest order group on a table.
  static bool canModifyLatestGroup(List<List<Map<String, dynamic>>> groups) {
    if (groups.isEmpty || groups.last.isEmpty) return true;
    return canModify(addedAt: parseAddedAt(groups.last.first['addedAt']));
  }

  /// Whether Staff may still edit/delete based on items currently on screen
  /// (Menu Page edit / clear flows).
  static bool canModifyItems(Iterable<Map<String, dynamic>> items) {
    return canModify(addedAt: latestAddedAtFromItems(items));
  }
}
