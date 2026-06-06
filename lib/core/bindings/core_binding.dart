import 'package:demo/core/repositories/user_repository.dart';
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
  }
}
