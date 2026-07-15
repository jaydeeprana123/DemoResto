import 'package:demo/core/repositories/user_repository.dart';
import 'package:demo/core/services/firestore_sync_status_service.dart';
import 'package:demo/core/services/restaurant_print_profile_service.dart';
import 'package:demo/core/services/restaurant_session.dart';
import 'package:get/get.dart';

class CoreBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UserRepository>(() => UserRepository(), fenix: true);
    Get.lazyPut<RestaurantSession>(
      () => RestaurantSession(Get.find<UserRepository>()),
      fenix: true,
    );
    Get.lazyPut<RestaurantPrintProfileService>(
      () => RestaurantPrintProfileService(),
      fenix: true,
    );
    Get.lazyPut<FirestoreSyncStatusService>(() => FirestoreSyncStatusService());
  }
}
