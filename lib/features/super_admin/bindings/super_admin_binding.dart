import 'package:demo/core/repositories/user_repository.dart';
import 'package:demo/features/super_admin/controllers/super_admin_controller.dart';
import 'package:demo/features/super_admin/repositories/super_admin_repository.dart';
import 'package:get/get.dart';

class SuperAdminBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SuperAdminRepository>(() => SuperAdminRepository(), fenix: true);
    Get.lazyPut<SuperAdminController>(
      () => SuperAdminController(
        Get.find<SuperAdminRepository>(),
        Get.find<UserRepository>(),
      ),
      fenix: true,
    );
  }
}
