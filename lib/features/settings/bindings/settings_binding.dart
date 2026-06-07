import 'package:demo/core/repositories/user_repository.dart';
import 'package:demo/features/settings/controllers/admin_dashboard_controller.dart';
import 'package:demo/features/settings/controllers/expenses_controller.dart';
import 'package:demo/features/settings/controllers/settings_controller.dart';
import 'package:demo/features/settings/controllers/staff_controller.dart';
import 'package:demo/features/settings/repositories/admin_dashboard_repository.dart';
import 'package:demo/features/settings/repositories/expenses_repository.dart';
import 'package:demo/features/settings/repositories/export_repository.dart';
import 'package:demo/features/settings/repositories/staff_repository.dart';
import 'package:get/get.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ExpensesRepository>(() => ExpensesRepository(), fenix: true);
    Get.lazyPut<AdminDashboardRepository>(
      () => AdminDashboardRepository(),
      fenix: true,
    );
    Get.lazyPut<ExportRepository>(() => ExportRepository(), fenix: true);
    Get.lazyPut<SettingsController>(
      () => SettingsController(Get.find<UserRepository>()),
      fenix: true,
    );
    Get.lazyPut<ExpensesController>(
      () => ExpensesController(Get.find<ExpensesRepository>()),
      fenix: true,
    );
    Get.lazyPut<AdminDashboardController>(
      () => AdminDashboardController(Get.find<AdminDashboardRepository>()),
      fenix: true,
    );
    Get.lazyPut<StaffRepository>(() => StaffRepository(), fenix: true);
    Get.lazyPut<StaffController>(
      () => StaffController(Get.find<StaffRepository>()),
      fenix: true,
    );
  }
}
