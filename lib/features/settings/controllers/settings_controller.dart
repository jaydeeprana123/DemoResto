import 'package:demo/core/repositories/user_repository.dart';
import 'package:demo/features/kitchen/services/kitchen_settings.dart';
import 'package:get/get.dart';

class SettingsController extends GetxController {
  SettingsController(this._userRepository);

  final UserRepository _userRepository;

  final userRole = Rxn<String>();
  final isLoadingRole = true.obs;
  final kitchenShowTableAllOrders = false.obs;

  Future<void> loadUserRole() async {
    isLoadingRole.value = true;
    final user = _userRepository.currentUser;
    if (user == null) {
      userRole.value = null;
      isLoadingRole.value = false;
      return;
    }
    userRole.value = await _userRepository.getUserRole(user.uid);
    isLoadingRole.value = false;
  }

  Future<void> loadKitchenSettings() async {
    kitchenShowTableAllOrders.value =
        await KitchenSettings.getShowTableAllOrders();
  }

  Future<void> setKitchenShowTableAllOrders(bool value) async {
    await KitchenSettings.setShowTableAllOrders(value);
    kitchenShowTableAllOrders.value = value;
  }

  Future<void> signOut() => _userRepository.signOut();

  bool get isAdmin => userRole.value == 'Admin';
}
