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
          content: Text("Category added"),
          backgroundColor: _orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navyDk,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Expanded(
              child: Text(
                "Manage Categories",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: fontMulishBold,
                ),
              ),
            ),
            // ── Import Menu button ──────────────────────────────────────
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Get.to(() => const MenuSeederPage());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined,
                        size: 16, color: Colors.greenAccent),
                    const SizedBox(width: 4),
                    Text(
                      "Import",
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: fontMulishSemiBold,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // ── Add Menu Item button ────────────────────────────────────
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Get.to(AddMenuItemPage());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _orange.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle, size: 16, color: _orange),
                    const SizedBox(width: 4),
                    Text(
                      "Menu",
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: fontMulishSemiBold,
                        color: _orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_navy, _navyDk],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Add Category Card ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
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
                        color: Colors.white,
                        fontSize: 15,
                        fontFamily: fontMulishBold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: fontMulishSemiBold,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        labelText: "Category Name",
                        labelStyle: const TextStyle(
                          color: Colors.white60,
                          fontFamily: fontMulishRegular,
                          fontSize: 13,
                        ),
                        hintText: 'e.g. Starters, Beverages',
                        hintStyle: const TextStyle(
                          color: Colors.white30,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.category_outlined,
                          color: Colors.white54,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.08),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _orange, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addCategory,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(
                          "Add Category",
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: fontMulishSemiBold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 4,
                          shadowColor: _orange.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  "Existing Categories",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontFamily: fontMulishSemiBold,
                    letterSpacing: 0.5,
                  ),
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
                            const Icon(Icons.category_outlined,
                                color: Colors.white24, size: 56),
                            const SizedBox(height: 12),
                            Text(
                              "No categories yet",
                              style: TextStyle(
                                color: Colors.white38,
                                fontFamily: fontMulishRegular,
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
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _orange.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.fastfood_outlined,
                                  color: _orange, size: 20),
                            ),
                            title: Text(
                              category['name'],
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontFamily: fontMulishSemiBold,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent, size: 22),
                              onPressed: () {
                                FirebaseFirestore.instance
                                    .collection('menus')
                                    .doc(category.id)
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
