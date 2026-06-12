import 'dart:typed_data';

import 'package:demo/Styles/my_font.dart';
import 'package:demo/features/zomato/models/zomato_extracted_order.dart';
import 'package:demo/features/zomato/widgets/zomato_screenshot_viewer.dart';
import 'package:flutter/material.dart';

const _navy = Color(0xFF1A3A5C);
const _orange = Color(0xFFf57c35);

class ZomatoExtractedOrderReviewPage extends StatefulWidget {
  const ZomatoExtractedOrderReviewPage({
    required this.imageBytes,
    required this.extracted,
    required this.menuItems,
    super.key,
  });

  final Uint8List imageBytes;
  final ZomatoExtractedOrder extracted;
  final List<Map<String, dynamic>> menuItems;

  @override
  State<ZomatoExtractedOrderReviewPage> createState() =>
      _ZomatoExtractedOrderReviewPageState();
}

class _ZomatoExtractedOrderReviewPageState
    extends State<ZomatoExtractedOrderReviewPage> {
  late List<ZomatoExtractedItem> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.extracted.items
        .map(
          (item) => ZomatoExtractedItem(
            extractedName: item.extractedName,
            quantity: item.quantity,
            remarks: item.remarks,
            matchedMenuItem: item.matchedMenuItem != null
                ? Map<String, dynamic>.from(item.matchedMenuItem!)
                : null,
          ),
        )
        .toList();
  }

  int get _matchedCount => _rows.where((row) => row.isMatched).length;

  List<Map<String, dynamic>> get _menuDropdownItems {
    final sorted = List<Map<String, dynamic>>.from(widget.menuItems)
      ..sort((a, b) {
        final catCompare = (a['category']?.toString() ?? '')
            .compareTo(b['category']?.toString() ?? '');
        if (catCompare != 0) return catCompare;
        return (a['name']?.toString() ?? '')
            .compareTo(b['name']?.toString() ?? '');
      });
    return sorted;
  }

  String? _menuValueFor(ZomatoExtractedItem row) {
    final menuItem = row.matchedMenuItem;
    if (menuItem == null) return null;
    final categoryId = menuItem['categoryId']?.toString() ?? '';
    final itemId = menuItem['itemId']?.toString() ?? '';
    final name = menuItem['name']?.toString() ?? '';
    if (categoryId.isNotEmpty && itemId.isNotEmpty) {
      return '$categoryId|$itemId';
    }
    return name.isEmpty ? null : name;
  }

  void _setMenuMatch(ZomatoExtractedItem row, String? value) {
    if (value == null || value.isEmpty) {
      setState(() => row.matchedMenuItem = null);
      return;
    }

    setState(() {
      final matched = _findMenuItem(value);
      row.matchedMenuItem =
          matched != null ? Map<String, dynamic>.from(matched) : null;
    });
  }

  Map<String, dynamic>? _findMenuItem(String value) {
    if (value.contains('|')) {
      final parts = value.split('|');
      if (parts.length == 2) {
        for (final item in widget.menuItems) {
          if (item['categoryId']?.toString() == parts[0] &&
              item['itemId']?.toString() == parts[1]) {
            return item;
          }
        }
      }
    }
    for (final item in widget.menuItems) {
      if (item['name']?.toString() == value) return item;
    }
    return null;
  }

  void _removeRow(int index) {
    setState(() => _rows.removeAt(index));
  }

  void _confirm({bool screenshotOnly = false}) {
    if (!screenshotOnly && _matchedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match at least one item to your menu before saving.'),
        ),
      );
      return;
    }

    final result = screenshotOnly
        ? <ZomatoExtractedItem>[]
        : _rows.where((row) => row.isMatched).toList();
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final extracted = widget.extracted;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text(
          'Review extracted order',
          style: MyFont.bold(18, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GestureDetector(
                    onTap: () => ZomatoScreenshotViewer.show(
                      context,
                      imageBytes: widget.imageBytes,
                    ),
                    child: Image.memory(
                      widget.imageBytes,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (extracted.zomatoOrderNumber != null)
                      _infoChip(
                        Icons.tag,
                        'Order #${extracted.zomatoOrderNumber}',
                      ),
                    if (extracted.orderTime != null)
                      _infoChip(Icons.schedule, extracted.orderTime!),
                    if (extracted.totalAmount != null)
                      _infoChip(
                        Icons.currency_rupee,
                        extracted.totalAmount!.toStringAsFixed(0),
                      ),
                    _infoChip(
                      Icons.restaurant_menu,
                      '$_matchedCount / ${_rows.length} matched',
                      highlight: _matchedCount < _rows.length,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_rows.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No items were found on this screenshot. You can still save the screenshot without items.',
                      style: MyFont.regular(14, color: Colors.grey.shade700),
                    ),
                  )
                else
                  ...List.generate(_rows.length, (index) {
                    final row = _rows[index];
                    return _ItemReviewCard(
                      row: row,
                      menuItems: _menuDropdownItems,
                      menuValue: _menuValueFor(row),
                      onMenuChanged: (value) => _setMenuMatch(row, value),
                      onQtyChanged: (qty) =>
                          setState(() => row.quantity = qty),
                      onRemarksChanged: (value) =>
                          setState(() => row.remarks = value),
                      onRemove: () => _removeRow(index),
                    );
                  }),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_rows.any((row) => !row.isMatched))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Unmatched lines must be linked to a menu item or removed.',
                        style: MyFont.regular(13, color: Colors.orange.shade800),
                      ),
                    ),
                  if (_rows.isEmpty)
                    OutlinedButton(
                      onPressed: () => _confirm(screenshotOnly: true),
                      child: const Text(
                        'Save screenshot only',
                        style: TextStyle(fontFamily: fontMulishSemiBold),
                      ),
                    ),
                  if (_rows.isEmpty) const SizedBox(height: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _navy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _rows.isEmpty
                        ? null
                        : () => _confirm(),
                    child: Text(
                      _matchedCount == 0
                          ? 'Match items to save'
                          : 'Save order with $_matchedCount item(s)',
                      style: const TextStyle(fontFamily: fontMulishBold),
                    ),
                  ),
                  if (_rows.isNotEmpty && _matchedCount < _rows.length) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => _confirm(screenshotOnly: true),
                      child: const Text(
                        'Save screenshot only (skip items)',
                        style: TextStyle(fontFamily: fontMulishSemiBold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? Colors.orange.shade50
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? _orange : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: highlight ? _orange : _navy),
          const SizedBox(width: 6),
          Text(
            label,
            style: MyFont.semiBold(12, color: highlight ? _orange : _navy),
          ),
        ],
      ),
    );
  }
}

