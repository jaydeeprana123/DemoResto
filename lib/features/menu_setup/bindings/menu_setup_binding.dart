import 'package:demo/features/menu_setup/controllers/menu_setup_controller.dart';
import 'package:demo/features/menu_setup/repositories/menu_setup_repository.dart';
import 'package:demo/features/menu_setup/services/menu_cache_service.dart';
import 'package:get/get.dart';

class MenuSetupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MenuCacheService>(() => MenuCacheService(), fenix: true);
    Get.lazyPut<MenuSetupRepository>(() => MenuSetupRepository(), fenix: true);
    Get.lazyPut<MenuSetupController>(
      () => MenuSetupController(Get.find<MenuSetupRepository>()),
      fenix: true,
    );
  }
}
