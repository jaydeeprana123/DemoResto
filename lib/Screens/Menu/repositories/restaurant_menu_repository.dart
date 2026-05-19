import 'package:shared_preferences/shared_preferences.dart';

/// RestaurantMenuRepository
/// 
/// Part of the GetX Repository Pattern.
/// This repository is responsible for managing local persistence for menu preferences
/// and selected categories, serving as a clean abstraction over SharedPreferences.
class RestaurantMenuRepository {
  static const String _kSelectedCategoriesKey = 'selectedCategories';

  /// Saves the list of selected categories locally.
  Future<void> saveSelectedCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSelectedCategoriesKey, categories);
  }

  /// Loads the list of selected categories from local storage.
  Future<List<String>> loadSelectedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kSelectedCategoriesKey) ?? [];
  }
}
