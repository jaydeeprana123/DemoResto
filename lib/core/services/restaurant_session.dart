import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartKitchen/core/firestore/firestore_paths.dart';
import 'package:smartKitchen/core/models/restaurant.dart';
import 'package:smartKitchen/core/models/user_profile.dart';
import 'package:smartKitchen/core/services/restaurant_print_profile_service.dart';
import 'package:smartKitchen/core/repositories/user_repository.dart';
import 'package:smartKitchen/features/menu_setup/services/menu_cache_service.dart';
import 'package:smartKitchen/features/menu_setup/services/menu_sync_coordinator.dart';
import 'package:smartKitchen/features/settings/controllers/stock_controller.dart';
import 'package:smartKitchen/features/tables/services/shared_tables_snapshot_service.dart';
import 'package:smartKitchen/features/zomato/services/imagekit_settings.dart';
import 'package:get/get.dart';

class RestaurantAccessInfo {
  const RestaurantAccessInfo({
    required this.allowed,
    this.restaurant,
    this.message,
    this.showExpiryWarning = false,
    this.daysUntilExpiry,
  });

  final bool allowed;
  final Restaurant? restaurant;
  final String? message;
  final bool showExpiryWarning;
  final int? daysUntilExpiry;
}

class RestaurantSession extends GetxService {
  RestaurantSession(this._userRepository);

  final UserRepository _userRepository;

  final profile = Rxn<UserProfile>();
  final activeRestaurant = Rxn<Restaurant>();
  final assignedRestaurants = <Restaurant>[].obs;
  final isSwitchingRestaurant = false.obs;

  /// Bumped after a successful restaurant switch so live screens rebuild
  /// and subscribe to the selected restaurant only.
  final scopeVersion = 0.obs;

  /// When true, reads/writes use legacy root collections (pre-migration data).
  bool useLegacyCollections = false;

  String? _selectedRestaurantId;
  bool _primaryUsesLegacy = false;

  /// Null for single-restaurant accounts, which keep using [UserProfile.restaurantId].
  String? get selectedRestaurantId => _selectedRestaurantId;

  String get scopedRestaurantId {
    final selected = _selectedRestaurantId;
    if (selected != null && selected.isNotEmpty) return selected;
    return profile.value?.restaurantId ?? FirestorePaths.legacyRestaurantId;
  }

  bool get isSuperAdmin => profile.value?.isSuperAdmin ?? false;
  bool get isRestaurantUser => profile.value?.isRestaurantUser ?? false;

  bool get showRestaurantSwitcher {
    final current = profile.value;
    if (current == null || !current.isAdmin) return false;
    return current.hasMultipleRestaurants;
  }

  Future<void> loadForCurrentUser() async {
    final user = _userRepository.currentUser;
    if (user == null) {
      clear();
      return;
    }

    final doc = await FirestorePaths.user(user.uid).get();
    if (!doc.exists) {
      clear();
      return;
    }

    profile.value = UserProfile.fromFirestore(user.uid, doc.data()!);
    activeRestaurant.value = null;
    useLegacyCollections = false;

    if (profile.value!.isRestaurantUser) {
      await _detectLegacyDataPath();
      _primaryUsesLegacy = useLegacyCollections;
      if (profile.value!.restaurantId != null) {
        await _loadRestaurant(profile.value!.restaurantId!);
      }
      await _refreshAssignedRestaurants();
    }
  }

  /// Switches the active restaurant for an admin assigned to more than one.
  /// Stops live listeners for the previous restaurant before the UI reloads.
  Future<String?> switchRestaurant(String restaurantId) async {
    final currentProfile = profile.value;
    if (currentProfile == null || !currentProfile.isAdmin) {
      return 'Only an admin can switch restaurants.';
    }
    if (!currentProfile.managesRestaurant(restaurantId)) {
      return 'You are not assigned to this restaurant.';
    }
    if (restaurantId == scopedRestaurantId || isSwitchingRestaurant.value) {
      return null;
    }

    final previousSelected = _selectedRestaurantId;
    final previousLegacy = useLegacyCollections;
    final previousRestaurant = activeRestaurant.value;

    isSwitchingRestaurant.value = true;
    var applied = false;
    try {
      final candidate = await _fetchRestaurant(restaurantId);
      if (candidate == null) return 'Restaurant record not found.';

      final blocked = _unavailableMessage(candidate);
      if (blocked != null) return blocked;

      _pauseScopedListeners();
      _clearTransientRestaurantState();
      _selectedRestaurantId = restaurantId;
      useLegacyCollections = restaurantId == currentProfile.restaurantId
          ? _primaryUsesLegacy
          : false;
      activeRestaurant.value = candidate;
      _upsertAssignedRestaurant(candidate);
      // Rebuild immediately so the previous screens dispose before any write
      // can use the new restaurant scope.
      scopeVersion.value++;
      applied = true;

      await _loadPrintProfile(candidate);
      await _rebindMenuCache();
      return null;
    } catch (e) {
      if (applied) {
        await _restoreSelection(
          selectedId: previousSelected,
          useLegacy: previousLegacy,
          restaurant: previousRestaurant,
        );
      }
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      isSwitchingRestaurant.value = false;
    }
  }

