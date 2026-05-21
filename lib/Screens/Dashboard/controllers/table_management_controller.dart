import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:demo/Screens/Dashboard/repositories/table_management_repository.dart';

/// TableManagementController
///
/// Coordinates state management, validation, and action invocation for adding
/// and deleting restaurant tables using the [TableManagementRepository].
class TableManagementController extends GetxController {
  final TableManagementRepository _repository = TableManagementRepository();

  // Controllers and Keys for Table Creation Form
  final GlobalKey<FormState> tableFormKey = GlobalKey<FormState>();
  final TextEditingController tableNameController = TextEditingController();

  @override
  void onClose() {
    tableNameController.dispose();
    super.onClose();
  }

  /// Exposes the real-time tables stream from the repository.
  Stream<dynamic> getTablesStream() => _repository.getTablesStream();

  /// Validates input form and creates a new table using the repository.
  Future<void> addNewTable() async {
    if (tableFormKey.currentState?.validate() ?? false) {
      final name = tableNameController.text.trim();
      try {
        await _repository.createTable(name);
        tableNameController.clear();
        Get.snackbar(
          "Success",
          "Table '$name' added successfully",
          backgroundColor: Colors.green.shade700,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } catch (e) {
        Get.snackbar(
          "Error",
          "Failed to add table: $e",
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  /// Deletes the table document with the specified [docId] via the repository.
  Future<void> deleteTable(String docId, String name) async {
    try {
      await _repository.removeTable(docId);
      Get.snackbar(
        "Success",
        "Table '$name' deleted successfully",
        backgroundColor: Colors.green.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to delete table '$name': $e",
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
