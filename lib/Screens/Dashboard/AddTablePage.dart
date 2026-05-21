import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/Screens/Dashboard/controllers/table_management_controller.dart';

// Unused imports from original code (preserved if required by build environment)
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// AddTablePage
///
/// Refactored to leverage the GetX Repository Pattern.
/// Operates as a pure presentation layer that communicates with the registered
/// [TableManagementController] to observe reactive inputs, display tables
/// in real time, and invoke write/delete table events.
class AddTablePage extends StatelessWidget {
  const AddTablePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Register or locate the TableManagementController
    final TableManagementController controller = Get.put(
      TableManagementController(),
    );

    return Scaffold(
      appBar: _buildAppBar(),
      body: Container(
        color: const Color(0xFFF5F6FA),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAddTableFormCard(controller),
              const SizedBox(height: 24),
              _buildSectionHeader(),
              const SizedBox(height: 12),
              _buildTablesList(controller),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the top app bar matching the brand theme.
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1A3A5C),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text(
        "Add Table",
        style: TextStyle(
          fontSize: 16,
          fontFamily: fontMulishBold,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Builds the card containing the input form to create a new table.
  Widget _buildAddTableFormCard(TableManagementController controller) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: controller.tableFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Create New Table",
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: fontMulishBold,
                  color: Color(0xFF1A3A5C),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller.tableNameController,
                decoration: InputDecoration(
                  labelText: 'Table Name',
                  hintText: 'e.g., Table 1, Table 2',
                  prefixIcon: const Icon(
                    Icons.table_restaurant_rounded,
                    color: Color(0xFF1A3A5C),
                  ),
                  labelStyle: const TextStyle(
                    fontFamily: fontMulishRegular,
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFf57c35),
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  isDense: true,
                ),
                style: const TextStyle(
                  fontFamily: fontMulishSemiBold,
                  fontSize: 14,
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: controller.addNewTable,
                icon: const Icon(
                  Icons.add,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  "ADD TABLE",
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: fontMulishBold,
                    color: Colors.white,
                    letterSpacing: 1.1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf57c35), // Primary orange
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the header section for the existing tables list.
  Widget _buildSectionHeader() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFFf57c35),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          "All Tables",
          style: TextStyle(
            fontSize: 15,
            fontFamily: fontMulishBold,
            color: Color(0xFF1A3A5C),
          ),
        ),
      ],
    );
  }

  /// Builds the real-time list of restaurant tables.
  Widget _buildTablesList(TableManagementController controller) {
    return Expanded(
      child: StreamBuilder<dynamic>(
        stream: controller.getTablesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || (snapshot.data as QuerySnapshot).docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.table_restaurant_outlined,
                    size: 48,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "No tables found",
                    style: TextStyle(
                      fontFamily: fontMulishSemiBold,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          final tables = (snapshot.data as QuerySnapshot).docs;

          return ListView.builder(
            itemCount: tables.length,
            itemBuilder: (context, index) {
              final doc = tables[index];
              final name = doc['name'] ?? '';

              return Card(
                elevation: 2,
                shadowColor: Colors.black12,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFf57c35).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.table_restaurant_rounded,
                      color: Color(0xFFf57c35),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: fontMulishSemiBold,
                      color: Color(0xFF1A3A5C),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: () => _confirmAndDeleteTable(doc.id, name, controller),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Displays confirmation dialog and triggers table deletion upon confirmation.
  Future<void> _confirmAndDeleteTable(
    String docId,
    String name,
    TableManagementController controller,
  ) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          "Delete Table",
          style: TextStyle(
            fontFamily: fontMulishBold,
            color: Color(0xFF1A3A5C),
          ),
        ),
        content: Text(
          "Are you sure you want to delete '$name'?",
          style: const TextStyle(
            fontFamily: fontMulishRegular,
            color: Color(0xFF212121),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text(
              "Cancel",
              style: TextStyle(
                fontFamily: fontMulishSemiBold,
                color: Colors.grey,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text(
              "Delete",
              style: TextStyle(
                fontFamily: fontMulishBold,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.deleteTable(docId, name);
    }
  }
}
