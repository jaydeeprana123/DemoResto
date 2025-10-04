import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/Styles/my_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'Styles/my_colors.dart';
import 'Styles/my_font.dart';

/// Cart Page
class CartPage extends StatefulWidget {
  final String tableName;
  final List<Map<String, dynamic>> menuData;
  final void Function(List<Map<String, dynamic>> selectedItems, bool isBillPaid) onConfirm;

  const CartPage({required this.menuData, required this.onConfirm,required this.tableName, Key? key})
    : super(key: key);

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
        title: Row(
          children: [
            Expanded(child: Text("Cart - ${widget.tableName}",style: TextStyle(
        fontSize: 16,
        fontFamily: fontMulishBold,
        ))),
            
            InkWell(onTap: ()async{

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

              if(widget.tableName.contains("Take Away")){
                widget.onConfirm(cartItems, true);
              }else{
                widget.onConfirm([], true);
              }


              Navigator.pop(context);
              Navigator.pop(context);
            },child: SvgPicture.asset(icon_bill, width: 34, height: 34, color: Colors.black87,))
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: cartItems.isEmpty
                ? Center(child: Text("No items in cart"))
                : ListView.builder(
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                final item = cartItems[index];
                final qty = item['qty'] as int;
                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle,
                              color: Colors.red,
                            ),
                            onPressed: () => decrementQty(index),
                          ),
                          Text("$qty", style: TextStyle(
                            fontSize: 14,
                            color: text_color,
                            fontFamily: fontMulishSemiBold,
                          )),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.green,
                            ),
                            onPressed: () => incrementQty(index),
                          ),
                        ],
                      ),
                    ),
                    if (index < cartItems.length - 1)
                      Container(margin: EdgeInsets.symmetric(horizontal: 12),height: 0.5, color: Colors.grey.shade300),
                  ],
                );
              },
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
                    const Text("Subtotal"),
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
                        decoration: const InputDecoration(
                          labelText: "Discount %",
                          isDense: true,
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                        decoration: const InputDecoration(
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
                            });
                          },
                        ),
                        const Text('Cash'),
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
                            });
                          },
                        ),
                        const Text('Online'),
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
                        const Text('Both'),
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
                          decoration: const InputDecoration(
                            labelText: "Cash Amount",
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setState(() {
                              int cashVal = int.tryParse(value) ?? 0;
                              if (cashVal > total) cashVal = total;
                              cashController.text = cashVal.toString();
                              onlineController.text = (total - cashVal).toString();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: onlineController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Online Amount",
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setState(() {
                              int onlineVal = int.tryParse(value) ?? 0;
                              if (onlineVal > total) onlineVal = total;
                              onlineController.text = onlineVal.toString();
                              cashController.text = (total - onlineVal).toString();
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
                const SizedBox(height: 8),
              ],
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: InkWell(
              onTap: (){
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
                      child: Text(
                        "Add to Table",
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontFamily: fontMulishSemiBold,
                        ),
                      ),
                    ),

                    Icon(Icons.arrow_forward_ios, color: Colors.white,)

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
          )

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
    // Implement your Firestore batch logic similar to _CartPageForTakeAwayState
  }
}

