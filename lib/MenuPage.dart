import 'package:flutter/material.dart';
import 'dart:math'; // ⬅️ add this at the top

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

import 'CartPage.dart';

/// Menu Page
/// Menu Page
class MenuPage extends StatefulWidget {
  final void Function(List<Map<String, dynamic>> selectedItems) onConfirm;
  final List<Map<String, dynamic>> initialItems; // previously added items

  MenuPage({required this.onConfirm, this.initialItems = const []});

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  late Map<String, List<Map<String, dynamic>>> menuData;

  @override
  void initState() {
    super.initState();

    menuData = {
      "Appetizers": [
        {"name": "Truffle Arancini", "price": 18.50, "qty": 0},
        {"name": "Margherita Pizza", "price": 12.00, "qty": 0},
        {"name": "Caesar Salad", "price": 10.50, "qty": 0},
        {"name": "Spaghetti Carbonara", "price": 15.75, "qty": 0},
        {"name": "Garlic Bread", "price": 6.50, "qty": 0},
        {"name": "Grilled Salmon", "price": 22.00, "qty": 0},
        {"name": "Beef Lasagna", "price": 16.25, "qty": 0},
        {"name": "Chocolate Lava Cake", "price": 8.50, "qty": 0},
        {"name": "Tiramisu", "price": 7.75, "qty": 0},
        {"name": "Minestrone Soup", "price": 9.00, "qty": 0},
      ],
      "Mains": [
        {"name": "Spicy Tuna Tartare", "price": 24.00, "qty": 0},
        {"name": "Grilled Salmon", "price": 32.00, "qty": 0},
        {"name": "Fried Jeera", "price": 130.00, "qty": 0},
        {"name": "Fried Chicken Masala", "price": 100.00, "qty": 0},
        {"name": "Fried Mutton Masala", "price": 120.00, "qty": 0},
        {"name": "Bhuna Chicken Masala", "price": 200.00, "qty": 0},
        {"name": "Bhuna Mutton Masala", "price": 300.00, "qty": 0},
        {"name": "Chicken Tikka Masala", "price": 220.00, "qty": 0},
        {"name": "Mutton Tikka Masala", "price": 330.00, "qty": 0},
        {"name": "Paneer Butter Masala", "price": 180.00, "qty": 0},
        {"name": "Butter Naan", "price": 25.00, "qty": 0},
        {"name": "Garlic Naan", "price": 30.00, "qty": 0},
        {"name": "Dal Makhani", "price": 150.00, "qty": 0},
        {"name": "Vegetable Biryani", "price": 140.00, "qty": 0},
        {"name": "Chicken Biryani", "price": 220.00, "qty": 0},
        {"name": "Mutton Biryani", "price": 300.00, "qty": 0},
        {"name": "Fish Curry", "price": 210.00, "qty": 0},
        {"name": "Prawn Masala", "price": 320.00, "qty": 0},
        {"name": "Veg Spring Roll", "price": 80.00, "qty": 0},
        {"name": "Chicken Spring Roll", "price": 120.00, "qty": 0},
        {"name": "Gulab Jamun", "price": 60.00, "qty": 0},
        {"name": "Rasgulla", "price": 50.00, "qty": 0},
        {"name": "Ice Cream Sundae", "price": 90.00, "qty": 0},
        {"name": "Mango Lassi", "price": 70.00, "qty": 0},
        {"name": "Masala Chai", "price": 40.00, "qty": 0},
      ],
      "Desserts": [
        {"name": "Chocolate Lava Cake", "price": 12.00, "qty": 0},
        {"name": "Chocolate Browney", "price": 56.50, "qty": 0},
        {"name": "Pineple Cheese Cake", "price": 100.00, "qty": 0},
        {"name": "Choco Truffle", "price": 100.00, "qty": 0},
        {"name": "Strawberry Truffle", "price": 100.00, "qty": 0},
      ],
      "Beverages": [
        {"name": "Fresh Lemonade", "price": 6.00, "qty": 0},
        {"name": "Fresh Pineple", "price": 16.00, "qty": 0},
        {"name": "Fresh Strawberry Soda", "price": 26.00, "qty": 0},
      ],
    };

    // Pre-fill qty from previously added items
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
      for (var item in items)
        total += (item['qty'] as int) * (item['price'] as double);
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
          title: Text("Menu"),
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
                        trailing: qty == 0
                            ? GestureDetector(
                                onTap: () {
                                  setState(() {
                                    item['qty'] = 1; // Set qty to 1
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent, // No fill
                                    border: Border.all(
                                      color: Colors.black87, // Border color
                                      width: 0.5, // Border thickness
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Add",
                                    style: TextStyle(
                                      color:
                                          Colors.black87, // Text matches border
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
                                    icon: Icon(
                                      Icons.remove_circle,
                                      color: Colors.red,
                                    ),
                                    onPressed: () =>
                                        decrementQty(category, index),
                                  ),
                                  Text(
                                    "$qty",
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
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
                padding: EdgeInsets.all(16),
                color: Colors.orange,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "$totalItems items | \$${totalPrice.toStringAsFixed(2)}",
                      style: TextStyle(
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
                      child: Text("View Cart"),
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
