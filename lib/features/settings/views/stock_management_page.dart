import 'package:demo/core/models/menu_stock_entry.dart';
import 'package:demo/features/menu_setup/services/auto_stock_restock_service.dart';
import 'package:demo/features/settings/controllers/stock_controller.dart';
import 'package:demo/features/settings/widgets/stock_out_mode_sheet.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

const _navy = Color(0xFF1A3A5C);
const _orange = Color(0xFFf57c35);

class _CategoryStockGroup {
  const _CategoryStockGroup({
    required this.categoryId,
    required this.categoryName,
    required this.items,
  });

  final String categoryId;
  final String categoryName;
  final List<MenuStockEntry> items;
}

List<_CategoryStockGroup> _groupItemsByCategory(List<MenuStockEntry> items) {
  final groups = <String, _CategoryStockGroup>{};
  final order = <String>[];

  for (final item in items) {
    if (!groups.containsKey(item.categoryId)) {
      order.add(item.categoryId);
      groups[item.categoryId] = _CategoryStockGroup(
        categoryId: item.categoryId,
        categoryName: item.categoryName,
        items: [],
      );
    }
    groups[item.categoryId]!.items.add(item);
  }

  return order.map((id) => groups[id]!).toList();
}

class StockManagementPage extends StatefulWidget {
  const StockManagementPage({super.key});

  @override
  State<StockManagementPage> createState() => _StockManagementPageState();
}

class _StockManagementPageState extends State<StockManagementPage> {
  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<AutoStockRestockService>()) {
      Get.find<AutoStockRestockService>().processDueAutoRestocks();
    }
  }

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

          final categoryGroups = _groupItemsByCategory(items);

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
                  itemCount: categoryGroups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final group = categoryGroups[index];
                    final outOfStockCount =
                        group.items.where((e) => !e.inStock).length;

                    return Card(
                      elevation: 1,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          key: PageStorageKey<String>(group.categoryId),
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _navy.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.restaurant_menu_outlined,
                              color: _navy,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            group.categoryName,
                            style: MyFont.semiBold(15, color: _navy),
                          ),
                          subtitle: Text(
                            outOfStockCount > 0
                                ? '${group.items.length} items · '
                                    '$outOfStockCount out of stock'
                                : '${group.items.length} items',
                            style: MyFont.regular(12, color: Colors.grey.shade600),
                          ),
                          iconColor: _orange,
                          collapsedIconColor: _navy,
                          children: [
                            for (var i = 0; i < group.items.length; i++) ...[
                              if (i > 0) const SizedBox(height: 6),
                              Obx(() {
                                final item = group.items[i];
                                final selected =
                                    controller.selectedKeys.contains(item.key);
                                return _StockItemCard(
                                  item: item,
                                  selected: selected,
                                  showCategory: false,
                                  onChanged: controller.isLoading.value
                                      ? null
                                      : (value) => controller.toggleSelection(
                                            item.key,
                                            selected: value,
                                          ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    );
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
                        : () => _applyStockIn(context, controller),
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
                        : () => _applyStockOut(context, controller),
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

  Future<void> _applyStockOut(
    BuildContext context,
    StockController controller,
  ) async {
    if (controller.selectedKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item.')),
      );
      return;
    }

    final choice = await StockOutModeSheet.show(context);
    if (choice == null || !context.mounted) return;

    final String? error;
    if (choice.mode == StockOutMode.manual) {
      error = await controller.markSelectedOutManual();
    } else {
      error = await controller.markSelectedOutAuto(choice.nextStockTime!);
    }

    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    final message = choice.mode == StockOutMode.manual
        ? 'Selected items marked Out of Stock (manual).'
        : 'Selected items will return in stock at '
            '${DateFormat('EEE, d MMM · h:mm a').format(choice.nextStockTime!)}.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _applyStockIn(
    BuildContext context,
    StockController controller,
  ) async {
    final error = await controller.markSelectedInStock();

    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Selected items marked In Stock.'),
      ),
    );
  }
}

class _StockItemCard extends StatelessWidget {
  const _StockItemCard({
    required this.item,
    required this.selected,
    required this.onChanged,
    this.showCategory = true,
  });

  final MenuStockEntry item;
  final bool selected;
  final ValueChanged<bool?>? onChanged;
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final outOfStock = !item.inStock;

    return Card(
      elevation: 0,
      color: const Color(0xFFF8F9FB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                  if (showCategory) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.hasVariants
                          ? '${item.categoryName} · Half / Full'
                          : item.categoryName,
                      style: MyFont.regular(12, color: Colors.grey.shade600),
                    ),
                  ] else if (item.hasVariants) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Half / Full',
                      style: MyFont.regular(12, color: Colors.grey.shade600),
                    ),
                  ],
                  if (item.isAutoOut && item.nextStockTime != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Auto restock: ${DateFormat('EEE, d MMM · h:mm a').format(item.nextStockTime!)}',
                      style: MyFont.regular(11, color: Colors.orange.shade800),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (item.isAutoOut)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      'AUTO',
                      style: TextStyle(
                        fontFamily: fontMulishBold,
                        fontSize: 9,
                        color: Colors.orange.shade800,
                        letterSpacing: 0.4,
                      ),
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
          ],
        ),
      ),
    );
  }
}
