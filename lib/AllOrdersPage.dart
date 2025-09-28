import 'package:demo/AddMenuItemPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'MenuPage.dart';
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

class OrdersGroupedListPage extends StatefulWidget {
  const OrdersGroupedListPage({super.key});

  @override
  State<OrdersGroupedListPage> createState() => _OrdersGroupedListPageState();
}

class _OrdersGroupedListPageState extends State<OrdersGroupedListPage> {
  final AudioPlayer audioPlayer = AudioPlayer();
  Set<String> previousKeys = {}; // track existing group keys
  int? blinkingGroupKey;

  void _playNotificationSound() async {
    try {
      await audioPlayer.play(AssetSource('sounds/phone_bell.mp3'));
    } catch (e) {
      // ignore audio errors in production or print for debug:
      // print('Audio play failed: $e');
    }
  }

  List<TableGroup> _reconstructGroups(String tableName, List<dynamic>? itemsFromDb) {
    List<TableGroup> groups = [];
    if (itemsFromDb == null) return groups;

    Map<int, List<Map<String, dynamic>>> groupMap = {};
    Map<int, Timestamp> groupTimeMap = {};

    for (var item in itemsFromDb) {
      if (item is Map) {
        final itemMap = Map<String, dynamic>.from(item);
        final int groupIndex = (itemMap['groupIndex'] is int) ? itemMap['groupIndex'] as int : 0;
        final Timestamp addedAt = (itemMap['addedAt'] is Timestamp) ? itemMap['addedAt'] as Timestamp : Timestamp.now();

        // remove internal metadata so UI shows only item fields
        itemMap.remove('groupIndex');
        itemMap.remove('addedAt');

        groupMap.putIfAbsent(groupIndex, () => []);
        groupMap[groupIndex]!.add(itemMap);
        // store latest timestamp for this group (will be overwritten but that's okay)
        groupTimeMap[groupIndex] = addedAt;
      }
    }

    groupMap.forEach((index, items) {
      if (items.isEmpty) return; // skip empty groups
      final timestamp = groupTimeMap[index] ?? Timestamp.now();
      groups.add(TableGroup(
        tableName,
        items,
        timestamp.toDate().millisecondsSinceEpoch,
        key: '${tableName}_$index',
      ));
    });

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("All Orders (Time-wise)")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('tables').orderBy('createdAt', descending: false).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // clear previousKeys so next real data causes correct detection
            if (previousKeys.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => previousKeys = {});
              });
            }
            return const Center(child: Text("No orders found"));
          }

          // Build fresh groups from snapshot (always reflect the DB)
          List<TableGroup> updatedGroups = [];
          for (var doc in snapshot.data!.docs) {
            final data = doc.data();
            final tableName = (data['name'] ?? 'Unknown Table') as String;
            final itemsFromDb = (data.containsKey('items')) ? (data['items'] as List<dynamic>?) : null;
            updatedGroups.addAll(_reconstructGroups(tableName, itemsFromDb));
          }

          // sort by time
          updatedGroups.sort((a, b) => a.groupTime.compareTo(b.groupTime));

          // compute keys
          final currentKeys = updatedGroups.map((g) => g.key).toSet();

          // If this is the very first real load (previousKeys empty), DON'T blink/play sound.
          // Just initialize previousKeys to currentKeys.
          if (previousKeys.isEmpty && currentKeys.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;

              final String firstKey = currentKeys.last; // or .first depending on order
              setState(() {
                previousKeys = currentKeys;
                blinkingGroupKey = firstKey.hashCode;
              });

              _playNotificationSound();

              Timer(const Duration(seconds: 3), () {
                if (!mounted) return;
                if (blinkingGroupKey == firstKey.hashCode) {
                  setState(() => blinkingGroupKey = null);
                }
              });
            });
          }
          else {
            // detect newly added keys
            final addedKeys = currentKeys.difference(previousKeys);
            final removedKeys = previousKeys.difference(currentKeys);

            if (addedKeys.isNotEmpty) {
              // schedule setState after build to avoid calling setState during build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final String newKey = addedKeys.last; // pick last added (or change logic)
                setState(() {
                  previousKeys = currentKeys;
                  blinkingGroupKey = newKey.hashCode;
                });
                _playNotificationSound();

                // clear blinking after 3 seconds
                Timer(const Duration(seconds: 3), () {
                  if (!mounted) return;
                  // only clear if still blinking for this key
                  if (mounted && blinkingGroupKey == newKey.hashCode) {
                    setState(() {
                      blinkingGroupKey = null;
                    });
                  }
                });
              });
            } else if (removedKeys.isNotEmpty) {
              // if something removed, just update previousKeys (UI will reflect removal because updatedGroups is used)
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => previousKeys = currentKeys);
              });
            }
          }

          // Use updatedGroups directly so UI always matches Firestore (items removed/updated disappear instantly)
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: updatedGroups.length,
            separatorBuilder: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: DottedLine(
                dashLength: 6,
                dashGapLength: 4,
                lineThickness: 2,
                dashColor: Colors.grey,
              ),
            ),
            itemBuilder: (context, index) {
              final group = updatedGroups[index];
              final time = DateTime.fromMillisecondsSinceEpoch(group.groupTime);
              final isBlinking = blinkingGroupKey == group.key.hashCode;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                color: isBlinking ? Colors.lightGreenAccent : Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${group.tableName} (${DateFormat('dd MMM yyyy').format(time)}, ${DateFormat('hh:mm a').format(time)})",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    ...group.items.map((item) {
                      final qty = item['qty'] ?? 1;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: item['name']?.toString() ?? '',
                                style: const TextStyle(fontSize: 15, color: Colors.black),
                              ),
                              TextSpan(
                                text: "  x$qty",
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// TableGroup class
class TableGroup {
  final String tableName;
  final List<Map<String, dynamic>> items;
  final int groupTime;
  final String key;

  TableGroup(this.tableName, this.items, this.groupTime, {required this.key});
}
















