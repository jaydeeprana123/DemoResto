import 'package:flutter/material.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'package:demo/Styles/my_icons.dart';
import 'package:demo/MyWidgets/EditableTextField.dart';
import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/services/ai_order_service.dart'; // Holds OrderResult
import 'package:demo/Screens/Orders/controllers/cart_controller.dart';

/// Cart Page
/// 
/// Refactored to leverage the GetX Repository Pattern.
/// CartPageView acts as a pure presentation layer that communicates with
/// the tagged [CartController] to reactively observe cart items, subtotal, tax,
/// split billing cash/online ratios, and overall speech-to-text extraction.
class CartPageView extends StatefulWidget {
  final String tableName;
  final bool tableNameEditable;
  final List<Map<String, dynamic>> menuData; // selected items
  final List<Map<String, dynamic>> fullMenu; // all items for AI detection
  final bool showBilling;
  final String? overallRemarks;
  final bool isEditMode;

  const CartPageView({
    required this.menuData,
    required this.fullMenu,
    required this.tableName,
    required this.tableNameEditable,
    required this.showBilling,
    required this.isEditMode,
    this.overallRemarks,
    Key? key,
  }) : super(key: key);

  @override
  _CartPageViewState createState() => _CartPageViewState();
}

class _CartPageViewState extends State<CartPageView> {
  late final CartController controller;

  @override
  void initState() {
    super.initState();
    // Unique registration using tableName as tag to avoid cross-table conflicts
    controller = Get.put(CartController(), tag: widget.tableName);
    controller.initializeCart(
      initialItems: widget.menuData,
      initialTableName: widget.tableName,
      initialOverallRemarks: widget.overallRemarks,
    );
  }

  Future<void> _extractItemsFromRemarks() async {
    final results = await controller.extractItemsFromRemarks(widget.fullMenu);
    if (results != null && results.isNotEmpty) {
      _showExtractedItemsDialog(results);
    } else if (results != null && results.isEmpty) {
      Get.snackbar(
        'No Items Found',
        'Could not match any menu items from these remarks. Try saying the item name more clearly.',
        duration: const Duration(seconds: 4),
      );
    }
  }

