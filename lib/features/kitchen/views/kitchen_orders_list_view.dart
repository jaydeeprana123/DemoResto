import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/Styles/my_icons.dart';
import 'package:demo/features/kitchen/services/kitchen_settings.dart';
import 'package:demo/features/ordering/ordering.dart';
import 'package:demo/features/tables/repositories/table_item_served.dart';
import 'package:demo/features/tables/repositories/tables_repository.dart';
import 'package:demo/features/tables/widgets/order_item_row.dart';
import 'package:demo/models/GroupOrder.dart';

class KitchenOrdersListView extends StatefulWidget {
  /// When false (e.g. another bottom-nav tab is selected), order bells stay silent.
  final bool isTabActive;

  const KitchenOrdersListView({super.key, this.isTabActive = true});

  @override
  State<KitchenOrdersListView> createState() => _KitchenOrdersListViewState();
}

class _KitchenOrdersListViewState extends State<KitchenOrdersListView> {
  final AudioPlayer audioPlayer = AudioPlayer();
  // Separate player for the update tone so its faster double-ring pattern
  // doesn't clash with the single new-order ring.
  final AudioPlayer updateAudioPlayer = AudioPlayer();
  // Distinct tone when an order/table disappears from the kitchen list.
  final AudioPlayer deleteAudioPlayer = AudioPlayer();
  DateTime? _lastDeleteSoundAt;
  Set<String> previousKeys = {};
  // Snapshot of each group's content (name + qty + remarks) so we can detect
  // quantity changes / newly added items even when the group key stays the same.
  Map<String, String> _previousSignatures = {};
  // Doc ids that already existed last build, used to tell a brand-new table
  // apart from an update to an already-available table.
  Set<String> _previousDocIds = {};
  Map<String, TableGroup> _previousKeyToGroup = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tablesSub;
  final ValueNotifier<int> _minuteTick = ValueNotifier(0);
  bool _kitchenStreamReady = false;
  /// True when the kitchen list was last shown empty (no orders to display).
  bool _wasKitchenEmpty = false;
  List<TableGroup> _lastUpdatedGroups = [];
  List<TableGroup> _displayFilteredGroups = [];
  List<KitchenTableCard> _displayTableCards = [];
  int? blinkingGroupKey;
  // Color used for the currently blinking card: green for a new order,
  // yellow for an update (quantity changed / item added on existing table).
  Color _blinkColor = Colors.lightGreenAccent.shade100;
  Timer? _timer;
  final TableItemSelectionController _itemSelection =
      TableItemSelectionController();

  static final Color _newOrderBlinkColor = Colors.lightGreenAccent.shade100;
  static final Color _updateBlinkColor = Colors.yellow.shade300;

  bool get _canRingBell => widget.isTabActive;

  String _groupSignature(TableGroup group) {
    final parts =
        group.items
            .map(
              (it) =>
                  '${it['name']}~${it['qty'] ?? 1}~${it['remarks']?.toString() ?? ''}~${it['isServed'] == true}',
            )
            .toList()
          ..sort();
    return parts.join('|');
  }

