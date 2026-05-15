import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:printing/printing.dart';
import 'package:demo/services/pdf_service.dart';
import 'package:demo/Screens/BottomNavigation/bottom_navigation_view.dart';
import 'CartController.dart';

/// GetX refactored Cart Page
class CartPage extends StatelessWidget {
  final String tableName;
  final bool tableNameEditable;
  final List<Map<String, dynamic>> menuData; // selected items
  final List<Map<String, dynamic>> fullMenu; // all items for AI detection
  final bool showBilling;
  final String? overallRemarks;

  final dynamic Function(
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
          backgroundColor: Colors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: Color(0xFF1A3A5C)),
          title: Row(
            children: [
              const Icon(
                Icons.shopping_cart_outlined,
                color: Color(0xFF1A3A5C),
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                "Cart",
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: fontMulishBold,
                  color: Color(0xFF1A3A5C),
                ),
              ),
              const Text(
                " — ",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              (tableName.contains("Table") || !tableNameEditable)
                  ? Text(
                      tableName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontFamily: fontMulishSemiBold,
                        color: Color(0xFFf57c35),
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
                                      color: Colors.black.withOpacity(0.05),
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
                                          child: InkWell(
                                            onTap: () {
                                              controller.incrementQty(index);
                                            },
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['name'],
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontFamily: fontMulishBold,
                                                    color: Color(0xFF1A3A5C),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Text(
                                                      '₹${(item['price'] as num).toStringAsFixed(0)}',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                        fontFamily:
                                                            fontMulishSemiBold,
                                                      ),
                                                    ),

                                                    const SizedBox(width: 6),
                                                    if (qty > 0)
                                                      Text(
                                                        'X $qty',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors
                                                              .grey
                                                              .shade800,
                                                          fontFamily:
                                                              fontMulishRegular,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
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
                                    // const SizedBox(height: 8),
                                    // if (controller.remarkExpanded[index]) ...[
                                    //   TextField(
                                    //     controller:
                                    //         controller.remarkControllers[index],
                                    //     autofocus: false,
                                    //     decoration: InputDecoration(
                                    //       hintText:
                                    //           'e.g. less spicy, no onion, kam tel…',
                                    //       hintStyle: TextStyle(
                                    //         fontSize: 12,
                                    //         color: Colors.grey.shade400,
                                    //         fontStyle: FontStyle.italic,
                                    //       ),
                                    //       isDense: true,
                                    //       prefixIcon: Icon(
                                    //         Icons.notes_outlined,
                                    //         size: 16,
                                    //         color: Colors.orange.shade600,
                                    //       ),
                                    //       suffixIcon: GestureDetector(
                                    //         onTap: () {
                                    //           if (controller
                                    //               .remarkControllers[index]
                                    //               .text
                                    //               .isEmpty) {
                                    //             controller.toggleRemarkExpanded(
                                    //               index,
                                    //               false,
                                    //             );
                                    //           }
                                    //         },
                                    //         child: Icon(
                                    //           Icons.keyboard_arrow_up,
                                    //           size: 18,
                                    //           color: Colors.grey.shade400,
                                    //         ),
                                    //       ),
                                    //       border: OutlineInputBorder(
                                    //         borderRadius: BorderRadius.circular(
                                    //           8,
                                    //         ),
                                    //         borderSide: BorderSide(
                                    //           color: Colors.grey.shade300,
                                    //         ),
                                    //       ),
                                    //       focusedBorder: OutlineInputBorder(
                                    //         borderRadius: BorderRadius.circular(
                                    //           8,
                                    //         ),
                                    //         borderSide: BorderSide(
                                    //           color: Colors.orange.shade400,
                                    //           width: 1.5,
                                    //         ),
                                    //       ),
                                    //       contentPadding:
                                    //           const EdgeInsets.symmetric(
                                    //             horizontal: 10,
                                    //             vertical: 8,
                                    //           ),
                                    //       filled: true,
                                    //       fillColor: Colors.orange.shade50,
                                    //     ),
                                    //     style: TextStyle(
                                    //       fontSize: 12,
                                    //       color: Colors.orange.shade800,
                                    //       fontFamily: fontMulishRegular,
                                    //     ),
                                    //     maxLines: 1,
                                    //     onChanged: (val) =>
                                    //         controller.updateRemark(index, val),
                                    //   ),
                                    // ] else ...[
                                    //   GestureDetector(
                                    //     onTap: () => controller
                                    //         .toggleRemarkExpanded(index, true),
                                    //     child: Row(
                                    //       mainAxisSize: MainAxisSize.min,
                                    //       children: [
                                    //         Icon(
                                    //           Icons.add_comment_outlined,
                                    //           size: 14,
                                    //           color: Colors.orange.shade400,
                                    //         ),
                                    //         const SizedBox(width: 5),
                                    //         Text(
                                    //           'Add Remark',
                                    //           style: TextStyle(
                                    //             fontSize: 12,
                                    //             color: Colors.orange.shade500,
                                    //             fontFamily: fontMulishSemiBold,
                                    //           ),
                                    //         ),
                                    //       ],
                                    //     ),
                                    //   ),
                                    // ],
                                  ],
                                ),
                              );
                            },
                          ),
                          if (showBilling)
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Container(
                                margin: EdgeInsets.all(22),
                                child: FloatingActionButton.extended(
                                  backgroundColor: orange,
                                  foregroundColor: Colors.white,
                                  elevation: 6,
                                  icon: Icon(
                                    controller.isBilling.value
                                        ? Icons.restaurant
                                        : Icons.receipt_long_outlined,
                                    size: 22,
                                  ),
                                  label: Text(
                                    controller.isBilling.value
                                        ? "Send To Kitchen"
                                        : 'Billing',
                                    style: TextStyle(
                                      fontFamily: fontMulishSemiBold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  tooltip: 'Billing',
                                  onPressed: () async {
                                    if (!controller.isBilling.value) {
                                      controller.isBilling.value = true;
                                    } else {
                                      await onConfirm(
                                        controller.cartItems,
                                        false,
                                        controller.tableNameController.text.trim(),
                                        controller.overallRemarksController.text
                                            .trim(),
                                      );
                                      Navigator.pop(context);
                                      Navigator.pop(context);
                                    }
                                  },

                                  //     _showBillingBottomSheet(
                                  //   context,
                                  //   controller,
                                  // )
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: controller.overallRemarksController,
                  maxLines: 3,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A3A5C),
                    fontFamily: fontMulishSemiBold,
                  ),
                  decoration: InputDecoration(
                    labelText: "Order Instructions",
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontFamily: fontMulishMedium,
                    ),
                    hintText: "e.g. Less spicy, extra parcel boxes...",
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                      fontFamily: fontMulishRegular,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFf57c35),
                        width: 1.5,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.notes,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.mic,
                            color: Colors.red.shade400,
                            size: 20,
                          ),
                          onPressed: () =>
                              _startVoiceOrderCart(context, controller),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFFf57c35),
                            size: 20,
                          ),
                          onPressed: controller.extractItemsFromRemarks,
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
              ),

              // Billing Section
              if (controller.isBilling.value)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Subtotal & Tax Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _billingSmallText(
                            "Subtotal",
                            "₹${controller.subtotal.toStringAsFixed(0)}",
                          ),
                          _billingSmallText(
                            "Tax (8.5%)",
                            "₹${controller.tax.round()}",
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Discount Row
                      Row(
                        children: [
                          Expanded(
                            child: _billingField(
                              controller: controller.discountPercentController,
                              label: "Disc %",
                              icon: Icons.percent,
                              onChanged: (v) {
                                controller.discountPercent.value =
                                    double.tryParse(v) ?? 0;
                                controller.updateDiscountFromPercent();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _billingField(
                              controller: controller.discountAmountController,
                              label: "Disc ₹",
                              icon: Icons.currency_rupee,
                              onChanged: (v) {
                                controller.discountAmount.value =
                                    double.tryParse(v) ?? 0;
                                controller.updateDiscountFromAmount();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Payment Selection
                      Row(
                        children: [
                          const Text(
                            "Paid By:",
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: fontMulishBold,
                              color: Color(0xFF1A3A5C),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _paymentRadio(controller, 'Cash'),
                                  _paymentRadio(controller, 'Online'),
                                  _paymentRadio(controller, 'Both'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Both Inputs
                      if (controller.paymentMode.value == 'Both')
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: _billingField(
                                  controller: controller.cashController,
                                  label: "Cash ₹",
                                  icon: Icons.money,
                                  onChanged: (v) {
                                    int cashVal = int.tryParse(v) ?? 0;
                                    if (cashVal > controller.total)
                                      cashVal = controller.total;
                                    controller.cashController.text = cashVal
                                        .toString();
                                    controller.onlineController.text =
                                        (controller.total - cashVal).toString();
                                    controller.cashController.selection =
                                        TextSelection.fromPosition(
                                          TextPosition(
                                            offset: controller
                                                .cashController
                                                .text
                                                .length,
                                          ),
                                        );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _billingField(
                                  controller: controller.onlineController,
                                  label: "Online ₹",
                                  icon: Icons.phone_android,
                                  onChanged: (v) {
                                    int onlineVal = int.tryParse(v) ?? 0;
                                    if (onlineVal > controller.total)
                                      onlineVal = controller.total;
                                    controller.onlineController.text = onlineVal
                                        .toString();
                                    controller.cashController.text =
                                        (controller.total - onlineVal)
                                            .toString();
                                    controller.onlineController.selection =
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

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1),
                      ),

                      // Total & Action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Grand Total",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontFamily: fontMulishMedium,
                                ),
                              ),
                              Text(
                                "₹${controller.total}",
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontFamily: fontMulishBold,
                                  color: Color(0xFF1A3A5C),
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFf57c35),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
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
                                tableName: controller.tableNameController.text,
                                subtotal: controller.subtotal.round(),
                                tax: (controller.subtotal * 0.085).round(),
                                discount: controller.discountAmount.round(),
                                total: controller.total,
                                cashAmount: cash,
                                onlineAmount: online,
                              );

                              // ✅ Check Setting for Print
                              final prefs = await SharedPreferences.getInstance();
                              final bool showPrintSetting = prefs.getBool('show_print_dialog') ?? true;

                              if (showPrintSetting) {
                                // ✅ Ask for Print
                                bool? doPrint = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: const Text(
                                      "Print Receipt",
                                      style: TextStyle(
                                        fontFamily: fontMulishBold,
                                      ),
                                    ),
                                    content: const Text(
                                      "Do you want to print the receipt?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text(
                                          "No",
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFf57c35,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text(
                                          "Yes",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (doPrint == true) {
                                  // ✅ Generate PDF
                                  final pdfBytes =
                                      await PdfService.generateInvoicePdf(
                                        tableName:
                                            controller.tableNameController.text,
                                        items: controller.cartItems,
                                        subtotal: controller.subtotal,
                                        tax: controller.subtotal * 0.085,
                                        discount: controller.discountAmount.value,
                                        total: controller.total,
                                        cashAmount: cash,
                                        onlineAmount: online,
                                      );

                                  // ✅ Show PDF preview and allow print
                                  await Printing.layoutPdf(
                                    onLayout: (format) async => pdfBytes,
                                  );
                                }
                              }

                              await onConfirm(
                                controller.cartItems,
                                true,
                                controller.tableNameController.text.trim(),
                                controller.overallRemarksController.text.trim(),
                              );
                              controller.cartItems.clear(); // Clear local state after billing

                              Navigator.pop(context);
                              Navigator.pop(context);

                              // ✅ Return to dashboard
                              // if (context.mounted) {
                              //   Navigator.pushAndRemoveUntil(
                              //     context,
                              //     MaterialPageRoute(
                              //       builder: (_) =>
                              //           const BottomNavigationView(),
                              //     ),
                              //     (route) => false,
                              //   );
                              // }
                            },
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "CONFIRM & BILL",
                                  style: TextStyle(
                                    fontFamily: fontMulishBold,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else if (controller.cartItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () async {
                      await onConfirm(
                        controller.cartItems,
                        false,
                        controller.tableNameController.text.trim(),
                        controller.overallRemarksController.text.trim(),
                      );
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant, size: 20),
                        SizedBox(width: 12),
                        Text(
                          "SEND TO KITCHEN",
                          style: TextStyle(
                            fontFamily: fontMulishBold,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _billingSmallText(String label, String value) {
    return Row(
      children: [
        Text(
          "$label: ",
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontFamily: fontMulishMedium,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontFamily: fontMulishBold,
            color: Color(0xFF1A3A5C),
          ),
        ),
      ],
    );
  }

  Widget _billingField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 14,
        fontFamily: fontMulishBold,
        color: Color(0xFF1A3A5C),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        prefixIcon: Icon(
          icon,
          size: 14,
          color: const Color(0xFF1A3A5C).withOpacity(0.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFf57c35)),
        ),
      ),
    );
  }

  Widget _paymentRadio(CartController controller, String mode) {
    return Obx(() {
      final isSelected = controller.paymentMode.value == mode;
      return GestureDetector(
        onTap: () {
          controller.paymentMode.value = mode;
          controller.updatePaymentAmounts();
        },
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1A3A5C) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF1A3A5C)
                  : Colors.grey.shade300,
            ),
          ),
          child: Text(
            mode,
            style: TextStyle(
              fontSize: 12,
              fontFamily: fontMulishBold,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      );
    });
  }

  void _showBillingBottomSheet(
    BuildContext context,
    CartController controller,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Obx(() {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Checkout",
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: fontMulishBold,
                      color: Color(0xFF1A3A5C),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _billingSmallText(
                    "Subtotal",
                    "₹${controller.subtotal.toStringAsFixed(0)}",
                  ),
                  _billingSmallText("Tax", "₹${controller.tax.round()}"),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                "Select Payment Method",
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: fontMulishBold,
                  color: Color(0xFF1A3A5C),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _paymentRadio(controller, 'Cash'),
                  _paymentRadio(controller, 'Online'),
                  _paymentRadio(controller, 'Both'),
                ],
              ),
              const SizedBox(height: 24),

              if (controller.paymentMode.value == 'Both')
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _billingField(
                          controller: controller.cashController,
                          label: "Cash ₹",
                          icon: Icons.money,
                          onChanged: (v) {
                            int cashVal = int.tryParse(v) ?? 0;
                            if (cashVal > controller.total)
                              cashVal = controller.total;
                            controller.cashController.text = cashVal.toString();
                            controller.onlineController.text =
                                (controller.total - cashVal).toString();
                            controller
                                .cashController
                                .selection = TextSelection.fromPosition(
                              TextPosition(
                                offset: controller.cashController.text.length,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _billingField(
                          controller: controller.onlineController,
                          label: "Online ₹",
                          icon: Icons.phone_android,
                          onChanged: (v) {
                            int onlineVal = int.tryParse(v) ?? 0;
                            if (onlineVal > controller.total)
                              onlineVal = controller.total;
                            controller.onlineController.text = onlineVal
                                .toString();
                            controller.cashController.text =
                                (controller.total - onlineVal).toString();
                            controller
                                .onlineController
                                .selection = TextSelection.fromPosition(
                              TextPosition(
                                offset: controller.onlineController.text.length,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Total Amount",
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: fontMulishSemiBold,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "₹${controller.total}",
                      style: const TextStyle(
                        fontSize: 22,
                        fontFamily: fontMulishBold,
                        color: Color(0xFF1A3A5C),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf57c35),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  controller.isBilling.value = true;
                  Navigator.pop(ctx);
                },
                child: const Text(
                  "CONFIRM & PROCEED",
                  style: TextStyle(fontFamily: fontMulishBold, fontSize: 16),
                ),
              ),
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