  void _showExtractedItemsDialog(List<OrderResult> newItems) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Add Identified Items?',
          style: TextStyle(fontFamily: fontMulishBold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: newItems.length,
            itemBuilder: (context, i) {
              final item = newItems[i];
              return ListTile(
                title: Text(
                  item.item['name'],
                  style: const TextStyle(fontFamily: fontMulishSemiBold),
                ),
                subtitle: Text(
                  'Qty: ${item.quantity} ${item.remarks.isNotEmpty ? "\u2022 ${item.remarks}" : ""}',
                  style: const TextStyle(fontSize: 12),
                ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A3A5C),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              controller.syncCartWithExtractedItems(newItems);
              Navigator.pop(context);
              Get.snackbar('Success', 'Cart synced perfectly with remarks.');
            },
            child: const Text('Add All'),
          ),
        ],
      ),
    );
  }

  void _startVoiceOrderCart() async {
    final hasPerms = await controller.sttService.hasPermission();
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isRecording
                      ? 'Listening...'
                      : isTranscribing
                          ? 'Transcribing...'
                          : 'Ready to listen',
                  style: const TextStyle(
                    fontFamily: fontMulishBold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),
                if (recognizedText.isNotEmpty)
                  Text(
                    recognizedText,
                    style: const TextStyle(fontFamily: fontMulishSemiBold),
                  ),
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
                          await controller.sttService.startRecording();
                          setSheetState(() => isRecording = true);
                        } else {
                          setSheetState(() {
                            isRecording = false;
                            isTranscribing = true;
                          });
                          final text = await controller.sttService.stopAndTranscribe();
                          setSheetState(() {
                            isTranscribing = false;
                            recognizedText = text ?? '';
                          });
                          if (recognizedText.isNotEmpty) {
                            Navigator.pop(context);
                            if (controller.overallRemarksController.text.isNotEmpty) {
                              controller.overallRemarksController.text += '\n';
                            }
                            controller.overallRemarksController.text += recognizedText;
                            
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          Navigator.pop(context, controller.cartItems);
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
              const Icon(
                Icons.shopping_cart_outlined,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                "Cart",
                style: TextStyle(
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
                      child: EditableTextField(controller: controller.tableNameController),
                    ),
            ],
          ),
        ),
        body: Obx(() {
          final tax = controller.tax;
          final total = controller.total;
          final subtotal = controller.subtotal;

          return Column(
            children: [
              Expanded(
                child: controller.cartItems.isEmpty
                    ? const Center(child: Text("No items in cart"))
                    : Stack(
                        children: [
                          ListView.builder(
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: controller.cartItems.length,
                            itemBuilder: (context, index) {
                              final item = controller.cartItems[index];
                              final qty = item['qty'] as int;
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
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
                                                onTap: () => controller.decrementQty(index),
                                                child: Container(
                                                  width: 32,
                                                  height: 32,
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                    Icons.remove,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
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
                                                onTap: () => controller.incrementQty(index),
                                                child: Container(
                                                  width: 32,
                                                  height: 32,
                                                  alignment: Alignment.center,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFFf57c35),
                                                    borderRadius: BorderRadius.horizontal(
                                                      right: Radius.circular(20),
                                                    ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.add,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    // ── Remarks (collapsible) ─────────────────
                                    const SizedBox(height: 8),
                                    if (controller.remarkExpanded[index]) ...[
                                      TextField(
                                        controller: controller.remarkControllers[index],
                                        autofocus: false,
                                        decoration: InputDecoration(
                                          hintText: 'e.g. less spicy, no onion, kam tel…',
                                          hintStyle: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade400,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          isDense: true,
                                          prefixIcon: Icon(
                                            Icons.notes_outlined,
                                            size: 16,
                                            color: Colors.orange.shade600,
                                          ),
                                          suffixIcon: GestureDetector(
                                            onTap: () {
                                              if (controller.remarkControllers[index].text.isEmpty) {
                                                controller.remarkExpanded[index] = false;
                                              }
                                            },
                                            child: Icon(
                                              Icons.keyboard_arrow_up,
                                              size: 18,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                              color: Colors.orange.shade400,
                                              width: 1.5,
                                            ),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
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
                                          controller.cartItems[index]['remarks'] = val;
                                        },
                                      ),
                                    ] else ...[
                                      GestureDetector(
                                        onTap: () => controller.remarkExpanded[index] = true,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.add_comment_outlined,
                                              size: 14,
                                              color: Colors.orange.shade400,
                                            ),
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
                                icon: const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 22,
                                ),
                                label: const Text(
                                  'Billing',
                                  style: TextStyle(
                                    fontFamily: fontMulishSemiBold,
                                    fontSize: 14,
                                  ),
                                ),
                                tooltip: 'Billing',
                                onPressed: () {
                                  controller.isBilling.value = true;
                                  _showBillingBottomSheet(context);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
              ),

              // Overall Remarks Field
              if (controller.cartItems.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: controller.overallRemarksController,
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
                      prefixIcon: Icon(
                        Icons.speaker_notes,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.mic, color: Colors.red.shade400),
                            tooltip: 'Speak more instructions/items',
                            onPressed: _startVoiceOrderCart,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.auto_awesome,
                              color: Color(0xFFf57c35),
                            ),
                            tooltip: 'Detect items from remarks',
                            onPressed: _extractItemsFromRemarks,
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ),

              controller.isBilling.value
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
                                            groupValue: controller.paymentMode.value,
                                            onChanged: (value) {
                                              controller.paymentMode.value = value!;
                                              controller.updatePaymentAmounts();
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
                                      const SizedBox(width: 12),
                                      Row(
                                        children: [
                                          Radio<String>(
                                            value: 'Online',
                                            groupValue: controller.paymentMode.value,
                                            onChanged: (value) {
                                              controller.paymentMode.value = value!;
                                              controller.updatePaymentAmounts();
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
                                      const SizedBox(width: 12),
                                      Row(
                                        children: [
                                          Radio<String>(
                                            value: 'Both',
                                            groupValue: controller.paymentMode.value,
                                            onChanged: (value) {
                                              controller.paymentMode.value = value!;
                                              controller.updatePaymentAmounts();
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
                                  if (controller.paymentMode.value == 'Both')
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12.0,
                                        top: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          const Expanded(child: SizedBox()),
                                          Expanded(
                                            child: TextField(
                                              controller: controller.cashController,
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
                                                contentPadding: const EdgeInsets.symmetric(
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
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ),
                                              onChanged: (value) {
                                                int cashVal = int.tryParse(value) ?? 0;
                                                if (cashVal > total) cashVal = total;
                                                controller.cashController.text = cashVal.toString();
                                                controller.onlineController.text = (total - cashVal).toString();
                                                controller.cashController.selection = TextSelection.fromPosition(
                                                  TextPosition(offset: controller.cashController.text.length),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: controller.onlineController,
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
                                                contentPadding: const EdgeInsets.symmetric(
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
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ),
                                              onChanged: (value) {
                                                int onlineVal = int.tryParse(value) ?? 0;
                                                if (onlineVal > total) onlineVal = total;
                                                controller.onlineController.text = onlineVal.toString();
                                                controller.cashController.text = (total - onlineVal).toString();
                                                controller.onlineController.selection = TextSelection.fromPosition(
                                                  TextPosition(offset: controller.onlineController.text.length),
                                                );
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  const Expanded(
                                    flex: 2,
                                    child: Text(
                                      "Discount",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: secondary_text_color,
                                        fontFamily: fontMulishSemiBold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: controller.discountPercentController,
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
                                        contentPadding: const EdgeInsets.symmetric(
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
                                      keyboardType: const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      onChanged: (value) {
                                        controller.discountPercent.value = double.tryParse(value) ?? 0;
                                        controller.updateDiscountFromPercent();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: controller.discountAmountController,
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
                                        contentPadding: const EdgeInsets.symmetric(
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
                                        controller.discountAmount.value = double.tryParse(value) ?? 0;
                                        controller.updateDiscountFromAmount();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
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
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: InkWell(
                            onTap: () async {
                              final saved = await controller.saveTransaction();
                              if (saved) {
                                await controller.saveTableOrder(
                                  isEditMode: widget.isEditMode,
                                  isBillPaid: true,
                                );
                                Navigator.pop(context);
                                Navigator.pop(context);
                              }
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
                                        const SizedBox(width: 6),
                                        const Text(
                                          "Confirm & Billing",
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.white,
                                            fontFamily: fontMulishSemiBold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white,
                                  ),
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
                        onTap: () async {
                          final success = await controller.saveTableOrder(
                            isEditMode: widget.isEditMode,
                            isBillPaid: false,
                          );
                          if (success) {
                            Navigator.pop(context);
                            Navigator.pop(context);
                          }
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
                                    const SizedBox(width: 6),
                                    const Text(
                                      "Send to Kitchen",
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.white,
                                        fontFamily: fontMulishSemiBold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
            ],
          );
        }),
      ),
    );
  }

  void _showBillingBottomSheet(BuildContext context) {
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
                  child: Obx(() {
                    final tax = controller.tax;
                    final total = controller.total;
                    final subtotal = controller.subtotal;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(0),
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
                                                    visualDensity: const VisualDensity(
                                                      horizontal: -4,
                                                      vertical: -4,
                                                    ),
                                                    groupValue: controller.paymentMode.value,
                                                    onChanged: (value) {
                                                      setModalState(() {
                                                        controller.paymentMode.value = value!;
                                                        controller.updatePaymentAmounts();
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
                                              const SizedBox(width: 8),
                                              Row(
                                                children: [
                                                  Radio<String>(
                                                    value: 'Online',
                                                    visualDensity: const VisualDensity(
                                                      horizontal: -4,
                                                      vertical: -4,
                                                    ),
                                                    groupValue: controller.paymentMode.value,
                                                    onChanged: (value) {
                                                      setModalState(() {
                                                        controller.paymentMode.value = value!;
                                                        controller.updatePaymentAmounts();
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
                                              const SizedBox(width: 8),
                                              Row(
                                                children: [
                                                  Radio<String>(
                                                    value: 'Both',
                                                    visualDensity: const VisualDensity(
                                                      horizontal: -4,
                                                      vertical: -4,
                                                    ),
                                                    groupValue: controller.paymentMode.value,
                                                    onChanged: (value) {
                                                      setModalState(() {
                                                        controller.paymentMode.value = value!;
                                                        controller.updatePaymentAmounts();
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
                                          if (controller.paymentMode.value == 'Both')
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 12.0,
                                                top: 8,
                                              ),
                                              child: Row(
                                                children: [
                                                  const Expanded(child: SizedBox()),
                                                  Expanded(
                                                    child: TextField(
                                                      controller: controller.cashController,
                                                      keyboardType: TextInputType.number,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color: secondary_text_color,
                                                        fontFamily: fontMulishSemiBold,
                                                      ),
                                                      decoration: InputDecoration(
                                                        labelText: "Cash Amount",
                                                        labelStyle: const TextStyle(
                                                          fontSize: 13,
                                                          color: secondary_text_color,
                                                          fontFamily: fontMulishMedium,
                                                        ),
                                                        isDense: true,
                                                        contentPadding: const EdgeInsets.symmetric(
                                                          vertical: 10,
                                                          horizontal: 12,
                                                        ),
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide: const BorderSide(
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ),
                                                      onChanged: (value) {
                                                        setModalState(() {
                                                          int cashVal = int.tryParse(value) ?? 0;
                                                          if (cashVal > total) cashVal = total;
                                                          controller.cashController.text = cashVal.toString();
                                                          controller.onlineController.text = (total - cashVal).toString();
                                                          controller.cashController.selection = TextSelection.fromPosition(
                                                            TextSelection.fromPosition(
                                                              TextPosition(offset: controller.cashController.text.length),
                                                            ).base,
                                                          );
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: TextField(
                                                      controller: controller.onlineController,
                                                      keyboardType: TextInputType.number,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color: secondary_text_color,
                                                        fontFamily: fontMulishSemiBold,
                                                      ),
                                                      decoration: InputDecoration(
                                                        labelText: "Online Amount",
                                                        labelStyle: const TextStyle(
                                                          fontSize: 13,
                                                          color: secondary_text_color,
                                                          fontFamily: fontMulishMedium,
                                                        ),
                                                        isDense: true,
                                                        contentPadding: const EdgeInsets.symmetric(
                                                          vertical: 10,
                                                          horizontal: 12,
                                                        ),
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide: const BorderSide(
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ),
                                                      onChanged: (value) {
                                                        setModalState(() {
                                                          int onlineVal = int.tryParse(value) ?? 0;
                                                          if (onlineVal > total) onlineVal = total;
                                                          controller.onlineController.text = onlineVal.toString();
                                                          controller.cashController.text = (total - onlineVal).toString();
                                                          controller.onlineController.selection = TextSelection.fromPosition(
                                                            TextSelection.fromPosition(
                                                              TextPosition(offset: controller.onlineController.text.length),
                                                            ).base,
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
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                          const Expanded(
                                            flex: 2,
                                            child: Text(
                                              "Discount",
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: secondary_text_color,
                                                fontFamily: fontMulishSemiBold,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: TextField(
                                              controller: controller.discountPercentController,
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
                                                contentPadding: const EdgeInsets.symmetric(
                                                  vertical: 10,
                                                  horizontal: 12,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              keyboardType: const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                              onChanged: (value) {
                                                setModalState(() {
                                                  controller.discountPercent.value = double.tryParse(value) ?? 0;
                                                  controller.updateDiscountFromPercent();
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: controller.discountAmountController,
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
                                                contentPadding: const EdgeInsets.symmetric(
                                                  vertical: 10,
                                                  horizontal: 12,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              keyboardType: TextInputType.number,
                                              onChanged: (value) {
                                                setModalState(() {
                                                  controller.discountAmount.value = double.tryParse(value) ?? 0;
                                                  controller.updateDiscountFromAmount();
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
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            final saved = await controller.saveTransaction();
                            if (saved) {
                              await controller.saveTableOrder(
                                isEditMode: widget.isEditMode,
                                isBillPaid: true,
                              );
                              Navigator.pop(context);
                              Navigator.pop(context);
                              Navigator.pop(context);
                            }
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
                    );
                  }),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
