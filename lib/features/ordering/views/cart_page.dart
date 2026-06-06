import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/Styles/my_icons.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:demo/services/sarvam_stt_service.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'package:demo/MyWidgets/EditableTextField.dart';
import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/services/ai_order_service.dart';
import 'package:demo/services/restaurant_agent_service.dart';
import 'package:demo/models/agent_response.dart';

/// Cart Page
class CartPage extends StatefulWidget {
  final String tableName;
  final bool tableNameEditable;
  final List<Map<String, dynamic>> menuData; // new items only
  final List<Map<String, dynamic>> pastItems; // previous rounds — read-only
  final List<Map<String, dynamic>> fullMenu; // all items for AI detection
  final bool showBilling;

  final String? overallRemarks;

  final Future<void> Function(
    List<Map<String, dynamic>> selectedItems,
    bool isBillPaid,
    String tableName,
    String overallRemarks, {
    bool fromBilling ,
    bool fromFinalBilling,
  })
  onConfirm;

  /// Side panel on web inside [MenuPage] — no extra route on the stack.
  final bool embedded;

  /// Keeps menu quantities in sync when cart changes on web.
  final void Function(List<Map<String, dynamic>> items)? onCartUpdated;

  const CartPage({
    required this.menuData,
    this.pastItems = const [],
    required this.fullMenu,
    required this.onConfirm,
    required this.tableName,
    required this.tableNameEditable,
    required this.showBilling,
    this.overallRemarks,
    this.embedded = false,
    this.onCartUpdated,
    Key? key,
  }) : super(key: key);

  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late List<Map<String, dynamic>> pastItems;
  late List<Map<String, dynamic>> cartItems;
  late TextEditingController tableNameController;
  late TextEditingController overallRemarksController;
  late List<TextEditingController> _remarkControllers;
  late List<bool> _remarkExpanded;
  final TextEditingController discountPercentController =
      TextEditingController();
  final TextEditingController discountAmountController =
      TextEditingController();

  final TextEditingController cashController = TextEditingController();
  final TextEditingController onlineController = TextEditingController();

  double discountPercent = 0.0;
  double discountAmount = 0.0;

  bool isBilling = false;
  bool _pastItemsExpanded = false;

  String paymentMode = 'Cash'; // Cash, Online, Both

  @override
  void initState() {
    super.initState();
    tableNameController = TextEditingController(text: widget.tableName);
    overallRemarksController = TextEditingController(text: widget.overallRemarks ?? '');
    pastItems = widget.pastItems
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    cartItems = widget.menuData
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    _remarkControllers = cartItems
        .map((item) => TextEditingController(text: (item['remarks'] ?? '').toString()))
        .toList();
    // Expand remark field if item already has a remark
    _remarkExpanded = cartItems
        .map((item) => (item['remarks'] ?? '').toString().isNotEmpty)
        .toList();
    _updatePaymentAmounts();
  }

