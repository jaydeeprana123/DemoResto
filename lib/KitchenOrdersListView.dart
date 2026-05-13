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
import 'Styles/my_font.dart';
import 'models/GroupOrder.dart';
import 'package:demo/Screens/Menu/MenuPage.dart';

class KitchenOrdersListView extends StatefulWidget {
  const KitchenOrdersListView({super.key});

  @override
  State<KitchenOrdersListView> createState() => _KitchenOrdersListViewState();
}

class _KitchenOrdersListViewState extends State<KitchenOrdersListView> {
  final AudioPlayer audioPlayer = AudioPlayer();
  Set<String> previousKeys = {};
  int? blinkingGroupKey;
  Timer? _timer;

  // Multiple category selection
  Set<String> selectedCategories = {};
  bool showAllCategories = true; // Track if "All" is selected

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
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  // Filter groups by selected categories
  List<TableGroup> _filterByCategories(List<TableGroup> groups) {
    // If "All" is selected or no categories selected, show everything
    if (showAllCategories || selectedCategories.isEmpty) {
      return groups;
    }

    return groups.map((group) {
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
    }).whereType<TableGroup>().toList(); // Remove nulls
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
                content: Center(
                  child: CircularProgressIndicator(),
                ),
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
                              final isSelected = selectedCategories.contains(categoryName);

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
                                      selectedCategories.add(categoryName);
                                    } else {
                                      selectedCategories.remove(categoryName);
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
          style: TextStyle(
            fontFamily: fontMulishSemiBold,
            fontSize: 16,
          ),
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
            if (previousKeys.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => previousKeys = {});
              });
            }
            return const Center(child: Text("No orders found"));
          }

          // Build fresh groups from snapshot
          List<TableGroup> updatedGroups = [];

          for (var doc in snapshot.data!.docs) {
            final data = doc.data();
            final tableName = (data['name'] ?? 'Unknown Table') as String;
            final isPaid = (data.containsKey('isPaid')) ? (data['isPaid'] as bool) : false;
            final itemsFromDb = (data.containsKey('items'))
                ? (data['items'] as List<dynamic>?)
                : null;
            updatedGroups.addAll(_reconstructGroups(
              tableName,
              itemsFromDb,
              isPaid: isPaid,
              docId: doc.id,
            ));
          }

          // Sort by time
          updatedGroups.sort((a, b) => a.groupTime.compareTo(b.groupTime));

          // Filter by selected categories
          final filteredGroups = _filterByCategories(updatedGroups);

          // Compute keys
          final currentKeys = updatedGroups.map((g) => g.key).toSet();

          // Handle blinking for new orders
          if (previousKeys.isEmpty && currentKeys.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;

              final String firstKey = currentKeys.last;

              // Check if the new order contains items from selected categories
              final newGroup = updatedGroups.firstWhere(
                    (g) => g.key == firstKey,
                orElse: () => updatedGroups.last,
              );
              final shouldPlaySound = _shouldPlaySoundForGroup(newGroup);

              setState(() {
                previousKeys = currentKeys;
                blinkingGroupKey = firstKey.hashCode;
              });

              if (shouldPlaySound) {
                _playNotificationSound();
              }

              Timer(const Duration(seconds: 3), () {
                if (!mounted) return;
                if (blinkingGroupKey == firstKey.hashCode) {
                  setState(() => blinkingGroupKey = null);
                }
              });
            });
          } else {
            final addedKeys = currentKeys.difference(previousKeys);
            final removedKeys = previousKeys.difference(currentKeys);

            if (addedKeys.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final String newKey = addedKeys.last;

                // Check if the new order contains items from selected categories
                final newGroup = updatedGroups.firstWhere(
                      (g) => g.key == newKey,
                  orElse: () => updatedGroups.last,
                );
                final shouldPlaySound = _shouldPlaySoundForGroup(newGroup);

                setState(() {
                  previousKeys = currentKeys;
                  blinkingGroupKey = newKey.hashCode;
                });

                if (shouldPlaySound) {
                  _playNotificationSound();
                }

                Timer(const Duration(seconds: 3), () {
                  if (!mounted) return;
                  if (mounted && blinkingGroupKey == newKey.hashCode) {
                    setState(() {
                      blinkingGroupKey = null;
                    });
                  }
                });
              });
            } else if (removedKeys.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => previousKeys = currentKeys);
              });
            }
          }

          // Show message if no items match filter
          if (filteredGroups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.filter_list_off, size: 64, color: Colors.grey),
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
          final crossCols = screenW > 1200 ? 5
              : screenW > 900  ? 4
              : screenW > 600  ? 3
              : screenW > 400  ? 2
              : 1;

          return MasonryGridView.count(
            crossAxisCount: crossCols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            padding: const EdgeInsets.all(12),
            itemCount: filteredGroups.length,
            itemBuilder: (context, index) {
              final group = filteredGroups[index];
              final time = DateTime.fromMillisecondsSinceEpoch(group.groupTime);
              final isBlinking = blinkingGroupKey == group.key.hashCode;
              final isOld = DateTime.now().difference(time).inMinutes > 5;

              if (group.tableName.contains("Take Away") && isOld && group.isPaid) {
                deleteTable(group.docId);
              }

              return GestureDetector(
                onDoubleTap: () {
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
                        await _updateTableItemsInFirestore(
                            group.tableName, [], false);
                      }
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isBlinking ? Colors.lightGreenAccent.shade100 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isOld ? Colors.red.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: isOld ? Border.all(color: Colors.red, width: 2) : Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A3A5C), // Brand Navy
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  SvgPicture.asset(
                                    (group.tableName).contains("Take Away")
                                        ? icon_packing
                                        : icon_table,
                                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                    width: (group.tableName).contains("Take Away") ? 18 : 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      group.tableName,
                                      style: TextStyle(
                                        fontFamily: (group.tableName).contains("Take Away")
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
                            if (group.isPaid)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green,
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
                      ),
                      // Time indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: isOld ? Colors.red.shade50 : const Color(0xFFF5F6FA),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: isOld ? Colors.red : Colors.grey.shade700),
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
                              )
                            ]
                          ],
                        ),
                      ),
                      // Items List
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: group.items.map((item) {
                            final qty = item['qty'] ?? 1;
                            final remarks = item['remarks']?.toString() ?? '';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFf57c35).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFf57c35).withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      "${qty}x",
                                      style: const TextStyle(
                                        color: Color(0xFFf57c35), // Brand Orange
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
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
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
    _timer?.cancel();
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
           tableName.contains("Take Away")?"Mark as Delivered?": "Mark as Served?",
            style: TextStyle(fontFamily: fontMulishSemiBold, fontSize: 18),
          ),
          content: Text(
            tableName.contains("Take Away")? "Are you sure you want to mark table '$tableName' as delivered?":"Are you sure you want to mark table '$tableName' as served?",
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
              child:  Text(
                tableName.contains("Take Away")? "Delivered":"Served",
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



