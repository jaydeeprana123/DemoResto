import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'Styles/my_colors.dart';
import 'Styles/my_font.dart';

/// Cart Page
class CartPageForTakeAway extends StatefulWidget {
  final String tableName;
  final List<Map<String, dynamic>> menuData;
  final void Function(List<Map<String, dynamic>> selectedItems, bool isBillPaid) onConfirm;

  const CartPageForTakeAway({
    required this.menuData,
    required this.onConfirm,
    required this.tableName,
    Key? key,
  }) : super(key: key);

  @override
  _CartPageForTakeAwayState createState() => _CartPageForTakeAwayState();
}

class _CartPageForTakeAwayState extends State<CartPageForTakeAway> {
  late List<Map<String, dynamic>> cartItems;

  final TextEditingController discountPercentController =
      TextEditingController();
  final TextEditingController discountAmountController =
      TextEditingController();

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
    _updatePaymentAmounts();
  }

  double get subtotal => cartItems.fold(
    0,
    (sum, item) => sum + (item['qty'] as int) * (item['price'] as double),
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
        title: Text(
          "Cart - ${widget.tableName}",
          style: TextStyle(fontSize: 16),
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
                        return Column(
                          children: [
                            ListTile(
                              title: Text(item['name'], style: TextStyle(
                                fontSize: 14,
                                color: text_color,
                                fontFamily: fontMulishSemiBold,
                              )),
                              subtitle: Row(
                                children: [
                                  Text("₹${item['price']}", style: TextStyle(
                                    fontSize: 13,
                                    color: text_color,
                                    fontFamily: fontMulishSemiBold,
                                  )),
                                  SizedBox(width: 16),

                                  Text(
                                    "\u00D7${item['qty']}",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.red,
                                      fontFamily: fontMulishBold,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.remove_circle,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => decrementQty(index),
                                  ),
                                  Text("$qty"),
                                  IconButton(
                                    icon: Icon(
                                      Icons.add_circle,
                                      color: Colors.green,
                                    ),
                                    onPressed: () => incrementQty(index),
                                  ),
                                ],
                              ),
                            ),
                            if (index < cartItems.length - 1)
                              Divider(height: 0, color: Colors.grey.shade300),
                          ],
                        );
                      },
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Subtotal"),
                    Text("₹${subtotal.toStringAsFixed(0)}"),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text("Tax (8.5%)"), Text("₹$tax")],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: discountPercentController,
                        decoration: InputDecoration(
                          labelText: "Discount %",
                          isDense: true,
                        ),
                        keyboardType: TextInputType.numberWithOptions(
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: discountAmountController,
                        decoration: InputDecoration(
                          labelText: "Discount ₹",
                          isDense: true,
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
                const SizedBox(height: 8),
                // Payment Mode Radio
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Radio<String>(
                          value: 'Cash',
                          groupValue: paymentMode,
                          onChanged: (value) {
                            setState(() {
                              paymentMode = value!;
                              _updatePaymentAmounts();
                              cashController.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: cashController.text.length,
                              );
                            });
                          },
                        ),
                        Text(
                          'Cash',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: fontMulishBold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Radio<String>(
                          value: 'Online',
                          groupValue: paymentMode,
                          onChanged: (value) {
                            setState(() {
                              paymentMode = value!;
                              _updatePaymentAmounts();
                              onlineController.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: onlineController.text.length,
                              );
                            });
                          },
                        ),
                        Text(
                          'Online',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: fontMulishBold,
                          ),
                        ),
                      ],
                    ),
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
                        Text(
                          'Both',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: fontMulishBold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (paymentMode == 'Both')
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cashController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Cash Amount",
                            isDense: true,
                          ),
                          onTap: () {
                            cashController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: cashController.text.length,
                            );
                          },
                          onChanged: (value) {
                            setState(() {
                              int cashVal = int.tryParse(value) ?? 0;
                              if (cashVal > total) cashVal = total;
                              cashController.text = cashVal.toString();
                              onlineController.text = (total - cashVal)
                                  .toString();
                              cashController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(
                                      offset: cashController.text.length,
                                    ),
                                  );
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: onlineController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Online Amount",
                            isDense: true,
                          ),
                          onTap: () {
                            onlineController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: onlineController.text.length,
                            );
                          },
                          onChanged: (value) {
                            setState(() {
                              int onlineVal = int.tryParse(value) ?? 0;
                              if (onlineVal > total) onlineVal = total;
                              onlineController.text = onlineVal.toString();
                              cashController.text = (total - onlineVal)
                                  .toString();
                              onlineController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(
                                      offset: onlineController.text.length,
                                    ),
                                  );
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "₹$total",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async{
                      final cash = int.tryParse(cashController.text) ?? 0;
                      final online = int.tryParse(onlineController.text) ?? 0;

                      await addTransactionToFirestore(
                      items: cartItems,
                      tableName: widget.tableName,
                      subtotal: subtotal.round(),
                      tax: (subtotal * 0.085).round(),
                      discount: discountAmount.round(), // if no tip
                      total: total,
                      cashAmount: cash,
                      onlineAmount: online,
                      );


                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: Text("Confirm & Billing (₹$total)"),
                  ),
                ),
              ],
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
            .map((e) => {
          "name": e["name"],
          "qty": e["qty"],
          "price": (e["price"] as double).round(), // convert to int
          "total": ((e["qty"] as int) * (e["price"] as double)).round(),
        })
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
      final dailyRef = FirebaseFirestore.instance.collection("daily_stats").doc(dateKey);
      batch.set(
        dailyRef,
        {
          "revenue": FieldValue.increment(total),
          "transactions": FieldValue.increment(1),
          "lastUpdated": FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 3️⃣ Update global summary
      final summaryRef = FirebaseFirestore.instance.collection("stats").doc("summary");
      batch.set(
        summaryRef,
        {
          "totalRevenue": FieldValue.increment(total),
          "totalTransactions": FieldValue.increment(1),
          "lastUpdated": FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 4️⃣ Commit batch
      await batch.commit();
      Get.snackbar("Successfull", "Transaction saved successfully!");
    } catch (e) {
      Get.snackbar("Error", "Transaction not saved");
    }
  }

}
