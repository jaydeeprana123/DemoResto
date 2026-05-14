import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/Styles/my_icons.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:demo/MyWidgets/EditableTextField.dart';
import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/services/ai_order_service.dart';
import 'package:demo/models/agent_response.dart';
import 'CartController.dart';

/// GetX refactored Cart Page
class CartPage extends StatelessWidget {
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

  void _showExtractedItemsDialog(
    BuildContext context,
    CartController controller,
    List<OrderResult> newItems,
  ) {
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
              controller.syncItemsFromExtraction(newItems);
              Navigator.pop(context);
              Get.snackbar('Success', 'Cart synced perfectly with remarks.');
            },
            child: const Text('Add All'),
          ),
        ],
      ),
    );
  }

  Future<void> _startVoiceOrderCart(
    BuildContext context,
    CartController controller,
  ) async {
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
                        backgroundColor: isRecording
                            ? Colors.red
                            : Colors.green,
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
                          final text = await controller.sttService
                              .stopAndTranscribe();
                          setSheetState(() {
                            isTranscribing = false;
                            recognizedText = text ?? '';
                          });
                          if (recognizedText.isNotEmpty) {
                            Navigator.pop(context);
                            controller.onVoiceRecordingComplete(recognizedText);
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
    final controller = Get.put(
      CartController(
        initialCartItems: menuData,
        initialTableName: tableName,
        fullMenu: fullMenu,
        initialRemarks: overallRemarks,
      ),
    );

    // Initialize callbacks
    controller.showExtractedItemsDialog = (newItems) =>
        _showExtractedItemsDialog(context, controller, newItems);
    controller.showLoadingDialog = () => Get.dialog(
      const Center(child: CircularProgressIndicator(color: Color(0xFFf57c35))),
      barrierDismissible: false,
    );
    controller.hideLoadingDialog = () => Get.back();
    controller.showVoiceBottomSheet = (ctx) =>
        _startVoiceOrderCart(ctx, controller);

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
              (tableName.contains("Table") || !tableNameEditable)
                  ? Text(
                      tableName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontFamily: fontMulishBold,
                        color: Colors.white,
                      ),
                    )
                  : Expanded(
                      child: EditableTextField(
                        controller: controller.tableNameController,
                      ),
                    ),
            ],
          ),
        ),
        body: Obx(() {
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
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                        _buildStepper(
                                          qty: qty,
                                          lastQty:
                                              (item['lastQty'] as int?) ??
                                              (qty - 1),
                                          onDecrement: () =>
                                              controller.decrementQty(index),
                                          onIncrement: () =>
                                              controller.incrementQty(index),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (controller.remarkExpanded[index]) ...[
                                      TextField(
                                        controller:
                                            controller.remarkControllers[index],
                                        autofocus: false,
                                        decoration: InputDecoration(
                                          hintText:
                                              'e.g. less spicy, no onion, kam tel…',
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
                                              if (controller
                                                  .remarkControllers[index]
                                                  .text
                                                  .isEmpty) {
                                                controller.toggleRemarkExpanded(
                                                  index,
                                                  false,
                                                );
                                              }
                                            },
                                            child: Icon(
                                              Icons.keyboard_arrow_up,
                                              size: 18,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.orange.shade400,
                                              width: 1.5,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
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
                                        onChanged: (val) =>
                                            controller.updateRemark(index, val),
                                      ),
                                    ] else ...[
                                      GestureDetector(
                                        onTap: () => controller
                                            .toggleRemarkExpanded(index, true),
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
                                onPressed: () => _showBillingBottomSheet(
                                  context,
                                  controller,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),

              if (controller.cartItems.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                      hintText:
                          "e.g. Keep it less spicy, add extra parcel boxes...",
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
                            onPressed: () =>
                                _startVoiceOrderCart(context, controller),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.auto_awesome,
                              color: Color(0xFFf57c35),
                            ),
                            tooltip: 'Detect items from remarks',
                            onPressed: controller.extractItemsFromRemarks,
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ),

              (controller.isBilling.value)
                  ? Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          "Payment By",
                                          style: TextStyle(
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
                                            groupValue:
                                                controller.paymentMode.value,
                                            onChanged: (value) => controller
                                                .setPaymentMode(value!),
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
                                            groupValue:
                                                controller.paymentMode.value,
                                            onChanged: (value) => controller
                                                .setPaymentMode(value!),
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
                                            groupValue:
                                                controller.paymentMode.value,
                                            onChanged: (value) => controller
                                                .setPaymentMode(value!),
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
                                              controller:
                                                  controller.cashController,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: "Cash Amount",
                                                labelStyle: TextStyle(
                                                  fontSize: 10,
                                                ),
                                                border: OutlineInputBorder(),
                                              ),
                                              onChanged: (_) => controller
                                                  .updatePaymentAmounts(),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: TextField(
                                              controller:
                                                  controller.onlineController,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: "Online Amount",
                                                labelStyle: TextStyle(
                                                  fontSize: 10,
                                                ),
                                                border: OutlineInputBorder(),
                                              ),
                                              onChanged: (val) {
                                                int onlineVal =
                                                    int.tryParse(val) ?? 0;
                                                if (onlineVal >
                                                    controller.total)
                                                  onlineVal = controller.total;
                                                controller
                                                    .onlineController
                                                    .text = onlineVal
                                                    .toString();
                                                controller.cashController.text =
                                                    (controller.total -
                                                            onlineVal)
                                                        .toString();
                                                controller
                                                        .onlineController
                                                        .selection =
                                                    TextSelection.fromPosition(
                                                      TextPosition(
                                                        offset: controller
                                                            .onlineController
                                                            .text
                                                            .length,
                                                      ),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Subtotal",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontFamily: fontMulishSemiBold,
                                    ),
                                  ),
                                  Text(
                                    "₹${controller.subtotal.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      fontSize: 14,
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
                                      fontFamily: fontMulishSemiBold,
                                    ),
                                  ),
                                  Text(
                                    "₹${controller.tax.round()}",
                                    style: const TextStyle(
                                      fontSize: 14,
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
                                        fontFamily: fontMulishSemiBold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller:
                                          controller.discountPercentController,
                                      decoration: const InputDecoration(
                                        labelText: "Discount %",
                                        labelStyle: TextStyle(fontSize: 10),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) {
                                        controller.discountPercent.value =
                                            double.tryParse(val) ?? 0.0;
                                        controller.updateDiscountFromPercent();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller:
                                          controller.discountAmountController,
                                      decoration: const InputDecoration(
                                        labelText: "Discount Amt",
                                        labelStyle: TextStyle(fontSize: 10),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) {
                                        controller.discountAmount.value =
                                            double.tryParse(val) ?? 0.0;
                                        controller.updateDiscountFromAmount();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Grand Total",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontFamily: fontMulishBold,
                                      color: Color(0xFF1A3A5C),
                                    ),
                                  ),
                                  Text(
                                    "₹${controller.total}",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontFamily: fontMulishBold,
                                      color: Color(0xFF1A3A5C),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFf57c35),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    final cash =
                                        int.tryParse(
                                          controller.cashController.text,
                                        ) ??
                                        0;
                                    final online =
                                        int.tryParse(
                                          controller.onlineController.text,
                                        ) ??
                                        0;

                                    await controller.addTransactionToFirestore(
                                      items: controller.cartItems,
                                      tableName:
                                          controller.tableNameController.text,
                                      subtotal: controller.subtotal.round(),
                                      tax: controller.tax.round(),
                                      discount: controller.discountAmount.value
                                          .round(),
                                      total: controller.total,
                                      cashAmount: cash,
                                      onlineAmount: online,
                                    );

                                    onConfirm(
                                      controller.cartItems,
                                      true,
                                      controller.tableNameController.text,
                                      controller.overallRemarksController.text,
                                    );
                                    Navigator.pop(
                                      context,
                                      controller.cartItems,
                                    );
                                  },
                                  child: const Text(
                                    "Confirm & Print",
                                    style: TextStyle(
                                      fontFamily: fontMulishBold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Align(
                      alignment: Alignment.bottomCenter,
                      child: InkWell(
                        onTap: () {
                          onConfirm(
                            controller.cartItems,
                            false,
                            controller.tableNameController.text,
                            controller.overallRemarksController.text.trim(),
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
          );
        }),
      ),
    );
  }

  void _showBillingBottomSheet(
    BuildContext context,
    CartController controller,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Obx(() {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Billing Summary",
                style: TextStyle(fontSize: 18, fontFamily: fontMulishBold),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Subtotal"),
                  Text("₹${controller.subtotal.toStringAsFixed(0)}"),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Tax (8.5%)"),
                  Text("₹${controller.tax.round()}"),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Grand Total",
                    style: TextStyle(fontSize: 18, fontFamily: fontMulishBold),
                  ),
                  Text(
                    "₹${controller.total}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontFamily: fontMulishBold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "Payment Mode",
                style: TextStyle(fontFamily: fontMulishSemiBold),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: 'Cash',
                    groupValue: controller.paymentMode.value,
                    onChanged: (v) => controller.setPaymentMode(v!),
                  ),
                  const Text("Cash"),
                  Radio<String>(
                    value: 'Online',
                    groupValue: controller.paymentMode.value,
                    onChanged: (v) => controller.setPaymentMode(v!),
                  ),
                  const Text("Online"),
                  Radio<String>(
                    value: 'Both',
                    groupValue: controller.paymentMode.value,
                    onChanged: (v) => controller.setPaymentMode(v!),
                  ),
                  const Text("Both"),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf57c35),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  controller.isBilling.value = true;
                  Navigator.pop(ctx);
                },
                child: const Text(
                  "Proceed to Checkout",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStepper({
    required int qty,
    required int lastQty,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    final isIncrementing = qty >= lastQty;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A5C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              width: 36,
              height: 34,
              alignment: Alignment.center,
              child: const Icon(Icons.remove, color: Colors.white, size: 16),
            ),
          ),
          SizedBox(
            width: 28,
            height: 34,
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final isIncoming = child.key == ValueKey<int>(qty);
                  Offset beginOffset;
                  if (isIncrementing) {
                    beginOffset = isIncoming
                        ? const Offset(0, 1.0)
                        : const Offset(0, -1.0);
                  } else {
                    beginOffset = isIncoming
                        ? const Offset(0, -1.0)
                        : const Offset(0, 1.0);
                  }
                  return SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: beginOffset,
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOutCubic,
                          ),
                        ),
                    child: child,
                  );
                },
                child: Text(
                  '$qty',
                  key: ValueKey<int>(qty),
                  style: const TextStyle(
                    fontSize: 15,
                    fontFamily: fontMulishBold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              width: 36,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFf57c35),
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(20),
                ),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
