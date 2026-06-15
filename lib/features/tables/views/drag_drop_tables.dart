import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_sync_channel.dart';
import 'package:demo/core/firestore/resilient_firestore_listener.dart';
import 'package:demo/core/services/firestore_sync_status_service.dart';
import 'package:demo/core/widgets/firestore_sync_status_chip.dart';
import 'package:demo/core/utils/platform_utils.dart';
import 'package:demo/core/utils/table_name_utils.dart';
import 'package:demo/core/utils/zomato_order_utils.dart';
import 'package:demo/features/menu_setup/services/menu_cache_service.dart';
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
import 'package:demo/features/tables/services/dashboard_table_filter_settings.dart';
import 'package:demo/features/tables/views/AddTablePage.dart';
import 'package:demo/features/tables/widgets/order_item_row.dart';
import 'package:demo/features/zomato/widgets/add_zomato_order_sheet.dart';
import 'package:demo/features/zomato/repositories/zomato_orders_repository.dart';
import 'package:demo/features/zomato/services/zomato_clipboard_paste_service.dart';
import 'package:demo/features/zomato/widgets/dashboard_zomato_paste_scope.dart';
import 'package:demo/features/zomato/widgets/import_shared_zomato_sheet.dart';
import 'package:demo/features/zomato/widgets/zomato_order_progress_dialog.dart';
import 'package:demo/features/zomato/widgets/zomato_order_card_body.dart';
import 'package:demo/features/zomato/widgets/zomato_screenshot_viewer.dart';
import 'package:demo/features/transactions/services/reverse_billing_service.dart';
import 'package:demo/Styles/my_icons.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'dart:async';

import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';

class DragListBetweenTables extends StatefulWidget {
  const DragListBetweenTables({this.isTabActive = true, super.key});

  final bool isTabActive;

  @override
  State<DragListBetweenTables> createState() => _DragListBetweenTablesState();
}

