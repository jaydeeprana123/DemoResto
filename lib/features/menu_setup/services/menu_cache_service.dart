import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartKitchen/core/firestore/firestore_paths.dart';
import 'package:smartKitchen/core/services/restaurant_session.dart';
import 'package:smartKitchen/features/menu_setup/services/menu_revision.dart';
import 'package:smartKitchen/features/menu_setup/utils/menu_sort_utils.dart';
import 'package:smartKitchen/features/menu_setup/utils/menu_stock_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Caches menu locally so Dashboard/Kitchen do not refetch on every open.
class MenuCacheService {
  static const _cacheKeyPrefix = 'menu_cache_v1_';

  List<Map<String, dynamic>> _menu = [];
  String? _loadedRestaurantKey;
  int? _lastSyncedRevision;
  bool _syncInProgress = false;
  bool _autoSyncActive = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _metaSubscription;
  Timer? _revisionDebounce;

  /// Bumped whenever cached menu content changes after a network sync.
  final ValueNotifier<int> revisionListenable = ValueNotifier<int>(0);

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

  String _revisionPrefsKeyFor(String restaurantKey) =>
      '${MenuRevision.prefsKeyPrefix}$restaurantKey';

  Future<void> _ensureRestaurantLoaded() async {
    final restaurantKey = _restaurantCacheKey();
    if (_loadedRestaurantKey == restaurantKey && _menu.isNotEmpty) {
      return;
    }

    _loadedRestaurantKey = restaurantKey;
    _menu = await _readFromDisk(restaurantKey);
    _lastSyncedRevision = await _readRevisionFromDisk(restaurantKey);
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

  /// Phase 2 entry: load cache, check revision, listen for remote changes.
  Future<void> startAutoSync() async {
    if (_autoSyncActive) {
      await syncIfChanged();
      return;
    }

    _autoSyncActive = true;
    await loadFromCacheOnly();
    await syncIfChanged();
    _startMetaListener();
  }

  void pauseAutoSync() {
    _revisionDebounce?.cancel();
    _metaSubscription?.cancel();
    _metaSubscription = null;
  }

  Future<void> resumeAutoSync() async {
    if (!_autoSyncActive) return;
    await syncIfChanged();
    _startMetaListener();
  }

  void stopAutoSync() {
    _autoSyncActive = false;
    pauseAutoSync();
  }

  void resetForLogout() {
    stopAutoSync();
    _menu = [];
    _loadedRestaurantKey = null;
    _lastSyncedRevision = null;
    revisionListenable.value = 0;
  }

  /// Returns true when menu data was refreshed from Firestore.
  Future<bool> syncIfChanged({bool force = false}) async {
    if (_syncInProgress) return false;

    _syncInProgress = true;
    try {
      final restaurantKey = _restaurantCacheKey();
      await _ensureRestaurantLoaded();
      final localRevision =
          _lastSyncedRevision ?? await _readRevisionFromDisk(restaurantKey);
      final remoteRevision = await MenuRevision.readRemoteRevision();

      final needsFetch =
          force || _menu.isEmpty || remoteRevision != localRevision;
      if (!needsFetch) return false;

      await _fetchSaveAndNotify(restaurantKey, remoteRevision);
      return true;
    } catch (_) {
      return false;
    } finally {
      _syncInProgress = false;
    }
  }

  Future<List<Map<String, dynamic>>> refreshFromNetwork() async {
    final restaurantKey = _restaurantCacheKey();
    final remoteRevision = await MenuRevision.readRemoteRevision();
    await _fetchSaveAndNotify(restaurantKey, remoteRevision);
    return List<Map<String, dynamic>>.from(_menu);
  }

  Future<void> _fetchSaveAndNotify(
    String restaurantKey,
    int remoteRevision,
  ) async {
    final loadedMenu = await _fetchFromFirestore();
    _menu = loadedMenu;
    _loadedRestaurantKey = restaurantKey;
    _lastSyncedRevision = remoteRevision;
    await _writeToDisk(restaurantKey, loadedMenu);
    await _writeRevisionToDisk(restaurantKey, remoteRevision);
    revisionListenable.value++;
  }

  void _startMetaListener() {
    if (!_autoSyncActive || _metaSubscription != null) return;

    _metaSubscription = MenuRevision.metaRef().snapshots().listen(
      (snapshot) {
        final remote = MenuRevision.revisionFromSnapshot(snapshot);
        _scheduleRevisionReaction(remote);
      },
      onError: (_) {},
    );
  }

  void _scheduleRevisionReaction(int remoteRevision) {
    _revisionDebounce?.cancel();
    _revisionDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_handleRemoteRevision(remoteRevision));
    });
  }

  Future<void> _handleRemoteRevision(int remoteRevision) async {
    if (!_autoSyncActive || _syncInProgress) return;

    final restaurantKey = _restaurantCacheKey();
    if (_loadedRestaurantKey != null && _loadedRestaurantKey != restaurantKey) {
      await _ensureRestaurantLoaded();
    }

    final localRevision =
        _lastSyncedRevision ?? await _readRevisionFromDisk(restaurantKey);
    if (remoteRevision == localRevision && _menu.isNotEmpty) return;

    await syncIfChanged();
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
    final categoryDocs = sortMenuDocs(
      menuSnapshot.docs
          .where((doc) => !MenuRevision.isMetaDoc(doc.id))
          .toList(),
    );

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
          if (data['variants'] is List) 'variants': data['variants'],
          if (data['includes'] != null) 'includes': data['includes'],
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

  Future<int> _readRevisionFromDisk(String restaurantKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_revisionPrefsKeyFor(restaurantKey)) ?? 0;
  }

  Future<void> _writeToDisk(
    String restaurantKey,
    List<Map<String, dynamic>> menu,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyFor(restaurantKey), jsonEncode(menu));
  }

  Future<void> _writeRevisionToDisk(
    String restaurantKey,
    int revision,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_revisionPrefsKeyFor(restaurantKey), revision);
    _lastSyncedRevision = revision;
  }
}
