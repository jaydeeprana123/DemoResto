/// Helpers for menu item in-stock / out-of-stock status.
class MenuStockUtils {
  /// Default is in stock when field is missing.
  static bool isInStock(Map<String, dynamic>? data) => data?['inStock'] != false;

  static bool isInStockFromItem(Map<String, dynamic> item) => item['inStock'] != false;
}
