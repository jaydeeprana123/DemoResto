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

class OrdersGroupedListPage extends StatefulWidget {
  const OrdersGroupedListPage({super.key});

  @override
  State<OrdersGroupedListPage> createState() => _OrdersGroupedListPageState();
}

class _OrdersGroupedListPageState extends State<OrdersGroupedListPage> {
  final AudioPlayer audioPlayer = AudioPlayer();
  Set<String> previousKeys = {}; // track existing group keys
  int? blinkingGroupKey;
  Timer? _timer;
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
    List<dynamic>? itemsFromDb,
  ) {
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
        // store latest timestamp for this group (will be overwritten but that's okay)
        groupTimeMap[groupIndex] = addedAt;
      }
    }

    groupMap.forEach((index, items) {
      if (items.isEmpty) return; // skip empty groups
      final timestamp = groupTimeMap[index] ?? Timestamp.now();
      groups.add(
        TableGroup(
          tableName,
          items,
          timestamp.toDate().millisecondsSinceEpoch,
          key: '${tableName}_$index',
        ),
      );
    });

    return groups;
  }

  @override
  void initState() {
    super.initState();

    // Start a timer to update every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("All Orders (Time-wise)",style: const TextStyle(
        fontFamily: fontMulishSemiBold,
        fontSize: 16,
      ))),
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
          String docId = "";
          bool isPaid = false;
          for (var doc in snapshot.data!.docs) {
            final data = doc.data();
            docId = doc.id;
            final tableName = (data['name'] ?? 'Unknown Table') as String;
            isPaid = (data.containsKey('isPaid'))?(data['isPaid'] as bool):false;
            final itemsFromDb = (data.containsKey('items'))
                ? (data['items'] as List<dynamic>?)
                : null;
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

              final String firstKey =
                  currentKeys.last; // or .first depending on order
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
          } else {
            // detect newly added keys
            final addedKeys = currentKeys.difference(previousKeys);
            final removedKeys = previousKeys.difference(currentKeys);

            if (addedKeys.isNotEmpty) {
              // schedule setState after build to avoid calling setState during build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final String newKey =
                    addedKeys.last; // pick last added (or change logic)
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
                lineThickness: 1,
                dashColor: Colors.grey,
              ),
            ),
            itemBuilder: (context, index) {
              final group = updatedGroups[index];
              final time = DateTime.fromMillisecondsSinceEpoch(group.groupTime);
              final isBlinking = blinkingGroupKey == group.key.hashCode;

              // Continuous blink if older than 20 minutes
              final isOld = DateTime.now().difference(time).inMinutes > 2;

              if(group.tableName.contains("Take Away") && isOld && isPaid){
                deleteTable(docId);
              }


              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                color: isBlinking
                    ? Colors.lightGreenAccent:
                isOld?Colors.blue.shade100
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Row(

                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: SvgPicture.asset((group.tableName).contains("Take Away")?icon_packing:icon_table, color: (group.tableName).contains("Take Away")?Colors.black87:Colors.black87,width: (group.tableName).contains("Take Away")?18:24,),
                    ),

                    SizedBox(width: 10,),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Row(
                            mainAxisAlignment: MainAxisAlignment.start
                            ,children: [
                              Expanded(
                                child: Text(
                                  "${group.tableName} ",
                                  style:  TextStyle(
                                      fontFamily: (group.tableName).contains("Take Away")?fontMulishBold:fontMulishSemiBold,
                                      fontSize: 15,
                                      color: (group.tableName).contains("Take Away")?Colors.black:Colors.black
                                  ),
                                ),
                              ),

                              SizedBox(width: 6,),

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
                              padding: const EdgeInsets.only( bottom: 4),
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
      return DateFormat('dd MMM yyyy, hh:mm a').format(time); // fallback absolute
    }
  }


  @override
  void dispose() {
    _timer?.cancel(); // Cancel timer when widget is disposed
    super.dispose();
  }

  void deleteTable(String docId) async{
    await FirebaseFirestore.instance.collection('tables').doc(docId).delete();
    setState(() {

    });
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



