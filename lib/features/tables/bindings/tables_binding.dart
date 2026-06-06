import 'package:demo/features/tables/controllers/tables_controller.dart';
import 'package:demo/features/tables/repositories/tables_repository.dart';
import 'package:get/get.dart';

class TablesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TablesRepository>(() => TablesRepository(), fenix: true);
    Get.lazyPut<TablesController>(
      () => TablesController(Get.find<TablesRepository>()),
      fenix: true,
    );
  }
}
