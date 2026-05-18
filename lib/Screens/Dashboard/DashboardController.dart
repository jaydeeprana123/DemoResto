import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/Screens/Authentication/LoginScreenView.dart';
import 'package:demo/repositories/order_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// GetX Controller for managing the restaurant dashboard (dine-in tables and take away orders).
class DashboardController extends GetxController {
  // ── Repository Dependency ──
  final OrderRepository _orderRepository = OrderRepository();

  // ── Reactive State Variables (Observables) ──
  
  /// Holds all tables and their grouped items: { "Table 1": [ [Item1, Item2], [Item3] ] }
  var tables = <String, List<List<Map<String, dynamic>>>>{}.obs;
  
  /// Complete catalog list of menu items
  var menu = <Map<String, dynamic>>[].obs;
  
  /// Loading state indicator
  var isLoading = false.obs;
  
  /// The active UI tab filter ('All', 'Tables', 'Take Away')
  var selectedTab = 'All'.obs;

  StreamSubscription<QuerySnapshot>? _tablesSubscription;
  final user = FirebaseAuth.instance.currentUser;
  
  /// Counter tracking number of take-away orders to auto-generate names
  var tableNo = 0.obs;

  @override
  void onInit() {
    super.onInit();
    if (user != null) {
      listenToTables();
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

  /// Signs the active user session out and navigates back to the Login Screen.
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    Get.offAll(() => const LoginPage());
  }

  /// Updates the active tab selection filter.
  void selectTab(String tab) {
    selectedTab.value = tab;
  }

  /// Retrieves filtered table keys matching the currently selected tab.
  List<String> get filteredTableKeys {
    if (selectedTab.value == 'Take Away') {
      return tables.keys.where((key) => !key.contains('Table')).toList();
    } else if (selectedTab.value == 'Tables') {
      return tables.keys.where((key) => key.contains('Table')).toList();
    } else {
      return tables.keys.toList();
    }
  }

  /// Extracts the trailing/internal numeric digits from a table name string.
  int _extractTableNumber(String tableName) {
    final numeric = tableName.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(numeric) ?? 0;
  }

  /// Listens to real-time changes in tables collection from Firebase via the OrderRepository.
  void listenToTables() {
    _tablesSubscription = _orderRepository.listenToTables().listen((querySnapshot) {
      // Sort docs: Dine-In tables naturally ordered by number first, then Take Away naturally ordered by number
      final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(querySnapshot.docs);
      docs.sort((a, b) {
        final nameA = (a.data()['name'] ?? '').toString();
        final nameB = (b.data()['name'] ?? '').toString();
        
        final isTableA = nameA.toLowerCase().contains('table');
        final isTableB = nameB.toLowerCase().contains('table');
        
        if (isTableA && !isTableB) return -1;
        if (!isTableA && isTableB) return 1;
        
        final numA = _extractTableNumber(nameA);
        final numB = _extractTableNumber(nameB);
        
        if (numA != numB) {
          return numA.compareTo(numB);
        }
        return nameA.compareTo(nameB);
      });

      Map<String, List<List<Map<String, dynamic>>>> updatedTables = {};

      for (var doc in docs) {
        final tableName = doc['name'] as String;
        final List<dynamic>? itemsFromDb = doc.data().containsKey('items') ? doc['items'] : null;

        List<List<Map<String, dynamic>>> groupedItems = [];

        if (itemsFromDb != null && itemsFromDb.isNotEmpty) {
          bool hasGroupIndex = itemsFromDb.isNotEmpty &&
              itemsFromDb.first is Map &&
              (itemsFromDb.first as Map).containsKey('groupIndex');

          if (hasGroupIndex) {
            Map<int, List<Map<String, dynamic>>> groupMap = {};
            for (var item in itemsFromDb) {
              if (item is Map) {
                Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
                int groupIndex = itemMap['groupIndex'] ?? 0;
                itemMap.remove('groupIndex');

                if (!groupMap.containsKey(groupIndex)) {
                  groupMap[groupIndex] = [];
                }
                groupMap[groupIndex]!.add(itemMap);
              }
            }
            List<int> sortedGroupIndices = groupMap.keys.toList()..sort();
            for (int groupIndex in sortedGroupIndices) {
              groupedItems.add(groupMap[groupIndex]!);
            }
          } else if (itemsFromDb.first is List) {
            for (var group in itemsFromDb) {
              if (group is List) {
                List<Map<String, dynamic>> itemList = [];
                for (var item in group) {
                  if (item is Map) itemList.add(Map<String, dynamic>.from(item));
                }
                groupedItems.add(itemList);
              }
            }
          } else if (itemsFromDb.first is Map) {
            List<Map<String, dynamic>> itemList = [];
            for (var item in itemsFromDb) {
              if (item is Map) itemList.add(Map<String, dynamic>.from(item));
            }
            if (itemList.isNotEmpty) groupedItems.add(itemList);
          }
        }
        updatedTables[tableName] = groupedItems;
      }
      
      tables.value = updatedTables;
      
      // Compute correct monotonically increasing take away numbering base
      final takeAways = updatedTables.keys.where((k) => !k.contains('Table')).toList();
      int maxTakeAwayNum = 0;
      for (String k in takeAways) {
        if (k.toLowerCase().startsWith('take away')) {
          final digits = k.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.isNotEmpty) {
            int num = int.parse(digits);
            if (num > maxTakeAwayNum) maxTakeAwayNum = num;
          }
        }
      }
      tableNo.value = maxTakeAwayNum;
    });
  }

