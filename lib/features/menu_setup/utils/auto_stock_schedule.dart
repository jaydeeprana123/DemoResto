import 'package:cloud_firestore/cloud_firestore.dart';

/// Default auto restock schedule helpers.
class AutoStockSchedule {
  AutoStockSchedule._();

  static const defaultHour = 15;
  static const defaultMinute = 0;

  /// Next occurrence of 3:00 PM local time (today if still ahead, else tomorrow).
  static DateTime defaultNextRestockLocal({
    int hour = defaultHour,
    int minute = defaultMinute,
  }) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!now.isBefore(next)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  static Timestamp toTimestamp(DateTime local) {
    return Timestamp.fromDate(local);
  }
}
