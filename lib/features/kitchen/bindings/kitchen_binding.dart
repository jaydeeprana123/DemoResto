import 'package:demo/features/kitchen/controllers/kitchen_controller.dart';
import 'package:demo/features/tables/repositories/tables_repository.dart';
import 'package:get/get.dart';

class KitchenBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<KitchenController>(
      () => KitchenController(Get.find<TablesRepository>()),
      fenix: true,
    );
  }
}
