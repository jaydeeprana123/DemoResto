import 'package:smartKitchen/features/inventory_reports/repositories/inventory_reports_repository.dart';
import 'package:get/get.dart';

class InventoryReportsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InventoryReportsRepository>(
      () => InventoryReportsRepository(),
      fenix: true,
    );
  }
}
