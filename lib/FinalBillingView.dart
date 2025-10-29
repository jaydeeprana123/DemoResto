import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'Styles/my_colors.dart';
import 'Styles/my_font.dart';
import 'Styles/my_icons.dart';

/// Cart Page
class FinalBillingView extends StatefulWidget {
  final String tableName;
  final List<Map<String, dynamic>> menuData;
  final void Function(List<Map<String, dynamic>> selectedItems) onConfirm;

  FinalBillingView({
    required this.menuData,
    required this.onConfirm,
    required this.tableName,
    Key? key,
  }) : super(key: key);

  @override
  _FinalBillingViewState createState() => _FinalBillingViewState();
}

class _FinalBillingViewState extends State<FinalBillingView> {
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
      appBar: AppBar(
        title: Text(
          "Cart - ${widget.tableName}",
          style: TextStyle(fontSize: 16, fontFamily: fontMulishBold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: cartItems.isEmpty
                ? Center(child: Text("No items in cart"))
                : Scrollbar(
                    thickness: 4,
                    child: ListView.builder(
                      itemCount: cartItems.length,
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        final qty = item['qty'] as int;
                        final lastQty = lastQtys[index];
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
                  ),
          ),
          Column(
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

                    widget.onConfirm([]);
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
      Get.snackbar("Error", "Transaction not saved");
    }
  }
}
