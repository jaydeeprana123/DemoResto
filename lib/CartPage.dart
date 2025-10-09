import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/Styles/my_icons.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'Styles/my_colors.dart';
import 'Styles/my_font.dart';

/// Cart Page
class CartPage extends StatefulWidget {
  final String tableName;
  final List<Map<String, dynamic>> menuData;
  final bool showBilling;

  final void Function(List<Map<String, dynamic>> selectedItems, bool isBillPaid)
  onConfirm;

  const CartPage({
    required this.menuData,
    required this.onConfirm,
    required this.tableName,
    required this.showBilling,
    Key? key,
  }) : super(key: key);

  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late List<Map<String, dynamic>> cartItems;

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
    cartItems = widget.menuData
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    _updatePaymentAmounts();
  }

  double get subtotal => cartItems.fold(
    0,
    (sum, item) => sum + (item['qty'] as int) * (item['price']),
  );

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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // IconButton(
            //   icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
            //   onPressed: () => Navigator.pop(context, cartItems),
            // ),
            Expanded(
              child: Text(
                "Cart - ${widget.tableName}",
                style: TextStyle(fontSize: 16, fontFamily: fontMulishBold),
              ),
            ),

            // if (widget.showBilling)
            //   InkWell(
            //     onTap: () async {
            //       setState(() {
            //         isBilling = !isBilling;
            //       });
            //     },
            //     child: isBilling
            //         ? Row(
            //             children: [
            //               SvgPicture.asset(
            //                 icon_cooking,
            //                 width: 28,
            //                 height: 28,
            //                 color: Colors.black87,
            //               ),
            //
            //               SizedBox(width: 6),
            //               Text(
            //                 "Kitchen",
            //                 style: TextStyle(
            //                   fontSize: 14,
            //                   color: text_color,
            //                   fontFamily: fontMulishBold,
            //                 ),
            //               ),
            //             ],
            //           )
            //         : Row(
            //             children: [
            //               SvgPicture.asset(
            //                 icon_bill,
            //                 width: 24,
            //                 height: 24,
            //                 color: Colors.black87,
            //               ),
            //
            //               SizedBox(width: 6),
            //               Text(
            //                 "Billing",
            //                 style: TextStyle(
            //                   fontSize: 14,
            //                   color: text_color,
            //                   fontFamily: fontMulishBold,
            //                 ),
            //               ),
            //             ],
            //           ),
            //   ),
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
                          return InkWell(
                            onTap: () {
                              incrementQty(index);
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['name'],
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: text_color,
                                                fontFamily: fontMulishSemiBold,
                                              ),
                                            ),

                                            SizedBox(height: 2),

                                            Row(
                                              children: [
                                                Text(
                                                  "₹${item['price']}",
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: text_color,
                                                    fontFamily:
                                                        fontMulishSemiBold,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Text(
                                                  "\u00D7$qty",
                                                  style: TextStyle(
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
                                            onPressed: () =>
                                                decrementQty(index),
                                          ),
                                          Text(
                                            "$qty",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: text_color,
                                              fontFamily: fontMulishSemiBold,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add_circle,
                                              color: Colors.green,
                                            ),
                                            onPressed: () =>
                                                incrementQty(index),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  Container(
                                    margin: EdgeInsets.only(top: 8),
                                    height: 0.5,
                                    color: Colors.grey.shade300,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          margin: EdgeInsets.all(22),
                          child: FloatingActionButton(
                            backgroundColor: primary_color,
                            child: SvgPicture.asset(
                              icon_bill,
                              width: 36,
                              height: 28,
                              color: Colors.white,
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
                                                  (total - cashVal).toString();
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
                                              onlineController.text = onlineVal
                                                  .toString();
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
                            tableName: widget.tableName,
                            subtotal: subtotal.round(),
                            tax: (subtotal * 0.085).round(),
                            discount: discountAmount.round(),
                            total: total,
                            cashAmount: cash,
                            onlineAmount: online,
                          );

                          widget.onConfirm(cartItems, true);

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
                      widget.onConfirm(cartItems, false);
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

                          widget.onConfirm(cartItems, true);
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
