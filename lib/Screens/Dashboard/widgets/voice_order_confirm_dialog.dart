import 'package:demo/Screens/Dashboard/controllers/dashboard_controller.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/services/ai_order_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Voice order confirmation with confirmed items + pick-list for ambiguous phrases.
class VoiceOrderConfirmDialog extends StatelessWidget {
  const VoiceOrderConfirmDialog({
    super.key,
    required this.parsedOrder,
    required this.rawText,
    required this.controller,
  });

  final DashboardParsedOrder parsedOrder;
  final String rawText;
  final DashboardController controller;

  static const _navy = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);

  @override
  Widget build(BuildContext context) {
    final tableController = TextEditingController(text: parsedOrder.tableNumber);
    final items = List<OrderResult>.from(parsedOrder.items).obs;
    final suggestions = List<OrderSuggestionGroup>.from(parsedOrder.suggestions);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
          maxWidth: 520,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Heard: "$rawText"',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                        fontFamily: fontMulishRegular,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _tableField(tableController, parsedOrder),
                    const SizedBox(height: 16),
                    Obx(() => _confirmedSection(items)),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _suggestionsHeader(),
                      const SizedBox(height: 8),
                      ...suggestions.map(
                        (g) => _SuggestionGroupCard(
                          group: g,
                          onAdd: (menuItem) {
                            items.add(
                              OrderResult(
                                item: menuItem,
                                quantity: g.quantity,
                              ),
                            );
                            Get.snackbar(
                              'Added',
                              '${menuItem['name']} × ${g.quantity}',
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 1),
                              margin: const EdgeInsets.all(12),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _actions(context, tableController, items, suggestions),
          ],
        ),
      ),
    );
  }

  Widget _tableField(
    TextEditingController tableController,
    DashboardParsedOrder parsedOrder,
  ) {
    final knownTables = controller.tables.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parsedOrder.tableMatchedFromDb)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.table_restaurant, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Matched table from your list',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade800,
                      fontFamily: fontMulishSemiBold,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (knownTables.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Text(
              'Table not found — pick from your tables below',
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade900,
                fontFamily: fontMulishRegular,
              ),
            ),
          ),
        TextField(
          controller: tableController,
          decoration: InputDecoration(
            labelText: 'Table / Take Away',
            labelStyle: const TextStyle(
              fontFamily: fontMulishSemiBold,
              fontSize: 13,
            ),
            hintText: 'e.g. Table 1',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            isDense: true,
          ),
          style: const TextStyle(
            fontFamily: fontMulishBold,
            fontSize: 15,
          ),
        ),
        if (knownTables.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: knownTables.map((tableName) {
              final selected =
                  tableController.text.trim().toLowerCase() ==
                  tableName.toLowerCase();
              return ActionChip(
                label: Text(
                  tableName,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: fontMulishSemiBold,
                    color: selected ? Colors.white : _navy,
                  ),
                ),
                backgroundColor: selected ? _navy : Colors.grey.shade100,
                side: BorderSide(
                  color: selected ? _navy : Colors.grey.shade300,
                ),
                onPressed: () => tableController.text = tableName,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: const BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Confirm Voice Order',
              style: TextStyle(
                color: Colors.white,
                fontFamily: fontMulishBold,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmedSection(RxList<OrderResult> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
            const SizedBox(width: 6),
            const Text(
              'Confirmed items',
              style: TextStyle(
                fontFamily: fontMulishBold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              'No exact matches yet — pick items below.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontFamily: fontMulishRegular,
                fontSize: 12,
              ),
            ),
          )
        else
          ...List.generate(items.length, (index) {
            final item = items[index];
            final name = item.item['name'] as String;
            final price = (item.item['price'] as num).toDouble();
            final qty = item.quantity;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: fontMulishSemiBold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '₹${(price * qty).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: () {
                      if (qty > 1) {
                        items[index] = OrderResult(
                          item: item.item,
                          quantity: qty - 1,
                          remarks: item.remarks,
                        );
                      } else {
                        items.removeAt(index);
                      }
                    },
                  ),
                  Text('$qty', style: const TextStyle(fontFamily: fontMulishBold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    color: _orange,
                    onPressed: () {
                      items[index] = OrderResult(
                        item: item.item,
                        quantity: qty + 1,
                        remarks: item.remarks,
                      );
                    },
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _suggestionsHeader() {
    return Row(
      children: [
        Icon(Icons.help_outline, color: Colors.orange.shade700, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Pick the correct item',
            style: TextStyle(
              fontFamily: fontMulishBold,
              fontSize: 14,
              color: Colors.orange.shade900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actions(
    BuildContext context,
    TextEditingController tableController,
    RxList<OrderResult> items,
    List<OrderSuggestionGroup> suggestions,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          const Spacer(),
          Obx(() {
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: items.isEmpty && suggestions.isEmpty
                  ? null
                  : () => _submit(context, tableController, items),
              child: const Text(
                'Add Order',
                style: TextStyle(fontFamily: fontMulishBold),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    TextEditingController tableController,
    List<OrderResult> items,
  ) async {
    final selectedTable = tableController.text.trim();
    if (selectedTable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a table name')),
      );
      return;
    }

    final orderItems = items.map((res) {
      return {
        'name': res.item['name'],
        'price': res.item['price'],
        'categoryId': res.item['categoryId'],
        'itemId': res.item['itemId'],
        'category': res.item['category'],
        'qty': res.quantity,
        'remarks': res.remarks,
      };
    }).toList();

    Navigator.pop(context);

    controller.isLoading.value = true;
    try {
      String finalTable = selectedTable;
      if (selectedTable.toLowerCase().contains('take away') ||
          selectedTable.toLowerCase() == 'takeaway') {
        final nextNum = controller.tableNo + 1;
        finalTable = 'Take Away $nextNum';
      }

      await controller.addItemsToTable(
        tableName: finalTable,
        newItems: orderItems,
      );

      Get.snackbar(
        'Order Added',
        'Successfully added voice order to $finalTable.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to add order: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      controller.isLoading.value = false;
    }
  }
}

class _SuggestionGroupCard extends StatefulWidget {
  const _SuggestionGroupCard({
    required this.group,
    required this.onAdd,
  });

  final OrderSuggestionGroup group;
  final void Function(Map<String, dynamic> item) onAdd;

  @override
  State<_SuggestionGroupCard> createState() => _SuggestionGroupCardState();
}

class _SuggestionGroupCardState extends State<_SuggestionGroupCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final label = g.spokenPhrase.isEmpty ? 'Item' : g.spokenPhrase;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: VoiceOrderConfirmDialog._orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '×${g.quantity}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: fontMulishBold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '"$label"',
                      style: const TextStyle(
                        fontFamily: fontMulishSemiBold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                children: g.candidates.map((item) {
                  final name = item['name'] as String;
                  final price = (item['price'] as num).toDouble();
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => widget.onAdd(item),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontFamily: fontMulishSemiBold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '₹${price.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => widget.onAdd(item),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add'),
                              style: TextButton.styleFrom(
                                foregroundColor: VoiceOrderConfirmDialog._navy,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
