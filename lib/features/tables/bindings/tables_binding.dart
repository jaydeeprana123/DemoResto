import 'package:smartKitchen/features/tables/controllers/tables_controller.dart';
import 'package:smartKitchen/features/tables/repositories/tables_repository.dart';
import 'package:smartKitchen/features/tables/services/shared_tables_snapshot_service.dart';
import 'package:smartKitchen/features/tables/services/serve_notification_service.dart';
import 'package:smartKitchen/features/zomato/repositories/zomato_orders_repository.dart';
import 'package:smartKitchen/features/zomato/services/zomato_order_serve_service.dart';
import 'package:smartKitchen/features/zomato/services/zomato_share_intent_service.dart';
import 'package:get/get.dart';

class TablesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TablesRepository>(() => TablesRepository(), fenix: true);
    Get.lazyPut<SharedTablesSnapshotService>(
      () => SharedTablesSnapshotService(Get.find<TablesRepository>()),
      fenix: true,
    );
    Get.lazyPut<ServeNotificationService>(
      () => ServeNotificationService(),
      fenix: true,
    );
    Get.lazyPut<ZomatoOrdersRepository>(() => ZomatoOrdersRepository(), fenix: true);
    Get.lazyPut<ZomatoOrderServeService>(
      () => ZomatoOrderServeService(Get.find<ZomatoOrdersRepository>()),
      fenix: true,
    );
    if (!Get.isRegistered<ZomatoShareIntentService>()) {
      Get.put<ZomatoShareIntentService>(ZomatoShareIntentService(), permanent: true);
    }
    Get.lazyPut<TablesController>(
      () => TablesController(Get.find<TablesRepository>()),
      fenix: true,
    );
  }
}
