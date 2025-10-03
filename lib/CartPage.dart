import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'Styles/my_colors.dart';
import 'Styles/my_font.dart';

/// Cart Page
class CartPage extends StatefulWidget {
  final List<Map<String, dynamic>> menuData;
  final void Function(List<Map<String, dynamic>> selectedItems) onConfirm;

  const CartPage({required this.menuData, required this.onConfirm, Key? key})
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

  double discountPercent = 0.0;
  double discountAmount = 0.0;

  @override
  void initState() {
    super.initState();
    cartItems = widget.menuData
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  double get subtotal {
    return cartItems.fold(
      0,
      (sum, item) => sum + (item['qty'] as int) * (item['price'] as double),
    );
  }

  void incrementQty(int index) {
    setState(() {
      cartItems[index]['qty']++;
      _updateDiscountFromPercent();
    });
  }

  void decrementQty(int index) {
    setState(() {
      if (cartItems[index]['qty'] > 1) {
        cartItems[index]['qty']--;
      } else {
        cartItems[index]['qty'] = 0;
        cartItems.removeAt(index);
      }
      _updateDiscountFromPercent();
    });
  }

  void _updateDiscountFromPercent() {
    if (discountPercent > 0) {
      discountAmount = (subtotal * discountPercent) / 100;
      discountAmountController.text = discountAmount.toStringAsFixed(2);
    }
  }

  void _updateDiscountFromAmount() {
    if (discountAmount > 0 && subtotal > 0) {
      discountPercent = (discountAmount / subtotal) * 100;
      discountPercentController.text = discountPercent.toStringAsFixed(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tax = subtotal * 0.085;
    final total = subtotal + tax - discountAmount;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Cart",
          style: TextStyle(fontSize: 16, fontFamily: fontMulishSemiBold),
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
                            contentPadding: EdgeInsets.zero,
                            title: Text(item['name']),
                            subtitle: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("₹${item['price'].toStringAsFixed(2)}"),
                                const SizedBox(width: 16),
                                if (qty > 0)
                                  Text(
                                    "×$qty",
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.red,
                                      fontFamily: fontMulishBold,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: qty == 0
                                ? GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        item['qty'] = 1;
                                        _updateDiscountFromPercent();
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.black87,
                                          width: 0.5,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        "Add",
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.normal,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => decrementQty(index),
                                      ),
                                      Text(
                                        "$qty",
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontFamily: fontMulishSemiBold,
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
                          ),
                          if (index < cartItems.length - 1)
                            const Divider(
                              thickness: 0.8,
                              color: Colors.black26,
                              height: 0,
                            ),
                        ],
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                _buildRow("Subtotal", subtotal),
                _buildRow("Tax (8.5%)", tax),
                const SizedBox(height: 10),

                // ✅ Discount fields
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: discountPercentController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: "Discount %",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            discountPercent = double.tryParse(value) ?? 0;
                            _updateDiscountFromPercent();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: discountAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: "Discount ₹",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                        ),
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

                const SizedBox(height: 10),
                _buildRow("Discount", discountAmount),
                Divider(),
                _buildRow("Total", total, isTotal: true),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onConfirm(cartItems);
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: Text(
                      "Confirm & Add to Table (₹${total.toStringAsFixed(2)})",
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            "₹${value.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
