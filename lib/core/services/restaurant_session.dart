import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartKitchen/core/firestore/firestore_paths.dart';
import 'package:smartKitchen/core/models/restaurant.dart';
import 'package:smartKitchen/core/models/user_profile.dart';
import 'package:smartKitchen/core/services/restaurant_print_profile_service.dart';
import 'package:smartKitchen/core/repositories/user_repository.dart';
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

  /// When true, reads/writes use legacy root collections (pre-migration data).
  bool useLegacyCollections = false;

  String get scopedRestaurantId =>
      profile.value?.restaurantId ?? FirestorePaths.legacyRestaurantId;

  bool get isSuperAdmin => profile.value?.isSuperAdmin ?? false;
  bool get isRestaurantUser => profile.value?.isRestaurantUser ?? false;

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
      if (profile.value!.restaurantId != null) {
        await _loadRestaurant(profile.value!.restaurantId!);
      }
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

  Future<void> _loadRestaurant(String restaurantId) async {
    final doc = await FirestorePaths.restaurant(restaurantId).get();
    if (!doc.exists) return;

    var restaurant = Restaurant.fromFirestore(restaurantId, doc.data()!);
    restaurant = await _syncSubscriptionStatus(restaurant);
    activeRestaurant.value = restaurant;

    if (Get.isRegistered<RestaurantPrintProfileService>()) {
      await Get.find<RestaurantPrintProfileService>().loadFromRestaurant(
        restaurant,
      );
    }
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
    final restaurantId = profile.value?.restaurantId;
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
    useLegacyCollections = false;
    if (Get.isRegistered<RestaurantPrintProfileService>()) {
      Get.find<RestaurantPrintProfileService>().clear();
    }
  }
}
