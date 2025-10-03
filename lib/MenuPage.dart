import 'package:demo/CartPageForTakeAway.dart';
import 'package:flutter/material.dart';
import 'dart:math'; // ⬅️ add this at the top

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

import 'CartPage.dart';

import 'package:flutter/material.dart';

import 'Styles/my_colors.dart';
import 'Styles/my_font.dart';

class MenuPage extends StatefulWidget {
  final void Function(List<Map<String, dynamic>> selectedItems) onConfirm;
  final List<Map<String, dynamic>> menuList; // Passed from previous page
  final List<Map<String, dynamic>> initialItems;
  final String tableName;

  const MenuPage({
    required this.onConfirm,
    required this.menuList,
    required this.tableName,
    this.initialItems = const [],
    Key? key,
  }) : super(key: key);

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  late Map<String, List<Map<String, dynamic>>> menuData;

  @override
  void initState() {
    super.initState();

    // Group menuList by category and initialize qty = 0
    menuData = {};

    for (var item in widget.menuList) {
      final category = item['category'] as String;
      menuData[category] ??= [];
      menuData[category]!.add({...item, 'qty': 0});
    }

    // Pre-fill quantities from initialItems if any
    for (var category in menuData.keys) {
      for (var item in menuData[category]!) {
        final existingItem = widget.initialItems.firstWhere(
          (e) => e['name'] == item['name'],
          orElse: () => {},
        );
        if (existingItem.isNotEmpty) {
          item['qty'] = existingItem['qty'];
        }
      }
    }
  }

  void incrementQty(String category, int index) {
    setState(() {
      menuData[category]![index]['qty']++;
    });
  }

  void decrementQty(String category, int index) {
    setState(() {
      if (menuData[category]![index]['qty'] > 0) {
        menuData[category]![index]['qty']--;
      }
    });
  }

  int get totalItems {
    int total = 0;
    menuData.forEach((category, items) {
      for (var item in items) total += item['qty'] as int;
    });
    return total;
  }

  double get totalPrice {
    double total = 0.0;
    menuData.forEach((category, items) {
      for (var item in items) {
        total += (item['qty'] as int) * (item['price'] as double);
      }
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final categories = menuData.keys.toList();

    return DefaultTabController(
      length: categories.length,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Text("Menu - ",style: TextStyle(
                fontSize: 16,
                fontFamily: fontMulishBold,
              ),),


              Text(widget.tableName,style: TextStyle(
                fontSize: 16,
                fontFamily: fontMulishBold,
              ),),

            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            tabs: categories.map((c) => Tab(text: c)).toList(),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: categories.map((category) {
                  final items = menuData[category]!;

                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final qty = item['qty'] as int;

                      return InkWell(
                        onTap: () {
                          incrementQty(category, index);
                        },
                        child: ListTile(
                          title: Text(item['name'], style: TextStyle(
                            fontSize: 15,
                            color: text_color,
                            fontFamily: fontMulishSemiBold,
                          )),
                          subtitle: Row(
                            children: [
                              Text("₹${item['price'].toStringAsFixed(2)}", style: TextStyle(
                                fontSize: 14,
                                color: secondary_text_color,
                                fontFamily: fontMulishRegular,
                              ), ),

                              SizedBox(width: 16),

                              if (item['qty'] > 0)
                                Text(
                                  "\u00D7${item['qty']}",
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
                                      onPressed: () =>
                                          decrementQty(category, index),
                                    ),
                                    Text(
                                      "$qty",
                                      style: const TextStyle(
                                        fontSize: 15,
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
                                          incrementQty(category, index),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
            if (totalItems > 0)
              Container(
                padding: const EdgeInsets.all(16),
                color: primary_color,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "$totalItems items | ₹${totalPrice.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontFamily: fontMulishSemiBold,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final selectedItems = <Map<String, dynamic>>[];
                        menuData.forEach((category, items) {
                          selectedItems.addAll(
                            items.where((item) => item['qty'] > 0),
                          );
                        });

                        // Send selected items to cart or callback


                        if(widget.tableName == "Take Away"){
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CartPageForTakeAway(
                                tableName: widget.tableName,
                                menuData: selectedItems,
                                onConfirm: widget.onConfirm,
                              ),
                            ),
                          );
                        }else{
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CartPage(
                                tableName: widget.tableName,
                                menuData: selectedItems,
                                onConfirm: widget.onConfirm,
                              ),
                            ),
                          );
                        }


                      },
                      child: const Text("View Cart"),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
