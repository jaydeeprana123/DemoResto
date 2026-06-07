import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KitchenSettings {
  static const _keyShowTableAllOrders = 'kitchen_show_table_all_orders';
  static const _keyShowServeOrderScreen = 'kitchen_show_serve_order_screen';

  static final ValueNotifier<bool> showTableAllOrders = ValueNotifier(false);
  static final ValueNotifier<bool> showServeOrderScreen = ValueNotifier(true);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    showTableAllOrders.value =
        prefs.getBool(_keyShowTableAllOrders) ?? false;
    showServeOrderScreen.value =
        prefs.getBool(_keyShowServeOrderScreen) ?? true;
  }

  static Future<bool> getShowTableAllOrders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShowTableAllOrders) ?? false;
  }

  static Future<void> setShowTableAllOrders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowTableAllOrders, value);
    showTableAllOrders.value = value;
  }

  static Future<bool> getShowServeOrderScreen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShowServeOrderScreen) ?? true;
  }

  static Future<void> setShowServeOrderScreen(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowServeOrderScreen, value);
    showServeOrderScreen.value = value;
  }
}
