import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_icons.dart';
import 'package:demo/services/kitchen_settings.dart';
import 'Styles/my_font.dart';
import 'models/GroupOrder.dart';
import 'MenuPage.dart';

class KitchenOrdersListView extends StatefulWidget {
  const KitchenOrdersListView({super.key});

  @override
  State<KitchenOrdersListView> createState() => _KitchenOrdersListViewState();
}

class _KitchenOrdersListViewState extends State<KitchenOrdersListView> {
  final AudioPlayer audioPlayer = AudioPlayer();
  // Separate player for the update tone so its faster double-ring pattern
  // doesn't clash with the single new-order ring.
  final AudioPlayer updateAudioPlayer = AudioPlayer();
  Set<String> previousKeys = {};
  // Snapshot of each group's content (name + qty + remarks) so we can detect
  // quantity changes / newly added items even when the group key stays the same.
  Map<String, String> _previousSignatures = {};
  // Doc ids that already existed last build, used to tell a brand-new table
  // apart from an update to an already-available table.
  Set<String> _previousDocIds = {};
  int? blinkingGroupKey;
  // Color used for the currently blinking card: green for a new order,
  // yellow for an update (quantity changed / item added on existing table).
  Color _blinkColor = Colors.lightGreenAccent.shade100;
  Timer? _timer;

  static final Color _newOrderBlinkColor = Colors.lightGreenAccent.shade100;
  static final Color _updateBlinkColor = Colors.yellow.shade300;

  String _groupSignature(TableGroup group) {
    final parts =
        group.items
            .map(
              (it) =>
                  '${it['name']}~${it['qty'] ?? 1}~${it['remarks']?.toString() ?? ''}',
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
        blinkingGroupKey = key.hashCode;
        _blinkColor = isUpdate ? _updateBlinkColor : _newOrderBlinkColor;
      });

