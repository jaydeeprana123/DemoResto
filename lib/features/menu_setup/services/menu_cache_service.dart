import 'dart:convert';

import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/core/services/restaurant_session.dart';
import 'package:demo/features/menu_setup/utils/menu_sort_utils.dart';
import 'package:demo/features/menu_setup/utils/menu_stock_utils.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Caches menu locally so Dashboard/Kitchen do not refetch on every open.
class MenuCacheService {
  static const _cacheKeyPrefix = 'menu_cache_v1_';

  List<Map<String, dynamic>> _menu = [];
  String? _loadedRestaurantKey;

  List<Map<String, dynamic>> get menu => List.unmodifiable(_menu);

  bool get hasCache => _menu.isNotEmpty;

  String _restaurantCacheKey() {
    final session = Get.find<RestaurantSession>();
    if (session.useLegacyCollections) {
      return '${FirestorePaths.legacyRestaurantId}_legacy';
    }
    return session.scopedRestaurantId;
  }

  String _prefsKeyFor(String restaurantKey) => '$_cacheKeyPrefix$restaurantKey';

  Future<void> _ensureRestaurantLoaded() async {
    final restaurantKey = _restaurantCacheKey();
    if (_loadedRestaurantKey == restaurantKey && _menu.isNotEmpty) {
      return;
    }

    _loadedRestaurantKey = restaurantKey;
    _menu = await _readFromDisk(restaurantKey);
  }

  Future<List<Map<String, dynamic>>> loadFromCacheOnly() async {
    await _ensureRestaurantLoaded();
    return List<Map<String, dynamic>>.from(_menu);
  }

  /// Reads cache first; fetches from Firestore only when cache is empty.
  Future<List<Map<String, dynamic>>> ensureLoaded() async {
    await _ensureRestaurantLoaded();
    if (_menu.isNotEmpty) {
      return List<Map<String, dynamic>>.from(_menu);
    }
    return refreshFromNetwork();
  }

  Future<List<Map<String, dynamic>>> refreshFromNetwork() async {
    final restaurantKey = _restaurantCacheKey();
    final loadedMenu = await _fetchFromFirestore();
    _menu = loadedMenu;
    _loadedRestaurantKey = restaurantKey;
    await _writeToDisk(restaurantKey, loadedMenu);
    return List<Map<String, dynamic>>.from(_menu);
  }

  List<String> getCategoryNamesSorted() {
    final categoryOrder = <String, int>{};
    for (final item in _menu) {
      final category = item['category']?.toString() ?? '';
      if (category.isEmpty) continue;
      final order = item['categorySortOrder'] as int? ?? 9999;
      categoryOrder.putIfAbsent(category, () => order);
    }

    final names = categoryOrder.keys.toList()
      ..sort((a, b) {
        final orderCompare = categoryOrder[a]!.compareTo(categoryOrder[b]!);
        if (orderCompare != 0) return orderCompare;
        return a.compareTo(b);
      });
    return names;
  }

  Map<String, List<String>> getItemsByCategoryMap() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in _menu) {
      final category = item['category']?.toString() ?? '';
      final name = item['name']?.toString() ?? '';
      if (category.isEmpty || name.isEmpty) continue;
      grouped.putIfAbsent(category, () => []).add(item);
    }

    final result = <String, List<String>>{};
    for (final entry in grouped.entries) {
      final sortedItems = List<Map<String, dynamic>>.from(entry.value)
        ..sort(
          (a, b) => (a['itemSortOrder'] as int? ?? 9999).compareTo(
            b['itemSortOrder'] as int? ?? 9999,
          ),
        );
      result[entry.key] = sortedItems
          .map((item) => item['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _fetchFromFirestore() async {
    final loadedMenu = <Map<String, dynamic>>[];
    final menuSnapshot = await FirestorePaths.scoped('menus').get();
    final categoryDocs = sortMenuDocs(menuSnapshot.docs);

    for (final categoryDoc in categoryDocs) {
      final categoryId = categoryDoc.id;
      final categoryName = categoryDoc.data()['name']?.toString() ?? '';
      if (categoryName.isEmpty) continue;

      final categorySortOrder =
          (categoryDoc.data()['sortOrder'] as num?)?.toInt() ?? 9999;

      final itemsSnapshot = await FirestorePaths.scopedSubCollection(
        'menus',
        categoryId,
        'items',
      ).get();

      for (final itemDoc in sortMenuDocs(itemsSnapshot.docs)) {
        final data = itemDoc.data();
        final itemSortOrder = (data['sortOrder'] as num?)?.toInt() ?? 9999;
        loadedMenu.add({
          'category': categoryName,
          'name': data['name'],
          'price': data['price'],
          if (data.containsKey('halfPrice')) 'halfPrice': data['halfPrice'],
          if (data.containsKey('fullPrice')) 'fullPrice': data['fullPrice'],
          'categoryId': categoryId,
          'itemId': itemDoc.id,
          'categorySortOrder': categorySortOrder,
          'itemSortOrder': itemSortOrder,
          'inStock': MenuStockUtils.isInStock(data),
          'qty': 1,
        });
      }
    }

    return loadedMenu;
  }

  Future<List<Map<String, dynamic>>> _readFromDisk(String restaurantKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKeyFor(restaurantKey));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeToDisk(
    String restaurantKey,
    List<Map<String, dynamic>> menu,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyFor(restaurantKey), jsonEncode(menu));
  }
}
