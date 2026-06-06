import 'package:demo/features/menu_setup/controllers/menu_setup_controller.dart';
import 'package:demo/features/menu_setup/repositories/menu_setup_repository.dart';
import 'package:get/get.dart';

class MenuSetupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MenuSetupRepository>(() => MenuSetupRepository(), fenix: true);
    Get.lazyPut<MenuSetupController>(
      () => MenuSetupController(Get.find<MenuSetupRepository>()),
      fenix: true,
    );
  }
}