  String? _unavailableMessage(Restaurant restaurant) {
    if (restaurant.status == RestaurantStatus.deactivated) {
      return 'This restaurant has been deactivated. Please contact Super Admin.';
    }
    if (restaurant.status == RestaurantStatus.expired) {
      return 'Your subscription has expired. Please contact Super Admin.';
    }
    return null;
  }

  Future<void> _restoreSelection({
    required String? selectedId,
    required bool useLegacy,
    required Restaurant? restaurant,
  }) async {
    _pauseScopedListeners();
    _selectedRestaurantId = selectedId;
    useLegacyCollections = useLegacy;
    activeRestaurant.value = restaurant;
    if (restaurant != null) {
      _upsertAssignedRestaurant(restaurant);
    }
    scopeVersion.value++;
    if (restaurant != null) {
      await _loadPrintProfile(restaurant);
    } else if (Get.isRegistered<RestaurantPrintProfileService>()) {
      Get.find<RestaurantPrintProfileService>().clear();
    }
    if (Get.isRegistered<MenuCacheService>()) {
      await Get.find<MenuCacheService>().rebindToCurrentRestaurant();
    }
  }

  void _pauseScopedListeners() {
    if (Get.isRegistered<SharedTablesSnapshotService>()) {
      Get.find<SharedTablesSnapshotService>().pauseForRestaurantSwitch();
    }
    if (Get.isRegistered<MenuCacheService>()) {
      Get.find<MenuCacheService>().pauseAutoSync();
    }
  }

  Future<void> _rebindMenuCache() async {
    ImageKitSettings.clearCache();
    if (Get.isRegistered<MenuCacheService>()) {
      await Get.find<MenuCacheService>().rebindToCurrentRestaurant();
    }
    if (Get.isRegistered<MenuSyncCoordinator>()) {
      await Get.find<MenuSyncCoordinator>().onRestaurantChanged();
    }
  }

  void _clearTransientRestaurantState() {
    if (Get.isRegistered<StockController>()) {
      Get.find<StockController>().selectedKeys.clear();
    }
  }

  Future<void> _detectLegacyDataPath() async {
    final rid = scopedRestaurantId;
    final nestedTables = await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(rid)
        .collection('tables')
        .limit(1)
        .get();
    final legacyTables =
        await FirebaseFirestore.instance.collection('tables').limit(1).get();

    if (nestedTables.docs.isEmpty && legacyTables.docs.isNotEmpty) {
      useLegacyCollections = true;
    }
  }

  Future<Restaurant?> _fetchRestaurant(String restaurantId) async {
    final doc = await FirestorePaths.restaurant(restaurantId).get();
    if (!doc.exists) return null;

    var restaurant = Restaurant.fromFirestore(restaurantId, doc.data()!);
    return _syncSubscriptionStatus(restaurant);
  }

  Future<void> _loadPrintProfile(Restaurant restaurant) async {
    if (!Get.isRegistered<RestaurantPrintProfileService>()) return;
    await Get.find<RestaurantPrintProfileService>().loadFromRestaurant(
      restaurant,
    );
  }

  Future<bool> _loadRestaurant(String restaurantId) async {
    final restaurant = await _fetchRestaurant(restaurantId);
    if (restaurant == null) {
      activeRestaurant.value = null;
      return false;
    }

    activeRestaurant.value = restaurant;
    _upsertAssignedRestaurant(restaurant);
    await _loadPrintProfile(restaurant);
    return true;
  }