  @override
  void dispose() {
    tableNameController.dispose();
    overallRemarksController.dispose();
    for (final c in _remarkControllers) c.dispose();
    discountPercentController.dispose();
    discountAmountController.dispose();
    cashController.dispose();
    onlineController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CartPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.embedded) return;
    if (_cartSignature(widget.menuData) != _cartSignature(oldWidget.menuData)) {
      _reloadCartFromMenuData();
    }
  }

  String _cartSignature(List<Map<String, dynamic>> items) {
    return items
        .map((e) => '${e['name']}:${e['qty']}')
        .join('|');
  }

  void _reloadCartFromMenuData() {
    setState(() {
      for (final c in _remarkControllers) {
        c.dispose();
      }
      cartItems = widget.menuData
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      _remarkControllers = cartItems
          .map((item) => TextEditingController(
              text: (item['remarks'] ?? '').toString()))
          .toList();
      _remarkExpanded = cartItems
          .map((item) => (item['remarks'] ?? '').toString().isNotEmpty)
          .toList();
      _updateDiscountFromPercent();
      _updatePaymentAmounts();
    });
  }

  void _notifyCartUpdated() {
    if (!widget.embedded || widget.onCartUpdated == null) return;
    widget.onCartUpdated!(
      cartItems.map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  void _closeAfterOrder({int routePops = 2}) {
    if (widget.embedded) {
      Navigator.of(context).pop();
      return;
    }
    for (var i = 0; i < routePops; i++) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
    }
  }

  Future<void> _completeBilling({BuildContext? sheetContext}) async {
    final billItems = _allBillableItems
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (billItems.isEmpty) {
      Get.snackbar('Empty cart', 'Add items before billing.');
      return;
    }

    final cash = int.tryParse(cashController.text) ?? 0;
    final online = int.tryParse(onlineController.text) ?? 0;

    await addTransactionToFirestore(
      items: billItems,
      tableName: widget.tableName,
      subtotal: subtotal.round(),
      tax: (subtotal * 0.085).round(),
      discount: discountAmount.round(),
      total: total,
      cashAmount: cash,
      onlineAmount: online,
    );

    await widget.onConfirm(
      billItems,
      true,
      tableNameController.text.trim(),
      overallRemarksController.text.trim(),
      fromBilling: true,
    );

    if (!mounted) return;

    if (sheetContext != null && Navigator.canPop(sheetContext)) {
      Navigator.of(sheetContext).pop();
    }

    if (widget.embedded) {
      Navigator.of(context).pop();
      return;
    }

    if (Navigator.canPop(context)) Navigator.of(context).pop();
    if (!mounted) return;
    if (Navigator.canPop(context)) Navigator.of(context).pop();
  }

  double _lineTotal(Map<String, dynamic> item) {
    final qty = (item['qty'] as num?)?.toInt() ?? 0;
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    return qty * price;
  }

  List<Map<String, dynamic>> get _allBillableItems {
    final Map<String, Map<String, dynamic>> itemMap = {};
    for (final item in [...pastItems, ...cartItems]) {
      final key = '${item['name']}_${item['categoryId']}';
      if (itemMap.containsKey(key)) {
        itemMap[key]!['qty'] =
            ((itemMap[key]!['qty'] as num?)?.toInt() ?? 0) +
            ((item['qty'] as num?)?.toInt() ?? 0);
      } else {
        itemMap[key] = Map<String, dynamic>.from(item);
      }
    }
    return itemMap.values.toList();
  }

  double get subtotal => [...pastItems, ...cartItems].fold(
        0.0,
        (sum, item) => sum + _lineTotal(item),
      );

  Future<void> _extractItemsFromRemarks() async {
    final text = overallRemarksController.text.trim();
    if (text.isEmpty) {
      Get.snackbar('Empty Remarks', 'Please enter some text in remarks first.');
      return;
    }

    // ── Guard: fullMenu must be populated for accurate matching ──────────────
    if (widget.fullMenu.isEmpty) {
      debugPrint('[CartPage] ⚠️ fullMenu is EMPTY — cannot match items. '
          'Make sure CartPage is called with the complete menu list.');
      Get.snackbar(
        'Menu Not Loaded',
        'The full menu is not available. Please go back and try again.',
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    // Show loading
    Get.dialog(
      const Center(child: CircularProgressIndicator(color: Color(0xFFf57c35))),
      barrierDismissible: false,
    );

    try {
      // Call AI — fullMenu items carry 'category' so the category-annotated
      // Gemini prompt can disambiguate similar names (e.g. rice vs noodles).
      debugPrint('[CartPage] Extracting items from: "$text"');
      debugPrint('[CartPage] fullMenu has ${widget.fullMenu.length} items');
      final withCategory =
          widget.fullMenu.where((m) => (m['category'] ?? '').toString().isNotEmpty).length;
      debugPrint('[CartPage] Items with category field: $withCategory / ${widget.fullMenu.length}');
      if (widget.fullMenu.isNotEmpty) {
        debugPrint('[CartPage] Sample: ${widget.fullMenu.take(3).map((m) => "[${m['category'] ?? ''}] ${m['name']}").join(' | ')}');
      }

      final aiService = AiOrderService();
      final results = await aiService.parseOrder(text, widget.fullMenu);

      Get.back(); // close loading

      if (results.isEmpty) {
        Get.snackbar(
          'No Items Found',
          'Could not match any menu items from these remarks. '
          'Try saying the item name more clearly.',
          duration: const Duration(seconds: 4),
        );
        return;
      }

      // Show a confirmation dialog
      _showExtractedItemsDialog(results);
    } catch (e) {
      Get.back(); // close loading
      Get.snackbar('Error', 'AI extraction failed: $e');
    }
  }

  void _showExtractedItemsDialog(List<OrderResult> newItems) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Identified Items?', style: TextStyle(fontFamily: fontMulishBold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: newItems.length,
            itemBuilder: (context, i) {
              final item = newItems[i];
              return ListTile(
                title: Text(item.item['name'], style: const TextStyle(fontFamily: fontMulishSemiBold)),
                subtitle: Text('Qty: ${item.quantity} ${item.remarks.isNotEmpty ? "\u2022 ${item.remarks}" : ""}', style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.add_circle, color: Colors.green),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A3A5C), foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                // We will perform a Full Sync: the remarks are the "Truth"
                
                // 1. Create a set of identified item names
                final identifiedNames = newItems.map((ni) => ni.item['name']).toSet();

                // 2. Update or Remove existing items
                // We iterate backwards to safely remove items if needed
                for (int i = cartItems.length - 1; i >= 0; i--) {
                  final cartItemName = cartItems[i]['name'].toString().toLowerCase();
                  
                  final match = newItems.firstWhereOrNull(
                    (ni) => ni.item['name'].toString().toLowerCase() == cartItemName
                  );
                  
                  if (match != null) {
                    // Update to match remarks exactly
                    cartItems[i]['qty'] = match.quantity;
                    cartItems[i]['remarks'] = match.remarks;
                    _remarkControllers[i].text = match.remarks;
                    _remarkExpanded[i] = match.remarks.isNotEmpty;
                  } else {
                    // Item in cart but NOT in "perfect" remarks -> Remove it
                    cartItems.removeAt(i);
                    _remarkControllers[i].dispose();
                    _remarkControllers.removeAt(i);
                    _remarkExpanded.removeAt(i);
                  }
                }

                // 3. Add brand new items found in remarks
                for (var ni in newItems) {
                  final niNameLower = ni.item['name'].toString().toLowerCase();
                  final alreadyHandled = cartItems.any(
                    (ci) => ci['name'].toString().toLowerCase() == niNameLower
                  );
                  if (!alreadyHandled) {
                    final newItem = Map<String, dynamic>.from(ni.item);
                    newItem['qty'] = ni.quantity;
                    newItem['remarks'] = ni.remarks;
                    cartItems.add(newItem);
                    _remarkControllers.add(TextEditingController(text: ni.remarks));
                    _remarkExpanded.add(ni.remarks.isNotEmpty);
                  }
                }
                
                _updatePaymentAmounts();
              });
              _notifyCartUpdated();
              Navigator.pop(context);
              Get.snackbar('Success', 'Cart synced perfectly with remarks.');
            },
            child: const Text('Add All'),
          ),
        ],
      ),
    );
  }

  final SarvamSttService _sttService = SarvamSttService();

  Future<void> _startVoiceOrderCart() async {
    final hasPerms = await _sttService.hasPermission();
    if (!hasPerms) {
      Get.snackbar('Permission Denied', 'Microphone permission is required.');
      return;
    }

    String recognizedText = '';
    bool isRecording = false;
    bool isTranscribing = false;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isRecording ? 'Listening...' : isTranscribing ? 'Transcribing...' : 'Ready to listen', 
                  style: const TextStyle(fontFamily: fontMulishBold, fontSize: 18)),
                const SizedBox(height: 20),
                if (recognizedText.isNotEmpty)
                  Text(recognizedText, style: const TextStyle(fontFamily: fontMulishSemiBold)),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRecording ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (!isRecording) {
                          await _sttService.startRecording();
                          setSheetState(() => isRecording = true);
                        } else {
                          setSheetState(() {
                            isRecording = false;
                            isTranscribing = true;
                          });
                          final text = await _sttService.stopAndTranscribe();
                          setSheetState(() {
                            isTranscribing = false;
                            recognizedText = text ?? '';
                          });
                          if (recognizedText.isNotEmpty) {
                            Navigator.pop(context);
                            setState(() {
                              if (overallRemarksController.text.isNotEmpty) {
                                overallRemarksController.text += '\n';
                              }
                              overallRemarksController.text += recognizedText;
                            });
                            // Automatically trigger extraction
                            _extractItemsFromRemarks();
                          }
                        }
                      },
                      child: Text(isRecording ? 'Stop' : 'Start Recording'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  int get total => ((subtotal + (subtotal * 0.085) - discountAmount).round());

  void incrementQty(int index) {
    setState(() {
      cartItems[index]['qty']++;
      _updateDiscountFromPercent();
      _updatePaymentAmounts();
    });
    _notifyCartUpdated();
  }

  void decrementQty(int index) {
    setState(() {
      if (cartItems[index]['qty'] > 1) {
        cartItems[index]['qty']--;
      } else {
        cartItems.removeAt(index);
        _remarkControllers[index].dispose();
        _remarkControllers.removeAt(index);
        _remarkExpanded.removeAt(index);
      }
      _updateDiscountFromPercent();
      _updatePaymentAmounts();
    });
    _notifyCartUpdated();
  }

  void _updateDiscountFromPercent() {
    if (discountPercent > 0) {
      discountAmount = (subtotal * discountPercent) / 100;
      discountAmountController.text = discountAmount.toStringAsFixed(0);
    }
    _updatePaymentAmounts();
  }

  void _updateDiscountFromAmount() {
    if (discountAmount > 0 && subtotal > 0) {
      discountPercent = (discountAmount / subtotal) * 100;
      discountPercentController.text = discountPercent.toStringAsFixed(2);
    }
    _updatePaymentAmounts();
  }

  void _updatePaymentAmounts() {
    if (paymentMode == 'Cash') {
      cashController.text = total.toString();
      onlineController.text = "0";
    } else if (paymentMode == 'Online') {
      cashController.text = "0";
      onlineController.text = total.toString();
    } else if (paymentMode == 'Both') {
      int cash = int.tryParse(cashController.text) ?? total;
      if (cash > total) cash = total;
      cashController.text = cash.toString();
      onlineController.text = (total - cash).toString();
    }
  }

  static const _orange = Color(0xFFf57c35);
  static const _navy = Color(0xFF1A3A5C);

  Widget _sectionLabel(String title, {bool isPast = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontFamily: fontMulishBold,
              color: isPast ? Colors.grey.shade700 : _navy,
            ),
          ),
          if (isPast) ...[
            const SizedBox(width: 8),
            Text(
              '(non editable)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPastItemRow(Map<String, dynamic> item) {
    final qty = (item['qty'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item['name'] ?? '',
              style: TextStyle(
                fontSize: 13,
                fontFamily: fontMulishRegular,
                color: Colors.grey.shade800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '×$qty',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontFamily: fontMulishSemiBold,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '₹${_lineTotal(item).toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 13,
              fontFamily: fontMulishSemiBold,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  double get _pastItemsSubtotal =>
      pastItems.fold(0.0, (sum, item) => sum + _lineTotal(item));

  int get _pastItemsQty =>
      pastItems.fold(0, (sum, item) => sum + ((item['qty'] as num?)?.toInt() ?? 0));

  Widget _buildPastItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _pastItemsExpanded = !_pastItemsExpanded),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 6, 10, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Past Items',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: fontMulishBold,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${pastItems.length} item${pastItems.length == 1 ? '' : 's'} · $_pastItemsQty qty · ₹${_pastItemsSubtotal.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontFamily: fontMulishRegular,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'non editable',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _pastItemsExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey.shade700,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeIn,
          sizeCurve: Curves.easeInOut,
          crossFadeState: _pastItemsExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                ...pastItems.map(_buildPastItemRow),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Past subtotal',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontFamily: fontMulishSemiBold,
                        ),
                      ),
                      Text(
                        '₹${_pastItemsSubtotal.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: fontMulishBold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Divider(height: 1),
        ),
      ],
    );
  }

  Widget _buildNewItemRow(int index) {
    final item = cartItems[index];
    final qty = (item['qty'] as num?)?.toInt() ?? 0;
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => incrementQty(index),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: fontMulishBold,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '₹${price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontFamily: fontMulishRegular,
                          ),
                        ),
                        if (qty > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '×$qty',
                            style: const TextStyle(
                              fontSize: 13,
                              color: _orange,
                              fontFamily: fontMulishSemiBold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => decrementQty(index),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    child: const Icon(Icons.remove, color: Colors.white, size: 18),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '$qty',
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: fontMulishBold,
                      color: Colors.white,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => incrementQty(index),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _orange,
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(20),
                      ),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
      children: [
        if (pastItems.isNotEmpty) _buildPastItemsSection(),
        if (cartItems.isNotEmpty) ...[
          _sectionLabel('New Items'),
          ...List.generate(cartItems.length, _buildNewItemRow),
        ] else if (pastItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Add more items from the menu',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontFamily: fontMulishRegular,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tax = (subtotal * 0.085).round();

    final scaffold = Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A3A5C),
          elevation: 0,
          automaticallyImplyLeading: !widget.embedded,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Row(
            children: [
              const Icon(Icons.shopping_cart_outlined, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                "Cart",
                style: const TextStyle(
                  fontSize: 15,
                  fontFamily: fontMulishSemiBold,
                  color: Colors.white54,
                ),
              ),
              const Text(
                " — ",
                style: TextStyle(fontSize: 15, color: Colors.white38),
              ),
              (widget.tableName.contains("Table") || !widget.tableNameEditable)
                  ? Text(
                      widget.tableName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontFamily: fontMulishBold,
                        color: Colors.white,
                      ),
                    )
                  : Expanded(
                      child: EditableTextField(controller: tableNameController),
                    ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: (pastItems.isEmpty && cartItems.isEmpty)
                  ? const Center(child: Text('No items in cart'))
                  : Stack(
                      children: [
                        _buildCartList(),

                       if(widget.showBilling) Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            margin: const EdgeInsets.all(22),
                            child: FloatingActionButton.extended(
                              backgroundColor: const Color(0xFF1A3A5C),
                              foregroundColor: Colors.white,
                              elevation: 6,
                              icon: const Icon(Icons.receipt_long_outlined, size: 22),
                              label: const Text(
                                'Billing',
                                style: TextStyle(
                                  fontFamily: fontMulishSemiBold,
                                  fontSize: 14,
                                ),
                              ),
                              tooltip: 'Billing',
                              onPressed: () async {
                                _showBillingBottomSheet(context);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            
            // Overall Remarks Field
            // if (cartItems.isNotEmpty)
            //   Container(
            //     margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            //     child: TextField(
            //       controller: overallRemarksController,
            //       maxLines: 12,
            //       minLines: 5,
            //       style: const TextStyle(
            //         fontSize: 14,
            //         color: Color(0xFF1A3A5C),
            //         fontFamily: fontMulishSemiBold,
            //       ),
            //       decoration: InputDecoration(
            //         labelText: "Overall Order Remarks",
            //         labelStyle: const TextStyle(
            //           fontSize: 12,
            //           color: Colors.grey,
            //           fontFamily: fontMulishMedium,
            //         ),
            //         hintText: "e.g. Keep it less spicy, add extra parcel boxes...",
            //         hintStyle: TextStyle(
            //           fontSize: 13,
            //           color: Colors.grey.shade400,
            //           fontFamily: fontMulishRegular,
            //         ),
            //         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            //         border: OutlineInputBorder(
            //           borderRadius: BorderRadius.circular(12),
            //           borderSide: BorderSide(color: Colors.grey.shade300),
            //         ),
            //         focusedBorder: OutlineInputBorder(
            //           borderRadius: BorderRadius.circular(12),
            //           borderSide: const BorderSide(color: Color(0xFFf57c35)),
            //         ),
            //         filled: true,
            //         fillColor: Colors.white,
            //         prefixIcon: Icon(Icons.speaker_notes, color: Colors.grey.shade400, size: 20),
            //         suffixIcon: Row(
            //           mainAxisSize: MainAxisSize.min,
            //           children: [
            //             IconButton(
            //               icon: Icon(Icons.mic, color: Colors.red.shade400),
            //               tooltip: 'Speak more instructions/items',
            //               onPressed: _startVoiceOrderCart,
            //             ),
            //             IconButton(
            //               icon: const Icon(Icons.auto_awesome, color: Color(0xFFf57c35)),
            //               tooltip: 'Detect items from remarks',
            //               onPressed: _extractItemsFromRemarks,
            //             ),
            //             const SizedBox(width: 8),
            //           ],
            //         ),
            //       ),
            //     ),
            //   ),

          isBilling
                ?   (pastItems.isNotEmpty || cartItems.isNotEmpty)?Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Payment Mode Selection
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Payment By",
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: secondary_text_color,
                                          fontFamily: fontMulishSemiBold,
                                        ),
                                      ),
                                    ),

                                    Row(
                                      children: [
                                        Radio<String>(
                                          value: 'Cash',
                                          groupValue: paymentMode,
                                          onChanged: (value) {
                                            setState(() {
                                              paymentMode = value!;
                                              _updatePaymentAmounts();
                                            });
                                          },
                                        ),
                                        const Text(
                                          'Cash',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: text_color,
                                            fontFamily: fontMulishSemiBold,
                                          ),
                                        ),
                                      ],
                                    ),

                                    SizedBox(width: 12),
                                    Row(
                                      children: [
                                        Radio<String>(
                                          value: 'Online',
                                          groupValue: paymentMode,
                                          onChanged: (value) {
                                            setState(() {
                                              paymentMode = value!;
                                              _updatePaymentAmounts();
                                            });
                                          },
                                        ),
                                        const Text(
                                          'Online',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: text_color,
                                            fontFamily: fontMulishSemiBold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 12),
                                    Row(
                                      children: [
                                        Radio<String>(
                                          value: 'Both',
                                          groupValue: paymentMode,
                                          onChanged: (value) {
                                            setState(() {
                                              paymentMode = value!;
                                              _updatePaymentAmounts();
                                            });
                                          },
                                        ),
                                        const Text(
                                          'Both',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: text_color,
                                            fontFamily: fontMulishSemiBold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 4),

                                // Cash + Online Inputs (only if Both selected)
                                if (paymentMode == 'Both')
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 12.0,
                                      top: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        // Cash Amount Field
                                        Expanded(child: SizedBox()),

                                        Expanded(
                                          child: TextField(
                                            controller: cashController,
                                            keyboardType: TextInputType.number,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: secondary_text_color,
                                              fontFamily: fontMulishSemiBold,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: "Cash Amount",
                                              labelStyle: const TextStyle(
                                                fontSize: 10,
                                                color: secondary_text_color,
                                                fontFamily: fontMulishMedium,
                                              ),
                                              hintText: "Enter %",
                                              hintStyle: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey,
                                                fontFamily: fontMulishRegular,
                                              ),
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: 12,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: const BorderSide(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: const BorderSide(
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                            onChanged: (value) {
                                              setState(() {
                                                int cashVal =
                                                    int.tryParse(value) ?? 0;
                                                if (cashVal > total)
                                                  cashVal = total;
                                                cashController.text = cashVal
                                                    .toString();
                                                onlineController.text =
                                                    (total - cashVal)
                                                        .toString();
                                                cashController.selection =
                                                    TextSelection.fromPosition(
                                                      TextPosition(
                                                        offset: cashController
                                                            .text
                                                            .length,
                                                      ),
                                                    );
                                              });
                                            },
                                          ),
                                        ),

                                        const SizedBox(width: 8),

                                        // Online Amount Field
                                        Expanded(
                                          child: TextField(
                                            controller: onlineController,
                                            keyboardType: TextInputType.number,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: secondary_text_color,
                                              fontFamily: fontMulishSemiBold,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: "Online Amount",
                                              labelStyle: const TextStyle(
                                                fontSize: 10,
                                                color: secondary_text_color,
                                                fontFamily: fontMulishMedium,
                                              ),
                                              hintText: "Enter %",
                                              hintStyle: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey,
                                                fontFamily: fontMulishRegular,
                                              ),
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: 12,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: const BorderSide(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: const BorderSide(
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                            onChanged: (value) {
                                              setState(() {
                                                int onlineVal =
                                                    int.tryParse(value) ?? 0;
                                                if (onlineVal > total)
                                                  onlineVal = total;
                                                onlineController.text =
                                                    onlineVal.toString();
                                                cashController.text =
                                                    (total - onlineVal)
                                                        .toString();
                                                onlineController.selection =
                                                    TextSelection.fromPosition(
                                                      TextPosition(
                                                        offset: onlineController
                                                            .text
                                                            .length,
                                                      ),
                                                    );
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Subtotal",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: secondary_text_color,
                                    fontFamily: fontMulishSemiBold,
                                  ),
                                ),
                                Text(
                                  "₹${subtotal.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: text_color,
                                    fontFamily: fontMulishSemiBold,
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 8),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Tax (8.5%)",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: secondary_text_color,
                                    fontFamily: fontMulishSemiBold,
                                  ),
                                ),
                                Text(
                                  "₹$tax",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: text_color,
                                    fontFamily: fontMulishSemiBold,
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 6),

                            Row(
                              children: [
                                // Discount Percentage
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "Discount",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: secondary_text_color,
                                      fontFamily: fontMulishSemiBold,
                                    ),
                                  ),
                                ),

                                Expanded(
                                  child: TextField(
                                    controller: discountPercentController,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: secondary_text_color,
                                      fontFamily: fontMulishSemiBold,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: "Discount %",
                                      labelStyle: const TextStyle(
                                        fontSize: 10,
                                        color: secondary_text_color,
                                        fontFamily: fontMulishMedium,
                                      ),
                                      hintText: "Enter %",
                                      hintStyle: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                        fontFamily: fontMulishRegular,
                                      ),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade100,
                                          width: 0.25,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: primary_color,
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: (value) {
                                      setState(() {
                                        discountPercent =
                                            double.tryParse(value) ?? 0;
                                        _updateDiscountFromPercent();
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(width: 8),
                                // Discount Amount
                                Expanded(
                                  child: TextField(
                                    controller: discountAmountController,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: secondary_text_color,
                                      fontFamily: fontMulishSemiBold,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: "Discount ₹",
                                      labelStyle: const TextStyle(
                                        fontSize: 10,
                                        color: secondary_text_color,
                                        fontFamily: fontMulishMedium,
                                      ),
                                      hintText: "Enter ₹",
                                      hintStyle: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                        fontFamily: fontMulishRegular,
                                      ),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: Colors.grey,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: primary_color,
                                        ),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      setState(() {
                                        discountAmount =
                                            double.tryParse(value) ?? 0;
                                        _updateDiscountFromAmount();
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Payment Mode Radio
                            DottedLine(
                              dashLength: 2,
                              dashGapLength: 6,
                              lineThickness: 1,
                              dashColor: Colors.black87,
                            ),

                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Total",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "₹$total",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            // const SizedBox(height: 8),
                          ],
                        ),
                      ),

                      Align(
                        alignment: Alignment.bottomCenter,
                        child: InkWell(
                          onTap: () async {
                            await _completeBilling();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            color: primary_color,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      SvgPicture.asset(
                                        icon_bill,
                                        width: 24,
                                        color: Colors.white,
                                      ),

                                      SizedBox(width: 6),

                                      Text(
                                        "Confirm & Billing",
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.white,
                                          fontFamily: fontMulishSemiBold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white,
                                ),

                                // ElevatedButton(
                                //   onPressed: () {
                                //     final selectedItems = <Map<String, dynamic>>[];
                                //     menuData.forEach((category, items) {
                                //       selectedItems.addAll(
                                //         items.where((item) => item['qty'] > 0),
                                //       );
                                //     });
                                //
                                //     // Send selected items to cart or callback
                                //
                                //
                                //     if(widget.tableName == "Take Away"){
                                //       Navigator.push(
                                //         context,
                                //         MaterialPageRoute(
                                //           builder: (_) => CartPageForTakeAway(
                                //             tableName: widget.tableName,
                                //             menuData: selectedItems,
                                //             onConfirm: widget.onConfirm,
                                //           ),
                                //         ),
                                //       );
                                //     }else{
                                //       Navigator.push(
                                //         context,
                                //         MaterialPageRoute(
                                //           builder: (_) => CartPage(
                                //             tableName: widget.tableName,
                                //             menuData: selectedItems,
                                //             onConfirm: widget.onConfirm,
                                //           ),
                                //         ),
                                //       );
                                //     }
                                //
                                //
                                //   },
                                //   child: const Text("View Cart"),
                                // ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ):SizedBox()
                : (cartItems.isNotEmpty)?Align(
                    alignment: Alignment.bottomCenter,
                    child: InkWell(
                      onTap: () {
                        widget.onConfirm(
                          cartItems,
                          false,
                          tableNameController.text,
                          overallRemarksController.text.trim(),
                        );
                        _closeAfterOrder(routePops: 2);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        color: primary_color,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  SvgPicture.asset(
                                    icon_cooking,
                                    width: 32,
                                    color: Colors.white,
                                  ),

                                  SizedBox(width: 6),

                                  Text(
                                    "Send to Kitchen",
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.white,
                                      fontFamily: fontMulishSemiBold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Icon(Icons.arrow_forward_ios, color: Colors.white),

                            // ElevatedButton(
                            //   onPressed: () {
                            //     final selectedItems = <Map<String, dynamic>>[];
                            //     menuData.forEach((category, items) {
                            //       selectedItems.addAll(
                            //         items.where((item) => item['qty'] > 0),
                            //       );
                            //     });
                            //
                            //     // Send selected items to cart or callback
                            //
                            //
                            //     if(widget.tableName == "Take Away"){
                            //       Navigator.push(
                            //         context,
                            //         MaterialPageRoute(
                            //           builder: (_) => CartPageForTakeAway(
                            //             tableName: widget.tableName,
                            //             menuData: selectedItems,
                            //             onConfirm: widget.onConfirm,
                            //           ),
                            //         ),
                            //       );
                            //     }else{
                            //       Navigator.push(
                            //         context,
                            //         MaterialPageRoute(
                            //           builder: (_) => CartPage(
                            //             tableName: widget.tableName,
                            //             menuData: selectedItems,
                            //             onConfirm: widget.onConfirm,
                            //           ),
                            //         ),
                            //       );
                            //     }
                            //
                            //
                            //   },
                            //   child: const Text("View Cart"),
                            // ),
                          ],
                        ),
                      ),
                    ),
                  ):SizedBox(),
          ],
        ),
      );

    if (widget.embedded) return scaffold;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          Navigator.pop(context, cartItems);
        }
      },
      child: scaffold,
    );
  }

  Future<void> addTransactionToFirestore({
    required List<Map<String, dynamic>> items,
    required String tableName,
    required int subtotal,
    required int tax,
    required int discount,
    required int total,
    required int cashAmount,
    required int onlineAmount,
  }) async {
    try {
      final now = DateTime.now();
      final dateKey = DateFormat("yyyy-MM-dd").format(now);

      final batch = FirebaseFirestore.instance.batch();

      // 1️⃣ Add transaction
      final txRef = FirebaseFirestore.instance.collection("transactions").doc();
      batch.set(txRef, {
        "table": tableName,
        "items": items
            .map(
              (e) => {
                "name": e["name"],
                "qty": e["qty"],
                "price": (e["price"]).round(), // convert to int
                "total": ((e["qty"]) * (e["price"])).round(),
              },
            )
            .toList(),
        "subtotal": subtotal,
        "tax": tax,
        "discount": discount,
        "total": total,
        "cashAmount": cashAmount,
        "onlineAmount": onlineAmount,
        "createdAt": FieldValue.serverTimestamp(),
      });

      // 2️⃣ Update daily_stats
      final dailyRef = FirebaseFirestore.instance
          .collection("daily_stats")
          .doc(dateKey);
      batch.set(dailyRef, {
        "revenue": FieldValue.increment(total),
        "totalCash": FieldValue.increment(cashAmount),
        "totalOnline": FieldValue.increment(onlineAmount),
        "transactions": FieldValue.increment(1),
        "lastUpdated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3️⃣ Update global summary
      final summaryRef = FirebaseFirestore.instance
          .collection("stats")
          .doc("summary");
      batch.set(summaryRef, {
        "totalRevenue": FieldValue.increment(total),
        "totalTransactions": FieldValue.increment(1),
        "lastUpdated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4️⃣ Commit batch
      await batch.commit();
      Get.snackbar("Successfull", "Transaction saved successfully!");
    } catch (e) {
      Get.snackbar("Error", "Transaction not saved" + e.toString());
    }
  }

  void _showBillingBottomSheet(BuildContext context) {
    final tax = (subtotal * 0.085).round();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- Header with Cancel icon ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Billing Summary",
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: fontMulishSemiBold,
                              color: text_color,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.black87,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // --- Scrollable Content ---
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(0),
                                child: Column(
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Payment Mode Selection
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                "Payment By",
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: secondary_text_color,
                                                  fontFamily:
                                                      fontMulishSemiBold,
                                                ),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Radio<String>(
                                                  value: 'Cash',
                                                  visualDensity: VisualDensity(
                                                    horizontal: -4,
                                                    vertical: -4,
                                                  ),
                                                  groupValue: paymentMode,
                                                  onChanged: (value) {
                                                    setModalState(() {
                                                      paymentMode = value!;
                                                      _updatePaymentAmounts();
                                                    });
                                                  },
                                                ),
                                                const Text(
                                                  'Cash',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: text_color,
                                                    fontFamily:
                                                        fontMulishSemiBold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 8),
                                            Row(
                                              children: [
                                                Radio<String>(
                                                  value: 'Online',
                                                  visualDensity: VisualDensity(
                                                    horizontal: -4,
                                                    vertical: -4,
                                                  ),
                                                  groupValue: paymentMode,
                                                  onChanged: (value) {
                                                    setModalState(() {
                                                      paymentMode = value!;
                                                      _updatePaymentAmounts();
                                                    });
                                                  },
                                                ),
                                                const Text(
                                                  'Online',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: text_color,
                                                    fontFamily:
                                                        fontMulishSemiBold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 8),
                                            Row(
                                              children: [
                                                Radio<String>(
                                                  value: 'Both',
                                                  visualDensity: VisualDensity(
                                                    horizontal: -4,
                                                    vertical: -4,
                                                  ),
                                                  groupValue: paymentMode,
                                                  onChanged: (value) {
                                                    setModalState(() {
                                                      paymentMode = value!;
                                                      _updatePaymentAmounts();
                                                    });
                                                  },
                                                ),
                                                const Text(
                                                  'Both',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: text_color,
                                                    fontFamily:
                                                        fontMulishSemiBold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 4),

                                        // Cash + Online Inputs (only if Both selected)
                                        if (paymentMode == 'Both')
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12.0,
                                              top: 8,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(child: SizedBox()),

                                                Expanded(
                                                  child: TextField(
                                                    controller: cashController,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color:
                                                          secondary_text_color,
                                                      fontFamily:
                                                          fontMulishSemiBold,
                                                    ),
                                                    decoration: InputDecoration(
                                                      labelText: "Cash Amount",
                                                      labelStyle: const TextStyle(
                                                        fontSize: 13,
                                                        color:
                                                            secondary_text_color,
                                                        fontFamily:
                                                            fontMulishMedium,
                                                      ),
                                                      isDense: true,
                                                      contentPadding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 10,
                                                            horizontal: 12,
                                                          ),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                      ),
                                                    ),
                                                    onChanged: (value) {
                                                      setModalState(() {
                                                        int cashVal =
                                                            int.tryParse(
                                                              value,
                                                            ) ??
                                                            0;
                                                        if (cashVal > total)
                                                          cashVal = total;
                                                        cashController.text =
                                                            cashVal.toString();
                                                        onlineController.text =
                                                            (total - cashVal)
                                                                .toString();
                                                        cashController
                                                                .selection =
                                                            TextSelection.fromPosition(
                                                              TextPosition(
                                                                offset:
                                                                    cashController
                                                                        .text
                                                                        .length,
                                                              ),
                                                            );
                                                      });
                                                    },
                                                  ),
                                                ),

                                                const SizedBox(width: 8),

                                                // Online Amount Field
                                                Expanded(
                                                  child: TextField(
                                                    controller:
                                                        onlineController,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color:
                                                          secondary_text_color,
                                                      fontFamily:
                                                          fontMulishSemiBold,
                                                    ),
                                                    decoration: InputDecoration(
                                                      labelText:
                                                          "Online Amount",
                                                      labelStyle: const TextStyle(
                                                        fontSize: 13,
                                                        color:
                                                            secondary_text_color,
                                                        fontFamily:
                                                            fontMulishMedium,
                                                      ),
                                                      isDense: true,
                                                      contentPadding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 10,
                                                            horizontal: 12,
                                                          ),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                      ),
                                                    ),
                                                    onChanged: (value) {
                                                      setModalState(() {
                                                        int onlineVal =
                                                            int.tryParse(
                                                              value,
                                                            ) ??
                                                            0;
                                                        if (onlineVal > total)
                                                          onlineVal = total;
                                                        onlineController.text =
                                                            onlineVal
                                                                .toString();
                                                        cashController.text =
                                                            (total - onlineVal)
                                                                .toString();
                                                        onlineController
                                                                .selection =
                                                            TextSelection.fromPosition(
                                                              TextPosition(
                                                                offset:
                                                                    onlineController
                                                                        .text
                                                                        .length,
                                                              ),
                                                            );
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "Subtotal",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: secondary_text_color,
                                            fontFamily: fontMulishSemiBold,
                                          ),
                                        ),
                                        Text(
                                          "₹${subtotal.toStringAsFixed(0)}",
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: text_color,
                                            fontFamily: fontMulishSemiBold,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "Tax (8.5%)",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: secondary_text_color,
                                            fontFamily: fontMulishSemiBold,
                                          ),
                                        ),
                                        Text(
                                          "₹$tax",
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: text_color,
                                            fontFamily: fontMulishSemiBold,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 6),

                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            "Discount",
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: secondary_text_color,
                                              fontFamily: fontMulishSemiBold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller:
                                                discountPercentController,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: secondary_text_color,
                                              fontFamily: fontMulishSemiBold,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: "Disc %",
                                              labelStyle: const TextStyle(
                                                fontSize: 10,
                                                color: secondary_text_color,
                                                fontFamily: fontMulishMedium,
                                              ),
                                              hintText: "Enter %",
                                              hintStyle: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey,
                                                fontFamily: fontMulishRegular,
                                              ),
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: 12,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            onChanged: (value) {
                                              setModalState(() {
                                                discountPercent =
                                                    double.tryParse(value) ?? 0;
                                                _updateDiscountFromPercent();
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller:
                                                discountAmountController,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: secondary_text_color,
                                              fontFamily: fontMulishSemiBold,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: "Discount ₹",
                                              labelStyle: const TextStyle(
                                                fontSize: 10,
                                                color: secondary_text_color,
                                                fontFamily: fontMulishMedium,
                                              ),
                                              hintText: "Enter %",
                                              hintStyle: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey,
                                                fontFamily: fontMulishRegular,
                                              ),
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: 12,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            keyboardType: TextInputType.number,
                                            onChanged: (value) {
                                              setModalState(() {
                                                discountAmount =
                                                    double.tryParse(value) ?? 0;
                                                _updateDiscountFromAmount();
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    const DottedLine(
                                      dashLength: 2,
                                      dashGapLength: 6,
                                      lineThickness: 1,
                                      dashColor: Colors.black87,
                                    ),

                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "Total",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          "₹$total",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Confirm & Billing Button
                      InkWell(
                        onTap: () async {
                          await _completeBilling(sheetContext: context);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primary_color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              "Confirm & Billing",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                                fontFamily: fontMulishSemiBold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
