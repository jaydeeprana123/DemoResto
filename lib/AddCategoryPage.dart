import 'package:demo/AddMenuItemPage.dart';
import 'package:demo/MenuSeederPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import 'Styles/my_font.dart';

// Same brand colours as login screen
const _navy   = Color(0xFF1A3A5C);
const _navyDk = Color(0xFF0D2137);
const _orange = Color(0xFFf57c35);
const _cardBg = Color(0xFF1E4570);

class AddCategoryPage extends StatefulWidget {
  @override
  _AddCategoryPageState createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends State<AddCategoryPage> {
  final TextEditingController _nameController = TextEditingController();

  Future<void> _addCategory() async {
    if (_nameController.text.trim().isEmpty) return;

    await FirebaseFirestore.instance.collection('menus').add({
      'name': _nameController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    }).then((docRef) {
      _nameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Category added successfully"),
          backgroundColor: _orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    });
  }

  Future<void> _deleteCategory(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Delete Category",
          style: TextStyle(color: _navy, fontFamily: fontMulishBold),
        ),
        content: Text(
          "Are you sure you want to delete '$name'?",
          style: TextStyle(color: Colors.black87, fontFamily: fontMulishRegular),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text("Cancel",
                style: TextStyle(color: Colors.grey.shade600, fontFamily: fontMulishSemiBold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text("Delete",
                style: TextStyle(fontFamily: fontMulishSemiBold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('menus').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Category '$name' deleted"),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: _navy),
        title: Text(
          "Manage Categories",
          style: TextStyle(
            color: _navy,
            fontSize: 18,
            fontFamily: fontMulishBold,
          ),
        ),
        actions: [
          // ── Import Menu button ──────────────────────────────────────
          TextButton.icon(
            onPressed: () => Get.to(() => const MenuSeederPage()),
            icon: const Icon(Icons.cloud_upload_outlined, size: 18, color: Colors.green),
            label: const Text(
              "Import",
              style: TextStyle(
                fontSize: 13,
                fontFamily: fontMulishBold,
                color: Colors.green,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.to(AddMenuItemPage()),
        backgroundColor: _navy,
        icon: const Icon(Icons.add_shopping_cart, size: 20, color: Colors.white),
        label: const Text(
          "Manage Items",
          style: TextStyle(color: Colors.white, fontFamily: fontMulishBold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Add Category Card ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Add New Category",
                    style: TextStyle(
                      color: _navy,
                      fontSize: 15,
                      fontFamily: fontMulishBold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(
                      color: _navy,
                      fontFamily: fontMulishSemiBold,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      labelText: "Category Name",
                      labelStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontFamily: fontMulishMedium,
                        fontSize: 13,
                      ),
                      hintText: 'e.g. Starters, Beverages',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.category_outlined,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: _orange, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addCategory,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        "Add Category",
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: fontMulishBold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                        shadowColor: _orange.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _orange,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "EXISTING CATEGORIES",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontFamily: fontMulishBold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // ── Category List ─────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('menus')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _orange),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.category_outlined,
                              color: Colors.grey.shade300, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            "No categories found",
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontFamily: fontMulishSemiBold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final categories = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: categories.length,
                    padding: const EdgeInsets.only(bottom: 80),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final name = category['name'] ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.fastfood_rounded,
                                color: _orange, size: 22),
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              color: _navy,
                              fontSize: 15,
                              fontFamily: fontMulishBold,
                            ),
                          ),
                          subtitle: Text(
                            "Menu Category",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontFamily: fontMulishRegular,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline_rounded,
                                color: Colors.red.shade300, size: 24),
                            onPressed: () => _deleteCategory(category.id, name),
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
    );
  }
}
id)
                                    .delete();
                              },
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
