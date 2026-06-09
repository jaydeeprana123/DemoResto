import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/features/menu_setup/utils/menu_sort_utils.dart';
import 'package:demo/features/menu_setup/widgets/setup_page_layout.dart';
import 'package:demo/features/transactions/repositories/transactions_repository.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';

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
      final menuSnapshot = await FirestorePaths.scoped('menus').get();
      final grouped = <String, List<Map<String, dynamic>>>{};
      final categoryOrder = <String, int>{};

      for (final categoryDoc in sortMenuDocs(menuSnapshot.docs)) {
        final categoryName = categoryDoc.data()['name']?.toString() ?? 'Menu';
        categoryOrder[categoryName] =
            (categoryDoc.data()['sortOrder'] as num?)?.toInt() ?? 9999;
        final itemsSnapshot = await FirestorePaths
            .scopedSubCollection('menus', categoryDoc.id, 'items')
            .get();

        for (final itemDoc in sortMenuDocs(itemsSnapshot.docs)) {
          final data = itemDoc.data();
          grouped.putIfAbsent(categoryName, () => []).add({
            'name': data['name']?.toString() ?? '',
            'price': data['price'],
          });
        }
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
        child: Text(
          'No menu items found.',
          style: TextStyle(
            fontFamily: fontMulishRegular,
            color: Colors.grey.shade600,
          ),
        ),
      );
    }

    final categories = _menuByCategory.keys.toList()..sort();

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
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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

                return ListTile(
                  dense: true,
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontFamily: fontMulishRegular,
                      fontSize: 14,
                    ),
                  ),
                  trailing: Text(
                    '₹$price',
                    style: const TextStyle(
                      fontFamily: fontMulishBold,
                      fontSize: 13,
                      color: SetupPageColors.orange,
                    ),
                  ),
                  onTap: () => _selectItem(item),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
