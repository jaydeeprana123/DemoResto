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

import 'MyWidgets/EditableTextField.dart';
import 'Styles/my_colors.dart';
import 'Styles/my_font.dart';
import 'services/ai_order_service.dart';
import 'services/restaurant_agent_service.dart';
import 'models/agent_response.dart';

/// Cart Page
class CartPage extends StatefulWidget {
  final String tableName;
  final bool tableNameEditable;
  final List<Map<String, dynamic>> menuData; // selected items
  final List<Map<String, dynamic>> fullMenu; // all items for AI detection
  final bool showBilling;

  final String? overallRemarks;

  final void Function(
    List<Map<String, dynamic>> selectedItems,
    bool isBillPaid,
    String tableName,
    String overallRemarks,
  )
  onConfirm;

  const CartPage({
    required this.menuData,
    required this.fullMenu,
    required this.onConfirm,
    required this.tableName,
    required this.tableNameEditable,
    required this.showBilling,
    this.overallRemarks,
    Key? key,
  }) : super(key: key);

  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
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

  String paymentMode = 'Cash'; // Cash, Online, Both

  @override
  void initState() {
    super.initState();
    tableNameController = TextEditingController(text: widget.tableName);
    overallRemarksController = TextEditingController(text: widget.overallRemarks ?? '');
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

  double get subtotal => cartItems.fold(
    0,
    (sum, item) => sum + (item['qty'] as int) * (item['price']),
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

  @override
  Widget build(BuildContext context) {
    final tax = (subtotal * 0.085).round();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          Navigator.pop(context, cartItems);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A3A5C),
          elevation: 0,
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
              child: cartItems.isEmpty
                  ? Center(child: Text("No items in cart"))
                  : Stack(
                      children: [
                        ListView.builder(
                          padding: EdgeInsets.only(bottom: 100),
                          itemCount: cartItems.length,
                          itemBuilder: (context, index) {
                            final item = cartItems[index];
                            final qty = item['qty'] as int;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
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
                                              item['name'],
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontFamily: fontMulishBold,
                                                color: Color(0xFF1A3A5C),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '₹${(item['price'] as num).toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade500,
                                                fontFamily: fontMulishRegular,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // ── Stepper ─────────────────────────
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1A3A5C),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                              onTap: () => decrementQty(index),
                                              child: Container(
                                                width: 32, height: 32,
                                                alignment: Alignment.center,
                                                child: const Icon(Icons.remove, color: Colors.white, size: 16),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
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
                                                width: 32, height: 32,
                                                alignment: Alignment.center,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFf57c35),
                                                  borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
                                                ),
                                                child: const Icon(Icons.add, color: Colors.white, size: 16),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  // ── Remarks (collapsible) ─────────────────
                                  const SizedBox(height: 8),
                                  if (_remarkExpanded[index]) ...[
                                    TextField(
                                      controller: _remarkControllers[index],
                                      autofocus: false,
                                      decoration: InputDecoration(
                                        hintText: 'e.g. less spicy, no onion, kam tel…',
                                        hintStyle: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade400,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        isDense: true,
                                        prefixIcon: Icon(Icons.notes_outlined,
                                            size: 16, color: Colors.orange.shade600),
                                        suffixIcon: GestureDetector(
                                          onTap: () => setState(() {
                                            if (_remarkControllers[index].text.isEmpty) {
                                              _remarkExpanded[index] = false;
                                            }
                                          }),
                                          child: Icon(Icons.keyboard_arrow_up,
                                              size: 18, color: Colors.grey.shade400),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                              color: Colors.orange.shade400, width: 1.5),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 8),
                                        filled: true,
                                        fillColor: Colors.orange.shade50,
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade800,
                                        fontFamily: fontMulishRegular,
                                      ),
                                      maxLines: 1,
                                      onChanged: (val) {
                                        cartItems[index]['remarks'] = val;
                                      },
                                    ),
                                  ] else ...[
                                    GestureDetector(
                                      onTap: () => setState(
                                          () => _remarkExpanded[index] = true),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add_comment_outlined,
                                              size: 14, color: Colors.orange.shade400),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Add Remark',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange.shade500,
                                              fontFamily: fontMulishSemiBold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );


                          },
                        ),

                        Align(
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
            if (cartItems.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: overallRemarksController,
                  maxLines: 12,
                  minLines: 5,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A3A5C),
                    fontFamily: fontMulishSemiBold,
                  ),
                  decoration: InputDecoration(
                    labelText: "Overall Order Remarks",
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontFamily: fontMulishMedium,
                    ),
                    hintText: "e.g. Keep it less spicy, add extra parcel boxes...",
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                      fontFamily: fontMulishRegular,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFf57c35)),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.speaker_notes, color: Colors.grey.shade400, size: 20),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.mic, color: Colors.red.shade400),
                          tooltip: 'Speak more instructions/items',
                          onPressed: _startVoiceOrderCart,
                        ),
                        IconButton(
                          icon: const Icon(Icons.auto_awesome, color: Color(0xFFf57c35)),
                          tooltip: 'Detect items from remarks',
                          onPressed: _extractItemsFromRemarks,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),

            isBilling
                ? Column(
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
                            final cash = int.tryParse(cashController.text) ?? 0;
                            final online =
                                int.tryParse(onlineController.text) ?? 0;

                            await addTransactionToFirestore(
                              items: cartItems,
                              tableName: tableNameController.text,
                              subtotal: subtotal.round(),
                              tax: (subtotal * 0.085).round(),
                              discount: discountAmount.round(),
                              total: total,
                              cashAmount: cash,
                              onlineAmount: online,
                            );

                            widget.onConfirm(
                              cartItems,
                              true,
                              tableNameController.text,
                              overallRemarksController.text.trim(),
                            );

                            // if(widget.tableName.contains("Take Away")){
                            //   widget.onConfirm(cartItems, true);
                            // }else{
                            //   widget.onConfirm([], true);
                            // }

                            Navigator.pop(context);
                            Navigator.pop(context);
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
                  )
                : Align(
                    alignment: Alignment.bottomCenter,
                    child: InkWell(
                      onTap: () {
                        widget.onConfirm(
                          cartItems,
                          false,
                          tableNameController.text,
                          overallRemarksController.text.trim(),
                        );
                        Navigator.pop(context);
                        Navigator.pop(context);
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
                  ),
          ],
        ),
      )
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
                          final cash = int.tryParse(cashController.text) ?? 0;
                          final online =
                              int.tryParse(onlineController.text) ?? 0;

                          await addTransactionToFirestore(
                            items: cartItems,
                            tableName: widget.tableName,
                            subtotal: subtotal.round(),
                            tax: (subtotal * 0.085).round(),
                            discount: discountAmount.round(),
                            total: total,
                            cashAmount: cash,
                            onlineAmount: online,
                          );

                          widget.onConfirm(
                            cartItems,
                            true,
                            tableNameController.text,
                            overallRemarksController.text.trim(),
                          );
                          Navigator.pop(context);
                          Navigator.pop(context);
                          Navigator.pop(context);
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
