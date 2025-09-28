import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/AddCategoryPage.dart' hide AddTablePage;
import 'package:demo/AddMenuItemPage.dart';
import 'package:flutter/material.dart';
import 'AddTablePage.dart';
import 'CartPage.dart';
import 'FinalCartPage.dart';
import 'MenuPage.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:flutter/material.dart';
import 'MenuPage.dart';
import 'package:get/get.dart';

import 'package:flutter/material.dart';
import 'MenuPage.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';

// Import your AddTablePage, AddCategoryPage, MenuPage, FinalCartPage here
// import 'add_table_page.dart';
// import 'add_category_page.dart';
// import 'menu_page.dart';
// import 'final_cart_page.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class DragListBetweenTables extends StatefulWidget {
  @override
  State<DragListBetweenTables> createState() => _DragListBetweenTablesState();
}

class _DragListBetweenTablesState extends State<DragListBetweenTables> {
  Map<String, List<Map<String, dynamic>>> tables = {};
  final List<Map<String, dynamic>> menu = [];
  bool isLoading = false;

  StreamSubscription<QuerySnapshot>? tablesSubscription;

  @override
  void initState() {
    super.initState();
    _listenToTables();
    _loadMenu(); // Load menu once (no real-time needed)
  }

  @override
  void dispose() {
    tablesSubscription?.cancel();
    super.dispose();
  }

  void _listenToTables() {
    tablesSubscription = FirebaseFirestore.instance
        .collection('tables')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen((querySnapshot) {
      Map<String, List<Map<String, dynamic>>> updatedTables = {};

      for (var doc in querySnapshot.docs) {
        final tableName = doc['name'] as String;
        final List<dynamic>? itemsFromDb =
        doc.data().containsKey('items') ? doc['items'] : null;

        List<Map<String, dynamic>> itemsList = [];
        if (itemsFromDb != null) {
          itemsList = List<Map<String, dynamic>>.from(
              itemsFromDb.map((item) => Map<String, dynamic>.from(item)));
        }
        updatedTables[tableName] = itemsList;
      }

      setState(() {
        tables = updatedTables;
      });
    });
  }

  Future<void> _loadMenu() async {
    setState(() {
      isLoading = true;
    });

    try {
      List<Map<String, dynamic>> loadedMenu = [];
      final menuSnapshot = await FirebaseFirestore.instance.collection('menus').get();

      for (var categoryDoc in menuSnapshot.docs) {
        final categoryId = categoryDoc.id;
        final categoryName = categoryDoc['name'];

        final itemsSnapshot = await FirebaseFirestore.instance
            .collection('menus')
            .doc(categoryId)
            .collection('items')
            .get();

        for (var itemDoc in itemsSnapshot.docs) {
          loadedMenu.add({
            "category": categoryName,
            "name": itemDoc['name'],
            "price": itemDoc['price'],
            "categoryId": categoryId,
            "itemId": itemDoc.id,
            "qty": 1, // default quantity when loading menu
          });
        }
      }

      setState(() {
        menu.clear();
        menu.addAll(loadedMenu);
        isLoading = false;
      });
    } catch (e) {
      print("Error loading menu data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateTableItemsInFirestore(
      String tableName, List<Map<String, dynamic>> items) async {
    try {
      final tableQuery = await FirebaseFirestore.instance
          .collection('tables')
          .where('name', isEqualTo: tableName)
          .limit(1)
          .get();

      if (tableQuery.docs.isNotEmpty) {
        final docId = tableQuery.docs.first.id;

        await FirebaseFirestore.instance.collection('tables').doc(docId).update({
          'items': items,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        print("Table $tableName not found in Firestore!");
      }
    } catch (e) {
      print("Error updating items in Firestore: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(child: Text("My Restaurant", style: TextStyle(fontSize: 16))),
            InkWell(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddTablePage()),
                );
                if (result == true) {
                  // No need to reload tables manually because of real-time listener
                }
              },
              child: Row(
                children: [
                  Icon(Icons.add_circle),
                  SizedBox(width: 3),
                  Text("Table", style: TextStyle(fontSize: 15)),
                ],
              ),
            ),
            SizedBox(width: 16),
            InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => AddCategoryPage()));
              },
              child: Row(
                children: [
                  Icon(Icons.menu_book),
                  SizedBox(width: 3),
                  Text("Menu", style: TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(0.0),
            child: tables.isEmpty
                ? Center(child: Text("No tables available. Please add a table."))
                : RefreshIndicator(
              onRefresh: () async {
                // Manual refresh for menu only, since tables auto-refresh
                await _loadMenu();
              },
              child: MasonryGridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                itemCount: tables.keys.length,
                itemBuilder: (context, index) {
                  final tableName = tables.keys.elementAt(index);
                  final items = tables[tableName]!;

                  return DragTarget<String>(
                    onAccept: (sourceTable) async {
                      if (sourceTable != tableName) {
                        setState(() {
                          tables[tableName]!.addAll(tables[sourceTable]!);
                          tables[sourceTable]!.clear();
                        });

                        await _updateTableItemsInFirestore(tableName, tables[tableName]!);
                        await _updateTableItemsInFirestore(sourceTable, tables[sourceTable]!);
                      }
                    },
                    builder: (context, candidateData, rejectedData) {
                      return LongPressDraggable<String>(
                        data: tableName,
                        feedback: Material(
                          child: Container(
                            width: 160,
                            padding: EdgeInsets.all(8),
                            color: Colors.blueAccent,
                            child: Text(
                              tableName,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                color: items.isNotEmpty ? Colors.green : Colors.orange,
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      tableName,
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    InkWell(
                                      onTap: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => MenuPage(
                                              menuList: menu,
                                              initialItems: List<Map<String, dynamic>>.from(items),
                                              onConfirm: (selectedItems) async {
                                                setState(() {
                                                  tables[tableName]!.clear();
                                                  tables[tableName]!.addAll(selectedItems);
                                                });
                                                await _updateTableItemsInFirestore(tableName, selectedItems);
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                      child: Icon(
                                        Icons.add_circle,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (items.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(40.0),
                                  child: Center(
                                    child: Text(
                                      "No items",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.black38,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                GestureDetector(
                                  onDoubleTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FinalCartPage(
                                          menuData: List<Map<String, dynamic>>.from(items),
                                          onConfirm: (selectedItems) async {
                                            setState(() {
                                              tables[tableName]!.clear();
                                              tables[tableName]!.addAll(selectedItems);
                                            });
                                            await _updateTableItemsInFirestore(tableName, selectedItems);
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: items.map((item) {
                                        final qty = item['qty'] ?? 1;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: item['name'],
                                                  style: TextStyle(fontSize: 13, color: Colors.black87),
                                                ),
                                                TextSpan(
                                                  text: " \u00D7$qty",
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          if (isLoading) Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}





