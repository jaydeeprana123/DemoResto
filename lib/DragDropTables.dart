import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/AddCategoryPage.dart' hide AddTablePage;
import 'package:demo/AddMenuItemPage.dart';
import 'package:demo/Styles/my_icons.dart';
import 'package:demo/TransactionsPage.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'AddTablePage.dart';
import 'AllOrdersPage.dart';
import 'CartPage.dart';
import 'FinalCartPage.dart';
import 'MenuPage.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

import 'Styles/my_colors.dart';
import 'Styles/my_font.dart';

class DragListBetweenTables extends StatefulWidget {
  @override
  State<DragListBetweenTables> createState() => _DragListBetweenTablesState();
}

class _DragListBetweenTablesState extends State<DragListBetweenTables> {
  Map<String, List<List<Map<String, dynamic>>>> tables = {};
  final List<Map<String, dynamic>> menu = [];
  bool isLoading = false;

  StreamSubscription<QuerySnapshot>? tablesSubscription;

  @override
  void initState() {
    super.initState();
    _listenToTables();
    _loadMenu();
  }

  @override
  void dispose() {
    tablesSubscription?.cancel();
    super.dispose();
  }

  // Listen to Firestore tables collection changes - UPDATED for flattened structure
  void _listenToTables() {
    tablesSubscription = FirebaseFirestore.instance
        .collection('tables')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen((querySnapshot) {
          Map<String, List<List<Map<String, dynamic>>>> updatedTables = {};

          for (var doc in querySnapshot.docs) {
            final tableName = doc['name'] as String;
            final List<dynamic>? itemsFromDb = doc.data().containsKey('items')
                ? doc['items']
                : null;

            List<List<Map<String, dynamic>>> groupedItems = [];

            if (itemsFromDb != null && itemsFromDb.isNotEmpty) {
              // Check if items have groupIndex (new flattened format)
              bool hasGroupIndex =
                  itemsFromDb.isNotEmpty &&
                  itemsFromDb.first is Map &&
                  (itemsFromDb.first as Map).containsKey('groupIndex');

              if (hasGroupIndex) {
                // NEW FORMAT: Reconstruct groups from flattened data using groupIndex
                Map<int, List<Map<String, dynamic>>> groupMap = {};

                for (var item in itemsFromDb) {
                  if (item is Map) {
                    Map<String, dynamic> itemMap = Map<String, dynamic>.from(
                      item,
                    );
                    int groupIndex = itemMap['groupIndex'] ?? 0;

                    // Remove groupIndex from the item (it's only for storage)
                    itemMap.remove('groupIndex');

                    if (!groupMap.containsKey(groupIndex)) {
                      groupMap[groupIndex] = [];
                    }
                    groupMap[groupIndex]!.add(itemMap);
                  }
                }

                // Convert to ordered list of groups
                List<int> sortedGroupIndices = groupMap.keys.toList()..sort();
                for (int groupIndex in sortedGroupIndices) {
                  groupedItems.add(groupMap[groupIndex]!);
                }

                print(
                  "Reconstructed ${groupedItems.length} groups from flattened data",
                );
              }
              // Handle legacy formats
              else if (itemsFromDb.first is List) {
                // OLD NESTED FORMAT: Direct conversion (shouldn't happen with new saves)
                for (var group in itemsFromDb) {
                  if (group is List) {
                    List<Map<String, dynamic>> itemList = [];
                    for (var item in group) {
                      if (item is Map) {
                        itemList.add(Map<String, dynamic>.from(item));
                      }
                    }
                    groupedItems.add(itemList);
                  }
                }
              } else if (itemsFromDb.first is Map) {
                // FLAT FORMAT: Convert to single group
                List<Map<String, dynamic>> itemList = [];
                for (var item in itemsFromDb) {
                  if (item is Map) {
                    itemList.add(Map<String, dynamic>.from(item));
                  }
                }
                if (itemList.isNotEmpty) {
                  groupedItems.add(itemList);
                }
              }
            }

            updatedTables[tableName] = groupedItems;
            print(
              "Table '$tableName' loaded with ${groupedItems.length} groups",
            );
          }

          setState(() {
            tables = updatedTables;
          });
        });
  }

