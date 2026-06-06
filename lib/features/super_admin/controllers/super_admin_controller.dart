import 'package:demo/core/models/restaurant.dart';
import 'package:demo/core/repositories/user_repository.dart';
import 'package:demo/features/super_admin/repositories/super_admin_repository.dart';
import 'package:get/get.dart';

class SuperAdminController extends GetxController {
  SuperAdminController(this._repository, this._userRepository);

  final SuperAdminRepository _repository;
  final UserRepository _userRepository;

  final restaurants = <Restaurant>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();

  Stream<List<Restaurant>>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _subscription = _repository.watchRestaurants();
    _subscription!.listen(
      (list) => restaurants.assignAll(list),
      onError: (e) => errorMessage.value = e.toString(),
    );
  }

  Future<String?> createRestaurant({
    required String name,
    String? address,
    required int subscriptionYears,
  }) async {
    if (name.trim().isEmpty) return 'Restaurant name is required.';
    isLoading.value = true;
    try {
      await _repository.createRestaurant(
        name: name,
        address: address,
        subscriptionYears: subscriptionYears,
      );
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
    await _userRepository.signOut();
  }
}