  void _scheduleBlink({
    required String key,
    required Map<String, TableGroup> keyToGroup,
    required Set<String> currentKeys,
    required Map<String, String> currentSignatures,
    required Set<String> currentDocIds,
    required bool isUpdate,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final group = keyToGroup[key];
      final shouldPlaySound = group != null
          ? _shouldPlaySoundForGroup(group)
          : true;

      setState(() {
        previousKeys = currentKeys;
        _previousSignatures = currentSignatures;
        _previousDocIds = currentDocIds;
        _previousKeyToGroup = keyToGroup;
        blinkingGroupKey = key.hashCode;
        _blinkColor = isUpdate ? _updateBlinkColor : _newOrderBlinkColor;
      });

      if (shouldPlaySound && _canRingBell) {
        if (isUpdate) {
          _playUpdateSound();
        } else {
          _playNotificationSound();
        }
      }

      Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        if (blinkingGroupKey == key.hashCode) {
          setState(() => blinkingGroupKey = null);
        }
      });
    });
  }

  // Multiple category selection
  Set<String> selectedCategories = {};
  bool showAllCategories = true; // Track if "All" is selected
  bool _showTableAllOrders = false;
  /// 0 = active (unserved items), 1 = served items only
  int _kitchenOrderTabIndex = 0;

  void _onKitchenSettingsChanged() {
    if (!mounted) return;
    setState(() {
      _showTableAllOrders = KitchenSettings.showTableAllOrders.value == true;
      _rebuildDisplayFromCache();
    });
  }

  void _playNotificationSound() async {
    if (!_canRingBell) return;
    try {
      await audioPlayer.play(AssetSource('sounds/phone_bell.mp3'));
    } catch (e) {
      // ignore audio errors
    }
  }

  Future<bool> _hasDeleteBellAsset() async {
    try {
      await rootBundle.load('assets/sounds/delete_bell.mp3');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Distinct from new-order (phone_bell) and update (update_bell) rings.
  void _playDeleteSound() async {
    if (!_canRingBell) return;
    final now = DateTime.now();
    if (_lastDeleteSoundAt != null &&
        now.difference(_lastDeleteSoundAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastDeleteSoundAt = now;

    try {
      await deleteAudioPlayer.stop();
      await deleteAudioPlayer.setReleaseMode(ReleaseMode.stop);

      if (await _hasDeleteBellAsset()) {
        await deleteAudioPlayer.setPlaybackRate(1.0);
        await deleteAudioPlayer.play(AssetSource('sounds/delete_bell.mp3'));
      } else {
        // Slower update bell — clearly different tone without a separate file.
        await deleteAudioPlayer.setPlaybackRate(0.52);
        await deleteAudioPlayer.play(AssetSource('sounds/update_bell.mp3'));
        await deleteAudioPlayer.setPlaybackRate(1.0);
      }
    } catch (e) {
      // ignore audio errors
    }
  }

  bool _shouldPlaySoundForRemoval(
    Set<String> removedKeys,
    Set<String> removedDocIds,
  ) {
    if (showAllCategories || selectedCategories.isEmpty) {
      return removedKeys.isNotEmpty || removedDocIds.isNotEmpty;
    }

    for (final key in removedKeys) {
      final group = _previousKeyToGroup[key];
      if (group != null && _shouldPlaySoundForGroup(group)) return true;
    }

    for (final group in _previousKeyToGroup.values) {
      if (removedDocIds.contains(group.docId) &&
          _shouldPlaySoundForGroup(group)) {
        return true;
      }
    }

    return false;
  }

  void _notifyOrderRemoved({
    required Set<String> removedKeys,
    required Set<String> removedDocIds,
    required Set<String> currentKeys,
    required Map<String, String> currentSignatures,
    required Set<String> currentDocIds,
    required Map<String, TableGroup> keyToGroup,
  }) {
    final shouldPlay = _shouldPlaySoundForRemoval(removedKeys, removedDocIds);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        previousKeys = currentKeys;
        _previousSignatures = currentSignatures;
        _previousDocIds = currentDocIds;
        _previousKeyToGroup = keyToGroup;
      });
      if (shouldPlay && _canRingBell) _playDeleteSound();
    });
  }

  Future<void> _stopAllKitchenSounds() async {
    try {
      await audioPlayer.stop();
      await updateAudioPlayer.stop();
      await deleteAudioPlayer.stop();
    } catch (_) {
      // ignore audio errors
    }
  }

  // Distinct tone for order updates (quantity changed / item added on an
  // already-available table) so kitchen staff can tell it apart from a
  // brand-new order's ring.
  void _playUpdateSound() async {
    if (!_canRingBell) return;
    try {
      await updateAudioPlayer.stop();
      await updateAudioPlayer.play(AssetSource('sounds/update_bell.mp3'));
    } catch (e) {
      // ignore audio errors
    }
  }

  List<TableGroup> _reconstructGroups(
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

        // remove internal metadata so UI shows only item fields
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
          groupIndex: index,
        ),
      );
    });

    return groups;
  }

  @override
  void didUpdateWidget(KitchenOrdersListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isTabActive && !widget.isTabActive) {
      _stopAllKitchenSounds();
    }
  }

  @override
  void initState() {
    super.initState();
    KitchenSettings.load().then((_) {
      if (mounted) {
        setState(() {
          _showTableAllOrders =
              KitchenSettings.showTableAllOrders.value == true;
        });
      }
    });
    KitchenSettings.showTableAllOrders.addListener(_onKitchenSettingsChanged);
    _tablesSub = FirebaseFirestore.instance
        .collection('tables')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen(_handleTablesSnapshot);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _minuteTick.value++;
    });
  }

  void _rebuildDisplayFromCache() {
    final filtered = _applyKitchenDisplayFilters(_lastUpdatedGroups);
    _displayFilteredGroups = filtered;
    _displayTableCards = _mergeGroupsByTable(filtered);
  }

  List<TableGroup> _applyKitchenDisplayFilters(List<TableGroup> groups) {
    final byCategory = _filterByCategories(groups);
    return _filterByServedStatus(
      byCategory,
      servedOnly: _kitchenOrderTabIndex == 1,
    );
  }

  void _onKitchenOrderTabChanged(int index) {
    if (_kitchenOrderTabIndex == index) return;
    setState(() {
      _kitchenOrderTabIndex = index;
      _itemSelection.cancel();
      _rebuildDisplayFromCache();
    });
  }

  List<TableGroup> _filterByServedStatus(
    List<TableGroup> groups, {
    required bool servedOnly,
  }) {
    return groups
        .map((group) {
          final filteredItems = group.items.asMap().entries
              .where((entry) {
                final served = TableItemServed.isServed(entry.value);
                return servedOnly ? served : !served;
              })
              .map((entry) {
                final copy = Map<String, dynamic>.from(entry.value);
                copy['__itemIndex'] =
                    entry.value['__itemIndex'] as int? ?? entry.key;
                return copy;
              })
              .toList();

          if (filteredItems.isEmpty) return null;

          return TableGroup(
            group.tableName,
            filteredItems,
            group.groupTime,
            key: group.key,
            docId: group.docId,
            isPaid: group.isPaid,
            groupIndex: group.groupIndex,
          );
        })
        .whereType<TableGroup>()
        .toList();
  }

  bool _sameGroupList(List<TableGroup> a, List<TableGroup> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].key != b[i].key ||
          a[i].isPaid != b[i].isPaid ||
          _groupSignature(a[i]) != _groupSignature(b[i])) {
        return false;
      }
    }
    return true;
  }

  bool _sameTableCards(List<KitchenTableCard> a, List<KitchenTableCard> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].docId != b[i].docId || a[i].isPaid != b[i].isPaid) {
        return false;
      }
      if (a[i].batches.length != b[i].batches.length) return false;
      for (var j = 0; j < a[i].batches.length; j++) {
        if (a[i].batches[j].key != b[i].batches[j].key ||
            _groupSignature(a[i].batches[j]) !=
                _groupSignature(b[i].batches[j])) {
          return false;
        }
      }
    }
    return true;
  }

  void _handleTablesSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!mounted) return;

    if (snapshot.docs.isEmpty) {
      _wasKitchenEmpty = true;
      if (previousKeys.isNotEmpty || _previousSignatures.isNotEmpty) {
        previousKeys = {};
        _previousSignatures = {};
        _previousDocIds = {};
        _previousKeyToGroup = {};
      }
      if (_displayFilteredGroups.isNotEmpty ||
          _displayTableCards.isNotEmpty ||
          !_kitchenStreamReady) {
        setState(() {
          _lastUpdatedGroups = [];
          _displayFilteredGroups = [];
          _displayTableCards = [];
          _kitchenStreamReady = true;
        });
      }
      return;
    }

    final updatedGroups = <TableGroup>[];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final tableName = (data['name'] ?? 'Unknown Table') as String;
      final isPaid = data['isPaid'] == true;
      final itemsFromDb =
          data.containsKey('items') ? (data['items'] as List<dynamic>?) : null;
      updatedGroups.addAll(
        _reconstructGroups(
          tableName,
          itemsFromDb,
          isPaid: isPaid,
          docId: doc.id,
        ),
      );
    }

    updatedGroups.sort((a, b) => a.groupTime.compareTo(b.groupTime));
    _lastUpdatedGroups = updatedGroups;

    final filteredGroups = _applyKitchenDisplayFilters(updatedGroups);
    final tableCards = _mergeGroupsByTable(filteredGroups);

    if (filteredGroups.isEmpty) {
      _wasKitchenEmpty = true;
    }

    final currentKeys = updatedGroups.map((g) => g.key).toSet();
    final currentSignatures = <String, String>{};
    final currentDocIds = <String>{};
    final keyToGroup = <String, TableGroup>{};
    for (final g in updatedGroups) {
      currentSignatures[g.key] = _groupSignature(g);
      currentDocIds.add(g.docId);
      keyToGroup[g.key] = g;
    }

    if (_previousSignatures.isEmpty && currentKeys.isNotEmpty) {
      if (_wasKitchenEmpty) {
        final newTableKeys = currentKeys
            .where((k) => !_previousDocIds.contains(keyToGroup[k]?.docId))
            .toList();
        final keyToBlink = newTableKeys.isNotEmpty
            ? newTableKeys.last
            : currentKeys.last;
        _scheduleBlink(
          key: keyToBlink,
          keyToGroup: keyToGroup,
          currentKeys: currentKeys,
          currentSignatures: currentSignatures,
          currentDocIds: currentDocIds,
          isUpdate: false,
        );
        _wasKitchenEmpty = false;
      } else {
        previousKeys = currentKeys;
        _previousSignatures = currentSignatures;
        _previousDocIds = currentDocIds;
        _previousKeyToGroup = keyToGroup;
      }
    } else if (_previousSignatures.isNotEmpty) {
      final addedKeys = currentKeys.difference(previousKeys);
      final removedKeys = previousKeys.difference(currentKeys);
      final removedDocIds = _previousDocIds.difference(currentDocIds);

      final changedKeys = currentKeys
          .where(
            (k) =>
                previousKeys.contains(k) &&
                _previousSignatures[k] != currentSignatures[k],
          )
          .toList();

      final newTableKeys = addedKeys
          .where((k) => !_previousDocIds.contains(keyToGroup[k]?.docId))
          .toList();

      final updateKeys = <String>[
        ...addedKeys.where(
          (k) => _previousDocIds.contains(keyToGroup[k]?.docId),
        ),
        ...changedKeys,
      ];

      if (newTableKeys.isNotEmpty) {
        _scheduleBlink(
          key: newTableKeys.last,
          keyToGroup: keyToGroup,
          currentKeys: currentKeys,
          currentSignatures: currentSignatures,
          currentDocIds: currentDocIds,
          isUpdate: false,
        );
      } else if (updateKeys.isNotEmpty) {
        _scheduleBlink(
          key: updateKeys.last,
          keyToGroup: keyToGroup,
          currentKeys: currentKeys,
          currentSignatures: currentSignatures,
          currentDocIds: currentDocIds,
          isUpdate: true,
        );
      } else if (removedKeys.isNotEmpty || removedDocIds.isNotEmpty) {
        _notifyOrderRemoved(
          removedKeys: removedKeys,
          removedDocIds: removedDocIds,
          currentKeys: currentKeys,
          currentSignatures: currentSignatures,
          currentDocIds: currentDocIds,
          keyToGroup: keyToGroup,
        );
      }
    }

    final displayChanged = _showTableAllOrders
        ? !_sameTableCards(_displayTableCards, tableCards)
        : !_sameGroupList(_displayFilteredGroups, filteredGroups);

    if (displayChanged || !_kitchenStreamReady) {
      setState(() {
        _displayFilteredGroups = filteredGroups;
        _displayTableCards = tableCards;
        _kitchenStreamReady = true;
      });
    }

    if (filteredGroups.isNotEmpty) {
      _wasKitchenEmpty = false;
    }
  }

  Widget _buildKitchenEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            !showAllCategories && selectedCategories.isNotEmpty
                ? Icons.filter_list_off
                : Icons.inbox_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _kitchenOrderTabIndex == 1
                ? (!showAllCategories && selectedCategories.isNotEmpty
                    ? "No served orders in selected categories"
                    : "No served orders")
                : (!showAllCategories && selectedCategories.isNotEmpty
                    ? "No orders in selected categories"
                    : "No orders found"),
            style: const TextStyle(
              fontFamily: fontMulishSemiBold,
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          if (!showAllCategories && selectedCategories.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Selected: ${selectedCategories.join(', ')}",
              style: const TextStyle(
                fontFamily: fontMulishRegular,
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKitchenOrdersGrid() {
    final screenW = MediaQuery.of(context).size.width;
    final crossCols = screenW > 1200
        ? 5
        : screenW > 900
        ? 4
        : screenW > 600
        ? 3
        : screenW > 400
        ? 2
        : 1;

    if (_showTableAllOrders) {
      final firstUnpaidIndex =
          _displayTableCards.indexWhere((c) => !c.isPaid);
      return MasonryGridView.count(
        key: const ValueKey('kitchen_table_grid'),
        crossAxisCount: crossCols,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        padding: const EdgeInsets.all(12),
        itemCount: _displayTableCards.length,
        itemBuilder: (context, index) => _buildTableBatchCard(
          _displayTableCards[index],
          index + 1,
          isNext: index == firstUnpaidIndex && firstUnpaidIndex != -1,
        ),
      );
    }

    final firstUnpaidIndex =
        _displayFilteredGroups.indexWhere((g) => !g.isPaid);
    return MasonryGridView.count(
      key: const ValueKey('kitchen_group_grid'),
      crossAxisCount: crossCols,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      padding: const EdgeInsets.all(12),
      itemCount: _displayFilteredGroups.length,
      itemBuilder: (context, index) => _buildGroupCard(
        _displayFilteredGroups[index],
        index + 1,
        isNext: index == firstUnpaidIndex && firstUnpaidIndex != -1,
      ),
    );
  }

  Widget _orderCardShell({
    required bool isBlinking,
    required BoxDecoration decoration,
    required Widget child,
    Duration animationDuration = const Duration(milliseconds: 400),
  }) {
    if (isBlinking) {
      return AnimatedContainer(
        duration: animationDuration,
        curve: Curves.easeInOut,
        decoration: decoration,
        child: child,
      );
    }
    return Container(decoration: decoration, child: child);
  }

  List<KitchenTableCard> _mergeGroupsByTable(List<TableGroup> groups) {
    final Map<String, KitchenTableCard> map = {};

    for (final group in groups) {
      if (!map.containsKey(group.docId)) {
        map[group.docId] = KitchenTableCard(
          tableName: group.tableName,
          docId: group.docId,
          isPaid: group.isPaid,
          batches: [group],
        );
      } else {
        map[group.docId]!.batches.add(group);
        if (group.isPaid) map[group.docId]!.isPaid = true;
      }
    }

    for (final card in map.values) {
      card.batches.sort((a, b) => a.groupTime.compareTo(b.groupTime));
    }

    final cards = map.values.toList()
      ..sort(
        (a, b) =>
            a.batches.first.groupTime.compareTo(b.batches.first.groupTime),
      );
    return cards;
  }

  // Filter groups by selected categories
  List<TableGroup> _filterByCategories(List<TableGroup> groups) {
    // If "All" is selected or no categories selected, show everything
    if (showAllCategories || selectedCategories.isEmpty) {
      return groups;
    }

    return groups
        .map((group) {
          // Filter items in this group by selected categories
          final filteredItems = group.items.asMap().entries
              .where((entry) {
                final itemCategory =
                    entry.value['category']?.toString() ?? '';
                return selectedCategories.contains(itemCategory);
              })
              .map((entry) {
                final copy = Map<String, dynamic>.from(entry.value);
                copy['__itemIndex'] = entry.key;
                return copy;
              })
              .toList();

          // If no items match, return null (will be filtered out)
          if (filteredItems.isEmpty) return null;

          // Return new group with filtered items
          return TableGroup(
            group.tableName,
            filteredItems,
            group.groupTime,
            key: group.key,
            docId: group.docId,
            isPaid: group.isPaid,
            groupIndex: group.groupIndex,
          );
        })
        .whereType<TableGroup>()
        .toList(); // Remove nulls
  }

  // Check if the group contains items from selected categories
  bool _shouldPlaySoundForGroup(TableGroup group) {
    // If "All" is selected, always play sound
    if (showAllCategories || selectedCategories.isEmpty) {
      return true;
    }

    // Check if any item in the group matches selected categories
    for (var item in group.items) {
      final itemCategory = item['category']?.toString() ?? '';
      if (selectedCategories.contains(itemCategory)) {
        return true;
      }
    }

    return false;
  }

  void _showCategoryFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('menus')
              .orderBy('createdAt', descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: Center(child: CircularProgressIndicator()),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  "Filter by Category",
                  style: TextStyle(
                    fontFamily: fontMulishSemiBold,
                    fontSize: 18,
                  ),
                ),
                content: const Text("No categories found"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"),
                  ),
                ],
              );
            }

            final categories = snapshot.data!.docs;

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text(
                    "Filter by Category",
                    style: TextStyle(
                      fontFamily: fontMulishSemiBold,
                      fontSize: 18,
                    ),
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // "All" checkbox
                        CheckboxListTile(
                          title: const Text(
                            "All Categories",
                            style: TextStyle(
                              fontFamily: fontMulishSemiBold,
                              fontSize: 15,
                            ),
                          ),
                          value: showAllCategories,
                          activeColor: Colors.green,
                          onChanged: (bool? value) {
                            setDialogState(() {
                              showAllCategories = value ?? true;
                              if (showAllCategories) {
                                selectedCategories.clear();
                              }
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                        const Divider(),
                        // Individual category checkboxes
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              final categoryName = category['name'] as String;
                              final isSelected = selectedCategories.contains(
                                categoryName,
                              );

                              return CheckboxListTile(
                                title: Text(
                                  categoryName,
                                  style: const TextStyle(
                                    fontFamily: fontMulishRegular,
                                    fontSize: 14,
                                  ),
                                ),
                                value: isSelected,
                                activeColor: Colors.green,
                                enabled: !showAllCategories,
                                onChanged: showAllCategories
                                    ? null
                                    : (bool? value) {
                                        setDialogState(() {
                                          if (value == true) {
                                            selectedCategories.add(
                                              categoryName,
                                            );
                                          } else {
                                            selectedCategories.remove(
                                              categoryName,
                                            );
                                          }
                                        });
                                      },
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        setDialogState(() {
                          selectedCategories.clear();
                          showAllCategories = true;
                        });
                      },
                      child: const Text(
                        "Clear",
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
                        setState(_rebuildDisplayFromCache);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Apply",
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
          },
        );
      },
    );
  }

  Widget _buildKitchenOrderTabs() {
    const navy = Color(0xFF1A3A5C);
    const orange = Color(0xFFf57c35);

    Widget tabButton(String label, int index) {
      final selected = _kitchenOrderTabIndex == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => _onKitchenOrderTabChanged(index),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? orange : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: selected ? fontMulishBold : fontMulishSemiBold,
                fontSize: 14,
                color: selected ? Colors.white : Colors.white70,
              ),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: navy,
      child: Row(
        children: [
          tabButton('All Orders', 0),
          tabButton('Served Orders', 1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Kitchen",
          style: TextStyle(fontFamily: fontMulishSemiBold, fontSize: 16),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _buildKitchenOrderTabs(),
        ),
        actions: [
          // Filter button with badge showing count
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () => _showCategoryFilterDialog(context),
                tooltip: "Filter by Category",
              ),
              if (!showAllCategories && selectedCategories.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        '${selectedCategories.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontFamily: fontMulishBold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: !_kitchenStreamReady
          ? const Center(child: CircularProgressIndicator())
          : (_showTableAllOrders
                ? _displayTableCards.isEmpty
                : _displayFilteredGroups.isEmpty)
              ? _buildKitchenEmptyState()
              : _buildKitchenOrdersGrid(),
    );
  }

  Widget _buildGroupCard(
    TableGroup group,
    int queueNumber, {
    bool isNext = false,
  }) {
    final time = DateTime.fromMillisecondsSinceEpoch(group.groupTime);
    final isBlinking = blinkingGroupKey == group.key.hashCode;
    final isOld = DateTime.now().difference(time).inMinutes > 5;

    if (group.tableName.contains("Take Away") && isOld && group.isPaid) {
      deleteTable(group.docId);
    }

    return KeyedSubtree(
      key: ValueKey(group.key),
      child: ListenableBuilder(
        listenable: _minuteTick,
        builder: (context, _) {
          final tickTime = DateTime.fromMillisecondsSinceEpoch(group.groupTime);
          final tickIsOld = DateTime.now().difference(tickTime).inMinutes > 5;
          return _orderCardShell(
            isBlinking: isBlinking,
            animationDuration: const Duration(milliseconds: 800),
            decoration: _orderCardDecoration(isBlinking, tickIsOld, isNext),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOrderHeader(
                  group.tableName,
                  group.isPaid,
                  queueNumber,
                  isNext: isNext,
                  onPaidTap: group.isPaid
                      ? () => _markTableServed(group.tableName, group.docId)
                      : null,
                ),
                _buildTimeBar(tickTime, tickIsOld),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ListenableBuilder(
                    listenable: _itemSelection.listenableFor(group.docId),
                    builder: (context, _) {
                      final selectionMode =
                          _itemSelection.isSelectionModeFor(group.docId);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...group.items.asMap().entries.map(
                            (entry) => _buildItemRow(
                              entry.value,
                              docId: group.docId,
                              groupIndex: group.groupIndex,
                              itemIndexInGroup:
                                  (entry.value['__itemIndex'] as int?) ??
                                  entry.key,
                              selectionMode: selectionMode,
                            ),
                          ),
                          TableItemSelectionActionBar(
                            docId: group.docId,
                            controller: _itemSelection,
                            action: _kitchenOrderTabIndex == 1
                                ? TableItemSelectionAction.markPending
                                : TableItemSelectionAction.serve,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableBatchCard(
    KitchenTableCard tableCard,
    int queueNumber, {
    bool isNext = false,
  }) {
    final isBlinking = tableCard.batches.any(
      (g) => blinkingGroupKey == g.key.hashCode,
    );

    for (final batch in tableCard.batches) {
      final time = DateTime.fromMillisecondsSinceEpoch(batch.groupTime);
      final isOld = DateTime.now().difference(time).inMinutes > 5;
      if (tableCard.tableName.contains("Take Away") &&
          isOld &&
          tableCard.isPaid) {
        deleteTable(tableCard.docId);
        break;
      }
    }

    return KeyedSubtree(
      key: ValueKey(tableCard.docId),
      child: ListenableBuilder(
        listenable: _minuteTick,
        builder: (context, _) {
          final tickIsOld = tableCard.batches.any((batch) {
            final batchTime =
                DateTime.fromMillisecondsSinceEpoch(batch.groupTime);
            return DateTime.now().difference(batchTime).inMinutes > 5;
          });
          return _orderCardShell(
            isBlinking: isBlinking,
            decoration: _orderCardDecoration(isBlinking, tickIsOld, isNext),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOrderHeader(
                  tableCard.tableName,
                  tableCard.isPaid,
                  queueNumber,
                  isNext: isNext,
                  onPaidTap: tableCard.isPaid
                      ? () => _markTableServed(
                          tableCard.tableName,
                          tableCard.docId,
                        )
                      : null,
                  useDoubleTapForPaid: true,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 6, 12),
                  child: ListenableBuilder(
                    listenable: _itemSelection.listenableFor(tableCard.docId),
                    builder: (context, _) {
                      final selectionMode =
                          _itemSelection.isSelectionModeFor(tableCard.docId);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < tableCard.batches.length; i++) ...[
                            if (i > 0) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: DottedLine(
                                  dashColor: Colors.grey.shade300,
                                  lineThickness: 1,
                                  dashLength: 4,
                                  dashGapLength: 4,
                                ),
                              ),
                            ],
                            Align(
                              alignment: Alignment.centerRight,
                              child: _KitchenRelativeTime(
                                time: DateTime.fromMillisecondsSinceEpoch(
                                  tableCard.batches[i].groupTime,
                                ),
                                tick: _minuteTick,
                                formatter: formatRelativeTime,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: fontMulishRegular,
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...tableCard.batches[i].items.asMap().entries.map(
                              (entry) => _buildItemRow(
                                entry.value,
                                docId: tableCard.docId,
                                groupIndex: tableCard.batches[i].groupIndex,
                                itemIndexInGroup:
                                    (entry.value['__itemIndex'] as int?) ??
                                    entry.key,
                                selectionMode: selectionMode,
                              ),
                            ),
                          ],
                          TableItemSelectionActionBar(
                            docId: tableCard.docId,
                            controller: _itemSelection,
                            action: _kitchenOrderTabIndex == 1
                                ? TableItemSelectionAction.markPending
                                : TableItemSelectionAction.serve,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _markTableServed(String tableName, String docId) {
    if (selectedCategories.isNotEmpty) return;
    showServedDialog(context, tableName, () async {
      _playDeleteSound();
      if (tableName.contains("Take Away")) {
        await FirebaseFirestore.instance.collection('tables').doc(docId).delete();
      } else {
        await _updateTableItemsInFirestore(tableName, [], false);
      }
    });
  }

  BoxDecoration _orderCardDecoration(bool isBlinking, bool isOld, bool isNext) {
    return BoxDecoration(
      color: isBlinking ? _blinkColor : Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: isNext
              ? Colors.green.withValues(alpha: 0.35)
              : isOld
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.05),
          blurRadius: isNext ? 12 : 8,
          offset: const Offset(0, 4),
        ),
      ],
      border: isNext
          ? Border.all(color: Colors.green, width: 2.5)
          : isOld
          ? Border.all(color: Colors.red, width: 2)
          : Border.all(color: Colors.grey.shade200),
    );
  }

  Widget _buildOrderHeader(
    String tableName,
    bool isPaid,
    int queueNumber, {
    bool isNext = false,
    VoidCallback? onPaidTap,
    bool useDoubleTapForPaid = false,
  }) {
    final paid = isPaid == true;
    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1A3A5C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                SvgPicture.asset(
                  tableName.contains("Take Away") ? icon_packing : icon_table,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                  width: tableName.contains("Take Away") ? 18 : 22,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    tableName,
                    style: TextStyle(
                      fontFamily: tableName.contains("Take Away")
                          ? fontMulishBold
                          : fontMulishSemiBold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          Container(
            margin: const EdgeInsets.only(right: 0),
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isNext ? Colors.green : const Color(0xFFf57c35),
              borderRadius: BorderRadius.circular(36),
            ),
            child: Text(
              '$queueNumber',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontFamily: fontMulishBold,
              ),
            ),
          ),

          if (isNext)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                "NEXT",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontFamily: fontMulishBold,
                ),
              ),
            ),
          if (paid)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                "PAID",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontFamily: fontMulishBold,
                ),
              ),
            ),
        ],
      ),
    );

    if (onPaidTap == null) return header;

    return GestureDetector(
      onTap: useDoubleTapForPaid ? null : onPaidTap,
      onDoubleTap: useDoubleTapForPaid ? onPaidTap : null,
      behavior: HitTestBehavior.opaque,
      child: header,
    );
  }

  Widget _buildTimeBar(DateTime time, bool isOld) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: isOld ? Colors.red.shade50 : const Color(0xFFF5F6FA),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            size: 14,
            color: isOld ? Colors.red : Colors.grey.shade700,
          ),
          const SizedBox(width: 6),
          _KitchenRelativeTime(
            time: time,
            tick: _minuteTick,
            formatter: formatRelativeTime,
            style: TextStyle(
              fontFamily: fontMulishSemiBold,
              fontSize: 13,
              color: isOld ? Colors.red : Colors.grey.shade800,
            ),
          ),
          if (isOld) ...[
            const Spacer(),
            const Text(
              "DELAYED",
              style: TextStyle(
                color: Colors.red,
                fontSize: 10,
                fontFamily: fontMulishBold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemRow(
    Map<String, dynamic> item, {
    required String docId,
    required int groupIndex,
    required int itemIndexInGroup,
    required bool selectionMode,
  }) {
    final key = TableItemKey(
      docId: docId,
      groupIndex: groupIndex,
      itemIndexInGroup: itemIndexInGroup,
    );
    return OrderItemRow(
      item: item,
      docId: docId,
      groupIndex: groupIndex,
      itemIndexInGroup: itemIndexInGroup,
      selectionController: _itemSelection,
      selectionMode: selectionMode,
      isSelected: _itemSelection.isSelected(key),
      style: OrderItemRowStyle.kitchen,
      selectionForServedItems: _kitchenOrderTabIndex == 1,
    );
  }

  String formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return "just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes} min${difference.inMinutes > 1 ? "s" : ""} ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours} hr${difference.inHours > 1 ? "s" : ""} ago";
    } else if (difference.inDays == 1) {
      return "yesterday";
    } else if (difference.inDays < 7) {
      return "${difference.inDays} day${difference.inDays > 1 ? "s" : ""} ago";
    } else {
      return DateFormat('dd MMM yyyy, hh:mm a').format(time);
    }
  }

  @override
  void dispose() {
    KitchenSettings.showTableAllOrders.removeListener(
      _onKitchenSettingsChanged,
    );
    _tablesSub?.cancel();
    _timer?.cancel();
    _minuteTick.dispose();
    audioPlayer.dispose();
    updateAudioPlayer.dispose();
    deleteAudioPlayer.dispose();
    super.dispose();
  }

  void deleteTable(String docId) async {
    await FirebaseFirestore.instance.collection('tables').doc(docId).delete();
  }

  void showServedDialog(
    BuildContext context,
    String tableName,
    VoidCallback onServed,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
              onPressed: () => Navigator.pop(context),
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
                Navigator.pop(context);
                onServed();
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

  Future<void> _updateTableItemsInFirestore(
    String tableName,
    List<List<Map<String, dynamic>>> groups,
    bool isBillPaid,
  ) async {
    try {
      await Get.find<TablesRepository>().updateTableItems(
        tableName: tableName,
        groups: groups,
        isBillPaid: isBillPaid,
      );
    } catch (e) {
      print("ERROR: Failed to update Firestore: $e");
      if (e is FirebaseException) {
        print("Firebase error code: ${e.code}");
        print("Firebase error message: ${e.message}");
      }
    }
  }
}

class TableGroup {
  final String tableName;
  final List<Map<String, dynamic>> items;
  final int groupTime;
  final String key;
  final String docId;
  final bool isPaid;
  final int groupIndex;

  TableGroup(
    this.tableName,
    this.items,
    this.groupTime, {
    required this.key,
    required this.docId,
    required this.isPaid,
    required this.groupIndex,
  });
}

class KitchenTableCard {
  final String tableName;
  final String docId;
  bool isPaid;
  final List<TableGroup> batches;

  KitchenTableCard({
    required this.tableName,
    required this.docId,
    required this.isPaid,
    required this.batches,
  });
}

/// Rebuilds only this label on the minute tick — avoids refreshing the whole grid.
class _KitchenRelativeTime extends StatelessWidget {
  final DateTime time;
  final ValueListenable<int> tick;
  final String Function(DateTime) formatter;
  final TextStyle style;

  const _KitchenRelativeTime({
    required this.time,
    required this.tick,
    required this.formatter,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: tick,
      builder: (context, _, __) => Text(formatter(time), style: style),
    );
  }
}
