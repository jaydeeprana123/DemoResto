import 'dart:typed_data';

import 'package:smartKitchen/core/models/restaurant.dart';
import 'package:smartKitchen/core/models/user_profile.dart';
import 'package:smartKitchen/core/repositories/user_repository.dart';
import 'package:smartKitchen/core/widgets/logout_confirmation_dialog.dart';
import 'package:smartKitchen/features/super_admin/repositories/super_admin_repository.dart';
import 'package:smartKitchen/features/super_admin/widgets/restaurant_profile_fields.dart';
import 'package:get/get.dart';

class SuperAdminController extends GetxController {
  SuperAdminController(this._repository, this._userRepository);

  final SuperAdminRepository _repository;
  final UserRepository _userRepository;

  final restaurants = <Restaurant>[].obs;
  final admins = <UserProfile>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();

  Stream<List<Restaurant>>? _restaurantsSubscription;
  Stream<List<UserProfile>>? _adminsSubscription;

  @override
  void onInit() {
    super.onInit();
    _restaurantsSubscription = _repository.watchRestaurants();
    _restaurantsSubscription!.listen(
      (list) => restaurants.assignAll(list),
      onError: (e) => errorMessage.value = e.toString(),
    );

    _adminsSubscription = _repository.watchRestaurantAdmins();
    _adminsSubscription!.listen(
      (list) => admins.assignAll(list),
      onError: (e) => errorMessage.value = e.toString(),
    );
  }

  List<UserProfile> adminsForRestaurant(String restaurantId) {
    return admins
        .where((admin) => admin.restaurantId == restaurantId)
        .toList();
  }

  String adminSummaryForRestaurant(String restaurantId) {
    final restaurantAdmins = adminsForRestaurant(restaurantId)
        .where((admin) => admin.active)
        .toList();
    if (restaurantAdmins.isEmpty) return 'None';

    return restaurantAdmins
        .map((admin) {
          final name = admin.name?.trim();
          if (name != null && name.isNotEmpty) return name;
          return admin.email;
        })
        .join(', ');
  }

  Future<String?> createRestaurant({
    required String name,
    String? address,
    required String mobile1,
    String? mobile2,
    String? mobile3,
    Uint8List? logoBytes,
    Uint8List? qrCodeBytes,
    required int subscriptionYears,
  }) async {
    final validationError = validateRestaurantForm(
      name: name,
      mobile1: mobile1,
      mobile2: mobile2,
      mobile3: mobile3,
    );
    if (validationError != null) return validationError;

    isLoading.value = true;
    try {
      final restaurantId = await _repository.createRestaurant(
        name: name,
        address: address,
        mobile1: normalizeRestaurantMobile(mobile1),
        mobile2: mobile2 != null && mobile2.trim().isNotEmpty
            ? normalizeRestaurantMobile(mobile2)
            : null,
        mobile3: mobile3 != null && mobile3.trim().isNotEmpty
            ? normalizeRestaurantMobile(mobile3)
            : null,
        subscriptionYears: subscriptionYears,
      );

      String? logoUrl;
      if (logoBytes != null) {
        logoUrl = await uploadRestaurantLogo(
          restaurantId: restaurantId,
          bytes: logoBytes,
        );
      }
      String? qrCodeUrl;
      if (qrCodeBytes != null) {
        qrCodeUrl = await uploadRestaurantQrCode(
          restaurantId: restaurantId,
          bytes: qrCodeBytes,
        );
      }
      if (logoUrl != null || qrCodeUrl != null) {
        await _repository.updateRestaurantProfile(
          restaurantId: restaurantId,
          name: name.trim(),
          address: address,
          mobile1: normalizeRestaurantMobile(mobile1),
          mobile2: mobile2 != null && mobile2.trim().isNotEmpty
              ? normalizeRestaurantMobile(mobile2)
              : null,
          mobile3: mobile3 != null && mobile3.trim().isNotEmpty
              ? normalizeRestaurantMobile(mobile3)
              : null,
          logoUrl: logoUrl,
          qrCodeUrl: qrCodeUrl,
        );
      }
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> updateRestaurant({
    required Restaurant restaurant,
    required String name,
    String? address,
    required String mobile1,
    String? mobile2,
    String? mobile3,
    Uint8List? logoBytes,
    bool removeLogo = false,
    Uint8List? qrCodeBytes,
    bool removeQrCode = false,
    DateTime? subscriptionEnd,
  }) async {
    final validationError = validateRestaurantForm(
      name: name,
      mobile1: mobile1,
      mobile2: mobile2,
      mobile3: mobile3,
    );
    if (validationError != null) return validationError;

    isLoading.value = true;
    try {
      String? logoUrl = removeLogo ? null : restaurant.logoUrl;
      if (logoBytes != null) {
        logoUrl = await uploadRestaurantLogo(
          restaurantId: restaurant.id,
          bytes: logoBytes,
        );
      }
      String? qrCodeUrl = removeQrCode ? null : restaurant.qrCodeUrl;
      if (qrCodeBytes != null) {
        qrCodeUrl = await uploadRestaurantQrCode(
          restaurantId: restaurant.id,
          bytes: qrCodeBytes,
        );
      }

      await _repository.updateRestaurantProfile(
        restaurantId: restaurant.id,
        name: name,
        address: address,
        mobile1: normalizeRestaurantMobile(mobile1),
        mobile2: mobile2 != null && mobile2.trim().isNotEmpty
            ? normalizeRestaurantMobile(mobile2)
            : null,
        mobile3: mobile3 != null && mobile3.trim().isNotEmpty
            ? normalizeRestaurantMobile(mobile3)
            : null,
        logoUrl: logoUrl,
        qrCodeUrl: qrCodeUrl,
      );

      if (subscriptionEnd != null) {
        await _repository.updateSubscriptionEnd(
          restaurantId: restaurant.id,
          subscriptionEnd: subscriptionEnd,
        );
      }
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> createRestaurantAdmin({
    required String restaurantId,
    required String name,
    required String email,
    required String password,
  }) async {
    if (name.trim().isEmpty) return 'Admin name is required.';
    if (email.trim().isEmpty) return 'Email is required.';
    if (password.length < 6) return 'Password must be at least 6 characters.';
    isLoading.value = true;
    try {
      await _repository.createRestaurantAdmin(
        email: email,
        password: password,
        name: name,
        restaurantId: restaurantId,
      );
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> deleteRestaurantAdmin({
    required UserProfile admin,
    required String restaurantId,
  }) async {
    isLoading.value = true;
    try {
      await _repository.deleteRestaurantAdmin(
        admin: admin,
        restaurantId: restaurantId,
      );
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> activateRestaurant(String id) async {
    await _repository.setRestaurantStatus(
      restaurantId: id,
      status: RestaurantStatus.active,
    );
  }

  Future<void> deactivateRestaurant(String id) async {
    await _repository.setRestaurantStatus(
      restaurantId: id,
      status: RestaurantStatus.deactivated,
    );
  }

  Future<String?> extendSubscription({
    required String restaurantId,
    required int years,
  }) async {
    isLoading.value = true;
    try {
      await _repository.extendSubscription(
        restaurantId: restaurantId,
        additionalYears: years,
      );
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    if (!await confirmLogout()) return;
    await _userRepository.signOut();
  }
}