class _DragListBetweenTablesState extends State<DragListBetweenTables>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
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
  bool _isRefreshingDashboard = false;
  bool _tablesLoading = false;
  final user = FirebaseAuth.instance.currentUser;
  int tableNo = 0;
  String selectedTab = 'All'; // 👈 Add this variable at class level
  final Set<String> _tableFilterSelection = {};
  final Map<String, String> tableSources = {};
  final Map<String, String> tableScreenshotUrls = {};
  final Map<String, String> tableZomatoStatuses = {};
  ResilientFirestoreListener<QuerySnapshot<Map<String, dynamic>>>?
      _tablesListener;
  final ScrollController _gridScrollController = ScrollController();
  bool _zomatoPasteInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loadTableFilter();

    if (user != null) {
      _tablesLoading = true;
      _listenToTables();
      _loadMenuFromCache();
    }
  }

  Future<void> _loadTableFilter() async {
    final saved = await DashboardTableFilterSettings.loadSelection();
    if (!mounted) return;
    setState(() {
      _tableFilterSelection
        ..clear()
        ..addAll(saved);
    });
  }

  Future<void> _persistTableFilter() async {
    await DashboardTableFilterSettings.saveSelection(_tableFilterSelection);
  }

  Future<void> _updateTableFilterSelection(
    void Function(Set<String> selection) update,
  ) async {
    setState(() => update(_tableFilterSelection));
    await _persistTableFilter();
  }

  Future<void> signOut() async {
    await Get.find<UserRepository>().signOut();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gridScrollController.dispose();
    _tablesListener?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tablesListener?.restart();
    }
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

  bool _sameGroupedItems(
    List<List<Map<String, dynamic>>> a,
    List<List<Map<String, dynamic>>> b,
  ) {
    if (a.length != b.length) return false;
    for (var gi = 0; gi < a.length; gi++) {
      if (a[gi].length != b[gi].length) return false;
      for (var ii = 0; ii < a[gi].length; ii++) {
        final left = a[gi][ii];
        final right = b[gi][ii];
        if (left['name'] != right['name'] ||
            left['qty'] != right['qty'] ||
            left['price'] != right['price'] ||
            TableItemServed.isServed(left) !=
                TableItemServed.isServed(right) ||
            left['remarks'] != right['remarks']) {
          return false;
        }
      }
    }
    return true;
  }

  bool _sameTablesData(
    Map<String, List<List<Map<String, dynamic>>>> a,
    Map<String, List<List<Map<String, dynamic>>>> b,
  ) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || !_sameGroupedItems(entry.value, other)) {
        return false;
      }
    }
    return true;
  }

  bool _sameStringMap(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  bool _sameBoolMap(Map<String, bool> a, Map<String, bool> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  bool _sameIntListMap(Map<String, List<int>> a, Map<String, List<int>> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || !listEquals(entry.value, other)) return false;
    }
    return true;
  }

  bool _dashboardSnapshotUnchanged({
    required Map<String, List<List<Map<String, dynamic>>>> updatedTables,
    required Map<String, List<int>> updatedFirestoreGroupIndices,
    required Map<String, bool> updatedIsPaid,
    required Map<String, String> updatedDocIds,
    required Map<String, String> updatedTransactionIds,
    required Map<String, String> updatedSources,
    required Map<String, String> updatedScreenshotUrls,
    required Map<String, String> updatedZomatoStatuses,
  }) {
    return _sameTablesData(tables, updatedTables) &&
        _sameIntListMap(_firestoreGroupIndices, updatedFirestoreGroupIndices) &&
        _sameBoolMap(tableIsPaid, updatedIsPaid) &&
        _sameStringMap(tableDocIds, updatedDocIds) &&
        _sameStringMap(tableTransactionIds, updatedTransactionIds) &&
        _sameStringMap(tableSources, updatedSources) &&
        _sameStringMap(tableScreenshotUrls, updatedScreenshotUrls) &&
        _sameStringMap(tableZomatoStatuses, updatedZomatoStatuses);
  }

  void _restoreGridScroll(double offset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_gridScrollController.hasClients) return;
      final maxExtent = _gridScrollController.position.maxScrollExtent;
      final target = offset.clamp(0.0, maxExtent);
      if ((_gridScrollController.offset - target).abs() > 0.5) {
        _gridScrollController.jumpTo(target);
      }
    });
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
    final syncStatus = Get.find<FirestoreSyncStatusService>();
    _tablesListener?.stop();
    _tablesListener = ResilientFirestoreListener<QuerySnapshot<Map<String, dynamic>>>(
      debugLabel: 'dashboard',
      streamFactory: () => FirestorePaths
          .scoped('tables')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      onStatus: (status) =>
          syncStatus.setStatus(FirestoreSyncChannel.dashboard, status),
      onData: _onTablesSnapshot,
    )..start();
  }

  void _onTablesSnapshot(QuerySnapshot<Map<String, dynamic>> querySnapshot) {
    Map<String, List<List<Map<String, dynamic>>>> updatedTables = {};
    final Map<String, List<int>> updatedFirestoreGroupIndices = {};

    final Map<String, Timestamp?> updatedCreatedAt = {};
    final Map<String, bool> updatedIsPaid = {};
    final Map<String, String> updatedDocIds = {};
    final Map<String, String> updatedTransactionIds = {};
    final Map<String, String> updatedSources = {};
    final Map<String, String> updatedScreenshotUrls = {};
    final Map<String, String> updatedZomatoStatuses = {};

    for (var doc in querySnapshot.docs) {
            final tableName = doc['name'] as String;
            final data = doc.data();
            updatedCreatedAt[tableName] = data['createdAt'] as Timestamp?;
            updatedIsPaid[tableName] = data['isPaid'] == true;
            updatedDocIds[tableName] = doc.id;
            if (ZomatoOrderUtils.isZomatoDoc(data)) {
              updatedSources[tableName] = ZomatoOrderUtils.sourceZomato;
              updatedScreenshotUrls[tableName] =
                  data['screenshotUrl']?.toString() ?? '';
              updatedZomatoStatuses[tableName] = ZomatoOrderUtils.normalizeStatus(
                data['zomatoStatus']?.toString(),
              );
            }
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
                final groupItemCounters = <int, int>{};

                for (var item in itemsFromDb) {
                  if (item is Map) {
                    Map<String, dynamic> itemMap = Map<String, dynamic>.from(
                      item,
                    );
                    final groupIndex =
                        TableItemServed.parseGroupIndex(itemMap['groupIndex']);
                    final indexInGroup = groupItemCounters[groupIndex] ?? 0;
                    groupItemCounters[groupIndex] = indexInGroup + 1;

                    itemMap.remove('groupIndex');
                    itemMap['__firestoreGroupIndex'] = groupIndex;
                    itemMap['__itemIndex'] = indexInGroup;

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
                for (var i = 0; i < itemsFromDb.length; i++) {
                  final item = itemsFromDb[i];
                  if (item is Map) {
                    final itemMap = Map<String, dynamic>.from(item);
                    itemMap['__firestoreGroupIndex'] = 0;
                    itemMap['__itemIndex'] = i;
                    itemList.add(itemMap);
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

    var filterPruned = false;
    final scrollOffset = _gridScrollController.hasClients
        ? _gridScrollController.offset
        : null;
    final unchanged = _dashboardSnapshotUnchanged(
      updatedTables: updatedTables,
      updatedFirestoreGroupIndices: updatedFirestoreGroupIndices,
      updatedIsPaid: updatedIsPaid,
      updatedDocIds: updatedDocIds,
      updatedTransactionIds: updatedTransactionIds,
      updatedSources: updatedSources,
      updatedScreenshotUrls: updatedScreenshotUrls,
      updatedZomatoStatuses: updatedZomatoStatuses,
    );

    if (unchanged) {
      if (_tablesLoading && mounted) {
        setState(() => _tablesLoading = false);
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _tablesLoading = false;
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
      tableSources
        ..clear()
        ..addAll(updatedSources);
      tableScreenshotUrls
        ..clear()
        ..addAll(updatedScreenshotUrls);
      tableZomatoStatuses
        ..clear()
        ..addAll(updatedZomatoStatuses);
      if (_tableFilterSelection.isNotEmpty) {
        final before = _tableFilterSelection.length;
        _tableFilterSelection.removeWhere(
          (key) => !updatedTables.containsKey(key),
        );
        filterPruned = before != _tableFilterSelection.length;
      }
    });
    if (filterPruned) {
      _persistTableFilter();
    }
    if (scrollOffset != null) {
      _restoreGridScroll(scrollOffset);
    }
  }

  Future<void> _loadMenuFromCache() async {
    if (!mounted) return;

    try {
      final loadedMenu = await Get.find<MenuCacheService>().ensureLoaded();
      if (!mounted) return;
      setState(() {
        menu.clear();
        menu.addAll(loadedMenu);
      });
    } catch (e) {
      print("Error loading cached menu: $e");
    }
  }

  Future<void> _reloadMenuFromCache() async {
    if (!mounted) return;

    try {
      final loadedMenu = await Get.find<MenuCacheService>().loadFromCacheOnly();
      if (!mounted || loadedMenu.isEmpty) return;
      setState(() {
        menu.clear();
        menu.addAll(loadedMenu);
      });
    } catch (e) {
      print('Error reloading menu cache: $e');
    }
  }

  Future<void> _refreshDashboard() async {
    if (_isRefreshingDashboard || !mounted) return;

    setState(() => _isRefreshingDashboard = true);
    try {
      final snapshot =
          await Get.find<TablesRepository>().fetchAllTablesFresh();
      if (!mounted) return;
      _onTablesSnapshot(snapshot);
      _tablesListener?.restart();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh tables: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingDashboard = false);
      }
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

    final result = await TableBillingSheet.runBillingFlow(
      context,
      tableName: tableName,
      items: merged,
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

    if (result != null) {
      TableBillingSheet.deliverReceiptInBackground(result);
    }
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

  bool get _showDashboardRefreshButton =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  Widget _buildTablesScrollArea(int crossCols, double screenW) {
    final minScrollHeight = MediaQuery.sizeOf(context).height * 0.55;

    if (_tablesLoading && tables.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: minScrollHeight,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 220,
                    child: LinearProgressIndicator(
                      color: _orange,
                      backgroundColor: Color(0xFFE5E7EB),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading tables...',
                    style: TextStyle(
                      fontFamily: fontMulishSemiBold,
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (tables.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: minScrollHeight, child: _buildEmptyState()),
        ],
      );
    }

    if (_filteredTableKeys().isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: minScrollHeight,
            child: _buildFilterEmptyState(),
          ),
        ],
      );
    }

    return MasonryGridView.count(
      controller: _gridScrollController,
      restorationId: 'dashboard_tables_grid',
      cacheExtent: 3000,
      physics: const AlwaysScrollableScrollPhysics(),
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
        final tableName = _filteredTableKeys().elementAt(index);
        final groups = tables[tableName]!;
        final queuePos = _takeAwayNumber(tableName);
        return KeyedSubtree(
          key: ValueKey(tableName),
          child: _buildTableCard(
            tableName,
            groups,
            takeAwayNum: queuePos,
          ),
        );
      },
    );
  }

  Future<void> _handleZomatoPaste() async {
    if (!supportsZomatoClipboardPaste || _zomatoPasteInProgress || !mounted) {
      return;
    }

    final bytes = await ZomatoClipboardPasteService.readImageBytes();
    if (!mounted) return;

    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image found in clipboard.')),
      );
      return;
    }

    _zomatoPasteInProgress = true;
    try {
      final imported = await ImportSharedZomatoSheet.show(
        context,
        imageBytes: bytes,
        fileName:
            'zomato_paste_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      if (!mounted || !imported) return;
      setState(() => selectedTab = 'Zomato');
    } finally {
      _zomatoPasteInProgress = false;
    }
  }

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

    return DashboardZomatoPasteScope(
      enabled: supportsZomatoClipboardPaste && widget.isTabActive,
      onPasteImage: _handleZomatoPaste,
      child: Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              if (_tablesLoading || _isRefreshingDashboard)
                LinearProgressIndicator(
                  minHeight: 3,
                  color: _orange,
                  backgroundColor: _orange.withValues(alpha: 0.15),
                ),
              _buildTabBar(),
              Expanded(
                child: RefreshIndicator(
                  color: _orange,
                  onRefresh: _refreshDashboard,
                  child: _buildTablesScrollArea(crossCols, screenW),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
    ),
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
        const FirestoreSyncStatusChip(channel: FirestoreSyncChannel.dashboard),
        if (_showDashboardRefreshButton)
          IconButton(
            icon: _isRefreshingDashboard
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _orange,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Refresh tables',
            onPressed:
                _isRefreshingDashboard ? null : _refreshDashboard,
          ),
        IconButton(
          icon: Icon(
            _tableFilterSelection.isNotEmpty
                ? Icons.filter_alt_rounded
                : Icons.filter_list_rounded,
            color: _tableFilterSelection.isNotEmpty
                ? _orange
                : Colors.white70,
          ),
          tooltip: _tableFilterSelection.isEmpty
              ? 'Filter tables'
              : 'Filter active (${_tableFilterSelection.length} selected)',
          onPressed: _showTableFilterSheet,
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_filteredTableKeys().length} ${_dashboardCountLabel()}',
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
          children: ['All', 'Tables', 'Take Away', 'Zomato'].map((label) {
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
                        fontSize: label == 'Take Away' || label == 'Zomato'
                            ? 11
                            : 13,
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

  Widget _buildFilterEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_alt_off_outlined,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No matching tables',
              style: TextStyle(
                fontSize: 18,
                fontFamily: fontMulishBold,
                color: _navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tableFilterSelection.isEmpty
                  ? 'Nothing to show for this tab.'
                  : 'Your filter has no tables on this tab.\n'
                      'Tap the filter icon to change your selection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontFamily: fontMulishRegular,
                color: Colors.grey.shade500,
              ),
            ),
            if (_tableFilterSelection.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _updateTableFilterSelection(
                  (selection) => selection.clear(),
                ),
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear filter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  side: const BorderSide(color: _navy),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _allTableKeysSorted() {
    final tableKeys =
        tables.keys.where((key) => key.startsWith('Table ')).toList()
          ..sort(_compareTableNumber);
    final takeAwayKeys = tables.keys
        .where((key) => _isTakeAway(key) && !_isZomatoTable(key))
        .toList()
      ..sort(_compareByCreatedAt);
    final zomatoKeys = tables.keys.where(_isActiveZomatoTable).toList()
      ..sort(_compareByCreatedAt);
    final otherKeys =
        tables.keys
            .where(
              (key) =>
                  !key.startsWith('Table ') &&
                  !_isTakeAway(key) &&
                  !_isZomatoTable(key),
            )
            .toList()
          ..sort();
    return [...tableKeys, ...takeAwayKeys, ...zomatoKeys, ...otherKeys];
  }

  Future<void> _showTableFilterSheet() async {
    final allKeys = _allTableKeysSorted();
    if (allKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tables available to filter.')),
      );
      return;
    }

    final dineInKeys =
        allKeys.where((key) => key.startsWith('Table ')).toList();
    final takeAwayKeys = allKeys.where(_isTakeAway).toList();
    final otherKeys = allKeys
        .where((key) => !key.startsWith('Table ') && !_isTakeAway(key))
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void toggleKey(String key, bool? selected) {
              _updateTableFilterSelection((selection) {
                if (selected == true) {
                  selection.add(key);
                } else {
                  selection.remove(key);
                }
              });
              setSheetState(() {});
            }

            void selectAll() {
              _updateTableFilterSelection((selection) {
                selection
                  ..clear()
                  ..addAll(allKeys);
              });
              setSheetState(() {});
            }

            void clearFilter() {
              _updateTableFilterSelection((selection) => selection.clear());
              setSheetState(() {});
            }

            Widget buildSection(String title, List<String> keys) {
              if (keys.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: fontMulishBold,
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  ...keys.map(
                    (key) => CheckboxListTile(
                      value: _tableFilterSelection.contains(key),
                      activeColor: _orange,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(
                        key,
                        style: const TextStyle(
                          fontFamily: fontMulishSemiBold,
                          fontSize: 15,
                          color: _navy,
                        ),
                      ),
                      subtitle: tableIsPaid[key] == true
                          ? Text(
                              'PAID',
                              style: TextStyle(
                                fontFamily: fontMulishSemiBold,
                                fontSize: 11,
                                color: Colors.red.shade700,
                              ),
                            )
                          : null,
                      onChanged: (value) => toggleKey(key, value),
                    ),
                  ),
                ],
              );
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.72,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Filter tables',
                                style: TextStyle(
                                  fontFamily: fontMulishBold,
                                  fontSize: 18,
                                  color: _navy,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: selectAll,
                              child: const Text('Select all'),
                            ),
                            TextButton(
                              onPressed: clearFilter,
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _tableFilterSelection.isEmpty
                              ? 'Showing all tables. Select tables to display only those.'
                              : '${_tableFilterSelection.length} selected · '
                                  'dashboard shows selected tables only',
                          style: TextStyle(
                            fontFamily: fontMulishRegular,
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          children: [
                            buildSection('Dine-in tables', dineInKeys),
                            buildSection('Take away', takeAwayKeys),
                            buildSection('Other', otherKeys),
                          ],
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _navy,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () => Navigator.pop(sheetContext),
                              child: Text(
                                _tableFilterSelection.isEmpty
                                    ? 'Show all tables'
                                    : 'Show ${_tableFilterSelection.length} selected',
                                style: const TextStyle(
                                  fontFamily: fontMulishBold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
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
    if (selectedTab == 'Zomato') {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text(
          'Add Zomato Order',
          style: TextStyle(fontFamily: fontMulishSemiBold, fontSize: 14),
        ),
        onPressed: () => AddZomatoOrderSheet.show(context),
      );
    }

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
              onMenuCacheUpdated: _reloadMenuFromCache,
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
        await _reloadMenuFromCache();
      },
    );
  }

  bool _isTakeAway(String name) => isTakeAwayOrderName(name) && !_isZomatoTable(name);

  bool _isZomatoTable(String name) =>
      ZomatoOrderUtils.isZomatoSource(tableSources[name]) ||
      ZomatoOrderUtils.isZomatoOrderName(name);

  bool _isActiveZomatoTable(String name) {
    if (!_isZomatoTable(name)) return false;
    return !ZomatoOrderUtils.isCompletedStatus(tableZomatoStatuses[name]);
  }

  String _dashboardCountLabel() {
    switch (selectedTab) {
      case 'Take Away':
      case 'Zomato':
        return 'orders';
      default:
        return 'tables';
    }
  }

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
    final isZomato = _isZomatoTable(tableName);
    final screenshotUrl = tableScreenshotUrls[tableName] ?? '';
    final zomatoStatus = tableZomatoStatuses[tableName] ?? 'Pending';
    final isTakeAway = _isTakeAway(tableName);
    final displayName = _shortDisplayName(tableName);
    final isMobileLayout = MediaQuery.sizeOf(context).width <= 600;
    // Header colour: green=has items, orange=empty dine-in, blue=empty takeaway
    final headerColor = isZomato
        ? const Color(0xFFE53935)
        : paid
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
      onTap: isZomato && screenshotUrl.isNotEmpty
          ? () => ZomatoScreenshotViewer.show(
                context,
                imageUrl: screenshotUrl,
                title: tableName,
              )
          : () async {
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
                onMenuCacheUpdated: _reloadMenuFromCache,
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
          await _reloadMenuFromCache();
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
                    if (isZomato) {
                      try {
                        await ZomatoOrderProgressDialog.run(
                          context,
                          action: () => Get.find<ZomatoOrdersRepository>()
                              .removeOrder(docId: docId),
                        );
                        if (mounted) setState(() {});
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not mark as served: $e'),
                            ),
                          );
                        }
                      }
                    } else if (isTakeAway) {
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
                      onMenuCacheUpdated: _reloadMenuFromCache,
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
                await _reloadMenuFromCache();
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
                    // Table icon (tablet/desktop only — saves space on mobile)
                    if (!isTakeAway && !isMobileLayout)
                      Icon(
                        Icons.table_restaurant_outlined,
                        color: Colors.white70,
                        size: 17,
                      ),
                    if (!isTakeAway && !isMobileLayout) const SizedBox(width: 6),
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
                              onMenuCacheUpdated: _reloadMenuFromCache,
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
                        await _reloadMenuFromCache();
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
            if (isZomato && screenshotUrl.isNotEmpty)
              ZomatoOrderCardBody(
                docId: docId,
                screenshotUrl: screenshotUrl,
                status: zomatoStatus,
                onStatusChanged: (value) {
                  if (ZomatoOrderUtils.isCompletedStatus(value)) {
                    setState(() {
                      tableZomatoStatuses.remove(tableName);
                      tableScreenshotUrls.remove(tableName);
                      tableSources.remove(tableName);
                    });
                    return;
                  }
                  setState(() => tableZomatoStatuses[tableName] = value);
                },
              )
            else if (!hasItems)
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
                        ...List.generate(groups.length, (gi) {
                          final group = groups[gi];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...group.asMap().entries.map((entry) {
                                final firestoreGi = TableItemServed
                                    .firestoreGroupIndexFor(
                                  entry.value,
                                  _firestoreGroupIndexFor(tableName, gi),
                                );
                                final itemIndex = TableItemServed
                                    .itemIndexInGroupFor(entry.value, entry.key);
                                final key = TableItemKey(
                                  docId: docId,
                                  groupIndex: firestoreGi,
                                  itemIndexInGroup: itemIndex,
                                );
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: OrderItemRow(
                                    item: entry.value,
                                    docId: docId,
                                    groupIndex: firestoreGi,
                                    itemIndexInGroup: itemIndex,
                                    selectionController: _itemSelection,
                                    selectionMode: selectionMode,
                                    isSelected: _itemSelection.isSelected(key),
                                    style: OrderItemRowStyle.dashboard,
                                  ),
                                );
                              }),
                              if (_groupTimeLabel(group) != null)
                                _GroupTimeAgoLabel(group: group),
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
                              true,
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

  // Filter the tables based on current selectedTab and table selection filter.
  List<String> _tabFilteredTableKeys() {
    if (selectedTab == 'Zomato') {
      final keys = tables.keys.where(_isActiveZomatoTable).toList()
        ..sort(_compareByCreatedAt);
      return keys;
    }

    if (selectedTab == 'Take Away') {
      final keys = tables.keys
          .where((key) => _isTakeAway(key) && !_isZomatoTable(key))
          .toList()
        ..sort(_compareByCreatedAt);
      return keys;
    }

    if (selectedTab == 'Tables') {
      final keys = tables.keys.where((key) => key.startsWith('Table ')).toList()
        ..sort(_compareTableNumber);
      return keys;
    }

    return _allTableKeysSorted();
  }

  List<String> _filteredTableKeys() {
    var keys = _tabFilteredTableKeys();
    if (_tableFilterSelection.isNotEmpty) {
      keys = keys.where((key) => _tableFilterSelection.contains(key)).toList();
    }
    return keys;
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

class _GroupTimeAgoLabel extends StatefulWidget {
  const _GroupTimeAgoLabel({required this.group});

  final List<Map<String, dynamic>> group;

  @override
  State<_GroupTimeAgoLabel> createState() => _GroupTimeAgoLabelState();
}

class _GroupTimeAgoLabelState extends State<_GroupTimeAgoLabel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    if (widget.group.isEmpty) return const SizedBox.shrink();
    final addedAt = _parseAddedAt(widget.group.first['addedAt']);
    if (addedAt == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 0, bottom: 1),
        child: Text(
          _formatTimeAgo(addedAt),
          style: TextStyle(
            fontSize: 11,
            fontFamily: fontMulishRegular,
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
