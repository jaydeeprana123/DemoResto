import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartKitchen/core/firestore/firestore_paths.dart';
import 'package:smartKitchen/features/menu_setup/services/menu_revision.dart';
import 'package:smartKitchen/features/menu_setup/utils/menu_sort_utils.dart';
import 'package:smartKitchen/features/menu_setup/widgets/setup_page_layout.dart';
import 'package:flutter/material.dart';

import 'package:smartKitchen/Styles/my_font.dart';

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

  Future<void> _openEditItemSheet({
    required String categoryId,
    required String categoryName,
    required String itemId,
    required Map<String, dynamic> itemData,
  }) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddMenuItemSheet(
        categoryId: categoryId,
        categoryName: categoryName,
        itemId: itemId,
        initialData: itemData,
      ),
    );
    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu item updated')),
      );
    }
  }

  Widget _buildPriceLabel(Map<String, dynamic> data) {
    final variants = data['variants'];
    if (variants is List && variants.isNotEmpty) {
      final prices = variants.whereType<Map>().map((v) {
        final label = v['label']?.toString().trim() ?? '';
        final price =
            '₹${((v['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}';
        return label.isEmpty ? price : '$label $price';
      }).join(' / ');
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
                                      tooltip: 'Edit',
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: SetupPageColors.navy,
                                        size: 20,
                                      ),
                                      onPressed: () => _openEditItemSheet(
                                        categoryId: category.id,
                                        categoryName: categoryName,
                                        itemId: item.id,
                                        itemData: Map<String, dynamic>.from(
                                          itemData,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete',
                                      visualDensity: VisualDensity.compact,
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

enum _PricingMode { single, halfFull, variants }

class _VariantColumnHeader extends StatelessWidget {
  const _VariantColumnHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontFamily: fontMulishSemiBold,
        color: Colors.grey.shade600,
      ),
    );
  }
}

class _AddMenuItemSheet extends StatefulWidget {
  const _AddMenuItemSheet({
    this.categoryId,
    this.categoryName,
    this.itemId,
    this.initialData,
  });

  final String? categoryId;
  final String? categoryName;
  final String? itemId;
  final Map<String, dynamic>? initialData;

  bool get isEditing => itemId != null && categoryId != null;

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
  final List<TextEditingController> _variantLabelControllers = [];
  final List<TextEditingController> _variantPriceControllers = [];
  _PricingMode _pricingMode = _PricingMode.single;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    if (data == null) return;

    _selectedCategoryId = widget.categoryId;
    _selectedCategoryName = widget.categoryName;
    _nameController.text = data['name']?.toString() ?? '';

    final rawVariants = data['variants'];
    if (rawVariants is List && rawVariants.isNotEmpty) {
      for (final entry in rawVariants.whereType<Map>()) {
        _variantLabelControllers.add(
          TextEditingController(text: entry['label']?.toString() ?? ''),
        );
        _variantPriceControllers.add(
          TextEditingController(text: _formatPrice(entry['price'])),
        );
      }
      _pricingMode = _PricingMode.variants;
      return;
    }

