import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/utils/table_name_utils.dart';
import 'package:demo/features/menu_setup/utils/menu_sort_utils.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/core/repositories/user_repository.dart';
import 'package:demo/core/services/restaurant_session.dart';
import 'package:demo/FinalCartPage.dart';
import 'package:demo/features/kitchen/kitchen.dart';
import 'package:demo/features/menu_setup/menu_setup.dart';
import 'package:demo/features/ordering/views/menu_page.dart';
import 'package:demo/features/ordering/widgets/table_billing_mode_dialog.dart';
import 'package:demo/features/ordering/widgets/table_billing_sheet.dart';
import 'package:demo/features/tables/repositories/table_item_served.dart';
import 'package:demo/features/tables/repositories/tables_repository.dart';
import 'package:demo/features/tables/views/AddTablePage.dart';
import 'package:demo/features/tables/widgets/order_item_row.dart';
import 'package:demo/features/transactions/services/reverse_billing_service.dart';
import 'package:demo/Styles/my_icons.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'dart:async';

import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';

class DragListBetweenTables extends StatefulWidget {
  const DragListBetweenTables({super.key});

  @override
  State<DragListBetweenTables> createState() => _DragListBetweenTablesState();
}

class _DragListBetweenTablesState extends State<DragListBetweenTables>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Map<String, List<List<Map<String, dynamic>>>> tables = {};
  final Map<String, Timestamp?> tableCreatedAt = {};
  final Map<String, bool> tableIsPaid = {};
  final Map<String, String> tableDocIds = {};
  final Map<String, String> tableTransactionIds = {};
  final Map<String, List<int>> _firestoreGroupIndices = {};
  final TableItemSelectionController _itemSelection =
      TableItemSelectionController();
  final List<Map<String, dynamic>> menu = [];
  bool isLoading = false;
  final user = FirebaseAuth.instance.currentUser;
  int tableNo = 0;
  String selectedTab = 'All'; // 👈 Add this variable at class level
  StreamSubscription<QuerySnapshot>? tablesSubscription;
  Timer? _timeRefreshTimer;

  @override
  void initState() {
    super.initState();

    _timeRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });

    if (user != null) {
      _listenToTables();
      _loadMenu();
    }
  }

  Future<void> signOut() async {
    await Get.find<UserRepository>().signOut();
  }

  @override
  void dispose() {
    _timeRefreshTimer?.cancel();
    tablesSubscription?.cancel();
    super.dispose();
  }

  DateTime? _parseAddedAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      return mins == 1 ? '1 min ago' : '$mins mins ago';
    }
    if (diff.inHours < 24) {
      final hours = diff.inHours;
      return hours == 1 ? '1 hour ago' : '$hours hours ago';
    }
    if (diff.inDays < 7) {
      final days = diff.inDays;
      return days == 1 ? '1 day ago' : '$days days ago';
    }
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String? _groupTimeLabel(List<Map<String, dynamic>> group) {
    if (group.isEmpty) return null;
    final addedAt = _parseAddedAt(group.first['addedAt']);
    if (addedAt == null) return null;
    return _formatTimeAgo(addedAt);
  }

  List<Map<String, dynamic>> _stampGroupAddedAt(
    List<Map<String, dynamic>> items, {
    dynamic preserveAddedAt,
  }) {
    final ts = preserveAddedAt ?? Timestamp.now();
    return items.map((item) {
      final copy = Map<String, dynamic>.from(item);
      copy['addedAt'] = ts;
      return copy;
    }).toList();
  }

  // Listen to Firestore tables collection changes - UPDATED for flattened structure
  void _listenToTables() {
    tablesSubscription = FirestorePaths
        .scoped('tables')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen(_onTablesSnapshot);
  }

  void _onTablesSnapshot(QuerySnapshot<Map<String, dynamic>> querySnapshot) {
    Map<String, List<List<Map<String, dynamic>>>> updatedTables = {};
    final Map<String, List<int>> updatedFirestoreGroupIndices = {};

    final Map<String, Timestamp?> updatedCreatedAt = {};
    final Map<String, bool> updatedIsPaid = {};
    final Map<String, String> updatedDocIds = {};
    final Map<String, String> updatedTransactionIds = {};

    for (var doc in querySnapshot.docs) {
            final tableName = doc['name'] as String;
            final data = doc.data();
            updatedCreatedAt[tableName] = data['createdAt'] as Timestamp?;
            updatedIsPaid[tableName] = data['isPaid'] == true;
            updatedDocIds[tableName] = doc.id;
            final txId = data['lastTransactionId']?.toString();
            if (txId != null && txId.isNotEmpty) {
              updatedTransactionIds[tableName] = txId;
            }
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
                updatedFirestoreGroupIndices[tableName] =
                    sortedGroupIndices.isNotEmpty
                    ? sortedGroupIndices
                    : List.generate(groupedItems.length, (i) => i);

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
            updatedFirestoreGroupIndices.putIfAbsent(
              tableName,
              () => List.generate(groupedItems.length, (i) => i),
            );
            print(
              "Table '$tableName' loaded with ${groupedItems.length} groups",
            );
          }

    void applySnapshot() {
      if (!mounted) return;
      setState(() {
        tables = updatedTables;
        _firestoreGroupIndices
          ..clear()
          ..addAll(updatedFirestoreGroupIndices);
        tableCreatedAt
          ..clear()
          ..addAll(updatedCreatedAt);
        tableIsPaid
          ..clear()
          ..addAll(updatedIsPaid);
        tableDocIds
          ..clear()
          ..addAll(updatedDocIds);
        tableTransactionIds
          ..clear()
          ..addAll(updatedTransactionIds);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => applySnapshot());
  }

  // Load menu data from Firestore
  Future<void> _loadMenu() async {
    setState(() {
      isLoading = true;
    });

    try {
      List<Map<String, dynamic>> loadedMenu = [];
      final menuSnapshot = await FirestorePaths
          .scoped('menus')
          .get();

      final categoryDocs = sortMenuDocs(menuSnapshot.docs);

      for (var categoryDoc in categoryDocs) {
        final categoryId = categoryDoc.id;
        final categoryName = categoryDoc['name'];
        final categorySortOrder =
            (categoryDoc.data()['sortOrder'] as num?)?.toInt() ?? 9999;

        final itemsSnapshot = await FirestorePaths
            .scopedSubCollection('menus', categoryId, 'items')
            .get();

        for (var itemDoc in sortMenuDocs(itemsSnapshot.docs)) {
          final data = itemDoc.data();
          final itemSortOrder = (data['sortOrder'] as num?)?.toInt() ?? 9999;
          loadedMenu.add({
            "category": categoryName,
            "name": data['name'],
            "price": data['price'],
            if (data.containsKey('halfPrice')) "halfPrice": data['halfPrice'],
            if (data.containsKey('fullPrice')) "fullPrice": data['fullPrice'],
            "categoryId": categoryId,
            "itemId": itemDoc.id,
            "categorySortOrder": categorySortOrder,
            "itemSortOrder": itemSortOrder,
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

  Future<void> _updateTableItemsInFirestore(
    String tableName,
    List<List<Map<String, dynamic>>> groups,
    bool isBillPaid, [
    String overallRemarks = '',
    String? lastTransactionId,
    bool clearLastTransactionId = false,
  ]) async {
    try {
      await Get.find<TablesRepository>().updateTableItems(
        tableName: tableName,
        groups: groups,
        isBillPaid: isBillPaid,
        overallRemarks: overallRemarks,
        docId: tableDocIds[tableName],
        lastTransactionId: lastTransactionId,
        clearLastTransactionId: clearLastTransactionId,
      );
      if (clearLastTransactionId) {
        tableTransactionIds.remove(tableName);
      } else if (lastTransactionId != null && lastTransactionId.isNotEmpty) {
        tableTransactionIds[tableName] = lastTransactionId;
      }
    } catch (e) {
      print("ERROR: Failed to update Firestore: $e");
      if (e is FirebaseException) {
        print("Firebase error code: ${e.code}");
        print("Firebase error message: ${e.message}");
      }
    }
  }

  /// Cart billing: keep items visible and mark table paid.
  Future<void> _applyBillingToTable(
    String tableName,
    List<Map<String, dynamic>> confirmedItems, [
    String overallRemarks = '',
    String? transactionId,
  ]) async {
    if (confirmedItems.isEmpty) return;

    final stampedGroup = _stampGroupAddedAt(
      confirmedItems.map((e) => Map<String, dynamic>.from(e)).toList(),
    );

    setState(() {
      tables[tableName] = [stampedGroup];
      tableIsPaid[tableName] = true;
    });
    await _updateTableItemsInFirestore(
      tableName,
      [stampedGroup],
      true,
      overallRemarks,
      transactionId,
    );
  }

  Future<void> _openDashboardBilling({
    required String tableName,
    required String docId,
    required List<List<Map<String, dynamic>>> groups,
    required bool isTakeAway,
  }) async {
    final merged = _mergeItemsByNameAndCategory(
      groups.expand((g) => g).toList(),
    );
    if (merged.isEmpty) return;

    final tableTotal = _tableOrderTotal(groups);

    final mode = await showTableBillingModeDialog(
      context,
      total: tableTotal,
      tableName: tableName,
    );
    if (mode == null || !mounted) return;

    await TableBillingSheet.show(
      context,
      tableName: tableName,
      items: merged,
      mode: mode,
      onSubmit: (submission) async {
        switch (submission.mode) {
          case TableBillingMode.paid:
            if (isTakeAway) {
              await _deleteTakeAwayAfterFinalBilling(tableName, docId);
            } else {
              await _clearTableAfterFinalBilling(tableName);
            }
          case TableBillingMode.paidWithoutServing:
            await _applyBillingToTable(
              tableName,
              submission.items,
              '',
              submission.documentId,
            );
        }
      },
    );
  }

  /// FinalBillingView billing on dine-in tables: clear items, not paid.
  Future<void> _clearTableAfterFinalBilling(
    String tableName, {
    String overallRemarks = '',
  }) async {
    setState(() {
      tables[tableName] = [];
      tableIsPaid[tableName] = false;
    });
    await _updateTableItemsInFirestore(tableName, [], false, overallRemarks);
  }

  /// Take Away billing: keep table visible, show items with PAID tag.
  Future<void> _billTakeAwayOrder(
    String tableName,
    List<Map<String, dynamic>> items, [
    String overallRemarks = '',
    String? transactionId,
  ]) async {
    if (items.isEmpty) return;

    final existing = await FirestorePaths
        .scoped('tables')
        .where('name', isEqualTo: tableName)
        .limit(1)
        .get();

    if (existing.docs.isEmpty) {
      await _addTableAndUpdateItems(tableName, items, true, overallRemarks);
      if (transactionId != null && transactionId.isNotEmpty) {
        final docRef = await FirestorePaths
            .scoped('tables')
            .where('name', isEqualTo: tableName)
            .limit(1)
            .get();
        if (docRef.docs.isNotEmpty) {
          await FirestorePaths.scopedDoc('tables', docRef.docs.first.id).update({
            'lastTransactionId': transactionId,
          });
          tableTransactionIds[tableName] = transactionId;
        }
      }
    } else {
      await _applyBillingToTable(
        tableName,
        items,
        overallRemarks,
        transactionId,
      );
    }

    final stampedGroup = _stampGroupAddedAt(
      items.map((e) => Map<String, dynamic>.from(e)).toList(),
    );
    setState(() {
      tables[tableName] = [stampedGroup];
      tableIsPaid[tableName] = true;
      if (existing.docs.isNotEmpty) {
        tableDocIds[tableName] = existing.docs.first.id;
      }
    });
  }

  /// Existing Take Away table billed via FinalBillingView — remove from dashboard.
  Future<void> _deleteTakeAwayAfterFinalBilling(
    String tableName,
    String docId,
  ) async {
    if (docId.isNotEmpty) {
      await FirestorePaths.scoped('tables').doc(docId).delete();
    } else {
      final query = await FirestorePaths
          .scoped('tables')
          .where('name', isEqualTo: tableName)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.delete();
      }
    }

    setState(() {
      tables.remove(tableName);
      tableIsPaid.remove(tableName);
      tableDocIds.remove(tableName);
      tableCreatedAt.remove(tableName);
    });
  }

  Future<void> _deleteTableFromMenu(String tableName, {String docId = ''}) async {
    if (_isTakeAway(tableName)) {
      await _deleteTakeAwayAfterFinalBilling(
        tableName,
        docId.isNotEmpty ? docId : (tableDocIds[tableName] ?? ''),
      );
      return;
    }
    await _clearTableAfterFinalBilling(tableName);
  }

  void _migrateTableKey(String oldName, String newName, String docId) {
    tables[newName] = tables.remove(oldName) ?? [];
    if (tableIsPaid.containsKey(oldName)) {
      tableIsPaid[newName] = tableIsPaid.remove(oldName)!;
    }
    tableDocIds[newName] = docId;
    tableDocIds.remove(oldName);
    if (tableCreatedAt.containsKey(oldName)) {
      tableCreatedAt[newName] = tableCreatedAt.remove(oldName);
    }
    if (_firestoreGroupIndices.containsKey(oldName)) {
      _firestoreGroupIndices[newName] =
          _firestoreGroupIndices.remove(oldName)!;
    }
  }

  Future<void> _renameTableIfNeeded(
    String oldName,
    String newName, {
    String docId = '',
  }) async {
    if (oldName == newName) return;

    final id = docId.isNotEmpty ? docId : (tableDocIds[oldName] ?? '');
    if (id.isEmpty) {
      final snap = await FirestorePaths
          .scoped('tables')
          .where('name', isEqualTo: oldName)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return;
      await snap.docs.first.reference.update({'name': newName});
      if (mounted) {
        setState(() => _migrateTableKey(oldName, newName, snap.docs.first.id));
      }
      return;
    }

    await FirestorePaths.scopedDoc('tables', id).update({'name': newName});
    if (mounted) {
      setState(() => _migrateTableKey(oldName, newName, id));
    }
  }

  Future<String> _createOrderWithGroups(
    String orderName,
    List<List<Map<String, dynamic>>> groups, {
    bool isBillPaid = false,
    String overallRemarks = '',
  }) async {
    final existing = await FirestorePaths
        .scoped('tables')
        .where('name', isEqualTo: orderName)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      await _updateTableItemsInFirestore(
        orderName,
        groups,
        isBillPaid,
        overallRemarks,
      );
      return existing.docs.first.id;
    }

    final flattenedItems = <Map<String, dynamic>>[];
    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final group = groups[groupIndex];
      final Timestamp groupTimestamp = group.isNotEmpty &&
              group.first.containsKey('addedAt') &&
              group.first['addedAt'] is Timestamp
          ? group.first['addedAt'] as Timestamp
          : Timestamp.now();

      for (final item in group) {
        final itemWithMeta = Map<String, dynamic>.from(item);
        itemWithMeta['groupIndex'] = groupIndex;
        itemWithMeta['addedAt'] = groupTimestamp;
        flattenedItems.add(itemWithMeta);
      }
    }

    final tableData = <String, dynamic>{
      'name': orderName,
      'items': flattenedItems,
      'isPaid': isBillPaid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (overallRemarks.isNotEmpty) {
      tableData['remarks'] = overallRemarks;
    }

    final docRef = await FirestorePaths.scoped('tables').add(tableData);
    return docRef.id;
  }

  Future<List<List<Map<String, dynamic>>>> _splitDiningTableToNewOrder(
    String diningTableName,
    String newOrderName,
    List<List<Map<String, dynamic>>> currentGroups,
  ) async {
    final copiedGroups = currentGroups
        .map(
          (group) => group.map((item) => Map<String, dynamic>.from(item)).toList(),
        )
        .toList();

    setState(() {
      currentGroups.clear();
      tableIsPaid[diningTableName] = false;
      _syncFirestoreGroupIndices(diningTableName, 0);
    });
    await _updateTableItemsInFirestore(diningTableName, [], false);

    final newDocId = await _createOrderWithGroups(newOrderName, copiedGroups);

    setState(() {
      tables[newOrderName] = copiedGroups;
      tableIsPaid[newOrderName] = false;
      tableDocIds[newOrderName] = newDocId;
      tableCreatedAt[newOrderName] = Timestamp.now();
      _syncFirestoreGroupIndices(newOrderName, copiedGroups.length);
    });

    return tables[newOrderName]!;
  }

  Future<({List<List<Map<String, dynamic>>> groups, String docId})>
      _prepareGroupsForConfirm(
    String originalName,
    String newName,
    List<List<Map<String, dynamic>>> groups, {
    required String docId,
  }) async {
    if (originalName == newName) {
      return (groups: groups, docId: docId);
    }

    if (isDiningTableName(originalName) && _isTakeAway(newName)) {
      final newGroups = await _splitDiningTableToNewOrder(
        originalName,
        newName,
        groups,
      );
      return (groups: newGroups, docId: tableDocIds[newName] ?? '');
    }

    await _renameTableIfNeeded(originalName, newName, docId: docId);
    return (
      groups: tables[newName] ?? groups,
      docId: tableDocIds[newName] ?? docId,
    );
  }

  Future<void> _handleMenuPageConfirm({
    required String originalName,
    required List<List<Map<String, dynamic>>> groups,
    required String docId,
    required List<Map<String, dynamic>> items,
    required bool isBillPaid,
    required String tName,
    required String overallRemarks,
    required bool fromBilling,
    required bool fromFinalBilling,
    bool editingLastGroup = false,
    String? transactionId,
  }) async {
    var activeGroups = groups;
    var activeDocId = docId;

    if (tName != originalName) {
      final prepared = await _prepareGroupsForConfirm(
        originalName,
        tName,
        groups,
        docId: docId,
      );
      activeGroups = prepared.groups;
      activeDocId = prepared.docId;
    }

    if (fromFinalBilling) {
      if (_isTakeAway(tName)) {
        await _deleteTakeAwayAfterFinalBilling(tName, activeDocId);
      } else {
        await _clearTableAfterFinalBilling(
          tName,
          overallRemarks: overallRemarks,
        );
      }
      return;
    }

    if (fromBilling) {
      await _applyBillingToTable(
        tName,
        items,
        overallRemarks,
        transactionId,
      );
      return;
    }

    if (editingLastGroup) {
      if (isBillPaid) {
        setState(() {
          activeGroups.clear();
          tableIsPaid[tName] = true;
          _syncFirestoreGroupIndices(tName, 0);
        });
        await _updateTableItemsInFirestore(
          tName,
          [],
          true,
          overallRemarks,
        );
        return;
      }

      final existingAddedAt = activeGroups.isNotEmpty
          ? activeGroups.last.first['addedAt']
          : null;
      setState(
        () => activeGroups[activeGroups.length - 1] = _stampGroupAddedAt(
          items,
          preserveAddedAt: existingAddedAt,
        ),
      );
      await _updateTableItemsInFirestore(
        tName,
        activeGroups,
        false,
        overallRemarks,
      );
      return;
    }

    setState(() {
      if (isBillPaid) {
        activeGroups.clear();
        tableIsPaid[tName] = true;
        _syncFirestoreGroupIndices(tName, 0);
      } else {
        activeGroups.add(_stampGroupAddedAt(items));
        _syncFirestoreGroupIndices(tName, activeGroups.length);
      }
    });
    await _updateTableItemsInFirestore(
      tName,
      isBillPaid ? [] : activeGroups,
      isBillPaid,
      overallRemarks,
    );
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

  int _firestoreGroupIndexFor(String tableName, int gi) {
    final indices = _firestoreGroupIndices[tableName];
    if (indices != null && gi >= 0 && gi < indices.length) {
      return indices[gi];
    }
    return gi;
  }

  void _syncFirestoreGroupIndices(String tableName, int groupCount) {
    if (groupCount <= 0) {
      _firestoreGroupIndices[tableName] = [];
      return;
    }
    final indices = _firestoreGroupIndices[tableName];
    if (indices != null && indices.length >= groupCount) return;
    final extended = List<int>.from(indices ?? []);
    var next = extended.isEmpty ? 0 : extended.last + 1;
    for (var i = extended.length; i < groupCount; i++) {
      extended.add(next++);
    }
    _firestoreGroupIndices[tableName] = extended;
  }

  // Add a new table with empty items list
  Future<void> _addTable(String tableName) async {
    try {
      final existing = await FirestorePaths
          .scoped('tables')
          .where('name', isEqualTo: tableName)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        print("Table already exists");
        return;
      }

      await FirestorePaths.scoped('tables').add({
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

      final existing = await FirestorePaths
          .scoped('tables')
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
      final docRef = await FirestorePaths
          .scoped('tables')
          .add(tableData);

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
  static const _navy = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);
  static const _green = Color(0xFF4CAF50);
  static const _bg = Color(0xFFF5F6FA);

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final screenW = MediaQuery.of(context).size.width;
    final crossCols = screenW > 1200
        ? 5
        : screenW > 900
        ? 4
        : screenW > 600
        ? 3
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
                          mainAxisSpacing: 22,
                          crossAxisSpacing: 6,
                          padding: EdgeInsets.fromLTRB(
                            screenW > 900 ? 16 : 4,
                            8,
                            screenW > 900 ? 16 : 4,
                            100,
                          ),
                          itemCount: _filteredTableKeys().length,
                          itemBuilder: (context, index) {
                            final tableName = _filteredTableKeys().elementAt(
                              index,
                            );
                            final groups = tables[tableName]!;
                            final queuePos = _takeAwayNumber(tableName);
                            return _buildTableCard(
                              tableName,
                              groups,
                              takeAwayNum: queuePos,
                            );
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
    final restaurantName =
        Get.find<RestaurantSession>().activeRestaurant.value?.name;
    final titleText = restaurantName != null && restaurantName.isNotEmpty
        ? 'Flavor Flow ($restaurantName)'
        : 'Flavor Flow';

    return AppBar(
      backgroundColor: _navy,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.restaurant, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titleText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: fontMulishBold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Restaurant Dashboard',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: fontMulishRegular,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
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
            '${_filteredTableKeys().length} ${selectedTab == 'Take Away' ? 'orders' : 'tables'}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: fontMulishSemiBold,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white70),
          tooltip: 'Sign Out',
          onPressed: signOut,
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
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: fontMulishSemiBold,
                        color: selected ? Colors.white : Colors.white60,
                      ),
                    ),
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
            child: const Icon(
              Icons.table_restaurant_outlined,
              size: 56,
              color: _orange,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No tables yet',
            style: TextStyle(
              fontSize: 18,
              fontFamily: fontMulishBold,
              color: _navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add tables from the Table tab\nor use the Take Away button below',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontFamily: fontMulishRegular,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  String _getNextTakeAwayName() {
    int maxNum = 0;
    for (var key in tables.keys) {
      if (key.startsWith("Take Away ")) {
        final suffix = key.substring("Take Away ".length).trim();
        final num = int.tryParse(suffix);
        if (num != null && num > maxNum) {
          maxNum = num;
        }
      }
    }
    return "Take Away ${maxNum + 1}";
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      backgroundColor: _navy,
      foregroundColor: Colors.white,
      elevation: 6,
      icon: SvgPicture.asset(
        icon_take_away,
        width: 22,
        height: 22,
        color: Colors.white,
      ),
      label: const Text(
        'Take Away',
        style: TextStyle(fontFamily: fontMulishSemiBold, fontSize: 14),
      ),
      onPressed: () async {
        final nextName = _getNextTakeAwayName();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MenuPage(
              menuList: menu,
              tableName: nextName,
              tableNameEditable: true,
              existingOrderNames: tables.keys.toSet(),
              initialItems: [],
              showBilling: true,
              isFromFinalBilling: false,
              onDeleteTable: (tName) => _deleteTableFromMenu(tName),
              onConfirm:
                  (
                    List<Map<String, dynamic>> selectedItems,
                    bool isBillPaid,
                    String tableName,
                    String overallRemarks, {
                    bool fromBilling = false,
                    bool fromFinalBilling = false,
                    String? transactionId,
                  }) async {
                    if (fromBilling || fromFinalBilling) {
                      await _billTakeAwayOrder(
                        tableName,
                        selectedItems,
                        overallRemarks,
                        transactionId,
                      );
                      return;
                    }
                    await _addTableAndUpdateItems(
                      tableName,
                      selectedItems,
                      isBillPaid,
                      overallRemarks,
                    );
                    setState(() {});
                  },
            ),
          ),
        );
      },
    );
  }

  bool _isTakeAway(String name) => isTakeAwayOrderName(name);

  bool get _isAdmin =>
      Get.find<RestaurantSession>().profile.value?.isAdmin ?? false;

  String _shortDisplayName(String tableName) {
    if (tableName.startsWith('Table ')) {
      final num = tableName.substring('Table '.length).trim();
      return 'T$num';
    }
    if (tableName.startsWith('Take Away ')) {
      return 'Away';
    }
    return tableName;
  }

  int _compareByCreatedAt(String a, String b) {
    final aTs = tableCreatedAt[a];
    final bTs = tableCreatedAt[b];
    if (aTs == null && bTs == null) return a.compareTo(b);
    if (aTs == null) return 1;
    if (bTs == null) return -1;
    return aTs.compareTo(bTs);
  }

  int _compareTableNumber(String a, String b) {
    final aNum = int.tryParse(a.substring('Table '.length).trim()) ?? 999;
    final bNum = int.tryParse(b.substring('Table '.length).trim()) ?? 999;
    return aNum.compareTo(bNum);
  }

  // int? _takeAwayQueuePosition(String tableName) {
  //   if (!_isTakeAway(tableName)) return null;
  //   final sorted = tables.keys.where(_isTakeAway).toList()
  //     ..sort(_compareByCreatedAt);
  //   final index = sorted.indexOf(tableName);
  //   return index >= 0 ? index + 1 : null;
  // }

  int? _takeAwayNumber(String tableName) {
    if (tableName.startsWith("Take Away ")) {
      final match = RegExp(r'\d+$').firstMatch(tableName);

      if (match != null) {
        int number = int.parse(match.group(0)!);
        return number;
      } else {
        return null;
      }

      // if (!_isTakeAway(tableName)) return null;
      // final sorted = tables.keys.where(_isTakeAway).toList()
      //   ..sort(_compareByCreatedAt);
      // final index = sorted.indexOf(tableName);
      // return index >= 0 ? index + 1 : null;
    } else {
      return null;
    }
  }

  Widget _buildTableCard(
    String tableName,
    List<List<Map<String, dynamic>>> groups, {
    int? takeAwayNum,
  }) {
    final isPaid = tableIsPaid[tableName] == true;
    final docId = tableDocIds[tableName] ?? '';

    return DragTarget<String>(
      onAccept: (sourceTable) async {
        if (sourceTable != tableName) {
          final sourcePaidStatus = tableIsPaid[sourceTable] == true;

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
            _syncFirestoreGroupIndices(tableName, destGroups.length);
            _syncFirestoreGroupIndices(sourceTable, 0);
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
              content: Text('Moved all items from $sourceTable to $tableName'),
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
                color: isPaid ? Colors.red : Colors.blueAccent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _shortDisplayName(tableName),
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
              takeAwayNum: takeAwayNum,
            ),
          ),
          child: _buildTableCardWithContent(
            tableName,
            groups,
            isPaid,
            docId,
            takeAwayNum: takeAwayNum,
          ),
        );
      },
    );
  }

  double _tableOrderTotal(List<List<Map<String, dynamic>>> groups) {
    return groups.expand((g) => g).fold<double>(0, (sum, item) {
      final qty = (item['qty'] as num?)?.toInt() ?? 0;
      final price = (item['price'] as num?)?.toDouble() ?? 0;
      return sum + qty * price;
    });
  }

  // ── Redesigned table card ────────────────────────────────────────────────
  Widget _buildTableCardWithContent(
    String tableName,
    List<List<Map<String, dynamic>>> groups,
    bool isPaid,
    String docId, {
    int? takeAwayNum,
  }) {
    final paid = isPaid == true;
    final hasItems = groups.isNotEmpty;
    final isTakeAway = _isTakeAway(tableName);
    final displayName = _shortDisplayName(tableName);
    // Header colour: green=has items, orange=empty dine-in, blue=empty takeaway
    final headerColor = paid
        ? Colors.red.shade700
        : hasItems
        ? _green
        : isTakeAway
        ? _navy
        : _orange;

    // Count total items across all groups
    final totalQty = groups
        .expand((g) => g)
        .fold<int>(
          0,
          (sum, item) => sum + ((item['qty'] as num?)?.toInt() ?? 1),
        );
    final tableTotal = _tableOrderTotal(groups);

    return InkWell(
      onTap: ()async{
        if(!hasItems){
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MenuPage(
                menuList: menu,
                tableName: tableName,
                tableNameEditable: false,
                existingOrderNames: tables.keys.toSet(),
                initialItems: [],
                pastItems: <Map<String, dynamic>>[],
                showBilling: !hasItems,
                isFromFinalBilling: false,
                onDeleteTable: (tName) =>
                    _deleteTableFromMenu(tName, docId: docId),
                onConfirm:
                    (
                    items,
                    isBillPaid,
                    tName,
                    overallRemarks, {
                  bool fromBilling = false,
                  bool fromFinalBilling = false,
                  String? transactionId,
                }) => _handleMenuPageConfirm(
                  originalName: tableName,
                  groups: groups,
                  docId: docId,
                  items: items,
                  isBillPaid: isBillPaid,
                  tName: tName,
                  overallRemarks: overallRemarks,
                  fromBilling: fromBilling,
                  fromFinalBilling: fromFinalBilling,
                  transactionId: transactionId,
                ),
              ),
            ),
          );
        }
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
            InkWell(
              onTap: () async{
                if (paid) {
                  showServedDialog(context, tableName, () async {
                    if (isTakeAway) {
                      await FirestorePaths
                          .scopedDoc('tables', docId)
                          .delete();
                      setState(() {});
                    } else {
                      await _updateTableItemsInFirestore(tableName, [], false);
                    }
                  });
                  return;
                }
                // Single-tap always opens MenuPage to add items
                final pastItems = hasItems
                    ? _mergeItemsByNameAndCategory(groups.expand((g) => g).toList())
                    : <Map<String, dynamic>>[];
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MenuPage(
                      menuList: menu,
                      tableName: tableName,
                      tableNameEditable: false,
                      existingOrderNames: tables.keys.toSet(),
                      initialItems: [],
                      pastItems: pastItems,
                      showBilling: !hasItems,
                      isFromFinalBilling: false,
                      onDeleteTable: (tName) =>
                          _deleteTableFromMenu(tName, docId: docId),
                      onConfirm:
                          (
                          items,
                          isBillPaid,
                          tName,
                          overallRemarks, {
                        bool fromBilling = false,
                        bool fromFinalBilling = false,
                        String? transactionId,
                      }) => _handleMenuPageConfirm(
                        originalName: tableName,
                        groups: groups,
                        docId: docId,
                        items: items,
                        isBillPaid: isBillPaid,
                        tName: tName,
                        overallRemarks: overallRemarks,
                        fromBilling: fromBilling,
                        fromFinalBilling: fromFinalBilling,
                        transactionId: transactionId,
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    // Table icon
                    if (!isTakeAway)
                      Icon(
                        isTakeAway
                            ? Icons.delivery_dining_outlined
                            : Icons.table_restaurant_outlined,
                        color: Colors.white70,
                        size: 17,
                      ),
                    if (!isTakeAway) const SizedBox(width: 6),
                    if (isTakeAway && takeAwayNum != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '# $takeAwayNum',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontFamily: fontMulishBold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: fontMulishBold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasItems)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          '₹${tableTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: _orange,
                            fontSize: 14,
                            fontFamily: fontMulishBold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    // Action icons
                    if (hasItems && !paid)
                      _cardIconBtn(Icons.edit_outlined, () async {
                        final lastGroup = groups.last;
                        final pastForEdit = groups.length > 1
                            ? _mergeItemsByNameAndCategory(
                                groups
                                    .sublist(0, groups.length - 1)
                                    .expand((g) => g)
                                    .toList(),
                              )
                            : <Map<String, dynamic>>[];
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MenuPage(
                              menuList: menu,
                              tableName: tableName,
                              tableNameEditable: false,
                              existingOrderNames: tables.keys.toSet(),
                              initialItems: List<Map<String, dynamic>>.from(
                                lastGroup,
                              ),
                              pastItems: pastForEdit,
                              showBilling: groups.length == 1,
                              isFromFinalBilling: false,
                              onDeleteTable: (tName) =>
                                  _deleteTableFromMenu(tName, docId: docId),
                              onConfirm:
                                  (
                                    items,
                                    isBillPaid,
                                    tName,
                                    overallRemarks, {
                                    bool fromBilling = false,
                                    bool fromFinalBilling = false,
                                    String? transactionId,
                                  }) => _handleMenuPageConfirm(
                                    originalName: tableName,
                                    groups: groups,
                                    docId: docId,
                                    items: items,
                                    isBillPaid: isBillPaid,
                                    tName: tName,
                                    overallRemarks: overallRemarks,
                                    fromBilling: fromBilling,
                                    fromFinalBilling: fromFinalBilling,
                                    editingLastGroup: true,
                                    transactionId: transactionId,
                                  ),
                            ),
                          ),
                        );
                      }),
                    // Billing icon — admin only, when items exist and not paid
                    if (hasItems && !paid && _isAdmin)
                      _cardIconBtn(Icons.receipt_long_outlined, () {
                        _openDashboardBilling(
                          tableName: tableName,
                          docId: docId,
                          groups: groups,
                          isTakeAway: isTakeAway,
                        );
                      }),
                    // PAID pill — admin double-tap to reverse billing
                    if (paid)
                      GestureDetector(
                        onDoubleTap: () => ReverseBillingService
                            .showReverseBillingDialog(
                          context,
                          tableName: tableName,
                          docId: docId,
                          transactionId: tableTransactionIds[tableName],
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'PAID',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontFamily: fontMulishBold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Card body ────────────────────────────────────────────────
            if (!hasItems)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        color: Colors.grey.shade300,
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap to order',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontFamily: fontMulishRegular,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: ListenableBuilder(
                  listenable: _itemSelection.listenableFor(docId),
                  builder: (context, _) {
                    final selectionMode =
                        _itemSelection.isSelectionModeFor(docId);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Item rows
                        ...List.generate(groups.length, (gi) {
                          final group = groups[gi];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...group.asMap().entries.map((entry) {
                                final firestoreGi = _firestoreGroupIndexFor(
                                  tableName,
                                  gi,
                                );
                                final key = TableItemKey(
                                  docId: docId,
                                  groupIndex: firestoreGi,
                                  itemIndexInGroup: entry.key,
                                );
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: OrderItemRow(
                                    item: entry.value,
                                    docId: docId,
                                    groupIndex: firestoreGi,
                                    itemIndexInGroup: entry.key,
                                    selectionController: _itemSelection,
                                    selectionMode: selectionMode,
                                    isSelected: _itemSelection.isSelected(key),
                                    style: OrderItemRowStyle.dashboard,
                                  ),
                                );
                              }),
                              if (_groupTimeLabel(group) != null)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      top: 0,
                                      bottom: 1,
                                    ),
                                    child: Text(
                                      _groupTimeLabel(group)!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: fontMulishRegular,
                                        color: Colors.grey.shade500,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ),
                              if (gi < groups.length - 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
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

                        TableItemSelectionActionBar(
                          docId: docId,
                          controller: _itemSelection,
                          showDeleteButton:
                              Get.find<RestaurantSession>()
                                  .profile
                                  .value
                                  ?.isAdmin ??
                              false,
                        ),

                        // Total row
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.grey.shade200,
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                hasItems
                                    ? '$totalQty item${totalQty != 1 ? 's' : ''} · ₹${tableTotal.toStringAsFixed(0)}'
                                    : '$totalQty item${totalQty != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade800,
                                  fontFamily: fontMulishBold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
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
      child: Icon(icon, color: Colors.white70, size: 20),
    ),
  );

  // Filter the tables based on current selectedTab
  List<String> _filteredTableKeys() {
    if (selectedTab == 'Take Away') {
      final keys = tables.keys.where(_isTakeAway).toList()
        ..sort(_compareByCreatedAt);
      return keys;
    }

    if (selectedTab == 'Tables') {
      final keys = tables.keys.where((key) => key.startsWith('Table ')).toList()
        ..sort(_compareTableNumber);
      return keys;
    }

    final tableKeys =
        tables.keys.where((key) => key.startsWith('Table ')).toList()
          ..sort(_compareTableNumber);
    final takeAwayKeys = tables.keys.where(_isTakeAway).toList()
      ..sort(_compareByCreatedAt);
    final otherKeys =
        tables.keys
            .where((key) => !key.startsWith('Table ') && !_isTakeAway(key))
            .toList()
          ..sort();

    return [...tableKeys, ...takeAwayKeys, ...otherKeys];
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
      await FirestorePaths.scoped('tables').doc(docId).delete();

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
            _isTakeAway(tableName)
                ? "Mark as Delivered?"
                : "Mark as Served?",
            style: TextStyle(fontFamily: fontMulishSemiBold, fontSize: 18),
          ),
          content: Text(
            _isTakeAway(tableName)
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
                _isTakeAway(tableName) ? "Delivered" : "Served",
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
