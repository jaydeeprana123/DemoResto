import 'package:cloud_firestore/cloud_firestore.dart';

/// Helpers for menu item in-stock / out-of-stock status.
class MenuStockUtils {
  MenuStockUtils._();

  static const modeManual = 'manual';
  static const modeAuto = 'auto';

  /// Default is in stock when field is missing.
  static bool isInStock(Map<String, dynamic>? data) => data?['inStock'] != false;

  static bool isInStockFromItem(Map<String, dynamic> item) =>
      item['inStock'] != false;

  static String stockModeFrom(Map<String, dynamic>? data) {
    final mode = data?['stockMode']?.toString().trim().toLowerCase();
    if (mode == modeAuto) return modeAuto;
    return modeManual;
  }

  static bool isAutoStockMode(Map<String, dynamic>? data) =>
      stockModeFrom(data) == modeAuto;

  static DateTime? nextStockTimeFrom(Map<String, dynamic>? data) {
    final value = data?['nextStockTime'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
