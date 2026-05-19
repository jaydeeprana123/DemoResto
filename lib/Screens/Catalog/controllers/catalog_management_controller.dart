import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:demo/Screens/Catalog/repositories/catalog_management_repository.dart';

/// CatalogManagementController
/// 
/// Part of the GetX Repository Pattern.
/// Coordinates state management, validation, and action invocation for adding and deleting
/// categories and menu items.
class CatalogManagementController extends GetxController {
  final CatalogManagementRepository _repository = CatalogManagementRepository();

  // ── Category Fields ──────────────────────────────────────────────────────
  final TextEditingController categoryNameController = TextEditingController();

  // ── Menu Item Fields ──────────────────────────────────────────────────────
  final TextEditingController menuItemNameController = TextEditingController();
  final TextEditingController menuItemPriceController = TextEditingController();
  final RxnString selectedCategoryId = RxnString();
  final RxnString selectedCategoryName = RxnString();

  @override
  void onClose() {
    categoryNameController.dispose();
    menuItemNameController.dispose();
    menuItemPriceController.dispose();
    super.onClose();
  }

  // ── Stream Accessors ──────────────────────────────────────────────────────
  Stream<dynamic> getCategoriesStream() => _repository.getCategoriesStream();
  Stream<dynamic> getMenuItemsStream(String categoryId) => _repository.getMenuItemsStream(categoryId);

  // ── Category Actions ──────────────────────────────────────────────────────
  Future<void> addCategory() async {
    final name = categoryNameController.text.trim();
    if (name.isEmpty) return;

    try {
      await _repository.addCategory(name);
      categoryNameController.clear();
      Get.snackbar("Success", "Category added",
          backgroundColor: Colors.green.shade700, colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Error", "Failed to add category: $e",
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      await _repository.deleteCategory(categoryId);
      Get.snackbar("Success", "Category deleted",
          backgroundColor: Colors.green.shade700, colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Error", "Failed to delete category: $e",
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
    }
  }

  // ── Menu Item Actions ─────────────────────────────────────────────────────
  void setSelectedCategory(String? id, String? name) {
    selectedCategoryId.value = id;
    selectedCategoryName.value = name;
  }

  Future<void> addMenuItem() async {
    final categoryId = selectedCategoryId.value;
    final categoryName = selectedCategoryName.value;
    final name = menuItemNameController.text.trim();
    final priceStr = menuItemPriceController.text.trim();

    if (categoryId == null || name.isEmpty || priceStr.isEmpty) {
      Get.snackbar("Required Fields", "Please complete all fields first",
          backgroundColor: Colors.orange.shade700, colorText: Colors.white);
      return;
    }

    final price = double.tryParse(priceStr) ?? 0.0;

    try {
      await _repository.addMenuItem(
        categoryId: categoryId,
        name: name,
        price: price,
      );
      menuItemNameController.clear();
      menuItemPriceController.clear();
      Get.snackbar("Success", "Menu item added to $categoryName",
          backgroundColor: Colors.green.shade700, colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Error", "Failed to add menu item: $e",
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
    }
  }

  Future<void> deleteMenuItem(String categoryId, String itemId) async {
    try {
      await _repository.deleteMenuItem(categoryId: categoryId, itemId: itemId);
      Get.snackbar("Success", "Menu item deleted",
          backgroundColor: Colors.green.shade700, colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Error", "Failed to delete menu item: $e",
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
    }
  }
}