  // Load menu data from Firestore
  Future<void> _loadMenu() async {
    setState(() {
      isLoading = true;
    });

    try {
      List<Map<String, dynamic>> loadedMenu = [];
      final menuSnapshot = await FirebaseFirestore.instance
          .collection('menus')
          .get();

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
            "qty": 1,
          });
        }
      }

      setState(() {
        menu.clear();
        menu.addAll(loadedMenu);
        isLoading = false;
      });
    } catch (e) {
      print("Error loading menu: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // Update table items in Firestore
  Future<void> _updateTableItemsInFirestore(
    String tableName,
    List<List<Map<String, dynamic>>> groups,
  ) async {
    try {
      print("=== UPDATING FIREBASE ===");
      print("Table name: $tableName");
      print("Groups to save: ${groups.length}");

      final tableQuery = await FirebaseFirestore.instance
          .collection('tables')
          .where('name', isEqualTo: tableName)
          .limit(1)
          .get();

      if (tableQuery.docs.isEmpty) {
        print("ERROR: Table $tableName not found in Firebase!");
        return;
      }

      final docId = tableQuery.docs.first.id;
      print("Document ID found: $docId");

      List<Map<String, dynamic>> flattenedItems = [];

      for (int groupIndex = 0; groupIndex < groups.length; groupIndex++) {
        var group = groups[groupIndex];

        // Get addedAt for the group (either from first item's addedAt or now)
        Timestamp groupTimestamp;
        if (group.isNotEmpty && group[0].containsKey('addedAt')) {
          groupTimestamp = group[0]['addedAt'];
        } else {
          groupTimestamp = Timestamp.now(); // default
        }

        for (var item in group) {
          final itemWithMeta = Map<String, dynamic>.from(item);

          // Add groupIndex and addedAt to item
          itemWithMeta['groupIndex'] = groupIndex;
          itemWithMeta['addedAt'] = groupTimestamp;

          flattenedItems.add(itemWithMeta);
        }
      }

      final updateData = {
        'items': flattenedItems,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('tables')
          .doc(docId)
          .update(updateData);

      print(
        "SUCCESS: Updated $tableName with ${flattenedItems.length} items and ${groups.length} groups",
      );
      print("=== END UPDATE ===");
    } catch (e) {
      print("ERROR: Failed to update Firestore: $e");
      if (e is FirebaseException) {
        print("Firebase error code: ${e.code}");
        print("Firebase error message: ${e.message}");
      }
    }
  }

  // Merge items by name and category to combine quantities
  List<Map<String, dynamic>> _mergeItemsByNameAndCategory(
    List<Map<String, dynamic>> items,
  ) {
    final Map<String, Map<String, dynamic>> itemMap = {};

    for (var item in items) {
      final key = "${item['name']}_${item['categoryId']}";
      if (itemMap.containsKey(key)) {
        itemMap[key]!['qty'] = (itemMap[key]!['qty'] ?? 1) + (item['qty'] ?? 1);
      } else {
        itemMap[key] = Map<String, dynamic>.from(item);
      }
    }

    return itemMap.values.toList();
  }

  // Add a new table with empty items list
  Future<void> _addTable(String tableName) async {
    try {
      final existing = await FirebaseFirestore.instance
          .collection('tables')
          .where('name', isEqualTo: tableName)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        print("Table already exists");
        return;
      }

      await FirebaseFirestore.instance.collection('tables').add({
        'name': tableName,
        'items': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      print("Table $tableName added.");
    } catch (e) {
      print("Error adding table: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                "My Restaurant",
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: fontMulishSemiBold,
                ),
              ),
            ),
            InkWell(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddTablePage()),
                );

                if (result is String && result.trim().isNotEmpty) {
                  await _addTable(result.trim());
                }
              },
              child: SvgPicture.asset(
                icon_table,
                height: 28,
                color: Colors.black87,
              ),

              // Row(
              //   children: [
              //     Icon(Icons.add_circle),
              //     SizedBox(width: 3),
              //     Text("Table", style: TextStyle(fontSize: 15)),
              //   ],
              // ),
            ),
            SizedBox(width: 16),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddCategoryPage()),
                );
              },
              child: SvgPicture.asset(
                icon_menu,
                width: 24,
                color: Colors.black87,
              ),

              // Row(
              //   children: [
              //     Icon(Icons.menu_book),
              //     SizedBox(width: 3),
              //     Text("Menu", style: TextStyle(fontSize: 15)),
              //   ],
              // ),
            ),

            SizedBox(width: 16),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TransactionsPage()),
                );
              },
              child: SvgPicture.asset(
                icon_transaction,
                width: 24,
                color: Colors.black87,
              ),

              // Row(
              //   children: [
              //     Icon(Icons.money),
              //     SizedBox(width: 3),
              //     Text("Transactions", style: TextStyle(fontSize: 15)),
              //   ],
              // ),
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
                ? Center(
                    child: Text("No tables available. Please add a table."),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await _loadMenu();
                    },
                    child: MasonryGridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      itemCount: tables.keys.length,
                      itemBuilder: (context, index) {
                        final tableName = tables.keys.elementAt(index);
                        final groups = tables[tableName]!;

                        return DragTarget<String>(
                          onAccept: (sourceTable) async {
                            if (sourceTable != tableName) {
                              final sourceGroups = tables[sourceTable]!;
                              final destGroups = tables[tableName]!;

                              setState(() {
                                // Append deep copy of source groups to destination
                                final copiedGroups = sourceGroups.map((group) {
                                  return group
                                      .map(
                                        (item) =>
                                            Map<String, dynamic>.from(item),
                                      )
                                      .toList();
                                }).toList();

                                destGroups.addAll(copiedGroups);
                                sourceGroups.clear();
                              });

                              await _updateTableItemsInFirestore(
                                tableName,
                                tables[tableName]!,
                              );
                              await _updateTableItemsInFirestore(
                                sourceTable,
                                [],
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Moved all items from $sourceTable to $tableName',
                                  ),
                                ),
                              );
                            }
                          },
                          builder: (context, candidateData, rejectedData) {
                            return LongPressDraggable<String>(
                              data: tableName,
                              feedback: Material(
                                elevation: 4,
                                color: Colors.transparent,
                                child: Container(
                                  width: 160,
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tableName,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: fontMulishSemiBold,
                                    ),
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.4,
                                child: _buildTableCard(tableName, groups),
                              ),
                              child: _buildTableCard(tableName, groups),
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
      // 🔹 Floating action button is outside the Stack
      floatingActionButton: FloatingActionButton(
        child: SvgPicture.asset(icon_take_away, width: 28, height: 28),
        tooltip: 'View all orders',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrdersGroupedListPage()),
          );
        },
      ),
    );
  }

  Widget _buildTableCard(
    String tableName,
    List<List<Map<String, dynamic>>> groups,
  ) {
    return GestureDetector(
      onDoubleTap: () async {
        final allItems = groups.expand((g) => g).toList();
        final mergedItems = _mergeItemsByNameAndCategory(allItems);

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FinalCartPage(
              menuData: mergedItems,
              onConfirm: (List<Map<String, dynamic>> confirmedItems) async {
                setState(() {
                  tables[tableName] = [confirmedItems];
                });
                await _updateTableItemsInFirestore(tableName, [confirmedItems]);
              },
              table: tableName,
            ),
          ),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        elevation: 8,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: groups.isNotEmpty ? Colors.green : primary_color,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tableName, style: TextStyle(color: Colors.white)),
                  Row(
                    children: [
                      if (groups.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.white),
                          onPressed: () async {
                            final lastGroup = groups.last;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MenuPage(
                                  menuList: menu,
                                  initialItems: List<Map<String, dynamic>>.from(
                                    lastGroup,
                                  ),
                                  onConfirm:
                                      (
                                        List<Map<String, dynamic>>
                                        selectedItems,
                                      ) async {
                                        setState(() {
                                          groups[groups.length - 1] =
                                              selectedItems;
                                        });
                                        await _updateTableItemsInFirestore(
                                          tableName,
                                          groups,
                                        );
                                      },
                                ),
                              ),
                            );
                          },
                        ),
                      IconButton(
                        icon: Icon(Icons.add_circle, color: Colors.white),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MenuPage(
                                menuList: menu,
                                initialItems: [],
                                onConfirm:
                                    (
                                      List<Map<String, dynamic>> selectedItems,
                                    ) async {
                                      setState(() {
                                        groups.add(selectedItems);
                                      });
                                      await _updateTableItemsInFirestore(
                                        tableName,
                                        groups,
                                      );
                                    },
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40.0),
                child: Center(
                  child: Text(
                    "No items",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black38,
                      fontFamily: fontMulishRegular,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(groups.length, (i) {
                    final group = groups[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...group.map((item) {
                          final qty = item['qty'] ?? 1;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: item['name'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      fontFamily: fontMulishRegular,
                                    ),
                                  ),
                                  TextSpan(
                                    text: " \u00D7$qty",
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.red,
                                      fontFamily: fontMulishSemiBold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        if (i < groups.length - 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: DottedLine(
                              dashColor: Colors.grey,
                              lineThickness: 1,
                              dashLength: 4,
                              dashGapLength: 4,
                            ),
                          ),
                      ],
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
