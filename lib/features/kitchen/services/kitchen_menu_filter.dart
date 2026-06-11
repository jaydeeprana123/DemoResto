import 'package:demo/features/menu_setup/services/menu_cache_service.dart';

/// Resolves kitchen order lines against menu category/item filters.
class KitchenMenuFilter {
  KitchenMenuFilter(this._menuCache);

  final MenuCacheService _menuCache;

  Map<String, String>? _categoryIdToName;
  Map<String, String>? _itemIdToCategoryName;
  Map<String, Set<String>>? _menuNamesByCategory;
  Map<String, String>? _menuNameToCategory;

  void invalidate() {
    _categoryIdToName = null;
    _itemIdToCategoryName = null;
    _menuNamesByCategory = null;
    _menuNameToCategory = null;
  }

  void _ensureIndexes() {
    if (_categoryIdToName != null) return;

    _categoryIdToName = {};
    _itemIdToCategoryName = {};
    _menuNamesByCategory = {};
    _menuNameToCategory = {};

    for (final item in _menuCache.menu) {
      final category = item['category']?.toString().trim() ?? '';
      final name = item['name']?.toString().trim() ?? '';
      final categoryId = item['categoryId']?.toString().trim() ?? '';
      final itemId = item['itemId']?.toString().trim() ?? '';

      if (category.isNotEmpty && categoryId.isNotEmpty) {
        _categoryIdToName![categoryId] = category;
      }
      if (category.isNotEmpty && name.isNotEmpty) {
        _menuNamesByCategory!.putIfAbsent(category, () => {}).add(name);
        _menuNameToCategory![_normalizeName(name)] = category;
      }
      if (categoryId.isNotEmpty && itemId.isNotEmpty && category.isNotEmpty) {
        _itemIdToCategoryName!['$categoryId|$itemId'] = category;
      }
    }
  }

  static String filterKey(String category, String itemName) =>
      '$category|$itemName';

  bool hasActiveFilter({
    required bool showAllCategories,
    required Set<String> selectedCategories,
    required Set<String> selectedMenuItems,
  }) {
    if (showAllCategories) return false;
    return selectedCategories.isNotEmpty || selectedMenuItems.isNotEmpty;
  }

  bool matchesOrderItem({
    required Map<String, dynamic> item,
    required bool showAllCategories,
    required Set<String> selectedCategories,
    required Set<String> selectedMenuItems,
    required bool categoryOnlyMode,
  }) {
    if (!hasActiveFilter(
      showAllCategories: showAllCategories,
      selectedCategories: selectedCategories,
      selectedMenuItems: selectedMenuItems,
    )) {
      return true;
    }

    _ensureIndexes();

    final category = resolveCategoryName(item);
    final itemName = item['name']?.toString().trim() ?? '';
    if (category.isEmpty || itemName.isEmpty) {
      return false;
    }

    if (categoryOnlyMode) {
      return selectedCategories.contains(category);
    }

    if (selectedCategories.contains(category)) {
      final hasSpecificItems =
          selectedMenuItems.any((key) => key.startsWith('$category|'));
      if (!hasSpecificItems) {
        return true;
      }
    }

    if (!selectedCategories.contains(category) &&
        !selectedMenuItems.any((key) => key.startsWith('$category|'))) {
      return false;
    }

    if (selectedMenuItems.contains(filterKey(category, itemName))) {
      return true;
    }

    final categoryId = item['categoryId']?.toString().trim() ?? '';
    final itemId = item['itemId']?.toString().trim() ?? '';
    if (categoryId.isNotEmpty && itemId.isNotEmpty) {
      for (final selectedKey in selectedMenuItems) {
        final parts = selectedKey.split('|');
        if (parts.length != 2) continue;
        final selectedCategory = parts[0];
        final selectedName = parts[1];
        if (selectedCategory != category) continue;

        final menuItem = _findMenuItem(selectedCategory, selectedName);
        if (menuItem == null) continue;

        final menuCategoryId = menuItem['categoryId']?.toString().trim() ?? '';
        final menuItemId = menuItem['itemId']?.toString().trim() ?? '';
        if (menuCategoryId == categoryId && menuItemId == itemId) {
          return true;
        }
      }
    }

    for (final selectedKey in selectedMenuItems) {
      if (_orderNameMatchesSelectedKey(
        orderName: itemName,
        selectedKey: selectedKey,
      )) {
        return true;
      }
    }

    return false;
  }

  String resolveCategoryName(Map<String, dynamic> item) {
    _ensureIndexes();

    final direct = item['category']?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;

    final categoryId = item['categoryId']?.toString().trim() ?? '';
    if (categoryId.isNotEmpty) {
      final fromId = _categoryIdToName![categoryId];
      if (fromId != null && fromId.isNotEmpty) return fromId;
    }

    final itemId = item['itemId']?.toString().trim() ?? '';
    if (categoryId.isNotEmpty && itemId.isNotEmpty) {
      final fromPair = _itemIdToCategoryName!['$categoryId|$itemId'];
      if (fromPair != null && fromPair.isNotEmpty) return fromPair;
    }

    final itemName = item['name']?.toString().trim() ?? '';
    if (itemName.isNotEmpty) {
      final fromName = _menuNameToCategory![_normalizeName(itemName)];
      if (fromName != null && fromName.isNotEmpty) return fromName;

      final baseName = _baseItemName(itemName);
      if (baseName != itemName) {
        final fromBase = _menuNameToCategory![_normalizeName(baseName)];
        if (fromBase != null && fromBase.isNotEmpty) return fromBase;
      }
    }

    return '';
  }

  Map<String, dynamic>? _findMenuItem(String category, String itemName) {
    for (final item in _menuCache.menu) {
      if (item['category']?.toString() != category) continue;
      if (item['name']?.toString() == itemName) {
        return item;
      }
    }
    return null;
  }

  bool _orderNameMatchesSelectedKey({
    required String orderName,
    required String selectedKey,
  }) {
    final parts = selectedKey.split('|');
    if (parts.length != 2) return false;
    final selectedCategory = parts[0];
    final selectedName = parts[1];
    final normalizedOrder = _normalizeName(orderName);
    final normalizedSelected = _normalizeName(selectedName);

    if (normalizedOrder == normalizedSelected) return true;

    final baseOrder = _normalizeName(_baseItemName(orderName));
    if (baseOrder == normalizedSelected) return true;

    if (normalizedOrder.startsWith('$normalizedSelected (')) return true;
    if (normalizedOrder.startsWith('$baseOrder (')) return true;

    return false;
  }

  static String _baseItemName(String name) {
    final match = RegExp(r'^(.+)\s+\((Half|Full)\)$', caseSensitive: false)
        .firstMatch(name.trim());
    return match?.group(1)?.trim() ?? name.trim();
  }

  static String _normalizeName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
