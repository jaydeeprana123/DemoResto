import 'package:demo/AddMenuItemPage.dart';
import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'MenuPage.dart';
import 'Styles/my_font.dart';
import 'models/GroupOrder.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_line/dotted_line.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_line/dotted_line.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dotted_line/dotted_line.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:dotted_line/dotted_line.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:dotted_line/dotted_line.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:dotted_line/dotted_line.dart';
import 'dart:async';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:dotted_line/dotted_line.dart';

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
      // ignore audio errors in production or print for debug:
      // print('Audio play failed: $e');
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

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filteredGroups.length,
            separatorBuilder: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: DottedLine(
                dashLength: 6,
                dashGapLength: 4,
                lineThickness: 1,
                dashColor: Colors.grey,
              ),
            ),
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
                  color: isBlinking
                      ? Colors.lightGreenAccent
                      : isOld
                      ? Colors.red.shade100
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: SvgPicture.asset(
                          (group.tableName).contains("Take Away")
                              ? icon_packing
                              : icon_table,
                          color: Colors.black87,
                          width: (group.tableName).contains("Take Away") ? 18 : 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Text(
                                        "${group.tableName} ",
                                        style: TextStyle(
                                          fontFamily: (group.tableName)
                                              .contains("Take Away")
                                              ? fontMulishBold
                                              : fontMulishSemiBold,
                                          fontSize: 15,
                                          color: Colors.black,
                                        ),
                                      ),
                                      if (group.isPaid)
                                        Container(
                                          color: Colors.red,
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 3, horizontal: 8),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 3,
                                          ),
                                          child: const Text(
                                            "PAID",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontFamily: fontMulishBold,
                                            ),
                                          ),
                                        )
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  formatRelativeTime(time),
                                  style: const TextStyle(
                                    fontFamily: fontMulishSemiBold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            ...group.items.map((item) {
                              final qty = item['qty'] ?? 1;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: item['name']?.toString() ?? '',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black,
                                          fontFamily: fontMulishRegular,
                                        ),
                                      ),
                                      TextSpan(
                                        text: "  x$qty",
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.red,
                                          fontFamily: fontMulishSemiBold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      )
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



