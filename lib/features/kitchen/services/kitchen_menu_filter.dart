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

        _menuNameToCategory!['${_normalizeName(name)}|$categoryId'] = category;

        _menuNameToCategory!.putIfAbsent(_normalizeName(name), () => category);

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



    final categoryInFilter = selectedCategories.contains(category) ||

        _categoryHasSelectedItems(category, selectedMenuItems);

    if (!categoryInFilter) {

      return false;

    }



    if (_isPartialCategorySelection(category, selectedMenuItems)) {

      return _matchesSelectedMenuItemKeys(

        item: item,

        category: category,

        itemName: itemName,

        selectedMenuItems: _selectedKeysForCategory(category, selectedMenuItems),

      );

    }



    return true;

  }



  bool _categoryHasSelectedItems(

    String category,

    Set<String> selectedMenuItems,

  ) {

    final prefix = '$category|';

    return selectedMenuItems.any((key) => key.startsWith(prefix));

  }



  Set<String> _selectedKeysForCategory(

    String category,

    Set<String> selectedMenuItems,

  ) {

    final prefix = '$category|';

    return selectedMenuItems.where((key) => key.startsWith(prefix)).toSet();

  }



  bool _isPartialCategorySelection(

    String category,

    Set<String> selectedMenuItems,

  ) {

    final selectedCount =

        _selectedKeysForCategory(category, selectedMenuItems).length;

    if (selectedCount == 0) return false;



    final totalCount = _menuNamesByCategory![category]?.length ?? 0;

    if (totalCount == 0) return selectedCount > 0;

    return selectedCount < totalCount;

  }



  bool _matchesSelectedMenuItemKeys({

    required Map<String, dynamic> item,

    required String category,

    required String itemName,

    required Set<String> selectedMenuItems,

  }) {

    if (selectedMenuItems.isEmpty) return false;



    final exactKey = filterKey(category, itemName);

    if (selectedMenuItems.contains(exactKey)) {

      return true;

    }



    final categoryId = item['categoryId']?.toString().trim() ?? '';

    final itemId = item['itemId']?.toString().trim() ?? '';

    if (categoryId.isNotEmpty && itemId.isNotEmpty) {

      for (final selectedKey in selectedMenuItems) {

        final parts = _splitFilterKey(selectedKey);

        if (parts == null || parts.$1 != category) continue;



        final menuItem = _menuItemForSelectedKey(selectedKey);

        if (menuItem == null) continue;



        final menuCategoryId =

            menuItem['categoryId']?.toString().trim() ?? '';

        final menuItemId = menuItem['itemId']?.toString().trim() ?? '';

        if (menuCategoryId == categoryId && menuItemId == itemId) {

          return true;

        }

      }

    }



    for (final selectedKey in selectedMenuItems) {

      final parts = _splitFilterKey(selectedKey);

      if (parts == null) continue;

      final selectedCategory = parts.$1;

      final selectedName = parts.$2;



      if (selectedCategory != category) continue;

      if (_namesMatchForFilter(orderName: itemName, menuName: selectedName)) {

        return true;

      }

    }



    return false;

  }



  String resolveCategoryName(Map<String, dynamic> item) {

    _ensureIndexes();



    final direct = item['category']?.toString().trim() ?? '';

    final categoryId = item['categoryId']?.toString().trim() ?? '';

    final itemId = item['itemId']?.toString().trim() ?? '';



    if (direct.isNotEmpty) return direct;



    if (categoryId.isNotEmpty) {

      final fromId = _categoryIdToName![categoryId];

      if (fromId != null && fromId.isNotEmpty) return fromId;

    }



    if (categoryId.isNotEmpty && itemId.isNotEmpty) {

      final fromPair = _itemIdToCategoryName!['$categoryId|$itemId'];

      if (fromPair != null && fromPair.isNotEmpty) return fromPair;

    }



    final itemName = item['name']?.toString().trim() ?? '';

    if (itemName.isEmpty) return '';



    if (categoryId.isNotEmpty) {

      final scoped = _menuNameToCategory!['${_normalizeName(itemName)}|$categoryId'];

      if (scoped != null && scoped.isNotEmpty) return scoped;

    }



    final fromName = _menuNameToCategory![_normalizeName(itemName)];

    if (fromName != null && fromName.isNotEmpty) return fromName;



    final baseName = _baseItemName(itemName);

    if (baseName != itemName) {

      if (categoryId.isNotEmpty) {

        final scoped =

            _menuNameToCategory!['${_normalizeName(baseName)}|$categoryId'];

        if (scoped != null && scoped.isNotEmpty) return scoped;

      }

      final fromBase = _menuNameToCategory![_normalizeName(baseName)];

      if (fromBase != null && fromBase.isNotEmpty) return fromBase;

    }



    return '';

  }



  Map<String, dynamic>? _menuItemForSelectedKey(String selectedKey) {

    final parts = _splitFilterKey(selectedKey);

    if (parts == null) return null;

    return _findMenuItem(parts.$1, parts.$2);

  }



  (String, String)? _splitFilterKey(String selectedKey) {

    final separator = selectedKey.indexOf('|');

    if (separator <= 0 || separator >= selectedKey.length - 1) {

      return null;

    }

    return (

      selectedKey.substring(0, separator),

      selectedKey.substring(separator + 1),

    );

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



  bool _namesMatchForFilter({

    required String orderName,

    required String menuName,

  }) {

    final normalizedOrder = _normalizeName(orderName);

    final normalizedMenu = _normalizeName(menuName);



    if (normalizedOrder == normalizedMenu) return true;



    final baseOrder = _normalizeName(_baseItemName(orderName));

    final baseMenu = _normalizeName(_baseItemName(menuName));



    if (baseOrder == normalizedMenu || baseOrder == baseMenu) return true;

    if (normalizedOrder.startsWith('$normalizedMenu (')) return true;

    if (normalizedOrder.startsWith('$baseMenu (')) return true;



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


