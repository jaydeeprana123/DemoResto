import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/Screens/Authentication/LoginScreenView.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Controller for managing the dashboard (tables, take aways, and menu).
class DashboardController extends GetxController {
  // ── Reactive State Variables (Observables) ──
  
  /// Holds all tables and their associated item groups.
  var tables = <String, List<List<Map<String, dynamic>>>>{}.obs;
  
  /// Holds the complete list of menu items.
  var menu = <Map<String, dynamic>>[].obs;
  
  /// Indicates if the menu is currently loading from Firestore.
  var isLoading = false.obs;
  
  /// The currently selected tab filter ('All', 'Tables', 'Take Away').
  var selectedTab = 'All'.obs;

  StreamSubscription<QuerySnapshot>? tablesSubscription;
  final user = FirebaseAuth.instance.currentUser;
  
  /// Tracks the number of take-away orders to auto-generate names.
  var tableNo = 0.obs;

  /// Runs automatically when the controller starts.
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

  /// Runs when the controller is destroyed.
  @override
  void onClose() {
    tablesSubscription?.cancel();
    super.onClose();
  }

  /// Signs the user out and navigates back to the Login Screen.
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    Get.offAll(() => const LoginPage());
  }

  /// Changes the active tab filter.
  void selectTab(String tab) {
    selectedTab.value = tab;
  }

  /// Returns a filtered list of table names based on the selected tab.
  List<String> get filteredTableKeys {
    if (selectedTab.value == 'Take Away') {
      return tables.keys.where((key) => !key.contains('Table')).toList();
    } else if (selectedTab.value == 'Tables') {
      return tables.keys.where((key) => key.contains('Table')).toList();
    } else {
      return tables.keys.toList();
    }
  }

  /// Listens to real-time changes in the 'tables' Firestore collection.
  void listenToTables() {
    tablesSubscription = FirebaseFirestore.instance
        .collection('tables')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen((querySnapshot) {
      Map<String, List<List<Map<String, dynamic>>>> updatedTables = {};

      for (var doc in querySnapshot.docs) {
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
      
      // Update the reactive variable
      tables.value = updatedTables;
      
      // Update tableNo count based on take away keys for the floating action button
      final takeAways = updatedTables.keys.where((k) => !k.contains('Table')).toList();
      tableNo.value = takeAways.length;
    });
  }

  /// Loads the entire menu from Firestore.
  Future<void> loadMenu() async {
    isLoading.value = true;
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
            "qty": 1,
          });
        }
      }
      
      menu.assignAll(loadedMenu);
    } catch (e) {
      debugPrint("Error loading menu: $e");
    } finally {
      isLoading.value = false;
    }
  }

  /// Updates existing table items in Firestore.
  Future<void> updateTableItemsInFirestore(
    String tableName,
    List<List<Map<String, dynamic>>> groups,
    bool isBillPaid, [
    String overallRemarks = '',
  ]) async {
    try {
      final tableQuery = await FirebaseFirestore.instance
          .collection('tables')
          .where('name', isEqualTo: tableName)
          .limit(1)
          .get();

      if (tableQuery.docs.isEmpty) return;

      final docId = tableQuery.docs.first.id;
      List<Map<String, dynamic>> flattenedItems = [];

      for (int groupIndex = 0; groupIndex < groups.length; groupIndex++) {
        var group = groups[groupIndex];
        Timestamp groupTimestamp;
        
        if (group.isNotEmpty && group[0].containsKey('addedAt')) {
          groupTimestamp = group[0]['addedAt'];
        } else {
          groupTimestamp = Timestamp.now();
        }

        for (var item in group) {
          final itemWithMeta = Map<String, dynamic>.from(item);
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

      await FirebaseFirestore.instance.collection('tables').doc(docId).update(updateData);
    } catch (e) {
      debugPrint("Failed to update Firestore: $e");
    }
  }

  /// Adds a new table (typically for take away) and its selected items to Firestore.
  Future<void> addTableAndUpdateItems(
    String tableName,
    List<Map<String, dynamic>> selectedItems,
    bool isBillPaid, [
    String overallRemarks = '',
  ]) async {
    try {
      final existing = await FirebaseFirestore.instance
          .collection('tables')
          .where('name', isEqualTo: tableName)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) return;

      List<Map<String, dynamic>> flattenedItems = [];
      final Timestamp groupTimestamp = Timestamp.now();

      for (int i = 0; i < selectedItems.length; i++) {
        final item = Map<String, dynamic>.from(selectedItems[i]);
        item['groupIndex'] = 0;
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

      await FirebaseFirestore.instance.collection('tables').add(tableData);
    } catch (e) {
      debugPrint("Failed to add table: $e");
    }
  }

  /// Deletes a table entirely from Firestore.
  Future<void> deleteTable(String docId) async {
    await FirebaseFirestore.instance.collection('tables').doc(docId).delete();
  }
  
  /// Helper method to merge items with identical name and category to combine their quantities.
  List<Map<String, dynamic>> mergeItemsByNameAndCategory(List<Map<String, dynamic>> items) {
    final Map<String, Map<String, dynamic>> itemMap = {};
    for (var item in items) {
      final key = "\${item['name']}_\${item['categoryId']}";
      if (itemMap.containsKey(key)) {
        itemMap[key]!['qty'] = (itemMap[key]!['qty'] ?? 1) + (item['qty'] ?? 1);
      } else {
        itemMap[key] = Map<String, dynamic>.from(item);
      }
    }
    return itemMap.values.toList();
  }
}
