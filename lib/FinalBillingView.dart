import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'Screens/BottomNavigation/bottom_navigation_view.dart';
import 'MenuPage.dart';
import 'Styles/my_colors.dart';
import 'Styles/my_font.dart';
import 'Styles/my_icons.dart';

/// Cart Page
class FinalBillingView extends StatefulWidget {
  final String tableName;
  final List<Map<String, dynamic>> menuData;
  final List<Map<String, dynamic>> totalMenuList; // Passed from previous page
  final void Function(List<Map<String, dynamic>> selectedItems) onConfirm;



  FinalBillingView({
    required this.menuData,
    required this.totalMenuList,
    required this.onConfirm,
    required this.tableName,
    Key? key,
  }) : super(key: key);

  @override
  _FinalBillingViewState createState() => _FinalBillingViewState();
}

class _FinalBillingViewState extends State<FinalBillingView> {
  static const _navy   = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);
  static const _bg     = Color(0xFFF5F6FA);

  late List<Map<String, dynamic>> cartItems;

  final TextEditingController discountPercentController =
      TextEditingController();
  final TextEditingController discountAmountController =
      TextEditingController();
  late List<int> lastQtys;
  final TextEditingController cashController = TextEditingController();
  final TextEditingController onlineController = TextEditingController();

  double discountPercent = 0.0;
  double discountAmount = 0.0;

  String paymentMode = 'Cash'; // Cash, Online, Both

  @override
  void initState() {
    super.initState();
    cartItems = widget.menuData
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    lastQtys = cartItems.map<int>((e) => e['qty'] as int).toList();

    _updatePaymentAmounts();
  }

  double get subtotal => cartItems.fold(
    0,
    (sum, item) => sum + (item['qty'] as int) * (item['price']),
  );

  int get total => ((subtotal + (subtotal * 0.085) - discountAmount).round());

  void incrementQty(int index) {
    setState(() {
      lastQtys[index] = cartItems[index]['qty']; // store old value
      cartItems[index]['qty']++;
      _updateDiscountFromPercent();
      _updatePaymentAmounts();
    });
  }

  void decrementQty(int index) {
    setState(() {
      lastQtys[index] = cartItems[index]['qty']; // store old value
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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Cart - ${widget.tableName}",
          style: const TextStyle(fontSize: 16, fontFamily: fontMulishBold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MenuPage(
                    menuList: widget.totalMenuList,
                    tableName: widget.tableName,
                    tableNameEditable: false,
                    initialItems: widget.menuData,
                    showBilling: false,
                    isFromFinalBilling: true,
                    onConfirm:
                        (
                          List<Map<String, dynamic>> selectedItems,
                          bool isBillPaid,
                          String tableName,
                          String overallRemarks,
                        ) async {
                          setState(() {
                            cartItems = selectedItems
                                .map((item) => Map<String, dynamic>.from(item))
                                .toList();

                            lastQtys = cartItems
                                .map<int>((e) => e['qty'] as int)
                                .toList();

                            _updatePaymentAmounts();
                          });
                        },
                  ),
                ),
              ).then((onValue) {
                if (onValue != null) {
                  List<Map<String, dynamic>> changedItems = onValue;
                  setState(() {
                    cartItems = changedItems
                        .map((item) => Map<String, dynamic>.from(item))
                        .toList();

                    lastQtys = cartItems
                        .map<int>((e) => e['qty'] as int)
                        .toList();

                    _updatePaymentAmounts();
                  });

                  setState(() {});
                }
              });
              ;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: cartItems.isEmpty
                ? Center(
                    child: Text(
                      "No items in cart",
                      style: TextStyle(
                        fontFamily: fontMulishSemiBold,
                        color: secondary_text_color,
                        fontSize: 16,
                      ),
                    ),
                  )
                : Scrollbar(
                    thickness: 4,
                    child: ListView.builder(
                      itemCount: cartItems.length,
                      padding: const EdgeInsets.only(top: 12, bottom: 12),
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        final qty = item['qty'] as int;
                        final lastQty = lastQtys[index];
                        return InkWell(
                          onTap: () {
                            incrementQty(index);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                          onPressed: () => decrementQty(index),
                                        ),
                                        SizedBox(
                                          // Fixed width to contain the number
                                          height: 30, // Fixed height
                                          child: ClipRect(
                                            // Extra ClipRect to ensure no overflow
                                            child: AnimatedSwitcher(
                                              duration: const Duration(
                                                milliseconds: 300,
                                              ),
                                              transitionBuilder:
                                                  (
                                                    Widget child,
                                                    Animation<double> animation,
                                                  ) {
                                                    final isIncrement =
                                                        (item['qty'] as int) >
                                                        lastQty;

                                                    return ClipRect(
                                                      child: SlideTransition(
                                                        position:
                                                            Tween<Offset>(
                                                              begin: isIncrement
                                                                  ? const Offset(
                                                                      0,
                                                                      0.5,
                                                                    ) // New from bottom
                                                                  : const Offset(
                                                                      0,
                                                                      -0.5,
                                                                    ), // New from top
                                                              end: Offset.zero,
                                                            ).animate(
                                                              CurvedAnimation(
                                                                parent:
                                                                    animation,
                                                                curve: Curves
                                                                    .easeOutCubic,
                                                              ),
                                                            ),
                                                        child: child,
                                                      ),
                                                    );
                                                  },
                                              layoutBuilder: (currentChild, previousChildren) {
                                                return Stack(
                                                  alignment: Alignment.center,
                                                  clipBehavior: Clip
                                                      .hardEdge, // ⭐ IMPORTANT: Clip overflow
                                                  children: [
                                                    if (previousChildren
                                                        .isNotEmpty)
                                                      SlideTransition(
                                                        position: AlwaysStoppedAnimation(
                                                          (item['qty'] as int) >
                                                                  lastQty
                                                              ? const Offset(
                                                                  0,
                                                                  -0.5,
                                                                ) // Exit to top
                                                              : const Offset(
                                                                  0,
                                                                  0.5,
                                                                ), // Exit to bottom
                                                        ),
                                                        child: previousChildren
                                                            .first,
                                                      ),
                                                    if (currentChild != null)
                                                      currentChild,
                                                  ],
                                                );
                                              },
                                              child: Text(
                                                "$qty",
                                                key: ValueKey<int>(qty),
                                                style: TextStyle(
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
                                          onPressed: () => incrementQty(index),
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
                  ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                                  visualDensity: VisualDensity(
                                    horizontal: -4,
                                    vertical: -4,
                                  ),
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
                                  visualDensity: VisualDensity(
                                    horizontal: -4,
                                    vertical: -4,
                                  ),
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
                                  visualDensity: VisualDensity(
                                    horizontal: -4,
                                    vertical: -4,
                                  ),
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
                                        fontSize: 13,
                                        color: secondary_text_color,
                                        fontFamily: fontMulishMedium,
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
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        int cashVal = int.tryParse(value) ?? 0;
                                        if (cashVal > total) cashVal = total;
                                        cashController.text = cashVal
                                            .toString();
                                        onlineController.text =
                                            (total - cashVal).toString();
                                        cashController.selection =
                                            TextSelection.fromPosition(
                                              TextPosition(
                                                offset:
                                                    cashController.text.length,
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
                                        fontSize: 13,
                                        color: secondary_text_color,
                                        fontFamily: fontMulishMedium,
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
                                            (total - onlineVal).toString();
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
                              setState(() {
                                discountPercent = double.tryParse(value) ?? 0;
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
                                discountAmount = double.tryParse(value) ?? 0;
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
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
                    final online = int.tryParse(onlineController.text) ?? 0;

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

                    // ✅ Generate PDF
                    final pdfBytes = await generateInvoicePdf(
                      tableName: widget.tableName,
                      items: cartItems,
                      subtotal: subtotal,
                      tax: subtotal * 0.085,
                      discount: discountAmount,
                      total: total,
                      cashAmount: cash,
                      onlineAmount: online,
                    );

                    // ✅ Show PDF preview and allow print
                    await Printing.layoutPdf(
                      onLayout: (format) async => pdfBytes,
                    );

                    // ✅ CLEAR TABLE IN FIRESTORE
                    final query = await FirebaseFirestore.instance
                        .collection('tables')
                        .where('name', isEqualTo: widget.tableName)
                        .get();
                    
                    for (var doc in query.docs) {
                      if (widget.tableName.contains("Take Away")) {
                        await doc.reference.delete();
                      } else {
                        await doc.reference.update({
                          'items': [],
                          'isPaid': false,
                          'remarks': FieldValue.delete(),
                        });
                      }
                    }

                    // ✅ Return to dashboard
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BottomNavigationView(),
                        ),
                        (route) => false,
                      );
                    }
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
                        const SizedBox(width: 24), // balance out the icon on the right
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
                        const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                        const SizedBox(width: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
      Get.snackbar("Error", "Transaction not saved");
    }
  }

  Future<Uint8List> generateInvoicePdf({
    required String tableName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double tax,
    required double discount,
    required int total,
    required int cashAmount,
    required int onlineAmount,
  }) async {
    final pdf = pw.Document();

    // ✅ Load custom Unicode font
    final fontData = await rootBundle.load("assets/fonts/NotoSans-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    // ✅ Load logo
    final ByteData logoData = await rootBundle.load('assets/images/logo.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.DefaultTextStyle(
            style: pw.TextStyle(font: ttf, fontSize: 12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header section with logo
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Image(logoImage, width: 64, height: 64),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        "Flavor Flow",
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Invoice / Bill",
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                
                pw.Text(
                  "Table / Order: $tableName",
                  style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold, fontSize: 14),
                ),

                pw.Divider(),

                pw.Table(
                  border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text("Item"),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text("Qty"),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text("Price"),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text("Total"),
                        ),
                      ],
                    ),
                    ...items.map((item) {
                      final qty = item['qty'] ?? 1;
                      final price =
                          double.tryParse(item['price'].toString()) ?? 0;
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(item['name'] ?? ''),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('$qty'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('₹${price.toStringAsFixed(2)}'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              '₹${(price * qty).toStringAsFixed(2)}',
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),

                pw.SizedBox(height: 16),

                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Subtotal: ₹${subtotal.toStringAsFixed(2)}"),
                      pw.Text("Tax (8.5%): ₹${tax.toStringAsFixed(2)}"),
                      pw.Text("Discount: ₹${discount.toStringAsFixed(2)}"),
                      pw.Text(
                        "Total: ₹${total.toStringAsFixed(2)}",
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text("Cash: ₹$cashAmount"),
                      pw.Text("Online: ₹$onlineAmount"),
                    ],
                  ),
                ),

                pw.Divider(),

                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    "Thank you for visiting!",
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}
