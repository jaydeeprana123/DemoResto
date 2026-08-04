import 'package:demo/features/authentication/controllers/login_controller.dart';
import 'package:demo/features/authentication/repositories/auth_repository.dart';
import 'package:get/get.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AuthRepository>(() => AuthRepository(), fenix: true);
    Get.lazyPut<LoginController>(
      () => LoginController(Get.find<AuthRepository>()),
      fenix: true,
    );
  }
}