      if (shouldPlaySound) {
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

  void _onKitchenSettingsChanged() {
    if (!mounted) return;
    setState(() {
      _showTableAllOrders = KitchenSettings.showTableAllOrders.value == true;
    });
  }

  void _playNotificationSound() async {
    try {
      await audioPlayer.play(AssetSource('sounds/phone_bell.mp3'));
    } catch (e) {
      // ignore audio errors
    }
  }

  void _playDeleteSound() async {
    try {
      // Re-using phone_bell.mp3 or a different one if available.
      await audioPlayer.play(AssetSource('sounds/phone_bell.mp3'));
    } catch (e) {
      // ignore audio errors
    }
  }

  // Distinct tone for order updates (quantity changed / item added on an
  // already-available table) so kitchen staff can tell it apart from a
  // brand-new order's ring.
  void _playUpdateSound() async {
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
        ),
      );
    });

    return groups;
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
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
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
          final filteredItems = group.items.where((item) {
            final itemCategory = item['category']?.toString() ?? '';
            return selectedCategories.contains(itemCategory);
          }).toList();

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
                        setState(() {
                          // Update the main state
                        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "All Orders",
          style: TextStyle(fontFamily: fontMulishSemiBold, fontSize: 16),
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('tables')
            .orderBy('createdAt', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            if (previousKeys.isNotEmpty || _previousSignatures.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    previousKeys = {};
                    _previousSignatures = {};
                    _previousDocIds = {};
                  });
                }
              });
            }
            return const Center(child: Text("No orders found"));
          }

          // Build fresh groups from snapshot
          List<TableGroup> updatedGroups = [];

          for (var doc in snapshot.data!.docs) {
            final data = doc.data();
            final tableName = (data['name'] ?? 'Unknown Table') as String;
            final isPaid = data['isPaid'] == true;
            final itemsFromDb = (data.containsKey('items'))
                ? (data['items'] as List<dynamic>?)
                : null;
            updatedGroups.addAll(
              _reconstructGroups(
                tableName,
                itemsFromDb,
                isPaid: isPaid,
                docId: doc.id,
              ),
            );
          }

          // Sort by time
          updatedGroups.sort((a, b) => a.groupTime.compareTo(b.groupTime));

          // Filter by selected categories
          final filteredGroups = _filterByCategories(updatedGroups);

          // Compute keys, content signatures and doc ids for this snapshot.
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
            // First load: just record the baseline, don't blink everything.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                previousKeys = currentKeys;
                _previousSignatures = currentSignatures;
                _previousDocIds = currentDocIds;
              });
            });
          } else {
            final addedKeys = currentKeys.difference(previousKeys);

            // Existing key whose content changed => quantity changed or an
            // item was added/removed within the same batch.
            final changedKeys = currentKeys
                .where(
                  (k) =>
                      previousKeys.contains(k) &&
                      _previousSignatures[k] != currentSignatures[k],
                )
                .toList();

            // A brand-new table = a new key on a doc id we hadn't seen before.
            final newTableKeys = addedKeys
                .where((k) => !_previousDocIds.contains(keyToGroup[k]?.docId))
                .toList();

            // An update = a new batch on an already-available table, or a
            // content change on an existing batch.
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
            } else if (currentKeys.length != previousKeys.length ||
                currentDocIds.length != _previousDocIds.length) {
              // Items/tables removed: just sync the baseline, no blink.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  previousKeys = currentKeys;
                  _previousSignatures = currentSignatures;
                  _previousDocIds = currentDocIds;
                });
              });
            }
          }

          // Show message if no items match filter
          if (filteredGroups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.filter_list_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    showAllCategories
                        ? "No orders found"
                        : "No orders in selected categories",
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

          if (_showTableAllOrders == true) {
            final tableCards = _mergeGroupsByTable(filteredGroups);
            final firstUnpaidIndex = tableCards.indexWhere((c) => !c.isPaid);
            return MasonryGridView.count(
              crossAxisCount: crossCols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              padding: const EdgeInsets.all(12),
              itemCount: tableCards.length,
              itemBuilder: (context, index) => _buildTableBatchCard(
                tableCards[index],
                index + 1,
                isNext: index == firstUnpaidIndex && firstUnpaidIndex != -1,
              ),
            );
          }

          final firstUnpaidIndex = filteredGroups.indexWhere((g) => !g.isPaid);
          return MasonryGridView.count(
            crossAxisCount: crossCols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            padding: const EdgeInsets.all(12),
            itemCount: filteredGroups.length,
            itemBuilder: (context, index) => _buildGroupCard(
              filteredGroups[index],
              index + 1,
              isNext: index == firstUnpaidIndex && firstUnpaidIndex != -1,
            ),
          );
        },
      ),
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

    return InkWell(
      onTap: () {
        if (group.isPaid && selectedCategories.isEmpty) {
          showServedDialog(context, group.tableName, () async {
            _playDeleteSound();
            if (group.tableName.contains("Take Away")) {
              await FirebaseFirestore.instance
                  .collection('tables')
                  .doc(group.docId)
                  .delete();
              setState(() {});
            } else {
              await _updateTableItemsInFirestore(group.tableName, [], false);
            }
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        decoration: _orderCardDecoration(isBlinking, isOld, isNext),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildOrderHeader(
              group.tableName,
              group.isPaid,
              queueNumber,
              isNext: isNext,
            ),
            _buildTimeBar(time, isOld),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: group.items.map(_buildItemRow).toList(),
              ),
            ),
          ],
        ),
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

    final isOld = tableCard.batches.any((batch) {
      final time = DateTime.fromMillisecondsSinceEpoch(batch.groupTime);
      return DateTime.now().difference(time).inMinutes > 5;
    });

    return GestureDetector(
      onDoubleTap: () {
        if (tableCard.isPaid && selectedCategories.isEmpty) {
          showServedDialog(context, tableCard.tableName, () async {
            _playDeleteSound();
            if (tableCard.tableName.contains("Take Away")) {
              await FirebaseFirestore.instance
                  .collection('tables')
                  .doc(tableCard.docId)
                  .delete();
              setState(() {});
            } else {
              await _updateTableItemsInFirestore(
                tableCard.tableName,
                [],
                false,
              );
            }
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        decoration: _orderCardDecoration(isBlinking, isOld, isNext),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildOrderHeader(
              tableCard.tableName,
              tableCard.isPaid,
              queueNumber,
              isNext: isNext,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < tableCard.batches.length; i++) ...[
                    if (i > 0) ...[
                      const SizedBox(height: 0),
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
                      child: Text(
                        formatRelativeTime(
                          DateTime.fromMillisecondsSinceEpoch(
                            tableCard.batches[i].groupTime,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: fontMulishRegular,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...tableCard.batches[i].items.map(_buildItemRow),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
  }) {
    final paid = isPaid == true;
    return Container(
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
          Text(
            formatRelativeTime(time),
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

  Widget _buildItemRow(Map<String, dynamic> item) {
    final qty = item['qty'] ?? 1;
    final remarks = item['remarks']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFf57c35).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: const Color(0xFFf57c35).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              "${qty}x",
              style: const TextStyle(
                color: Color(0xFFf57c35),
                fontFamily: fontMulishBold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontFamily: fontMulishSemiBold,
                    height: 1.2,
                  ),
                ),
                if (remarks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      "* $remarks",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade400,
                        fontFamily: fontMulishSemiBold,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
    _timer?.cancel();
    audioPlayer.dispose();
    updateAudioPlayer.dispose();
    super.dispose();
  }

  void deleteTable(String docId) async {
    await FirebaseFirestore.instance.collection('tables').doc(docId).delete();
    setState(() {});
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
}

class TableGroup {
  final String tableName;
  final List<Map<String, dynamic>> items;
  final int groupTime;
  final String key;
  final String docId;
  final bool isPaid;

  TableGroup(
    this.tableName,
    this.items,
    this.groupTime, {
    required this.key,
    required this.docId,
    required this.isPaid,
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
