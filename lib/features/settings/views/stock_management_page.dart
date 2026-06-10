import 'package:demo/core/models/menu_stock_entry.dart';
import 'package:demo/features/settings/controllers/stock_controller.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

const _navy = Color(0xFF1A3A5C);
const _orange = Color(0xFFf57c35);

class StockManagementPage extends StatelessWidget {
  const StockManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StockController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text(
          'Stock Management',
          style: MyFont.bold(18, color: Colors.white),
        ),
      ),
      body: StreamBuilder<List<MenuStockEntry>>(
        stream: controller.watchMenuStock(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _orange),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: MyFont.regular(14, color: Colors.red.shade700),
                ),
              ),
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No menu items yet',
                      style: MyFont.bold(18, color: _navy),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add categories and items under Settings → Menu first.',
                      textAlign: TextAlign.center,
                      style: MyFont.regular(14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Obx(() {
                final allSelected = controller.isAllSelected(items);
                final selectedCount = controller.selectedKeys.length;
                return Material(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: allSelected,
                          activeColor: _orange,
                          tristate: false,
                          onChanged: controller.isLoading.value
                              ? null
                              : (value) => controller.toggleSelectAll(
                                    items,
                                    selectAll: value == true,
                                  ),
                        ),
                        Expanded(
                          child: Text(
                            allSelected
                                ? 'Select all (${items.length})'
                                : 'Select all',
                            style: MyFont.semiBold(14, color: _navy),
                          ),
                        ),
                        if (selectedCount > 0)
                          Text(
                            '$selectedCount selected',
                            style: MyFont.regular(13, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                );
              }),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Obx(() {
                      final selected =
                          controller.selectedKeys.contains(item.key);
                      return _StockItemCard(
                        item: item,
                        selected: selected,
                        onChanged: controller.isLoading.value
                            ? null
                            : (value) => controller.toggleSelection(
                                  item.key,
                                  selected: value,
                                ),
                      );
                    });
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Obx(() {
        final busy = controller.isLoading.value;
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _applyStock(
                              context,
                              controller,
                              inStock: true,
                            ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Stock In'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => _applyStock(
                              context,
                              controller,
                              inStock: false,
                            ),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Stock Out'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _applyStock(
    BuildContext context,
    StockController controller, {
    required bool inStock,
  }) async {
    final error = inStock
        ? await controller.markSelectedInStock()
        : await controller.markSelectedOutOfStock();

    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          inStock
              ? 'Selected items marked In Stock.'
              : 'Selected items marked Out of Stock.',
        ),
      ),
    );
  }
}

class _StockItemCard extends StatelessWidget {
  const _StockItemCard({
    required this.item,
    required this.selected,
    required this.onChanged,
  });

  final MenuStockEntry item;
  final bool selected;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final outOfStock = !item.inStock;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              activeColor: _orange,
              onChanged: onChanged,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: MyFont.semiBold(15, color: _navy),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.hasVariants
                        ? '${item.categoryName} · Half / Full'
                        : item.categoryName,
                    style: MyFont.regular(12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: outOfStock
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: outOfStock
                      ? Colors.red.shade200
                      : Colors.green.shade200,
                ),
              ),
              child: Text(
                outOfStock ? 'Out of Stock' : 'In Stock',
                style: TextStyle(
                  fontFamily: fontMulishBold,
                  fontSize: 11,
                  color: outOfStock
                      ? Colors.red.shade700
                      : Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
