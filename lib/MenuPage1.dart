import 'package:flutter/material.dart';
import 'dart:math'; // ⬅️ add this at the top

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

import 'CartPage.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'Styles/my_colors.dart';
import 'Styles/my_font.dart';

class MenuPage extends StatefulWidget {
  final void Function(List<Map<String, dynamic>> selectedItems) onConfirm;
  final List<Map<String, dynamic>> initialItems;

  MenuPage({required this.onConfirm, this.initialItems = const []});

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  Map<String, Map<String, dynamic>> quantities = {}; // track qty separately

  void incrementQty(String categoryId, String itemId) {
    setState(() {
      quantities[categoryId] ??= {};
      quantities[categoryId]![itemId] =
          (quantities[categoryId]![itemId] ?? 0) + 1;
    });
  }

  void decrementQty(String categoryId, String itemId) {
    setState(() {
      if (quantities[categoryId] != null &&
          (quantities[categoryId]![itemId] ?? 0) > 0) {
        quantities[categoryId]![itemId]--;
      }
    });
  }

  int get totalItems {
    int total = 0;
    quantities.forEach((_, items) {
      items.forEach((_, qty) => total += qty as int);
    });
    return total;
  }

  double get totalPrice {
    double total = 0.0;
    // Need Firestore snapshot for item prices
    // (Handled inside build method)
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('menus').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        final categories = snapshot.data!.docs;

        return DefaultTabController(
          length: categories.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text("Menu"),
              bottom: TabBar(
                isScrollable: true,
                tabs: categories.map((c) => Tab(text: c['name'])).toList(),
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: TabBarView(
                    children: categories.map((categoryDoc) {
                      final categoryId = categoryDoc.id;

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('menus')
                            .doc(categoryId)
                            .collection('items')
                            .snapshots(),
                        builder: (context, itemSnapshot) {
                          if (!itemSnapshot.hasData)
                            return Center(child: CircularProgressIndicator());

                          final items = itemSnapshot.data!.docs;

                          return ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final itemId = item.id;
                              final name = item['name'];
                              final price = item['price'] * 1.0;
                              final qty =
                                  quantities[categoryId]?[itemId] ?? 0;

                              return ListTile(
                                title: Text(name),
                                subtitle: Text("\$${price.toStringAsFixed(2)}"),
                                trailing: qty == 0
                                    ? GestureDetector(
                                  onTap: () {
                                    incrementQty(categoryId, itemId);
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 5),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.black87,
                                        width: 0.5,
                                      ),
                                      borderRadius:
                                      BorderRadius.circular(12),
                                    ),
                                    child: Text("Add"),
                                  ),
                                )
                                    : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.remove_circle,
                                          color: Colors.red),
                                      onPressed: () =>
                                          decrementQty(categoryId, itemId),
                                    ),
                                    Text(
                                      "$qty",
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87,
                                        fontFamily: fontMulishSemiBold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.add_circle,
                                          color: Colors.green),
                                      onPressed: () =>
                                          incrementQty(categoryId, itemId),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
                if (totalItems > 0)
                  Container(
                    padding: EdgeInsets.all(16),
                    color: primary_color,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "$totalItems items",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final selectedItems = <Map<String, dynamic>>[];

                            // Prepare cart items
                            categories.forEach((categoryDoc) {
                              final categoryId = categoryDoc.id;
                              FirebaseFirestore.instance
                                  .collection('menus')
                                  .doc(categoryId)
                                  .collection('items')
                                  .get()
                                  .then((snapshot) {
                                for (var item in snapshot.docs) {
                                  final itemId = item.id;
                                  final qty =
                                      quantities[categoryId]?[itemId] ?? 0;
                                  if (qty > 0) {
                                    selectedItems.add({
                                      "name": item['name'],
                                      "price": item['price'],
                                      "qty": qty,
                                    });
                                  }
                                }
                                widget.onConfirm(selectedItems);
                              });
                            });
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
      },
    );
  }
}

