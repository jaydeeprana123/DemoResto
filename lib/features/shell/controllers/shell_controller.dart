import 'package:demo/core/repositories/user_repository.dart';
import 'package:get/get.dart';

class ShellController extends GetxController {
  ShellController(this._userRepository);

  final UserRepository _userRepository;

  final currentIndex = 0.obs;
  final userRole = Rxn<String>();

  static const kitchenTabIndex = 1;

  void changeTab(int index) => currentIndex.value = index;

  Future<void> loadUserRole() async {
    final user = _userRepository.currentUser;
    if (user == null) return;
    userRole.value = await _userRepository.getUserRole(user.uid);
  }
}
