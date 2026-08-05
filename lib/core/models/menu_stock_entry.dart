import 'package:smartKitchen/features/menu_setup/utils/menu_stock_utils.dart';

class MenuStockEntry {
  const MenuStockEntry({
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.inStock,
    required this.firestoreTargetKeys,
    this.hasVariants = false,
    this.stockMode = MenuStockUtils.modeManual,
    this.nextStockTime,
  });

  final String categoryId;
  final String categoryName;
  final String name;
  final bool inStock;
  /// One or more Firestore docs to update (`categoryId|itemId`).
  final List<String> firestoreTargetKeys;
  final bool hasVariants;
  final String stockMode;
  final DateTime? nextStockTime;

  bool get isAutoOut =>
      !inStock &&
      stockMode == MenuStockUtils.modeAuto &&
      nextStockTime != null;

  String get key => firestoreTargetKeys.join('~');
}
