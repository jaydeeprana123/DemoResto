import 'package:demo/features/menu_setup/services/menu_cache_service.dart';
import 'package:demo/features/menu_setup/utils/menu_stock_utils.dart';
import 'package:demo/features/menu_setup/widgets/setup_page_layout.dart';
import 'package:demo/features/transactions/repositories/transactions_repository.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Bottom sheet to pick a menu item when editing a transaction.
class AddMenuItemSheet extends StatefulWidget {
  const AddMenuItemSheet({
    required this.onItemSelected,
    super.key,
  });

  final void Function(Map<String, dynamic> item) onItemSelected;

  @override
  State<AddMenuItemSheet> createState() => _AddMenuItemSheetState();
}

class _AddMenuItemSheetState extends State<AddMenuItemSheet> {
  bool _loading = true;
  String? _error;
  final Map<String, List<Map<String, dynamic>>> _menuByCategory = {};

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    try {
      final cachedMenu =
          await Get.find<MenuCacheService>().loadFromCacheOnly();

      final grouped = <String, List<Map<String, dynamic>>>{};
      final categoryOrder = <String, int>{};

      for (final item in cachedMenu) {
        final category = item['category']?.toString() ?? '';
        final name = item['name']?.toString() ?? '';
        if (category.isEmpty || name.isEmpty) continue;

        categoryOrder.putIfAbsent(
          category,
          () => (item['categorySortOrder'] as num?)?.toInt() ?? 9999,
        );
        grouped.putIfAbsent(category, () => []).add({
          'name': name,
          'price': item['price'],
          'inStock': MenuStockUtils.isInStockFromItem(item),
          'itemSortOrder': (item['itemSortOrder'] as num?)?.toInt() ?? 9999,
        });
      }

      for (final items in grouped.values) {
        items.sort(
          (a, b) => (a['itemSortOrder'] as int).compareTo(
            b['itemSortOrder'] as int,
          ),
        );
      }

      final sortedGrouped = <String, List<Map<String, dynamic>>>{};
      final sortedNames = grouped.keys.toList()
        ..sort(
          (a, b) => (categoryOrder[a] ?? 9999).compareTo(categoryOrder[b] ?? 9999),
        );
      for (final name in sortedNames) {
        sortedGrouped[name] = grouped[name]!;
      }

      if (!mounted) return;
      setState(() {
        _menuByCategory
          ..clear()
          ..addAll(sortedGrouped);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _selectItem(Map<String, dynamic> item) {
    if (!MenuStockUtils.isInStockFromItem(item)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This item is out of stock and cannot be added.'),
        ),
      );
      return;
    }
    widget.onItemSelected({
      'name': item['name'],
      'price': item['price'],
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return SafeArea(
      child: SizedBox(
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add from menu',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: fontMulishBold,
                        color: SetupPageColors.navy,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: SetupPageColors.orange),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade700),
          ),
        ),
      );
    }

    if (_menuByCategory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Saved menu not found.\nOpen the Dashboard once to load the menu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: fontMulishRegular,
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    final categories = _menuByCategory.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final items = _menuByCategory[category]!;

        return SetupPageStyle.listCard(
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: index == 0,
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              title: Text(
                category,
                style: const TextStyle(
                  fontFamily: fontMulishSemiBold,
                  fontSize: 14,
                  color: SetupPageColors.navy,
                ),
              ),
              children: items.map((item) {
                final price = transactionAsInt(item['price']);
                final name = item['name']?.toString() ?? '';
                final inStock = MenuStockUtils.isInStockFromItem(item);

                return ListTile(
                  dense: true,
                  enabled: inStock,
                  title: Text(
                    name,
                    style: TextStyle(
                      fontFamily: fontMulishRegular,
                      fontSize: 14,
                      color: inStock ? null : Colors.grey.shade500,
                      decoration:
                          inStock ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: inStock
                      ? null
                      : Text(
                          'Out of stock',
                          style: TextStyle(
                            fontFamily: fontMulishSemiBold,
                            fontSize: 11,
                            color: Colors.red.shade600,
                          ),
                        ),
                  trailing: Text(
                    '₹$price',
                    style: TextStyle(
                      fontFamily: fontMulishBold,
                      fontSize: 13,
                      color: inStock
                          ? SetupPageColors.orange
                          : Colors.grey.shade400,
                    ),
                  ),
                  onTap: inStock ? () => _selectItem(item) : null,
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
