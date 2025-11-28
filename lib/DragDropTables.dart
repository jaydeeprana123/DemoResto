import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/AddCategoryPage.dart' hide AddTablePage;
import 'package:demo/AddMenuItemPage.dart';
import 'package:demo/Screens/Authentication/LoginScreenView.dart';
import 'package:demo/Styles/my_icons.dart';
import 'package:demo/TransactionsPage.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'AddTablePage.dart';
import 'KitchenOrdersListView.dart';
import 'CartPage.dart';
import 'FinalBillingView.dart';
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
  final user = FirebaseAuth.instance.currentUser;
  int tableNo = 0;
  String selectedTab = 'All'; // 👈 Add this variable at class level
  StreamSubscription<QuerySnapshot>? tablesSubscription;

  @override
  void initState() {
    super.initState();

    if (user != null) {
      _listenToTables();
      _loadMenu();
    } else {
      signOut();
    }
  }

  signOut() async {
    await FirebaseAuth.instance.signOut();

    Navigator.push(context, MaterialPageRoute(builder: (_) => LoginPage()));
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
    bool isBillPaid,
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
        "isPaid": isBillPaid,
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

  // Add a new table with items list
  Future<void> _addTableAndUpdateItems(
    String tableName,
    List<Map<String, dynamic>> selectedItems,
    bool isBillPaid,
  ) async {
    try {
      print("=== ADDING NEW TABLE ===");
      print("Table name: $tableName");
      print("Selected items count: ${selectedItems.length}");

      final existing = await FirebaseFirestore.instance
          .collection('tables')
          .where('name', isEqualTo: tableName)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        print("Table already exists: $tableName");
        return;
      }

      // Step 1: Build grouped structure similar to update method
      // For a new table, you can assume all items belong to one group (index = 0)
      List<Map<String, dynamic>> flattenedItems = [];

      final Timestamp groupTimestamp = Timestamp.now(); // one timestamp for all

      for (int i = 0; i < selectedItems.length; i++) {
        final item = Map<String, dynamic>.from(selectedItems[i]);

        // Add same meta fields as update method
        item['groupIndex'] = 0; // single group for new table
        item['addedAt'] = groupTimestamp;

        flattenedItems.add(item);
      }

      // Step 2: Add the document to Firestore
      final docRef = await FirebaseFirestore.instance.collection('tables').add({
        'name': tableName,
        'items': flattenedItems,
        "isPaid": isBillPaid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print(
        "SUCCESS: Table $tableName added with ${flattenedItems.length} items",
      );
      print("Document ID: ${docRef.id}");
      print("=== END ADD ===");
    } catch (e) {
      print("ERROR: Failed to add table: $e");
      if (e is FirebaseException) {
        print("Firebase error code: ${e.code}");
        print("Firebase error message: ${e.message}");
      }
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
                await FirebaseAuth.instance.signOut();

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LoginPage()),
                );
              },
              child: Icon(Icons.logout),

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
            margin: EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(0.0),
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTabButton("Tables"),
                      _buildTabButton("Take Away"),
                      _buildTabButton("All"),
                    ],
                  ),
                ),

                Expanded(
                  child: tables.isEmpty
                      ? Center(
                          child: Text(
                            "No tables available. Please add a table.",
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => await _loadMenu(),
                          child: MasonryGridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            padding: EdgeInsets.only(bottom: 152),
                            itemCount: _filteredTableKeys().length,
                            itemBuilder: (context, index) {
                              final tableName = _filteredTableKeys().elementAt(
                                index,
                              );
                              final groups = tables[tableName]!;
                              return _buildTableCard(tableName, groups);
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),

          if (isLoading) Center(child: CircularProgressIndicator()),
        ],
      ),
      // 🔹 Floating action button is outside the Stack
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        child: SvgPicture.asset(
          icon_take_away,
          width: 36,
          height: 28,
          color: Colors.black87,
        ),
        tooltip: 'View all orders',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MenuPage(
                menuList: menu,
                tableName: "Take Away ${tableNo + 1}",
                tableNameEditable: true,
                initialItems: [],
                showBilling: true,
                isFromFinalBilling: false,
                onConfirm:
                    (
                      List<Map<String, dynamic>> selectedItems,
                      bool isBillPaid,
                      String tableName,
                    ) async {
                      await _addTableAndUpdateItems(
                        tableName,
                        selectedItems,
                        isBillPaid,
                      );

                      setState(() {
                        // tables["Take Away $tableNo"] = [selectedItems];
                      });
                      // await _updateTableItemsInFirestore(
                      //     "Take Away $tableNo", [selectedItems]);
                    },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableCard(
    String tableName,
    List<List<Map<String, dynamic>>> groups,
  ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('tables')
          .where('name', isEqualTo: tableName)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        bool isPaid = false;
        String docId = "";

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final doc = snapshot.data!.docs.first;
          final data = doc.data();
          isPaid = (data['isPaid'] == true);
          docId = doc.id;
        }

        // Wrap with DragTarget to accept drops from other tables
        return DragTarget<String>(
          onAccept: (sourceTable) async {
            if (sourceTable != tableName) {
              // Get the isPaid status of source table
              bool sourcePaidStatus = false;
              try {
                final sourceQuery = await FirebaseFirestore.instance
                    .collection('tables')
                    .where('name', isEqualTo: sourceTable)
                    .limit(1)
                    .get();

                if (sourceQuery.docs.isNotEmpty) {
                  sourcePaidStatus =
                      sourceQuery.docs.first.data()['isPaid'] == true;
                }
              } catch (e) {
                print("Error getting source paid status: $e");
              }

              final sourceGroups = tables[sourceTable]!;
              final destGroups = tables[tableName]!;

              setState(() {
                // Append deep copy of source groups to destination
                final copiedGroups = sourceGroups.map((group) {
                  return group
                      .map((item) => Map<String, dynamic>.from(item))
                      .toList();
                }).toList();

                destGroups.addAll(copiedGroups);
                sourceGroups.clear();
              });

              // Update destination with source's paid status
              await _updateTableItemsInFirestore(
                tableName,
                tables[tableName]!,
                sourcePaidStatus,
              );
              await _updateTableItemsInFirestore(sourceTable, [], false);

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
            // Wrap with LongPressDraggable to make table draggable (even if paid)
            return LongPressDraggable<String>(
              data: tableName,
              feedback: Material(
                elevation: 4,
                color: Colors.transparent,
                child: Container(
                  width: 160,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isPaid ? Colors.red : Colors.blueAccent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tableName,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.4,
                child: _buildTableCardWithContent(
                  tableName,
                  groups,
                  isPaid,
                  docId,
                ),
              ),
              child: _buildTableCardWithContent(
                tableName,
                groups,
                isPaid,
                docId,
              ),
            );
          },
        );
      },
    );
  }

  // Renamed from _buildTableCardBody and updated to handle gestures
  Widget _buildTableCardWithContent(
    String tableName,
    List<List<Map<String, dynamic>>> groups,
    bool isPaid,
    String docId,
  ) {
    return GestureDetector(
      onDoubleTap: () async {
        if (isPaid) {
          showServedDialog(context, tableName, () async {
            if (!tableName.contains("Table")) {
              await FirebaseFirestore.instance
                  .collection('tables')
                  .doc(docId)
                  .delete();
              setState(() {});
            } else {
              await _updateTableItemsInFirestore(tableName, [], false);
            }

            print("${tableName} marked as served");
          });
          return;
        }

        if (groups.isEmpty) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MenuPage(
                menuList: menu,

                tableName: tableName,
                tableNameEditable: false,
                initialItems: [],
                showBilling: groups.isEmpty,
                isFromFinalBilling: false,
                onConfirm:
                    (
                      List<Map<String, dynamic>> selectedItems,
                      bool isBillPaid,
                      String tableName,
                    ) async {
                      setState(() {
                        groups.add(selectedItems);
                      });
                      await _updateTableItemsInFirestore(
                        tableName,
                        groups,
                        isBillPaid,
                      );
                    },
              ),
            ),
          );
          return;
        }

        final allItems = groups.expand((g) => g).toList();
        final mergedItems = _mergeItemsByNameAndCategory(allItems);

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FinalBillingView(
              menuData: mergedItems,
              totalMenuList: menu,
              onConfirm: (List<Map<String, dynamic>> confirmedItems) async {
                setState(() {
                  tables[tableName] = [confirmedItems];
                });
                await _updateTableItemsInFirestore(tableName, [
                  confirmedItems,
                ], false);

                if (!tableName.contains("Table") && confirmedItems.isEmpty) {
                  await FirebaseFirestore.instance
                      .collection('tables')
                      .doc(docId)
                      .delete();
                }
              },
              tableName: tableName,
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
                  Expanded(
                    child: Text(
                      tableName,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  Row(
                    children: [
                      if (groups.isNotEmpty && !isPaid)
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.white),
                          onPressed: () async {
                            final lastGroup = groups.last;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MenuPage(
                                  menuList: menu,
                                  tableName: tableName,
                                  tableNameEditable: false,
                                  initialItems: List<Map<String, dynamic>>.from(
                                    lastGroup,
                                  ),
                                  showBilling: groups.length == 1,
                                  isFromFinalBilling: false,
                                  onConfirm:
                                      (
                                        List<Map<String, dynamic>>
                                        selectedItems,
                                        bool isBillPaid,
                                        String tableName,
                                      ) async {
                                        setState(() {
                                          groups[groups.length - 1] =
                                              selectedItems;
                                        });
                                        await _updateTableItemsInFirestore(
                                          tableName,
                                          groups,
                                          isBillPaid,
                                        );
                                      },
                                ),
                              ),
                            );
                          },
                        ),
                      if (!isPaid)
                        IconButton(
                          icon: Icon(Icons.add_circle, color: Colors.white),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MenuPage(
                                  menuList: menu,
                                  tableName: tableName,
                                  tableNameEditable: false,
                                  initialItems: [],
                                  showBilling: groups.isEmpty,
                                  isFromFinalBilling: false,
                                  onConfirm:
                                      (
                                        List<Map<String, dynamic>>
                                        selectedItems,
                                        bool isBillPaid,
                                        String tableName,
                                      ) async {
                                        setState(() {
                                          groups.add(selectedItems);
                                        });
                                        await _updateTableItemsInFirestore(
                                          tableName,
                                          groups,
                                          isBillPaid,
                                        );
                                      },
                                ),
                              ),
                            );
                          },
                        ),
                      if (isPaid)
                        Container(
                          color: Colors.white,
                          margin: EdgeInsets.symmetric(vertical: 3),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 3,
                          ),
                          child: Text(
                            "PAID",
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontFamily: fontMulishBold,
                            ),
                          ),
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
                                    text: " ×$qty",
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

  Widget _buildTableCardBody(
    String tableName,
    List<List<Map<String, dynamic>>> groups,
    bool isPaid,
  ) {
    return Card(
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
                Expanded(
                  child: Text(tableName, style: TextStyle(color: Colors.white)),
                ),
                Row(
                  children: [
                    if (groups.isNotEmpty && !isPaid)
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.white),
                        onPressed: () async {
                          final lastGroup = groups.last;
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MenuPage(
                                menuList: menu,
                                tableName: tableName,
                                tableNameEditable: false,
                                initialItems: List<Map<String, dynamic>>.from(
                                  lastGroup,
                                ),
                                showBilling: groups.length == 1,
                                isFromFinalBilling: false,
                                onConfirm:
                                    (
                                      List<Map<String, dynamic>> selectedItems,
                                      bool isBillPaid,
                                      String tableName,
                                    ) async {
                                      setState(() {
                                        groups[groups.length - 1] =
                                            selectedItems;
                                      });
                                      await _updateTableItemsInFirestore(
                                        tableName,
                                        groups,
                                        isBillPaid,
                                      );
                                    },
                              ),
                            ),
                          );
                        },
                      ),
                    if (!isPaid)
                      IconButton(
                        icon: Icon(Icons.add_circle, color: Colors.white),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MenuPage(
                                menuList: menu,
                                tableName: tableName,
                                tableNameEditable: false,
                                initialItems: [],
                                showBilling: groups.isEmpty,
                                isFromFinalBilling: false,
                                onConfirm:
                                    (
                                      List<Map<String, dynamic>> selectedItems,
                                      bool isBillPaid,
                                      String tableName,
                                    ) async {
                                      setState(() {
                                        groups.add(selectedItems);
                                      });
                                      await _updateTableItemsInFirestore(
                                        tableName,
                                        groups,
                                        isBillPaid,
                                      );
                                    },
                              ),
                            ),
                          );
                        },
                      ),

                    if (isPaid)
                      Container(
                        color: Colors.white,
                        margin: EdgeInsets.symmetric(vertical: 3),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 3,
                        ),
                        child: Text(
                          "PAID",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontFamily: fontMulishBold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // 👇 rest of your table body
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
                                  text: " ×$qty",
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
    );
  }

  // Build each tab button
  Widget _buildTabButton(String label) {
    bool isSelected = selectedTab == label;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = label;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? secondary_text_color : Colors.white,
            border: Border.all(color: secondary_text_color, width: 0.5),

            borderRadius: label == "Tables"
                ? BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                  )
                : label == "All"
                ? BorderRadius.only(
                    topRight: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  )
                : BorderRadius.circular(0),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : secondary_text_color,
                fontFamily: fontMulishSemiBold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Filter the tables based on current selectedTab
  List<String> _filteredTableKeys() {
    if (selectedTab == 'Take Away') {
      return tables.keys.where((key) => !key.contains('Table')).toList();
    } else if (selectedTab == 'Tables') {
      return tables.keys.where((key) => key.contains('Table')).toList();
    } else {
      return tables.keys.toList();
    }
  }

  Future<void> _deleteTable(String docId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Table"),
        content: Text("Are you sure you want to delete '$name'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('tables').doc(docId).delete();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Table deleted")));
    }
  }

  void showServedDialog(
    BuildContext context,
    String tableName,
    VoidCallback onServed,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false, // prevent closing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            tableName.contains("Take Away")
                ? "Mark as Delivered?"
                : "Mark as Served?",
            style: TextStyle(fontFamily: fontMulishSemiBold, fontSize: 18),
          ),
          content: Text(
            tableName.contains("Take Away")
                ? "Are you sure you want to mark table '$tableName' as delivered?"
                : "Are you sure you want to mark table '$tableName' as served?",
            style: const TextStyle(fontFamily: fontMulishRegular, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // close dialog
              child: const Text(
                "Cancel",
                style: TextStyle(
                  fontFamily: fontMulishSemiBold,
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(context); // close dialog
                onServed(); // perform the action
              },
              child: Text(
                tableName.contains("Take Away") ? "Delivered" : "Served",
                style: TextStyle(
                  fontFamily: fontMulishSemiBold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
