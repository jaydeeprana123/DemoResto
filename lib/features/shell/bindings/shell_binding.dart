import 'package:smartKitchen/core/repositories/user_repository.dart';
import 'package:smartKitchen/features/shell/controllers/shell_controller.dart';
import 'package:get/get.dart';

class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ShellController>(
      () => ShellController(Get.find<UserRepository>()),
      fenix: true,
    );
  }
}
