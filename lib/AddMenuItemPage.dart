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

  // ── Helper: dark themed text field ──────────────────────────────────────
  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: fontMulishSemiBold,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.white60,
          fontFamily: fontMulishRegular,
          fontSize: 13,
        ),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
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
      backgroundColor: _navyDk,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Add Menu Item",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontFamily: fontMulishBold,
          ),
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
              // ── Add Item Form Card ──────────────────────────────────────
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
                      "New Menu Item",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontFamily: fontMulishBold,
                      ),
                    ),
                    const SizedBox(height: 14),

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
                          dropdownColor: _cardBg,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: fontMulishSemiBold,
                            fontSize: 14,
                          ),
                          iconEnabledColor: Colors.white54,
                          decoration: InputDecoration(
                            labelText: "Select Category",
                            labelStyle: const TextStyle(
                              color: Colors.white60,
                              fontFamily: fontMulishRegular,
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: fontMulishSemiBold,
                                ),
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
                  "Menu by Category",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontFamily: fontMulishSemiBold,
                    letterSpacing: 0.5,
                  ),
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
                            color: Colors.white38,
                            fontFamily: fontMulishRegular,
                            fontSize: 15,
                          ),
                        ),
                      );
                    }

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
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              tilePadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _orange.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.fastfood_outlined,
                                    color: _orange, size: 18),
                              ),
                              title: Text(
                                category['name'],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontFamily: fontMulishSemiBold,
                                ),
                              ),
                              iconColor: Colors.white54,
                              collapsedIconColor: Colors.white38,
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
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          "No items in this category",
                                          style: TextStyle(
                                            color: Colors.white38,
                                            fontFamily: fontMulishRegular,
                                            fontSize: 13,
                                          ),
                                        ),
                                      );
                                    }

                                    return Column(
                                      children: items.map((item) {
                                        return Container(
                                          margin: const EdgeInsets.only(
                                              left: 16,
                                              right: 16,
                                              bottom: 8),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withOpacity(0.06),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.circle,
                                                  size: 6,
                                                  color: _orange),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  item['name'],
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontFamily:
                                                        fontMulishSemiBold,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                "₹${item['price']}",
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 13,
                                                  fontFamily: fontMulishMedium,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () {
                                                  FirebaseFirestore.instance
                                                      .collection('menus')
                                                      .doc(category.id)
                                                      .collection('items')
                                                      .doc(item.id)
                                                      .delete();
                                                },
                                                child: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.redAccent,
                                                    size: 18),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
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
