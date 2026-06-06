import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KitchenSettings {
  static const _keyShowTableAllOrders = 'kitchen_show_table_all_orders';

  static final ValueNotifier<bool> showTableAllOrders = ValueNotifier(false);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    showTableAllOrders.value =
        prefs.getBool(_keyShowTableAllOrders) ?? false;
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
}
