import 'package:demo/features/tables/controllers/tables_controller.dart';
import 'package:demo/features/tables/repositories/tables_repository.dart';
import 'package:demo/features/zomato/repositories/zomato_orders_repository.dart';
import 'package:demo/features/zomato/services/zomato_share_intent_service.dart';
import 'package:get/get.dart';

class TablesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TablesRepository>(() => TablesRepository(), fenix: true);
    Get.lazyPut<ZomatoOrdersRepository>(() => ZomatoOrdersRepository(), fenix: true);
    if (!Get.isRegistered<ZomatoShareIntentService>()) {
      Get.put<ZomatoShareIntentService>(ZomatoShareIntentService(), permanent: true);
    }
    Get.lazyPut<TablesController>(
      () => TablesController(Get.find<TablesRepository>()),
      fenix: true,
    );
  }
}
