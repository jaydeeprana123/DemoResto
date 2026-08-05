import 'package:smartKitchen/core/repositories/user_repository.dart';
import 'package:smartKitchen/core/services/firestore_sync_status_service.dart';
import 'package:smartKitchen/core/services/restaurant_print_profile_service.dart';
import 'package:smartKitchen/core/services/restaurant_session.dart';
import 'package:smartKitchen/features/authentication/services/device_session_service.dart';
import 'package:get/get.dart';

class CoreBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UserRepository>(() => UserRepository(), fenix: true);
    Get.put<DeviceSessionService>(DeviceSessionService(), permanent: true);
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
