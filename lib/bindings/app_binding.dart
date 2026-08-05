import 'package:smartKitchen/core/bindings/core_binding.dart';
import 'package:smartKitchen/features/authentication/bindings/auth_binding.dart';
import 'package:smartKitchen/features/kitchen/bindings/kitchen_binding.dart';
import 'package:smartKitchen/features/menu_setup/bindings/menu_setup_binding.dart';
import 'package:smartKitchen/features/ordering/bindings/ordering_binding.dart';
import 'package:smartKitchen/features/settings/bindings/settings_binding.dart';
import 'package:smartKitchen/features/shell/bindings/shell_binding.dart';
import 'package:smartKitchen/features/tables/bindings/tables_binding.dart';
import 'package:smartKitchen/features/super_admin/bindings/super_admin_binding.dart';
import 'package:smartKitchen/features/transactions/bindings/transactions_binding.dart';
import 'package:get/get.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    CoreBinding().dependencies();
    AuthBinding().dependencies();
    ShellBinding().dependencies();
    TablesBinding().dependencies();
    KitchenBinding().dependencies();
    MenuSetupBinding().dependencies();
    TransactionsBinding().dependencies();
    OrderingBinding().dependencies();
    SettingsBinding().dependencies();
    SuperAdminBinding().dependencies();
  }
}
