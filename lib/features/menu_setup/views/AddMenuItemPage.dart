import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/features/menu_setup/services/menu_revision.dart';
import 'package:demo/features/menu_setup/utils/menu_sort_utils.dart';
import 'package:demo/features/menu_setup/widgets/setup_page_layout.dart';
import 'package:flutter/material.dart';

import 'package:demo/Styles/my_font.dart';

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
  final _halfPriceController = TextEditingController();
  final _fullPriceController = TextEditingController();
  bool _halfFullPricing = false;
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
      final itemsRef = FirestorePaths.scopedSubCollection(
        'menus',
        _selectedCategoryId!,
        'items',
      );
      final sortOrder = await nextSortOrder(itemsRef);

      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'sortOrder': sortOrder,
        'inStock': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_halfFullPricing) {
        final halfPrice =
            double.tryParse(_halfPriceController.text.trim()) ?? 0.0;
        final fullPrice =
            double.tryParse(_fullPriceController.text.trim()) ?? 0.0;
        data['priceType'] = 'half_full';
        data['halfPrice'] = halfPrice;
        data['fullPrice'] = fullPrice;
        // Keep `price` populated (full portion) for backward compatibility
        // with screens that read a single price.
        data['price'] = fullPrice;
      } else {
        data['priceType'] = 'single';
        data['price'] = double.tryParse(_priceController.text.trim()) ?? 0.0;
      }

      await itemsRef.add(data);
      await MenuRevision.bumpRevision();

      _nameController.clear();
      _priceController.clear();
      _halfPriceController.clear();
      _fullPriceController.clear();
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

  Widget _buildPriceLabel(Map<String, dynamic> data) {
    final isHalfFull = data['priceType'] == 'half_full';

    if (isHalfFull) {
      final half = (data['halfPrice'] as num?)?.toDouble() ?? 0.0;
      final full = (data['fullPrice'] as num?)?.toDouble() ?? 0.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          _portionPriceRow('Half', half),
          const SizedBox(height: 2),
          _portionPriceRow('Full', full),
        ],
      );
    }

    final price = (data['price'] as num?)?.toDouble() ?? 0.0;
    return Text(
      '₹${price.toStringAsFixed(0)}',
      style: const TextStyle(
        fontFamily: fontMulishBold,
        fontSize: 15,
        color: SetupPageColors.navy,
      ),
    );
  }

  Widget _portionPriceRow(String label, double price) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(
            fontFamily: fontMulishSemiBold,
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
        Text(
          '₹${price.toStringAsFixed(0)}',
          style: const TextStyle(
            fontFamily: fontMulishBold,
            fontSize: 14,
            color: SetupPageColors.navy,
          ),
        ),
      ],
    );
  }

  String? _priceValidator(String? value, {required String label}) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter $label';
    }
    final price = double.tryParse(value.trim());
    if (price == null || price < 0) {
      return 'Enter a valid $label';
    }
    return null;
  }

  Widget _buildPricingModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _pricingModeOption(label: 'Normal Price', halfFull: false),
          _pricingModeOption(label: 'Half + Full', halfFull: true),
        ],
      ),
    );
  }

  Widget _pricingModeOption({required String label, required bool halfFull}) {
    final selected = _halfFullPricing == halfFull;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_halfFullPricing == halfFull) return;
          setState(() => _halfFullPricing = halfFull);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? SetupPageColors.orange : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontFamily: fontMulishSemiBold,
              color: selected ? Colors.white : SetupPageColors.navy,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSinglePriceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SetupPageStyle.label('Price (₹)'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) => _priceValidator(value, label: 'price'),
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
      ],
    );
  }

  Widget _buildHalfFullPriceFields() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SetupPageStyle.label('Half Price (₹)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _halfPriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) =>
                    _priceValidator(value, label: 'half price'),
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: fontMulishRegular,
                  color: SetupPageColors.navy,
                ),
                decoration: SetupPageStyle.inputDecoration(
                  hint: 'e.g. 150',
                  icon: Icons.currency_rupee_rounded,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SetupPageStyle.label('Full Price (₹)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _fullPriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) =>
                    _priceValidator(value, label: 'full price'),
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
            ],
          ),
        ),
      ],
    );
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

    await FirestorePaths
        .scopedSubCollection('menus', categoryId, 'items')
        .doc(itemId)
        .delete();
    await MenuRevision.bumpRevision();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _halfPriceController.dispose();
    _fullPriceController.dispose();
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
                SetupPageStyle.label('Pricing'),
                const SizedBox(height: 8),
                _buildPricingModeToggle(),
                const SizedBox(height: 16),
                if (_halfFullPricing)
                  _buildHalfFullPriceFields()
                else
                  _buildSinglePriceField(),
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
      stream: FirestorePaths.scoped('menus').snapshots(),
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

        final categories = sortMenuDocs(snapshot.data?.docs ?? []);

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
      stream: FirestorePaths.scoped('menus').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: SetupPageColors.orange),
          );
        }

        final categories = sortMenuDocs(snapshot.data?.docs ?? []);

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
                      stream: FirestorePaths
                          .scopedSubCollection('menus', category.id, 'items')
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

                        final items =
                            sortMenuDocs(itemSnapshot.data?.docs ?? []);

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
                            final itemData = item.data();
                            final itemName =
                                itemData['name']?.toString() ?? '';

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
                                    _buildPriceLabel(itemData),
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
