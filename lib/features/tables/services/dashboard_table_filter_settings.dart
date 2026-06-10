import 'package:shared_preferences/shared_preferences.dart';

class DashboardTableFilterSettings {
  DashboardTableFilterSettings._();

  static const _keySelectedTables = 'dashboard_table_filter_selection';

  static Future<Set<String>> loadSelection() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_keySelectedTables) ?? []).toSet();
  }

  static Future<void> saveSelection(Set<String> tableNames) async {
    final prefs = await SharedPreferences.getInstance();
    if (tableNames.isEmpty) {
      await prefs.remove(_keySelectedTables);
      return;
    }
    final sorted = tableNames.toList()..sort();
    await prefs.setStringList(_keySelectedTables, sorted);
  }
}
