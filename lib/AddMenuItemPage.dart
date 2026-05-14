import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'Styles/my_font.dart';

// Same brand colours as login screen
const _navy   = Color(0xFF1A3A5C);
const _navyDk = Color(0xFF0D2137);
const _orange = Color(0xFFf57c35);
const _cardBg = Color(0xFF1E4570);

class AddMenuItemPage extends StatefulWidget {
  @override
  _AddMenuItemPageState createState() => _AddMenuItemPageState();
}

class _AddMenuItemPageState extends State<AddMenuItemPage> {
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  Future<void> _addMenuItem() async {
    if (_selectedCategoryId == null ||
        _nameController.text.trim().isEmpty ||
        _priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please fill all fields and select a category"),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('menus')
        .doc(_selectedCategoryId)
        .collection('items')
        .add({
      'name': _nameController.text.trim(),
      'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _nameController.clear();
    _priceController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Item added to '$_selectedCategoryName'"),
        backgroundColor: _orange,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _deleteMenuItem(String categoryId, String itemId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Delete Item",
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
      await FirebaseFirestore.instance
          .collection('menus')
          .doc(categoryId)
          .collection('items')
          .doc(itemId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Item '$name' deleted"),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── Helper: styled light themed text field ──────────────────────────────
  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: _navy,
        fontFamily: fontMulishSemiBold,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey.shade500,
          fontFamily: fontMulishMedium,
          fontSize: 13,
        ),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          borderSide: const BorderSide(color: _orange, width: 1.5),
        ),
      ),
    );
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
          "Manage Menu Items",
          style: TextStyle(
            color: _navy,
            fontSize: 18,
            fontFamily: fontMulishBold,
          ),
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Add Item Form Card ──────────────────────────────────────
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
                    "Add New Item",
                    style: TextStyle(
                      color: _navy,
                      fontSize: 15,
                      fontFamily: fontMulishBold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Category Dropdown ───────────────────────────────
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('menus')
                        .orderBy('createdAt', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child:
                                CircularProgressIndicator(color: _orange));
                      }

                      final categories = snapshot.data!.docs;

                      return DropdownButtonFormField<String>(
                        dropdownColor: Colors.white,
                        elevation: 2,
                        style: const TextStyle(
                          color: _navy,
                          fontFamily: fontMulishSemiBold,
                          fontSize: 14,
                        ),
                        iconEnabledColor: Colors.grey.shade400,
                        decoration: InputDecoration(
                          labelText: "Select Category",
                          labelStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontFamily: fontMulishMedium,
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
                            borderSide: const BorderSide(
                                color: _orange, width: 1.5),
                          ),
                        ),
                        value: _selectedCategoryId,
                        items: categories.map((doc) {
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(
                              doc['name'],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategoryId = value;
                            _selectedCategoryName =
                                categories.firstWhere(
                              (doc) => doc.id == value,
                            )['name'];
                          });
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // ── Item Name ───────────────────────────────────────
                  _field(
                    controller: _nameController,
                    label: "Item Name",
                    hint: "e.g. Chicken Biryani",
                    icon: Icons.fastfood_outlined,
                  ),
                  const SizedBox(height: 12),

                  // ── Price ───────────────────────────────────────────
                  _field(
                    controller: _priceController,
                    label: "Price (₹)",
                    hint: "e.g. 180",
                    icon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // ── Add Button ──────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addMenuItem,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        "Add Menu Item",
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
                    "MENU BY CATEGORY",
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

            // ── Category + Items Expanded List ──────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('menus')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(color: _orange));
                  }

                  final categories = snapshot.data!.docs;

                  if (categories.isEmpty) {
                    return Center(
                      child: Text(
                        "No categories found",
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontFamily: fontMulishSemiBold,
                          fontSize: 15,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: categories.length,
                    padding: const EdgeInsets.only(bottom: 20),
                    itemBuilder: (context, index) {
                      final category = categories[index];

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
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            tilePadding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _navy.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.folder_open_rounded,
                                  color: _navy, size: 20),
                            ),
                            title: Text(
                              category['name'],
                              style: TextStyle(
                                color: _navy,
                                fontSize: 15,
                                fontFamily: fontMulishBold,
                              ),
                            ),
                            iconColor: _navy,
                            collapsedIconColor: Colors.grey.shade400,
                            children: [
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('menus')
                                    .doc(category.id)
                                    .collection('items')
                                    .orderBy('createdAt', descending: false)
                                    .snapshots(),
                                builder: (context, itemSnapshot) {
                                  if (!itemSnapshot.hasData) {
                                    return const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                            color: _orange),
                                      ),
                                    );
                                  }

                                  final items = itemSnapshot.data!.docs;

                                  if (items.isEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        "No items in this category",
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontFamily: fontMulishRegular,
                                          fontSize: 13,
                                        ),
                                      ),
                                    );
                                  }

                                  return Column(
                                    children: items.map((item) {
                                      final itemName = item['name'] ?? '';
                                      return Container(
                                        margin: const EdgeInsets.only(
                                            left: 16,
                                            right: 16,
                                            bottom: 8),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(color: Colors.grey.shade100),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: const BoxDecoration(
                                                color: _orange,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                itemName,
                                                style: TextStyle(
                                                  color: _navy,
                                                  fontSize: 14,
                                                  fontFamily:
                                                      fontMulishSemiBold,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              "₹${item['price']}",
                                              style: TextStyle(
                                                color: _orange,
                                                fontSize: 14,
                                                fontFamily: fontMulishBold,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            GestureDetector(
                                              onTap: () => _deleteMenuItem(category.id, item.id, itemName),
                                              child: Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: Colors.red.shade300,
                                                  size: 20),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
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
    );
  }
}