  /// Loads menu catalogs from database using the OrderRepository.
  Future<void> loadMenu() async {
    isLoading.value = true;
    try {
      final loadedMenu = await _orderRepository.loadMenu();
      menu.assignAll(loadedMenu);
    } catch (e) {
      debugPrint("Error loading menu: $e");
    } finally {
      isLoading.value = false;
    }
  }

  /// Updates existing table active items. Direct delegate to Repository.
  Future<void> updateTableItemsInFirestore(
    String tableName,
    List<List<Map<String, dynamic>>> groups,
    bool isBillPaid, [
    String overallRemarks = '',
  ]) async {
    try {
      await _orderRepository.updateTableItems(
        tableName: tableName,
        groups: groups,
        isPaid: isBillPaid,
        overallRemarks: overallRemarks,
      );
    } catch (e) {
      debugPrint("Failed to update Firestore: $e");
    }
  }

  /// Adds a new table order. Appends to existing one if a duplicate name collision occurs.
  Future<void> addTableAndUpdateItems(
    String tableName,
    List<Map<String, dynamic>> selectedItems,
    bool isBillPaid, [
    String overallRemarks = '',
  ]) async {
    try {
      final exists = await _orderRepository.checkTableExists(tableName);

      if (exists) {
        // Safe collision fallback: append new items as a group to prevent data loss
        final existingGroups = tables[tableName] ?? [];
        if (isBillPaid) {
          existingGroups.clear();
        }
        existingGroups.add(selectedItems);
        await updateTableItemsInFirestore(tableName, existingGroups, isBillPaid, overallRemarks);
        return;
      }

      await _orderRepository.addNewTable(
        tableName: tableName,
        selectedItems: selectedItems,
        isPaid: isBillPaid,
        overallRemarks: overallRemarks,
      );
    } catch (e) {
      debugPrint("Failed to add table: $e");
    }
  }

  /// Deletes a table document (typically takeaway) entirely. Direct delegate to Repository.
  Future<void> deleteTable(String docId) async {
    try {
      await _orderRepository.deleteTable(docId);
    } catch (e) {
      debugPrint("Failed to delete table: $e");
    }
  }

  /// Deletes a table document by its name.
  Future<void> deleteTableByName(String tableName) async {
    try {
      await _orderRepository.deleteTableByName(tableName);
    } catch (e) {
      debugPrint("Failed to delete table by name: $e");
    }
  }
  
  /// Combines duplicates items matching name & category into one summed item entry.
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
}
