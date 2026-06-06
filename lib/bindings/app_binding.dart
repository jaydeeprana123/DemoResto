import 'package:demo/core/bindings/core_binding.dart';
import 'package:demo/features/authentication/bindings/auth_binding.dart';
import 'package:demo/features/kitchen/bindings/kitchen_binding.dart';
import 'package:demo/features/menu_setup/bindings/menu_setup_binding.dart';
import 'package:demo/features/ordering/bindings/ordering_binding.dart';
import 'package:demo/features/settings/bindings/settings_binding.dart';
import 'package:demo/features/shell/bindings/shell_binding.dart';
import 'package:demo/features/tables/bindings/tables_binding.dart';
import 'package:demo/features/transactions/bindings/transactions_binding.dart';
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
  }
}
