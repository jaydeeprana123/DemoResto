import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KitchenSettings {
  static const _keyShowTableAllOrders = 'kitchen_show_table_all_orders';
  static const _keyShowServeOrderScreen = 'kitchen_show_serve_order_screen';
  static const _keyMobileOrdersGridLayout = 'kitchen_mobile_orders_grid_layout';
  static const _keyShowAllCategories = 'kitchen_filter_show_all_categories';
  static const _keySelectedCategories = 'kitchen_filter_selected_categories';
  static const _keySelectedMenuItems = 'kitchen_filter_selected_menu_items';
  static const _keyOrderTypeFilterIndex = 'kitchen_filter_order_type_index';
  static const _keyShowZomatoOrdersInAll = 'kitchen_filter_show_zomato_in_all';
  static const _keyBackgroundOrderRingtone = 'kitchen_background_order_ringtone';
  static const _keyPreparationView = 'kitchen_preparation_view';

  static final ValueNotifier<bool> showTableAllOrders = ValueNotifier(true);
  static final ValueNotifier<bool> showServeOrderScreen = ValueNotifier(false);
  /// Groups kitchen orders by menu item (qty × table lines) instead of by table.
  static final ValueNotifier<bool> preparationViewEnabled = ValueNotifier(false);
  /// When true, order bells also play if the app is backgrounded or the screen is locked.
  /// Foreground kitchen bells do not depend on this setting.
  static final ValueNotifier<bool> backgroundOrderRingtoneEnabled =
      ValueNotifier(true);
  /// On mobile kitchen screen: true = 2-column grid, false = single-column list.
  static final ValueNotifier<bool> mobileOrdersGridLayout = ValueNotifier(false);

  /// Category filter: true = show all categories.
  static bool showAllCategories = true;
  static Set<String> selectedCategories = {};
  /// Keys are `category|itemName` for kitchen item-level filtering.
  static Set<String> selectedMenuItems = {};
  /// 0 = All, 1 = Table (dine-in), 2 = Take Away, 3 = Zomato
  static int orderTypeFilterIndex = 0;
  /// When false, Zomato orders are hidden from the All order-type tab only.
  static bool showZomatoOrdersInAll = true;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    showTableAllOrders.value =
        prefs.getBool(_keyShowTableAllOrders) ?? true;
    showServeOrderScreen.value =
        prefs.getBool(_keyShowServeOrderScreen) ?? false;
    backgroundOrderRingtoneEnabled.value =
        prefs.getBool(_keyBackgroundOrderRingtone) ?? true;
    preparationViewEnabled.value =
        prefs.getBool(_keyPreparationView) ?? false;
    mobileOrdersGridLayout.value =
        prefs.getBool(_keyMobileOrdersGridLayout) ?? false;

    showAllCategories = prefs.getBool(_keyShowAllCategories) ?? true;
    selectedCategories =
        (prefs.getStringList(_keySelectedCategories) ?? []).toSet();
    selectedMenuItems =
        (prefs.getStringList(_keySelectedMenuItems) ?? []).toSet();
    orderTypeFilterIndex = prefs.getInt(_keyOrderTypeFilterIndex) ?? 0;
    if (orderTypeFilterIndex < 0 || orderTypeFilterIndex > 3) {
      orderTypeFilterIndex = 0;
    }
    showZomatoOrdersInAll =
        prefs.getBool(_keyShowZomatoOrdersInAll) ?? true;
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

  static Future<bool> getPreparationViewEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPreparationView) ?? false;
  }

  static Future<void> setPreparationViewEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPreparationView, value);
    preparationViewEnabled.value = value;
  }

  static Future<void> setMobileOrdersGridLayout(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMobileOrdersGridLayout, value);
    mobileOrdersGridLayout.value = value;
  }

  static Future<void> saveCategoryFilter({
    required bool showAll,
    required Set<String> categories,
    Set<String>? menuItems,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowAllCategories, showAll);
    await prefs.setStringList(
      _keySelectedCategories,
      categories.toList()..sort(),
    );
    final items = menuItems ?? selectedMenuItems;
    if (showAll) {
      await prefs.remove(_keySelectedMenuItems);
      selectedMenuItems = {};
    } else {
      await prefs.setStringList(
        _keySelectedMenuItems,
        items.toList()..sort(),
      );
      selectedMenuItems = Set<String>.from(items);
    }
    showAllCategories = showAll;
    selectedCategories = Set<String>.from(categories);
  }

  static Future<void> saveOrderTypeFilterIndex(int index) async {
    final safeIndex = index < 0 || index > 3 ? 0 : index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOrderTypeFilterIndex, safeIndex);
    orderTypeFilterIndex = safeIndex;
  }

  static Future<void> saveShowZomatoOrdersInAll(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowZomatoOrdersInAll, value);
    showZomatoOrdersInAll = value;
  }
}
