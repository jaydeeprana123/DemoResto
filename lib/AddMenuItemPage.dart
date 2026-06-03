import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/Widgets/setup_page_layout.dart';
import 'package:flutter/material.dart';

import 'Styles/my_font.dart';

class AddMenuItemPage extends StatefulWidget {
  const AddMenuItemPage({super.key});

  @override
  State<AddMenuItemPage> createState() => _AddMenuItemPageState();
}

class _AddMenuItemPageState extends State<AddMenuItemPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isAdding = false;

  Future<void> _addMenuItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _isAdding = true);
    try {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item added to $_selectedCategoryName'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteMenuItem(
    String categoryId,
    String itemId,
    String itemName,
  ) async {
    final confirmed = await SetupPageStyle.confirmDelete(
      context,
      title: 'Delete Menu Item',
      message: "Are you sure you want to delete '$itemName'?",
    );
    if (confirmed != true || !mounted) return;

    await FirebaseFirestore.instance
        .collection('menus')
        .doc(categoryId)
        .collection('items')
        .doc(itemId)
        .delete();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SetupPageLayout(
      appBarTitle: 'Menu Items',
      wideTitle: 'Menu Items',
      wideSubtitle: 'Add dishes and prices under each category',
      panelTitle: 'Menu\nItems',
      panelSubtitle: 'Build your restaurant menu with\n'
          'items, prices, and categories.',
      panelIllustration: SetupPageStyle.panelIllustration(
        centerIcon: Icons.restaurant_rounded,
        rightIcon: Icons.attach_money_rounded,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SetupPageStyle.label('Category'),
                const SizedBox(height: 8),
                _buildCategoryDropdown(),
                const SizedBox(height: 16),
                SetupPageStyle.label('Item Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter item name'
                      : null,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: fontMulishRegular,
                    color: SetupPageColors.navy,
                  ),
                  decoration: SetupPageStyle.inputDecoration(
                    hint: 'e.g. Chicken Biryani',
                    icon: Icons.restaurant_outlined,
                  ),
                ),
                const SizedBox(height: 16),
                SetupPageStyle.label('Price (₹)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter price';
                    }
                    final price = double.tryParse(value.trim());
                    if (price == null || price < 0) {
                      return 'Enter a valid price';
                    }
                    return null;
                  },
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: fontMulishRegular,
                    color: SetupPageColors.navy,
                  ),
                  decoration: SetupPageStyle.inputDecoration(
                    hint: 'e.g. 250',
                    icon: Icons.currency_rupee_rounded,
                  ),
                ),
                const SizedBox(height: 16),
                _isAdding
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: SetupPageColors.orange,
                        ),
                      )
                    : SetupPageStyle.primaryButton(
                        label: 'Add Menu Item',
                        icon: Icons.add_rounded,
                        onTap: _addMenuItem,
                      ),
              ],
            ),
          ),
          SetupPageStyle.sectionDivider('menu by category'),
          Expanded(child: _buildMenuList()),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('menus')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SetupPageColors.orange,
                ),
              ),
            ),
          );
        }

        final categories = snapshot.data?.docs ?? [];

        if (categories.isEmpty) {
          return SetupPageStyle.listCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'No categories yet. Add categories first.',
                style: TextStyle(
                  fontFamily: fontMulishRegular,
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          );
        }

        return DropdownButtonFormField<String>(
          value: _selectedCategoryId,
          decoration: SetupPageStyle.inputDecoration(
            hint: 'Select category',
            icon: Icons.folder_outlined,
          ),
          items: categories.map((doc) {
            final name = doc.data()['name']?.toString() ?? '';
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(
                name,
                style: const TextStyle(
                  fontFamily: fontMulishSemiBold,
                  fontSize: 14,
                  color: SetupPageColors.navy,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategoryId = value;
              _selectedCategoryName = categories
                  .firstWhere((doc) => doc.id == value)
                  .data()['name']
                  ?.toString();
            });
          },
          validator: (value) =>
              value == null ? 'Select a category' : null,
        );
      },
    );
  }

  Widget _buildMenuList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('menus')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: SetupPageColors.orange),
          );
        }

        final categories = snapshot.data?.docs ?? [];

        if (categories.isEmpty) {
          return SetupPageStyle.emptyState(
            icon: Icons.restaurant_menu_outlined,
            title: 'No categories found',
            subtitle: 'Create categories before adding items',
          );
        }

        return ListView.separated(
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final category = categories[index];
            final categoryName = category.data()['name']?.toString() ?? '';

            return SetupPageStyle.listCard(
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  leading: SetupPageStyle.leadingIcon(
                    icon: Icons.folder_outlined,
                    color: SetupPageColors.navy,
                  ),
                  title: Text(
                    categoryName,
                    style: const TextStyle(
                      fontFamily: fontMulishSemiBold,
                      fontSize: 15,
                      color: SetupPageColors.navy,
                    ),
                  ),
                  children: [
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('menus')
                          .doc(category.id)
                          .collection('items')
                          .orderBy('createdAt', descending: false)
                          .snapshots(),
                      builder: (context, itemSnapshot) {
                        if (itemSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: SetupPageColors.orange,
                                ),
                              ),
                            ),
                          );
                        }

                        final items = itemSnapshot.data?.docs ?? [];

                        if (items.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'No items in this category',
                              style: TextStyle(
                                fontFamily: fontMulishRegular,
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: items.map((item) {
                            final itemName =
                                item.data()['name']?.toString() ?? '';
                            final price =
                                (item.data()['price'] as num?)?.toDouble() ??
                                0.0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: SetupPageColors.bg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                leading: SetupPageStyle.leadingIcon(
                                  icon: Icons.restaurant_outlined,
                                ),
                                title: Text(
                                  itemName,
                                  style: const TextStyle(
                                    fontFamily: fontMulishSemiBold,
                                    fontSize: 14,
                                    color: SetupPageColors.navy,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '₹${price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontFamily: fontMulishBold,
                                        fontSize: 15,
                                        color: SetupPageColors.navy,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () => _deleteMenuItem(
                                        category.id,
                                        item.id,
                                        itemName,
                                      ),
                                    ),
                                  ],
                                ),
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
    );
  }
}
