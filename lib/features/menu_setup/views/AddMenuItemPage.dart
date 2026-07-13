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
  Future<void> _openAddItemSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AddMenuItemSheet(),
    );
    if (added == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu item added')),
      );
    }
  }

  Widget _buildPriceLabel(Map<String, dynamic> data) {
    final variants = data['variants'];
    if (variants is List && variants.isNotEmpty) {
      final prices = variants
          .whereType<Map>()
          .map((v) => (v['price'] as num?)?.toDouble() ?? 0.0)
          .map((p) => '₹${p.toStringAsFixed(0)}')
          .join(' / ');
      return Text(
        prices,
        textAlign: TextAlign.end,
        style: const TextStyle(
          fontFamily: fontMulishBold,
          fontSize: 13,
          color: SetupPageColors.navy,
        ),
      );
    }

    final isHalfFull = data['priceType'] == 'half_full' ||
        (data.containsKey('halfPrice') && data.containsKey('fullPrice'));

    if (isHalfFull) {
      final half = (data['halfPrice'] as num?)?.toDouble() ?? 0.0;
      final full = (data['fullPrice'] as num?)?.toDouble() ?? 0.0;
      return Text(
        '₹${half.toStringAsFixed(0)} / ₹${full.toStringAsFixed(0)}',
        style: const TextStyle(
          fontFamily: fontMulishBold,
          fontSize: 13,
          color: SetupPageColors.navy,
        ),
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
  Widget build(BuildContext context) {
    return SetupPageLayout(
      appBarTitle: 'Menu Items',
      wideTitle: 'Menu Items',
      wideSubtitle: 'Browse and manage dishes by category',
      panelTitle: 'Menu\nItems',
      panelSubtitle: 'Build your restaurant menu with\n'
          'items, prices, and categories.',
      panelIllustration: SetupPageStyle.panelIllustration(
        centerIcon: Icons.restaurant_rounded,
        rightIcon: Icons.attach_money_rounded,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SetupPageColors.orange,
        foregroundColor: Colors.white,
        onPressed: _openAddItemSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Item',
          style: TextStyle(fontFamily: fontMulishSemiBold),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SetupPageStyle.sectionDivider('menu by category'),
          Expanded(child: _buildMenuList()),
        ],
      ),
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
          padding: const EdgeInsets.only(bottom: 88),
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
                  initiallyExpanded: index == 0,
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
                                    Flexible(child: _buildPriceLabel(itemData)),
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

class _AddMenuItemSheet extends StatefulWidget {
  const _AddMenuItemSheet();

  @override
  State<_AddMenuItemSheet> createState() => _AddMenuItemSheetState();
}

class _AddMenuItemSheetState extends State<_AddMenuItemSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _halfPriceController = TextEditingController();
  final _fullPriceController = TextEditingController();
  bool _halfFullPricing = false;
  bool _isAdding = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _halfPriceController.dispose();
    _fullPriceController.dispose();
    super.dispose();
  }

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
        data['price'] = fullPrice;
      } else {
        data['priceType'] = 'single';
        data['price'] = double.tryParse(_priceController.text.trim()) ?? 0.0;
      }

      await itemsRef.add(data);
      await MenuRevision.bumpRevision();

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add item: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
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
          validator: (value) => value == null ? 'Select a category' : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add Menu Item',
                        style: TextStyle(
                          fontFamily: fontMulishBold,
                          fontSize: 18,
                          color: SetupPageColors.navy,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SetupPageStyle.label('Category'),
                        const SizedBox(height: 8),
                        _buildCategoryDropdown(),
                        if (_selectedCategoryName != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Adding to $_selectedCategoryName',
                            style: TextStyle(
                              fontFamily: fontMulishRegular,
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SetupPageStyle.label('Item Name'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
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
                        const SizedBox(height: 20),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
