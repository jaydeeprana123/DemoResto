import 'package:demo/core/repositories/user_repository.dart';
import 'package:demo/features/settings/controllers/admin_dashboard_controller.dart';
import 'package:demo/features/settings/controllers/expenses_controller.dart';
import 'package:demo/features/settings/controllers/profile_controller.dart';
import 'package:demo/features/settings/controllers/settings_controller.dart';
import 'package:demo/features/settings/controllers/staff_controller.dart';
import 'package:demo/features/settings/controllers/stock_controller.dart';
import 'package:demo/features/settings/repositories/admin_dashboard_repository.dart';
import 'package:demo/features/settings/repositories/bill_customer_contacts_repository.dart';
import 'package:demo/features/settings/repositories/expenses_repository.dart';
import 'package:demo/features/settings/repositories/export_repository.dart';
import 'package:demo/features/settings/repositories/staff_repository.dart';
import 'package:demo/features/settings/repositories/stock_repository.dart';
import 'package:get/get.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ExpensesRepository>(() => ExpensesRepository(), fenix: true);
    Get.lazyPut<BillCustomerContactsRepository>(
      () => BillCustomerContactsRepository(),
      fenix: true,
    );
    Get.lazyPut<AdminDashboardRepository>(
      () => AdminDashboardRepository(),
      fenix: true,
    );
    Get.lazyPut<ExportRepository>(() => ExportRepository(), fenix: true);
    Get.lazyPut<ProfileController>(
      () => ProfileController(Get.find<UserRepository>()),
      fenix: true,
    );
    Get.put<SettingsController>(
      SettingsController(Get.find<UserRepository>()),
      permanent: true,
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
    Get.lazyPut<StockRepository>(() => StockRepository(), fenix: true);
    Get.lazyPut<StockController>(
      () => StockController(Get.find<StockRepository>()),
      fenix: true,
    );
  }
}