  Future<void> _refreshAssignedRestaurants() async {
    final ids = profile.value?.assignedRestaurantIds ?? const <String>[];
    if (ids.length <= 1) {
      final current = activeRestaurant.value;
      assignedRestaurants.assignAll(current == null ? const [] : [current]);
      return;
    }

    final loaded = <Restaurant>[];
    for (final id in ids) {
      if (activeRestaurant.value?.id == id) {
        loaded.add(activeRestaurant.value!);
        continue;
      }
      final doc = await FirestorePaths.restaurant(id).get();
      if (!doc.exists) continue;
      var restaurant = Restaurant.fromFirestore(id, doc.data()!);
      restaurant = await _syncSubscriptionStatus(restaurant);
      loaded.add(restaurant);
    }
    assignedRestaurants.assignAll(loaded);
  }

  void _upsertAssignedRestaurant(Restaurant restaurant) {
    final next = List<Restaurant>.from(assignedRestaurants);
    final index = next.indexWhere((item) => item.id == restaurant.id);
    if (index >= 0) {
      next[index] = restaurant;
    } else if ((profile.value?.assignedRestaurantIds.length ?? 0) > 1) {
      next.add(restaurant);
    } else {
      assignedRestaurants.assignAll([restaurant]);
      return;
    }
    assignedRestaurants.assignAll(next);
  }

  Future<Restaurant> _syncSubscriptionStatus(Restaurant restaurant) async {
    if (restaurant.status == RestaurantStatus.deactivated) {
      return restaurant;
    }

    if (DateTime.now().isAfter(restaurant.subscriptionEnd)) {
      if (restaurant.status != RestaurantStatus.expired) {
        await FirestorePaths.restaurant(restaurant.id).update({
          'status': RestaurantStatus.expired.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return restaurant.copyWith(status: RestaurantStatus.expired);
    }

    return restaurant;
  }

  Future<void> reloadRestaurant() async {
    final selected = _selectedRestaurantId;
    final restaurantId = (selected != null && selected.isNotEmpty)
        ? selected
        : profile.value?.restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) return;
    await _loadRestaurant(restaurantId);
  }

  RestaurantAccessInfo evaluateAccess() {
    if (profile.value == null) {
      return const RestaurantAccessInfo(
        allowed: false,
        message:
            'Your account is not set up. Contact Super Admin or Restaurant Admin.',
      );
    }

    if (isSuperAdmin) {
      return const RestaurantAccessInfo(allowed: true);
    }

    if (!isRestaurantUser) {
      return const RestaurantAccessInfo(
        allowed: false,
        message: 'Your account role is not authorized for this app.',
      );
    }

    if (profile.value!.active == false) {
      return const RestaurantAccessInfo(
        allowed: false,
        message:
            'Your account has been deactivated. Contact your restaurant admin.',
      );
    }

    final restaurantId = profile.value?.restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      if (useLegacyCollections) {
        return const RestaurantAccessInfo(allowed: true);
      }
      return const RestaurantAccessInfo(
        allowed: false,
        message:
            'No restaurant is linked to your account. Contact Super Admin.',
      );
    }

    final restaurant = activeRestaurant.value;
    if (restaurant == null) {
      if (useLegacyCollections) {
        return const RestaurantAccessInfo(allowed: true);
      }
      return const RestaurantAccessInfo(
        allowed: false,
        message: 'Restaurant record not found.',
      );
    }

    if (restaurant.status == RestaurantStatus.deactivated) {
      return RestaurantAccessInfo(
        allowed: false,
        restaurant: restaurant,
        message:
            'This restaurant has been deactivated. Please contact Super Admin.',
      );
    }

    if (restaurant.status == RestaurantStatus.expired) {
      return RestaurantAccessInfo(
        allowed: false,
        restaurant: restaurant,
        message: 'Your subscription has expired. Please contact Super Admin.',
      );
    }

    if (restaurant.isExpiringSoon) {
      return RestaurantAccessInfo(
        allowed: true,
        restaurant: restaurant,
        showExpiryWarning: true,
        daysUntilExpiry: restaurant.daysUntilExpiry,
        message:
            'Subscription expires in ${restaurant.daysUntilExpiry} day(s).',
      );
    }

    return RestaurantAccessInfo(allowed: true, restaurant: restaurant);
  }

  void clear() {
    profile.value = null;
    activeRestaurant.value = null;
    assignedRestaurants.clear();
    _selectedRestaurantId = null;
    _primaryUsesLegacy = false;
    useLegacyCollections = false;
    isSwitchingRestaurant.value = false;
    if (Get.isRegistered<RestaurantPrintProfileService>()) {
      Get.find<RestaurantPrintProfileService>().clear();
    }
  }
}
