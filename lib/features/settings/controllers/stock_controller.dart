import 'package:demo/core/models/menu_stock_entry.dart';
import 'package:demo/features/settings/repositories/stock_repository.dart';
import 'package:get/get.dart';

class StockController extends GetxController {
  StockController(this._repository);

  final StockRepository _repository;

  final isLoading = false.obs;
  final selectedKeys = <String>{}.obs;

  Stream<List<MenuStockEntry>> watchMenuStock() => _repository.watchMenuStock();

  void toggleSelection(String key, {required bool? selected}) {
    if (selected == true) {
      selectedKeys.add(key);
    } else {
      selectedKeys.remove(key);
    }
  }

  void toggleSelectAll(List<MenuStockEntry> items, {required bool selectAll}) {
    if (selectAll) {
      selectedKeys
        ..clear()
        ..addAll(items.map((e) => e.key));
    } else {
      selectedKeys.clear();
    }
  }

  bool isAllSelected(List<MenuStockEntry> items) {
    if (items.isEmpty) return false;
    return items.every((e) => selectedKeys.contains(e.key));
  }

  List<MenuStockEntry> selectedEntries(List<MenuStockEntry> all) {
    return all.where((e) => selectedKeys.contains(e.key)).toList();
  }

  Future<String?> markSelectedInStock() => _applyStock(inStock: true);

  Future<String?> markSelectedOutOfStock() => _applyStock(inStock: false);

  Future<String?> _applyStock({required bool inStock}) async {
    if (selectedKeys.isEmpty) {
      return 'Select at least one item.';
    }

    isLoading.value = true;
    try {
      await _repository.setStockByKeys(
        selectedKeys.toList(),
        inStock: inStock,
      );
      selectedKeys.clear();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }
}
