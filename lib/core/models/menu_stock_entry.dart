class MenuStockEntry {
  const MenuStockEntry({
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.inStock,
    required this.firestoreTargetKeys,
    this.hasVariants = false,
  });

  final String categoryId;
  final String categoryName;
  final String name;
  final bool inStock;
  /// One or more Firestore docs to update (`categoryId|itemId`).
  final List<String> firestoreTargetKeys;
  final bool hasVariants;

  String get key => firestoreTargetKeys.join('~');
}
