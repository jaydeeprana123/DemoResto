import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Helpers for delayed / future takeaway orders.
class FutureOrderUtils {
  FutureOrderUtils._();

  /// Minutes before [scheduledAt] when the order becomes visible in kitchen.
  static const int kitchenLeadMinutes = 10;

  static DateTime? parseScheduledAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static bool isFutureOrderFlag(dynamic value) => value == true;

  /// True when the order should appear in [KitchenOrdersListView].
  static bool isKitchenVisible({
    required bool isFutureOrder,
    DateTime? scheduledAt,
    DateTime? now,
  }) {
    if (!isFutureOrder || scheduledAt == null) return true;
    final current = now ?? DateTime.now();
    return !current.isBefore(
      scheduledAt.subtract(const Duration(minutes: kitchenLeadMinutes)),
    );
  }

  static String formatScheduledTime(DateTime scheduledAt) {
    return DateFormat('hh:mm a').format(scheduledAt);
  }

  static String scheduledLabel(DateTime scheduledAt) {
    return 'Future Order • ${formatScheduledTime(scheduledAt)}';
  }
}
