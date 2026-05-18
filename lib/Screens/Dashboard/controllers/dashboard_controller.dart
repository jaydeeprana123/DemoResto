import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:demo/Screens/Dashboard/repositories/dashboard_repository.dart';
import 'package:demo/Screens/Authentication/screens/LoginScreenView.dart';

/// DashboardController
/// 
/// Part of the GetX Repository Pattern.
/// This controller handles all presentation state (loading status, tab changes, table lists, and menus)
/// and orchestrates database sync operations by querying the [DashboardRepository].
class DashboardController extends GetxController {
  final DashboardRepository _repository = DashboardRepository();

  // ── Reactive Observables (.obs) ───────────────────────────────────────────
  final RxMap<String, List<List<Map<String, dynamic>>>> tables = <String, List<List<Map<String, dynamic>>>>{}.obs;
  final RxList<Map<String, dynamic>> menu = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxString selectedTab = 'All'.obs;

  StreamSubscription<QuerySnapshot>? _tablesSubscription;
  final user = FirebaseAuth.instance.currentUser;
  int tableNo = 0;

  @override
  void onInit() {
    super.onInit();
    if (user != null) {
      _listenToTables();
      loadMenu();
    } else {
      signOut();
    }
  }

  @override
  void onClose() {
    _tablesSubscription?.cancel();
    super.onClose();
  }

  // ── Listen & Sync Database Stream ──────────────────────────────────────────
  void _listenToTables() {
    _tablesSubscription = _repository.getTablesStream().listen((querySnapshot) {
      final Map<String, List<List<Map<String, dynamic>>>> updatedTables = {};

      for (var doc in querySnapshot.docs) {
        final tableName = doc['name'] as String;
        final List<dynamic>? itemsFromDb = doc.data().containsKey('items')
            ? doc['items']
            : null;

        List<List<Map<String, dynamic>>> groupedItems = [];

        if (itemsFromDb != null && itemsFromDb.isNotEmpty) {
          // Check if items have groupIndex (new flattened format)
          bool hasGroupIndex = itemsFromDb.isNotEmpty &&
              itemsFromDb.first is Map &&
              (itemsFromDb.first as Map).containsKey('groupIndex');

          if (hasGroupIndex) {
            // NEW FORMAT: Reconstruct groups from flattened data using groupIndex
            Map<int, List<Map<String, dynamic>>> groupMap = {};

            for (var item in itemsFromDb) {
              if (item is Map) {
                Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
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
          }
          // Handle legacy formats
          else if (itemsFromDb.first is List) {
            // OLD NESTED FORMAT: Direct conversion
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
      }

      // Update reactive map
      tables.value = updatedTables;
      
      // Update table counter for takeaway IDs
      _updateTableCounter();
    });
  }

  /// Calculates next index key for auto-generated takeaway IDs
  void _updateTableCounter() {
    int maxTakeAwayNum = 0;
    for (var key in tables.keys) {
      if (key.startsWith("Take Away ")) {
        final numPart = key.replaceFirst("Take Away ", "");
        final parsed = int.tryParse(numPart);
        if (parsed != null && parsed > maxTakeAwayNum) {
          maxTakeAwayNum = parsed;
        }
      }
    }
    tableNo = maxTakeAwayNum;
  }

  // ── Database Action Delegations ────────────────────────────────────────────

  /// Load menu structure
  Future<void> loadMenu() async {
    isLoading.value = true;
    try {
      final loadedMenu = await _repository.loadMenu();
      menu.assignAll(loadedMenu);
    } catch (e) {
      debugPrint("Error loading menu: $e");
    } finally {
      isLoading.value = false;
    }
  }

  /// Push order groups update to Cloud Firestore
  Future<void> updateTableItemsInFirestore({
    required String tableName,
    required List<List<Map<String, dynamic>>> groups,
    required bool isBillPaid,
    String overallRemarks = '',
  }) async {
    try {
      await _repository.updateTableItems(
        tableName: tableName,
        groups: groups,
        isBillPaid: isBillPaid,
        overallRemarks: overallRemarks,
      );
    } catch (e) {
      debugPrint("Error updating table items in Firestore: $e");
    }
  }

  /// Insert empty table document
  Future<void> addTable(String tableName) async {
    try {
      final success = await _repository.addTable(tableName);
      if (!success) {
        debugPrint("Table $tableName already exists.");
      }
    } catch (e) {
      debugPrint("Error adding table: $e");
    }
  }

  /// Add new takeaway table and commit active order items instantly
  Future<void> addTableAndUpdateItems({
    required String tableName,
    required List<Map<String, dynamic>> selectedItems,
    required bool isBillPaid,
    String overallRemarks = '',
  }) async {
    try {
      await _repository.addTableAndUpdateItems(
        tableName: tableName,
        selectedItems: selectedItems,
        isBillPaid: isBillPaid,
        overallRemarks: overallRemarks,
      );
    } catch (e) {
      debugPrint("Error adding table and updating items: $e");
    }
  }

  /// Delete table document from Firestore
  Future<void> deleteTable(String docId) async {
    try {
      await _repository.deleteTable(docId);
    } catch (e) {
      debugPrint("Error deleting table $docId: $e");
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    Get.offAll(() => const LoginPage());
  }

  // ── Helper Utilities ───────────────────────────────────────────────────────

  /// Filter the table keys based on selected Tab category
  List<String> getFilteredTableKeys() {
    if (selectedTab.value == 'Take Away') {
      return tables.keys.where((key) => !key.contains('Table')).toList();
    } else if (selectedTab.value == 'Tables') {
      return tables.keys.where((key) => key.contains('Table')).toList();
    } else {
      return tables.keys.toList();
    }
  }

  /// Merge duplicate items by matching name and category
  List<Map<String, dynamic>> mergeItemsByNameAndCategory(List<Map<String, dynamic>> items) {
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

  /// Drag-and-drop table merge transaction.
  /// Transfers all order groups from sourceTable to destTable, preserves paid status,
  /// and updates Firestore atomically.
  Future<void> mergeTables({
    required String sourceTable,
    required String destTable,
  }) async {
    try {
      final sourceGroups = tables[sourceTable];
      final destGroups = tables[destTable];
      if (sourceGroups == null || destGroups == null) return;

      // Fetch the paid status of source table from Firestore
      bool sourcePaidStatus = false;
      final sourceQuery = await FirebaseFirestore.instance
          .collection('tables')
          .where('name', isEqualTo: sourceTable)
          .limit(1)
          .get();

      if (sourceQuery.docs.isNotEmpty) {
        sourcePaidStatus = sourceQuery.docs.first.data()['isPaid'] == true;
      }

      // Deep copy source groups
      final copiedGroups = sourceGroups.map((group) {
        return group.map((item) => Map<String, dynamic>.from(item)).toList();
      }).toList();

      final List<List<Map<String, dynamic>>> newDestGroups = List.from(destGroups)..addAll(copiedGroups);

      // Perform mutations atomically via Repository
      await _repository.updateTableItems(
        tableName: destTable,
        groups: newDestGroups,
        isBillPaid: sourcePaidStatus,
      );
      
      await _repository.updateTableItems(
        tableName: sourceTable,
        groups: [],
        isBillPaid: false,
      );
    } catch (e) {
      debugPrint("Error merging tables $sourceTable -> $destTable: $e");
    }
  }
}
