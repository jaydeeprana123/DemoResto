import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import 'package:demo/Styles/my_font.dart';
import 'package:demo/Screens/Catalog/controllers/catalog_management_controller.dart';

/// AddMenuItemView
///
/// Refactored to leverage the GetX Repository Pattern.
/// Operates as a pure presentation layer that communicates with the registered
/// [CatalogManagementController] to observe reactive inputs, display category & item
/// listings in real time, and invoke catalog write/delete events.
class AddMenuItemView extends StatelessWidget {
  const AddMenuItemView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Locate the catalog management controller.
    final CatalogManagementController controller = Get.put(
      CatalogManagementController(),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Add Menu Item",
          style: TextStyle(
            fontSize: 16,
            fontFamily: fontMulishBold,
            color: Colors.white,
          ),
        ),
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
                        "Create New Menu Item",
                        style: TextStyle(
                          fontSize: 15,
                          fontFamily: fontMulishBold,
                          color: Color(0xFF1A3A5C),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Dropdown for categories
                      StreamBuilder<dynamic>(
                        stream: controller.getCategoriesStream(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final categories =
                              (snapshot.data as QuerySnapshot).docs;

                          return Obx(() {
                            return DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: "Select Category",
                                prefixIcon: const Icon(
                                  Icons.folder_open_rounded,
                                  color: Color(0xFF1A3A5C),
                                ),
                                labelStyle: const TextStyle(
                                  fontFamily: fontMulishRegular,
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.grey,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
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
                                color: Color(0xFF1A3A5C),
                              ),
                              value: controller.selectedCategoryId.value,
                              items: categories.map((doc) {
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(
                                    doc['name'],
                                    style: const TextStyle(
                                      fontFamily: fontMulishSemiBold,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  final categoryName =
                                      categories.firstWhere(
                                            (doc) => doc.id == value,
                                          )['name']
                                          as String;
                                  controller.setSelectedCategory(
                                    value,
                                    categoryName,
                                  );
                                }
                              },
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Menu Item Name
                      TextField(
                        controller: controller.menuItemNameController,
                        decoration: InputDecoration(
                          labelText: "Menu Item Name",
                          hintText: "e.g., Paneer Tikka, Butter Chicken",
                          prefixIcon: const Icon(
                            Icons.restaurant_menu_outlined,
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
                      const SizedBox(height: 12),

                      // Price
                      TextField(
                        controller: controller.menuItemPriceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Price (₹)",
                          hintText: "e.g., 250",
                          prefixIcon: const Icon(
                            Icons.currency_rupee_rounded,
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

                      // Add Button
                      ElevatedButton.icon(
                        onPressed: controller.addMenuItem,
                        icon: const Icon(
                          Icons.add,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "ADD MENU ITEM",
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
                    "Menu Catalog",
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily: fontMulishBold,
                      color: Color(0xFF1A3A5C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Expanded list of categories + items
              Expanded(
                child: StreamBuilder<dynamic>(
                  stream: controller.getCategoriesStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final categories = (snapshot.data as QuerySnapshot).docs;

                    if (categories.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.restaurant_menu_outlined,
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

                    return ListView.builder(
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];

                        return Card(
                          elevation: 2,
                          shadowColor: Colors.black12,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: Colors.white,
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1A3A5C,
                                  ).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.folder_open_rounded,
                                  color: Color(0xFF1A3A5C),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                category['name'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: fontMulishBold,
                                  color: Color(0xFF1A3A5C),
                                ),
                              ),
                              children: [
                                StreamBuilder<dynamic>(
                                  stream: controller.getMenuItemsStream(
                                    category.id,
                                  ),
                                  builder: (context, itemSnapshot) {
                                    if (!itemSnapshot.hasData) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }

                                    final items =
                                        (itemSnapshot.data as QuerySnapshot)
                                            .docs;

                                    if (items.isEmpty) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 16,
                                        ),
                                        child: Text(
                                          "No items in this category",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: fontMulishRegular,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      );
                                    }

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      color: Colors.grey.shade50,
                                      child: Column(
                                        children: items.map((item) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item['name'],
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontFamily:
                                                          fontMulishSemiBold,
                                                      color: Color(0xFF1A3A5C),
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  "₹${item['price']}",
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontFamily: fontMulishBold,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    color: Colors.red,
                                                    size: 18,
                                                  ),
                                                  onPressed: () =>
                                                      controller.deleteMenuItem(
                                                        category.id,
                                                        item.id,
                                                      ),
                                                  constraints:
                                                      const BoxConstraints(),
                                                  padding: EdgeInsets.zero,
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    );
                                  },
                                ),
                              ],
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