class _ItemReviewCard extends StatefulWidget {
  const _ItemReviewCard({
    required this.row,
    required this.menuItems,
    required this.menuValue,
    required this.onMenuChanged,
    required this.onQtyChanged,
    required this.onRemarksChanged,
    required this.onRemove,
  });

  final ZomatoExtractedItem row;
  final List<Map<String, dynamic>> menuItems;
  final String? menuValue;
  final ValueChanged<String?> onMenuChanged;
  final ValueChanged<int> onQtyChanged;
  final ValueChanged<String> onRemarksChanged;
  final VoidCallback onRemove;

  @override
  State<_ItemReviewCard> createState() => _ItemReviewCardState();
}

class _ItemReviewCardState extends State<_ItemReviewCard> {
  late final TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();
    _remarksController = TextEditingController(text: widget.row.remarks);
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: row.isMatched ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.extractedName,
                      style: MyFont.semiBold(15, color: _navy),
                    ),
                    Text(
                      row.isMatched ? 'Matched' : 'Needs menu match',
                      style: MyFont.regular(
                        12,
                        color: row.isMatched
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onRemove,
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Remove line',
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: widget.menuValue,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Menu item',
              border: const OutlineInputBorder(),
              isDense: true,
              errorText: row.isMatched ? null : 'Select a menu item',
            ),
            items: widget.menuItems
                .map(
                  (item) => DropdownMenuItem(
                    value: _dropdownValue(item),
                    child: Text(
                      '${item['category']} · ${item['name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: widget.onMenuChanged,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Qty', style: MyFont.semiBold(13, color: _navy)),
              const SizedBox(width: 10),
              IconButton.outlined(
                onPressed: row.quantity > 1
                    ? () => widget.onQtyChanged(row.quantity - 1)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Text(
                '${row.quantity}',
                style: MyFont.bold(16, color: _navy),
              ),
              IconButton.outlined(
                onPressed: row.quantity < 99
                    ? () => widget.onQtyChanged(row.quantity + 1)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          TextField(
            controller: _remarksController,
            decoration: const InputDecoration(
              labelText: 'Remarks / add-ons',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: widget.onRemarksChanged,
          ),
        ],
      ),
    );
  }

  static String _dropdownValue(Map<String, dynamic> item) {
    final categoryId = item['categoryId']?.toString() ?? '';
    final itemId = item['itemId']?.toString() ?? '';
    if (categoryId.isNotEmpty && itemId.isNotEmpty) {
      return '$categoryId|$itemId';
    }
    return item['name']?.toString() ?? '';
  }
}
