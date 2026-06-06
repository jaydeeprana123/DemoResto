import 'package:demo/core/repositories/user_repository.dart';
import 'package:get/get.dart';

class CoreBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UserRepository>(() => UserRepository(), fenix: true);
  }
}
