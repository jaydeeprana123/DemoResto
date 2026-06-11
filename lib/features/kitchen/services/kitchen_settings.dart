import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KitchenSettings {
  static const _keyShowTableAllOrders = 'kitchen_show_table_all_orders';
  static const _keyShowServeOrderScreen = 'kitchen_show_serve_order_screen';
  static const _keyMobileOrdersGridLayout = 'kitchen_mobile_orders_grid_layout';
  static const _keyShowAllCategories = 'kitchen_filter_show_all_categories';
  static const _keySelectedCategories = 'kitchen_filter_selected_categories';
  static const _keyOrderTypeFilterIndex = 'kitchen_filter_order_type_index';
  static const _keyBackgroundOrderRingtone = 'kitchen_background_order_ringtone';

  static final ValueNotifier<bool> showTableAllOrders = ValueNotifier(true);
  static final ValueNotifier<bool> showServeOrderScreen = ValueNotifier(false);
  /// When true, order bells play even if the app is backgrounded or the screen is locked.
  static final ValueNotifier<bool> backgroundOrderRingtoneEnabled =
      ValueNotifier(true);
  /// On mobile kitchen screen: true = 2-column grid, false = single-column list.
  static final ValueNotifier<bool> mobileOrdersGridLayout = ValueNotifier(false);

  /// Category filter: true = show all categories.
  static bool showAllCategories = true;
  static Set<String> selectedCategories = {};
  /// 0 = All, 1 = Table (dine-in), 2 = Take Away, 3 = Zomato
  static int orderTypeFilterIndex = 0;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    showTableAllOrders.value =
        prefs.getBool(_keyShowTableAllOrders) ?? true;
    showServeOrderScreen.value =
        prefs.getBool(_keyShowServeOrderScreen) ?? false;
    backgroundOrderRingtoneEnabled.value =
        prefs.getBool(_keyBackgroundOrderRingtone) ?? true;
    mobileOrdersGridLayout.value =
        prefs.getBool(_keyMobileOrdersGridLayout) ?? false;

    showAllCategories = prefs.getBool(_keyShowAllCategories) ?? true;
    selectedCategories =
        (prefs.getStringList(_keySelectedCategories) ?? []).toSet();
    orderTypeFilterIndex = prefs.getInt(_keyOrderTypeFilterIndex) ?? 0;
    if (orderTypeFilterIndex < 0 || orderTypeFilterIndex > 3) {
      orderTypeFilterIndex = 0;
    }
  }

  static Future<bool> getShowTableAllOrders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShowTableAllOrders) ?? true;
  }

  static Future<void> setShowTableAllOrders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowTableAllOrders, value);
    showTableAllOrders.value = value;
  }

  static Future<bool> getShowServeOrderScreen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShowServeOrderScreen) ?? false;
  }

  static Future<void> setShowServeOrderScreen(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowServeOrderScreen, value);
    showServeOrderScreen.value = value;
  }

  static Future<bool> getBackgroundOrderRingtoneEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBackgroundOrderRingtone) ?? true;
  }

  static Future<void> setBackgroundOrderRingtoneEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBackgroundOrderRingtone, value);
    backgroundOrderRingtoneEnabled.value = value;
  }

  static Future<void> setMobileOrdersGridLayout(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMobileOrdersGridLayout, value);
    mobileOrdersGridLayout.value = value;
  }

  static Future<void> saveCategoryFilter({
    required bool showAll,
    required Set<String> categories,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowAllCategories, showAll);
    await prefs.setStringList(
      _keySelectedCategories,
      categories.toList()..sort(),
    );
    showAllCategories = showAll;
    selectedCategories = Set<String>.from(categories);
  }

  static Future<void> saveOrderTypeFilterIndex(int index) async {
    final safeIndex = index < 0 || index > 3 ? 0 : index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOrderTypeFilterIndex, safeIndex);
    orderTypeFilterIndex = safeIndex;
  }
}
