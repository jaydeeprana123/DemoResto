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

  const MenuPage({
    required this.onConfirm,
    required this.menuList,
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
          title: const Text("Menu"),
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

                      return ListTile(
                        title: Text(item['name']),
                        subtitle: Text("₹${item['price'].toStringAsFixed(2)}"),
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
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.normal,
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

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CartPage(
                              menuData: selectedItems,
                              onConfirm: widget.onConfirm,
                            ),
                          ),
                        );
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