    final isHalfFull = data['priceType'] == 'half_full' ||
        (data.containsKey('halfPrice') && data.containsKey('fullPrice'));
    if (isHalfFull) {
      _pricingMode = _PricingMode.halfFull;
      _halfPriceController.text = _formatPrice(data['halfPrice']);
      _fullPriceController.text = _formatPrice(data['fullPrice']);
    } else {
      _priceController.text = _formatPrice(data['price']);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _halfPriceController.dispose();
    _fullPriceController.dispose();
    for (final controller in _variantLabelControllers) {
      controller.dispose();
    }
    for (final controller in _variantPriceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _formatPrice(dynamic value) {
    final price = (value as num?)?.toDouble();
    if (price == null) return '';
    if (price == price.roundToDouble()) return price.toInt().toString();
    return price.toString();
  }

  Map<String, dynamic> _pricingPayload(String name) {
    switch (_pricingMode) {
      case _PricingMode.halfFull:
        final halfPrice =
            double.tryParse(_halfPriceController.text.trim()) ?? 0.0;
        final fullPrice =
            double.tryParse(_fullPriceController.text.trim()) ?? 0.0;
        return {
          'priceType': 'half_full',
          'halfPrice': halfPrice,
          'fullPrice': fullPrice,
          'price': fullPrice,
        };
      case _PricingMode.variants:
        final labels = [
          for (final controller in _variantLabelControllers)
            controller.text.trim(),
        ];
        final variants = <Map<String, dynamic>>[];
        final usedNames = <String>{};
        for (var i = 0; i < labels.length; i++) {
          final label = labels[i];
          final price =
              double.tryParse(_variantPriceControllers[i].text.trim()) ?? 0.0;
          var lineName = _variantLineName(name, label, price, labels);
          if (!usedNames.add(lineName)) {
            var suffix = 2;
            while (!usedNames.add('$lineName #$suffix')) {
              suffix++;
            }
            lineName = '$lineName #$suffix';
          }
          variants.add({
            'label': label,
            'price': price,
            'name': lineName,
          });
        }
        return {
          'priceType': 'variants',
          'variants': variants,
          'price': variants.isEmpty ? 0.0 : variants.first['price'],
        };
      case _PricingMode.single:
        return {
          'priceType': 'single',
          'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        };
    }
  }

  Map<String, dynamic> _fieldsForWrite(String name) {
    final fields = <String, dynamic>{
      'name': name,
      ..._pricingPayload(name),
    };
    if (_pricingMode != _PricingMode.halfFull) {
      fields.remove('halfPrice');
      fields.remove('fullPrice');
    }
    if (_pricingMode != _PricingMode.variants) {
      fields.remove('variants');
    }
    return fields;
  }

  Map<String, dynamic> _fieldsForUpdate(String name) {
    final fields = _fieldsForWrite(name);
    if (_pricingMode != _PricingMode.halfFull) {
      fields['halfPrice'] = FieldValue.delete();
      fields['fullPrice'] = FieldValue.delete();
    }
    if (_pricingMode != _PricingMode.variants) {
      fields['variants'] = FieldValue.delete();
    }
    return fields;
  }

  /// Order-line name. Duplicate titles stay distinct by price so each row
  /// can be selected and billed on its own.
  String _variantLineName(
    String itemName,
    String label,
    double price,
    List<String> labels,
  ) {
    final duplicates = labels
        .where((entry) => entry.toLowerCase() == label.toLowerCase())
        .length;
    if (duplicates <= 1) return '$itemName ($label)';
    final priceText = price == price.roundToDouble()
        ? price.toInt().toString()
        : price.toString();
    return '$itemName ($label — ₹$priceText)';
  }

  void _selectPricingMode(_PricingMode mode) {
    if (_pricingMode == mode) return;
    setState(() {
      _pricingMode = mode;
      if (mode == _PricingMode.variants && _variantLabelControllers.isEmpty) {
        _addVariantRow();
      }
    });
  }

  void _addVariantRow() {
    _variantLabelControllers.add(TextEditingController());
    _variantPriceControllers.add(TextEditingController());
  }

  void _removeVariantRow(int index) {
    setState(() {
      _variantLabelControllers.removeAt(index).dispose();
      _variantPriceControllers.removeAt(index).dispose();
    });
  }

  Future<void> _saveMenuItem() async {
    if (_pricingMode == _PricingMode.variants &&
        _variantLabelControllers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one variant')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final name = _nameController.text.trim();
      if (widget.isEditing) {
        await _updateMenuItem(name);
      } else {
        await _createMenuItem(name);
      }
      await MenuRevision.bumpRevision();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Could not update item: $e'
                  : 'Could not add item: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _createMenuItem(String name) async {
    final itemsRef = FirestorePaths.scopedSubCollection(
      'menus',
      _selectedCategoryId!,
      'items',
    );
    final sortOrder = await nextSortOrder(itemsRef);
    await itemsRef.add({
      'name': name,
      'sortOrder': sortOrder,
      'inStock': true,
      'createdAt': FieldValue.serverTimestamp(),
      ..._pricingPayload(name),
    });
  }

  Future<void> _updateMenuItem(String name) async {
    final oldRef = FirestorePaths
        .scopedSubCollection('menus', widget.categoryId!, 'items')
        .doc(widget.itemId);

    if (_selectedCategoryId == widget.categoryId) {
      await oldRef.update(_fieldsForUpdate(name));
      return;
    }

    final snapshot = await oldRef.get();
    final existing = Map<String, dynamic>.from(snapshot.data() ?? {});
    existing
      ..remove('halfPrice')
      ..remove('fullPrice')
      ..remove('variants')
      ..addAll(_fieldsForWrite(name));

    final newItems = FirestorePaths.scopedSubCollection(
      'menus',
      _selectedCategoryId!,
      'items',
    );
    existing['sortOrder'] = await nextSortOrder(newItems);

    final batch = FirebaseFirestore.instance.batch();
    batch.set(newItems.doc(), existing);
    batch.delete(oldRef);
    await batch.commit();
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
    final modes = <_PricingMode>[
      _PricingMode.single,
      _PricingMode.halfFull,
      _PricingMode.variants,
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          for (final mode in modes)
            _pricingModeOption(label: _pricingModeLabel(mode), mode: mode),
        ],
      ),
    );
  }

  String _pricingModeLabel(_PricingMode mode) {
    switch (mode) {
      case _PricingMode.single:
        return 'Normal Price';
      case _PricingMode.halfFull:
        return 'Half + Full';
      case _PricingMode.variants:
        return 'Custom\nPrice/Variants';
    }
  }

  Widget _pricingModeOption({
    required String label,
    required _PricingMode mode,
  }) {
    final selected = _pricingMode == mode;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectPricingMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? SetupPageColors.orange : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 12,
              height: 1.15,
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

  InputDecoration _variantFieldDecoration({required String hint, String? prefix}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
      hintStyle: TextStyle(
        color: Colors.grey.shade400,
        fontSize: 13,
        fontFamily: fontMulishRegular,
      ),
      prefixStyle: const TextStyle(
        fontSize: 14,
        fontFamily: fontMulishSemiBold,
        color: SetupPageColors.navy,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
        borderSide: const BorderSide(color: SetupPageColors.orange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
    );
  }

  Widget _buildVariantFields() {
    const fieldStyle = TextStyle(
      fontSize: 14,
      fontFamily: fontMulishRegular,
      color: SetupPageColors.navy,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(flex: 3, child: _VariantColumnHeader('Variant Title')),
            SizedBox(width: 12),
            Expanded(flex: 2, child: _VariantColumnHeader('Price')),
            SizedBox(width: 40),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _variantLabelControllers.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _variantLabelControllers[i],
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Enter title'
                          : null,
                  style: fieldStyle,
                  decoration: _variantFieldDecoration(hint: 'e.g. 250 gm'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _variantPriceControllers[i],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) => _priceValidator(value, label: 'price'),
                  style: fieldStyle,
                  decoration: _variantFieldDecoration(
                    hint: '100',
                    prefix: '₹ ',
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                height: 48,
                child: IconButton(
                  tooltip: 'Remove',
                  padding: EdgeInsets.zero,
                  onPressed: () => _removeVariantRow(i),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(_addVariantRow),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Add More',
              style: TextStyle(
                fontSize: 14,
                fontFamily: fontMulishSemiBold,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: SetupPageColors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
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
                    Expanded(
                      child: Text(
                        widget.isEditing ? 'Edit Menu Item' : 'Add Menu Item',
                        style: const TextStyle(
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
                            widget.isEditing
                                ? 'Updating in $_selectedCategoryName'
                                : 'Adding to $_selectedCategoryName',
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
                        if (_pricingMode == _PricingMode.halfFull)
                          _buildHalfFullPriceFields()
                        else if (_pricingMode == _PricingMode.variants)
                          _buildVariantFields()
                        else
                          _buildSinglePriceField(),
                        const SizedBox(height: 20),
                        _isSaving
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: SetupPageColors.orange,
                                ),
                              )
                            : SetupPageStyle.primaryButton(
                                label: widget.isEditing
                                    ? 'Save Changes'
                                    : 'Add Menu Item',
                                icon: widget.isEditing
                                    ? Icons.check_rounded
                                    : Icons.add_rounded,
                                onTap: _saveMenuItem,
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
