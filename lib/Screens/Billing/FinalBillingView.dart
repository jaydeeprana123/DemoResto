import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

import 'package:demo/Screens/BottomNavigation/bottom_navigation_view.dart';
import 'package:demo/Screens/Menu/MenuPageView.dart';
import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/Styles/my_icons.dart';
import 'package:demo/Screens/Billing/controllers/billing_controller.dart';

/// FinalBillingView
/// 
/// Part of the GetX Repository Pattern.
/// Refactored to be a clean, high-performance [StatelessWidget] observing reactive variables
/// inside the [BillingController] via the [Obx] wrapper.
class FinalBillingView extends StatelessWidget {
  final String tableName;
  final List<Map<String, dynamic>> menuData;
  final List<Map<String, dynamic>> totalMenuList; // Passed from previous page

  FinalBillingView({
    required this.menuData,
    required this.totalMenuList,
    required this.tableName,
    Key? key,
  }) : super(key: key);

  static const _navy = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);
  static const _bg = Color(0xFFF5F6FA);

  @override
  Widget build(BuildContext context) {
    // Put or locate the controller. Tagging by tableName guarantees isolated state instances per table billing session.
    final BillingController controller = Get.put(
      BillingController(tableName: tableName, initialMenuData: menuData),
      tag: tableName,
    );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Cart - $tableName",
          style: const TextStyle(
            fontSize: 16,
            fontFamily: fontMulishBold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MenuPageView(
                    menuList: totalMenuList,
                    tableName: tableName,
                    tableNameEditable: false,
                    initialItems: controller.cartItems,
                    showBilling: false,
                    isFromFinalBilling: true,
                    isEditMode: true,
                  ),
                ),
              ).then((onValue) {
                if (onValue != null) {
                  List<Map<String, dynamic>> changedItems = onValue;
                  controller.cartItems.assignAll(
                    changedItems.map((item) => Map<String, dynamic>.from(item)).toList(),
                  );
                  controller.lastQtys.assignAll(
                    controller.cartItems.map<int>((e) => e['qty'] as int).toList(),
                  );
                  controller.updatePaymentAmounts();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (controller.cartItems.isEmpty) {
                return Center(
                  child: Text(
                    "No items in cart",
                    style: TextStyle(
                      fontFamily: fontMulishSemiBold,
                      color: secondary_text_color,
                      fontSize: 16,
                    ),
                  ),
                );
              }

              return Scrollbar(
                thickness: 4,
                child: ListView.builder(
                  itemCount: controller.cartItems.length,
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  itemBuilder: (context, index) {
                    final item = controller.cartItems[index];
                    final qty = item['qty'] as int;
                    final lastQty = controller.lastQtys[index];

                    return InkWell(
                      onTap: () {
                        controller.incrementQty(index);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: text_color,
                                          fontFamily: fontMulishSemiBold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            "₹${item['price']}",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: text_color,
                                              fontFamily: fontMulishSemiBold,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Text(
                                            "\u00D7$qty",
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.red,
                                              fontFamily: fontMulishBold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => controller.decrementQty(index),
                                    ),
                                    SizedBox(
                                      height: 30, // Fixed height
                                      child: ClipRect(
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          transitionBuilder: (
                                            Widget child,
                                            Animation<double> animation,
                                          ) {
                                            final isIncrement = qty > lastQty;

                                            return ClipRect(
                                              child: SlideTransition(
                                                position: Tween<Offset>(
                                                  begin: isIncrement
                                                      ? const Offset(0, 0.5) // New from bottom
                                                      : const Offset(0, -0.5), // New from top
                                                  end: Offset.zero,
                                                ).animate(
                                                  CurvedAnimation(
                                                    parent: animation,
                                                    curve: Curves.easeOutCubic,
                                                  ),
                                                ),
                                                child: child,
                                              ),
                                            );
                                          },
                                          layoutBuilder: (currentChild, previousChildren) {
                                            return Stack(
                                              alignment: Alignment.center,
                                              clipBehavior: Clip.hardEdge, // ⭐ IMPORTANT: Clip overflow
                                              children: [
                                                if (previousChildren.isNotEmpty)
                                                  SlideTransition(
                                                    position: AlwaysStoppedAnimation(
                                                      qty > lastQty
                                                          ? const Offset(0, -0.5) // Exit to top
                                                          : const Offset(0, 0.5), // Exit to bottom
                                                    ),
                                                    child: previousChildren.first,
                                                  ),
                                                if (currentChild != null)
                                                  currentChild,
                                              ],
                                            );
                                          },
                                          child: Text(
                                            "$qty",
                                            key: ValueKey<int>(qty),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.green,
                                              fontFamily: fontMulishBold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add_circle,
                                        color: Colors.green,
                                      ),
                                      onPressed: () => controller.incrementQty(index),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
          Obx(() {
            final tax = controller.tax;
            final subtotal = controller.subtotal;
            final total = controller.total;
            final paymentMode = controller.paymentMode.value;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Payment Mode Selection
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
                                        groupValue: paymentMode,
                                        visualDensity: const VisualDensity(
                                          horizontal: -4,
                                          vertical: -4,
                                        ),
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
                                        groupValue: paymentMode,
                                        visualDensity: const VisualDensity(
                                          horizontal: -4,
                                          vertical: -4,
                                        ),
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
                                        groupValue: paymentMode,
                                        visualDensity: const VisualDensity(
                                          horizontal: -4,
                                          vertical: -4,
                                        ),
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

                              // Cash + Online Split Inputs
                              if (paymentMode == 'Both')
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
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ),
                                          onChanged: (value) {
                                            int cashVal = int.tryParse(value) ?? 0;
                                            if (cashVal > total) {
                                              cashVal = total;
                                            }
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
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ),
                                          onChanged: (value) {
                                            int onlineVal = int.tryParse(value) ?? 0;
                                            if (onlineVal > total) {
                                              onlineVal = total;
                                            }
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
                                    controller.discountPercent.value = double.tryParse(value) ?? 0.0;
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
                                    controller.discountAmount.value = double.tryParse(value) ?? 0.0;
                                    controller.updateDiscountFromAmount();
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
                          // Saves transaction records and clears the active table/take away order in Firestore
                          await controller.checkoutBill();

                          // ✅ Gracefully return to the dashboard
                          Get.offAll(() => const BottomNavigationView());
                        },
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _orange,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _orange.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(width: 24), // Balance arrow icon on the right
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SvgPicture.asset(
                                      icon_bill,
                                      width: 22,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "Confirm & Billing",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontFamily: fontMulishBold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
