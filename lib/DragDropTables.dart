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
    bool isBillPaid, [
    String overallRemarks = '',
  ]) async {
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
      
      if (overallRemarks.isNotEmpty) {
        updateData['remarks'] = overallRemarks;
      }

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
    bool isBillPaid, [
    String overallRemarks = '',
  ]) async {
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

      final tableData = {
        'name': tableName,
        'items': flattenedItems,
        "isPaid": isBillPaid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (overallRemarks.isNotEmpty) {
        tableData['remarks'] = overallRemarks;
      }

      // Step 2: Add the document to Firestore
      final docRef = await FirebaseFirestore.instance.collection('tables').add(tableData);

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

  // ── Brand colours (matches login/signup) ────────────────────────────────
  static const _navy   = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);
  static const _green  = Color(0xFF4CAF50);
  static const _bg     = Color(0xFFF5F6FA);

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final crossCols = screenW > 1200 ? 5
        : screenW > 900  ? 4
        : screenW > 600  ? 3
        : 2;

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTabBar(),
              Expanded(
                child: tables.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: _orange,
                        onRefresh: () async => _loadMenu(),
                        child: MasonryGridView.count(
                          crossAxisCount: crossCols,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          padding: EdgeInsets.fromLTRB(
                            screenW > 900 ? 16 : 8,
                            8,
                            screenW > 900 ? 16 : 8,
                            100,
                          ),
                          itemCount: _filteredTableKeys().length,
                          itemBuilder: (context, index) {
                            final tableName =
                                _filteredTableKeys().elementAt(index);
                            final groups = tables[tableName]!;
                            return _buildTableCard(tableName, groups);
                          },
                        ),
                      ),
              ),
            ],
          ),
          if (isLoading)
            Container(
              color: Colors.black12,
              child: const Center(
                child: CircularProgressIndicator(color: _orange),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _navy,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              width: 36, height: 36,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.restaurant, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('Flavor Flow',
                  style: TextStyle(
                    fontSize: 16, fontFamily: fontMulishBold, color: Colors.white,
                  )),
              Text('Restaurant Dashboard',
                  style: TextStyle(
                    fontSize: 11, fontFamily: fontMulishRegular, color: Colors.white60,
                  )),
            ],
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_filteredTableKeys().length} tables',
            style: const TextStyle(
              color: Colors.white70, fontSize: 12, fontFamily: fontMulishSemiBold,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white70),
          tooltip: 'Sign Out',
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LoginPage()),
              );
            }
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: _navy,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: ['All', 'Tables', 'Take Away'].map((label) {
            final selected = selectedTab == label;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => selectedTab = label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? _orange : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text(label,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: fontMulishSemiBold,
                          color: selected ? Colors.white : Colors.white60,
                        )),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.table_restaurant_outlined, size: 56, color: _orange),
          ),
          const SizedBox(height: 16),
          const Text('No tables yet',
              style: TextStyle(fontSize: 18, fontFamily: fontMulishBold, color: _navy)),
          const SizedBox(height: 6),
          Text('Add tables from the Table tab\nor use the Take Away button below',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13, fontFamily: fontMulishRegular, color: Colors.grey.shade500,
              )),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      backgroundColor: _navy,
      foregroundColor: Colors.white,
      elevation: 6,
      icon: SvgPicture.asset(icon_take_away, width: 22, height: 22, color: Colors.white),
      label: const Text('Take Away',
          style: TextStyle(fontFamily: fontMulishSemiBold, fontSize: 14)),
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
              onConfirm: (
                List<Map<String, dynamic>> selectedItems,
                bool isBillPaid,
                String tableName,
                String overallRemarks,
              ) async {
                await _addTableAndUpdateItems(tableName, selectedItems, isBillPaid, overallRemarks);
                setState(() {});
              },
            ),
          ),
        );
      },
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

  // ── Redesigned table card ────────────────────────────────────────────────
  Widget _buildTableCardWithContent(
    String tableName,
    List<List<Map<String, dynamic>>> groups,
    bool isPaid,
    String docId,
  ) {
    final hasItems   = groups.isNotEmpty;
    final isTakeAway = !tableName.contains('Table');
    // Header colour: green=has items, orange=empty dine-in, blue=empty takeaway
    final headerColor = isPaid
        ? Colors.red.shade700
        : hasItems
            ? _green
            : isTakeAway
                ? _navy
                : _orange;

    // Count total items across all groups
    final totalQty = groups
        .expand((g) => g)
        .fold<int>(0, (sum, item) => sum + ((item['qty'] as num?)?.toInt() ?? 1));

    return GestureDetector(
      onDoubleTap: () async {
        if (isPaid) {
          showServedDialog(context, tableName, () async {
            if (isTakeAway) {
              await FirebaseFirestore.instance
                  .collection('tables')
                  .doc(docId)
                  .delete();
              setState(() {});
            } else {
              await _updateTableItemsInFirestore(tableName, [], false);
            }
          });
          return;
        }
        if (!hasItems) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MenuPage(
                menuList: menu,
                tableName: tableName,
                tableNameEditable: false,
                initialItems: [],
                showBilling: true,
                isFromFinalBilling: false,
                onConfirm: (selectedItems, isBillPaid, tName, overallRemarks) async {
                  setState(() => groups.add(selectedItems));
                  await _updateTableItemsInFirestore(tName, groups, isBillPaid, overallRemarks);
                },
              ),
            ),
          );
          return;
        }
        final merged = _mergeItemsByNameAndCategory(
            groups.expand((g) => g).toList());
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FinalBillingView(
              menuData: merged,
              totalMenuList: menu,
              tableName: tableName,
              onConfirm: (confirmedItems) async {
                setState(() => tables[tableName] = [confirmedItems]);
                await _updateTableItemsInFirestore(
                    tableName, [confirmedItems], false);
                if (isTakeAway && confirmedItems.isEmpty) {
                  await FirebaseFirestore.instance
                      .collection('tables')
                      .doc(docId)
                      .delete();
                }
              },
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _navy.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  // Table icon
                  Icon(
                    isTakeAway
                        ? Icons.delivery_dining_outlined
                        : Icons.table_restaurant_outlined,
                    color: Colors.white70,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  // Table name
                  Expanded(
                    child: Text(
                      tableName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: fontMulishBold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Action icons
                  if (hasItems && !isPaid)
                    _cardIconBtn(Icons.edit_outlined, () async {
                      final lastGroup = groups.last;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MenuPage(
                            menuList: menu,
                            tableName: tableName,
                            tableNameEditable: false,
                            initialItems: List<Map<String, dynamic>>.from(lastGroup),
                            showBilling: groups.length == 1,
                            isFromFinalBilling: false,
                            onConfirm: (items, isBillPaid, tName, overallRemarks) async {
                              setState(() => groups[groups.length - 1] = items);
                              await _updateTableItemsInFirestore(
                                  tName, groups, isBillPaid, overallRemarks);
                            },
                          ),
                        ),
                      );
                    }),
                  if (!isPaid)
                    _cardIconBtn(Icons.add_circle_outline, () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MenuPage(
                            menuList: menu,
                            tableName: tableName,
                            tableNameEditable: false,
                            initialItems: [],
                            showBilling: !hasItems,
                            isFromFinalBilling: false,
                            onConfirm: (items, isBillPaid, tName, overallRemarks) async {
                              setState(() => groups.add(items));
                              await _updateTableItemsInFirestore(
                                  tName, groups, isBillPaid, overallRemarks);
                            },
                          ),
                        ),
                      );
                    }),
                  // PAID pill
                  if (isPaid)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('PAID',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontFamily: fontMulishBold,
                          )),
                    ),
                ],
              ),
            ),

            // ── Card body ────────────────────────────────────────────────
            if (!hasItems)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.touch_app_outlined,
                          color: Colors.grey.shade300, size: 28),
                      const SizedBox(height: 6),
                      Text('Double-tap to order',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                            fontFamily: fontMulishRegular,
                          )),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item rows
                    ...List.generate(groups.length, (gi) {
                      final group = groups[gi];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...group.map((item) {
                            final qty = (item['qty'] as num?)?.toInt() ?? 1;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontFamily: fontMulishRegular,
                                        color: Color(0xFF212121),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _orange.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '×$qty',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _orange,
                                        fontFamily: fontMulishBold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (gi < groups.length - 1)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: DottedLine(
                                dashColor: Colors.grey.shade300,
                                lineThickness: 1,
                                dashLength: 4,
                                dashGapLength: 4,
                              ),
                            ),
                        ],
                      );
                    }),

                    // Total row
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                              color: Colors.grey.shade200, thickness: 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '$totalQty item${totalQty != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontFamily: fontMulishSemiBold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cardIconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(icon, color: Colors.white70, size: 18),
        ),
      );


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
