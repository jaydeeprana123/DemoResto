import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrdersGroupedListPage extends StatefulWidget {
  const OrdersGroupedListPage({super.key});

    @override
    State<OrdersGroupedListPage> createState() => _OrdersGroupedListPageState();
}

class _OrdersGroupedListPageState extends State<OrdersGroupedListPage> {
    final AudioPlayer audioPlayer = AudioPlayer();
    List<String> previousKeys = []; // keep track of existing group keys
    int? blinkingGroupKey;

    void _playNotificationSound() async {
        await audioPlayer.play(AssetSource('sounds/phone_bell.mp3'));
    }

    List<TableGroup> _reconstructGroups(String tableName, List<dynamic> itemsFromDb) {
        List<TableGroup> groups = [];
        Map<int, List<Map<String, dynamic>>> groupMap = {};
        Map<int, Timestamp> groupTimeMap = {};

        for (var item in itemsFromDb) {
            if (item is Map) {
                Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
                int groupIndex = itemMap['groupIndex'] ?? 0;
                Timestamp addedAt = itemMap['addedAt'] ?? Timestamp.now();

                itemMap.remove('groupIndex');
                itemMap.remove('addedAt');

                groupMap.putIfAbsent(groupIndex, () => []);
                groupMap[groupIndex]!.add(itemMap);
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
        body: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                .collection('tables')
                .orderBy('createdAt', descending: false)
            .snapshots(),
                builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No orders found"));
            }

            List<TableGroup> updatedGroups = [];

            for (var doc in snapshot.data!.docs) {
                final tableName = doc['name'] ?? "Unknown Table";
                final itemsFromDb = doc.data().toString().contains('items')
                        ? (doc['items'] as List<dynamic>)
                : [];
                updatedGroups.addAll(_reconstructGroups(tableName, itemsFromDb));
            }

            // Sort by time
            updatedGroups.sort((a, b) => a.groupTime.compareTo(b.groupTime));

            // detect new groups (compare keys with previous state)
            // detect new groups (compare keys with previous state)
            final newKeys = updatedGroups.map((g) => g.key).toList();

// 🔥 Detect removed groups
            for (var oldKey in previousKeys) {
                if (!newKeys.contains(oldKey)) {


                    // A group was removed → trigger rebuild
                    setState(() {});
                }
            }

// 🔥 Detect newly added groups
            for (var g in updatedGroups) {
                if (!previousKeys.contains(g.key)) {
                    blinkingGroupKey = g.key.hashCode;
                    _playNotificationSound();

                    Timer(const Duration(seconds: 3), () {
                        if (mounted) setState(() => blinkingGroupKey = null);
                    });
                }
            }

            previousKeys = newKeys; // update cache of keys



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
                        duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                        color: isBlinking ? Colors.lightGreenAccent : Colors.transparent,
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                Text(
                        "${group.tableName} "
                        "(${DateFormat('dd MMM yyyy').format(time)}, "
                        "${DateFormat('hh:mm a').format(time)})",
                        style: const TextStyle(fontFamily: fontMulishSemiBold, fontSize: 16),
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
                        text: item['name'],
                        style: const TextStyle(fontSize: 15, color: Colors.black),
                              ),
                TextSpan(
                        text: "  x$qty",
                        style: const TextStyle(
                        fontSize: 16, color: Colors.red, fontFamily: fontMulishSemiBold),
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

