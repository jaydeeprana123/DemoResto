import 'package:smartKitchen/features/inventory_reports/repositories/inventory_reports_repository.dart';
import 'package:smartKitchen/features/menu_setup/services/menu_cache_service.dart';
import 'package:get/get.dart';

class InventoryReportsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<MenuCacheService>()) {
      Get.lazyPut<MenuCacheService>(() => MenuCacheService(), fenix: true);
    }
    Get.lazyPut<InventoryReportsRepository>(
      () => InventoryReportsRepository(),
      fenix: true,
    );
  }
}
