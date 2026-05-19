import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import 'package:demo/models/GroupOrder.dart';
import 'package:demo/Screens/Kitchen/repositories/kitchen_repository.dart';

/// KitchenController
/// 
/// Part of the GetX Repository Pattern.
/// This controller handles reactive orders streams, menu categories streams,
/// audio sound notifications, order flashing states, and periodic relative-time updates.
class KitchenController extends GetxController {
  final KitchenRepository _repository = KitchenRepository();
  final AudioPlayer audioPlayer = AudioPlayer();

  // ── Reactive Presentation States ──────────────────────────────────────────
  final RxList<TableGroup> orders = <TableGroup>[].obs;
  final RxList<String> categoriesList = <String>[].obs;
  final RxSet<String> selectedCategories = <String>{}.obs;
  final RxBool showAllCategories = true.obs;
  final RxnInt blinkingGroupKey = RxnInt();
  final RxString blinkingColorMode = ''.obs; // 'green' or 'blue'

  // ── Internal Helpers ──────────────────────────────────────────────────────
  final RxSet<String> previousKeys = <String>{}.obs;
  final RxMap<String, String> groupContentHashes = <String, String>{}.obs;
  Timer? _relativeTimeTimer;

  @override
  void onInit() {
    super.onInit();

    // 1. Bind Firestore orders stream to reactive orders list
    orders.bindStream(
      _repository.getTablesStream().map((snapshotList) {
        List<TableGroup> updatedGroups = [];
        for (var doc in snapshotList) {
          final tableName = (doc['name'] ?? 'Unknown Table') as String;
          final isPaid = (doc.containsKey('isPaid')) ? (doc['isPaid'] as bool) : false;
          final itemsFromDb = (doc.containsKey('items'))
              ? (doc['items'] as List<dynamic>?)
              : null;
          updatedGroups.addAll(reconstructGroups(
            tableName,
            itemsFromDb,
            isPaid: isPaid,
            docId: doc['id'] as String,
          ));
        }
        // Sort groups chronologically
        updatedGroups.sort((a, b) => a.groupTime.compareTo(b.groupTime));
        return updatedGroups;
      }),
    );

    // 2. Bind menus category stream
    categoriesList.bindStream(
      _repository.getCategoriesStream().map((menusList) {
        return menusList.map((m) => m['name'] as String).toList();
      }),
    );

    // 3. Periodic timer to update relative-time display ("X mins ago")
    _relativeTimeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      orders.refresh();
    });

    // 4. Reactive worker: triggers audio notification / blink effects on new orders
    ever(orders, _handleNewOrdersNotification);
  }

  @override
  void onClose() {
    _relativeTimeTimer?.cancel();
    audioPlayer.dispose();
    super.onClose();
  }

  // ── Computed Observables (Getters) ────────────────────────────────────────

  /// Returns a chronologically sorted list of TableGroups filtered by the selected categories.
  List<TableGroup> get filteredOrders {
    if (showAllCategories.value || selectedCategories.isEmpty) {
      return orders;
    }

    return orders.map((group) {
      // Filter items in this group by selected categories
      final filteredItems = group.items.where((item) {
        final itemCategory = item['category']?.toString() ?? '';
        return selectedCategories.contains(itemCategory);
      }).toList();

      if (filteredItems.isEmpty) return null;

      // Return a new group matching the filtered categories
      return TableGroup(
        group.tableName,
        filteredItems,
        group.groupTime,
        key: group.key,
        docId: group.docId,
        isPaid: group.isPaid,
      );
    }).whereType<TableGroup>().toList();
  }

  // ── Sound Notification Operations ──────────────────────────────────────────

  /// Plays the standard speed phone bell sound notification on new/updated order arrival.
  void playNotificationSound() async {
    try {
      await audioPlayer.setPlaybackRate(1.0);
      await audioPlayer.play(AssetSource('sounds/phone_bell.mp3'));
    } catch (e) {
      // Ignore audio player initialization/playback warnings
    }
  }

  /// Plays a fast, high-pitched confirmation chime when an order is served or cleared.
  void playDeleteSound() async {
    try {
      await audioPlayer.setPlaybackRate(2.0); // Plays twice as fast and at a high pitch
      await audioPlayer.play(AssetSource('sounds/phone_bell.mp3'));
    } catch (e) {
      // Ignore audio warnings
    }
  }

  // ── Database operations ────────────────────────────────────────────────────

  /// Clears/deletes a takeaway order or empty dining table.
  Future<void> deleteTable(String docId) async {
    await _repository.deleteTable(docId);
  }

  /// Updates table items when marked as served or delivered.
  Future<void> updateTableItems(String tableName, List<Map<String, dynamic>> items, bool isPaid) async {
    await _repository.updateTableItems(tableName, items, isPaid);
  }

  // ── Extraction Helpers ─────────────────────────────────────────────────────

  /// Parses raw Firestore table documents into chronological order groups.
  List<TableGroup> reconstructGroups(
    String tableName,
    List<dynamic>? itemsFromDb, {
    required bool isPaid,
    required String docId,
  }) {
    List<TableGroup> groups = [];
    if (itemsFromDb == null) return groups;

    Map<int, List<Map<String, dynamic>>> groupMap = {};
    Map<int, Timestamp> groupTimeMap = {};

    for (var item in itemsFromDb) {
      if (item is Map) {
        final itemMap = Map<String, dynamic>.from(item);
        final int groupIndex = (itemMap['groupIndex'] is int)
            ? itemMap['groupIndex'] as int
            : 0;
        final Timestamp addedAt = (itemMap['addedAt'] is Timestamp)
            ? itemMap['addedAt'] as Timestamp
            : Timestamp.now();

        itemMap.remove('groupIndex');
        itemMap.remove('addedAt');

        groupMap.putIfAbsent(groupIndex, () => []);
        groupMap[groupIndex]!.add(itemMap);
        groupTimeMap[groupIndex] = addedAt;
      }
    }

    groupMap.forEach((index, items) {
      if (items.isEmpty) return;
      final timestamp = groupTimeMap[index] ?? Timestamp.now();
      groups.add(
        TableGroup(
          tableName,
          items,
          timestamp.toDate().millisecondsSinceEpoch,
          key: '${tableName}_$index',
          docId: docId,
          isPaid: isPaid,
        ),
      );
    });

    return groups;
  }

  /// Generates a simple text signature representing item names, quantities, and remarks inside a group.
  String _getGroupSignature(TableGroup group) {
    return group.items.map((item) {
      return "${item['name']}_${item['qty']}_${item['remarks']}";
    }).join("|");
  }

  /// Evaluates new and modified orders to flash their container and play sound notifications.
  void _handleNewOrdersNotification(List<TableGroup> currentOrders) {
    final currentKeys = currentOrders.map((g) => g.key).toSet();

    if (previousKeys.isEmpty && currentKeys.isNotEmpty) {
      // First time loading - record signatures and keys quietly to prevent sound explosion on initial app launch.
      for (var group in currentOrders) {
        groupContentHashes[group.key] = _getGroupSignature(group);
      }
      previousKeys.assignAll(currentKeys);
      return;
    }

    String? keyToBlink;
    String mode = '';
    bool playSound = false;

    for (var group in currentOrders) {
      final key = group.key;
      final signature = _getGroupSignature(group);

      if (!previousKeys.contains(key)) {
        // 1️⃣ Brand new order group added!
        keyToBlink = key;
        mode = 'green';
        if (_shouldPlaySoundForGroup(group)) {
          playSound = true;
        }
        groupContentHashes[key] = signature;
      } else {
        // 2️⃣ Existing group - verify if signature (item/qty/remarks) is updated
        final oldSignature = groupContentHashes[key];
        if (oldSignature != null && oldSignature != signature) {
          keyToBlink = key;
          mode = 'blue';
          if (_shouldPlaySoundForGroup(group)) {
            playSound = true;
          }
          groupContentHashes[key] = signature;
        }
      }
    }

    // Always synchronize local lists for the next event loop
    previousKeys.assignAll(currentKeys);
    for (var group in currentOrders) {
      groupContentHashes[group.key] = _getGroupSignature(group);
    }

    // Trigger reactive state effects
    if (keyToBlink != null) {
      final targetHash = keyToBlink.hashCode;
      blinkingGroupKey.value = targetHash;
      blinkingColorMode.value = mode;

      if (playSound) {
        playNotificationSound();
      }

      Timer(const Duration(seconds: 4), () {
        if (blinkingGroupKey.value == targetHash) {
          blinkingGroupKey.value = null;
          blinkingColorMode.value = '';
        }
      });
    }
  }

  /// Determines whether a sound/blink alert is enabled based on category filters.
  bool _shouldPlaySoundForGroup(TableGroup group) {
    if (showAllCategories.value || selectedCategories.isEmpty) {
      return true;
    }

    for (var item in group.items) {
      final itemCategory = item['category']?.toString() ?? '';
      if (selectedCategories.contains(itemCategory)) {
        return true;
      }
    }

    return false;
  }
}
