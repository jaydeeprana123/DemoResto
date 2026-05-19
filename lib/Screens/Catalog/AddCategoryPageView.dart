import 'package:demo/Screens/Catalog/AddMenuItemView.dart';
import 'package:demo/Screens/Menu/MenuSeederPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import 'package:demo/Styles/my_font.dart';
import 'package:demo/Screens/Catalog/controllers/catalog_management_controller.dart';

/// AddCategoryPageView
///
/// Refactored to leverage the GetX Repository Pattern.
/// Operates as a pure presentation layer that communicates with the registered
/// [CatalogManagementController] to observe reactive inputs, display category catalogs
/// in real time, and invoke write/delete catalog events.
class AddCategoryPageView extends StatelessWidget {
  const AddCategoryPageView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Put or locate the controller.
    final CatalogManagementController controller = Get.put(
      CatalogManagementController(),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Add Category",
          style: TextStyle(
            fontSize: 16,
            fontFamily: fontMulishBold,
            color: Colors.white,
          ),
        ),
        actions: [
          // ── Import Al-Haadi Menu button ──
          TextButton.icon(
            onPressed: () => Get.to(() => const MenuSeederPage()),
            icon: const Icon(
              Icons.cloud_upload_outlined,
              size: 16,
              color: Colors.greenAccent,
            ),
            label: const Text(
              "Import",
              style: TextStyle(
                fontSize: 12,
                fontFamily: fontMulishSemiBold,
                color: Colors.greenAccent,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => Get.to(() => const AddMenuItemView()),
            icon: const Icon(
              Icons.add_circle_outline,
              size: 16,
              color: Colors.white,
            ),
            label: const Text(
              "Menu",
              style: TextStyle(
                fontSize: 12,
                fontFamily: fontMulishSemiBold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        color: const Color(0xFFF5F6FA),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Beautiful Input Form Card
              Card(
                elevation: 4,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Create New Category",
                        style: TextStyle(
                          fontSize: 15,
                          fontFamily: fontMulishBold,
                          color: Color(0xFF1A3A5C),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller.categoryNameController,
                        decoration: InputDecoration(
                          labelText: "Category Name",
                          hintText: "e.g., Starters, Main Course",
                          prefixIcon: const Icon(
                            Icons.category_outlined,
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
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: controller.addCategory,
                        icon: const Icon(
                          Icons.add,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "ADD CATEGORY",
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: fontMulishBold,
                            color: Colors.white,
                            letterSpacing: 1.1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFFf57c35,
                          ), // Primary orange
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
              const SizedBox(height: 24),

              // Title Header for List
              Row(
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
                    "All Categories",
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily: fontMulishBold,
                      color: Color(0xFF1A3A5C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              /// Category List
              Expanded(
                child: StreamBuilder<dynamic>(
                  stream: controller.getCategoriesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData ||
                        (snapshot.data as QuerySnapshot).docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.category_outlined,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "No categories found",
                              style: TextStyle(
                                fontFamily: fontMulishSemiBold,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final categories = (snapshot.data as QuerySnapshot).docs;

                    return ListView.builder(
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final categoryName = category['name'] as String;

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
                                Icons.folder_open_rounded,
                                color: Color(0xFFf57c35),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              categoryName,
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
                              onPressed: () =>
                                  controller.deleteCategory(category.id),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
