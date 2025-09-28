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

class OrdersGroupedListPage extends StatelessWidget {
  const OrdersGroupedListPage({super.key});

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
      final timestamp = groupTimeMap[index] ?? Timestamp.now();
      groups.add(TableGroup(
        tableName,
        items,
        timestamp.toDate().millisecondsSinceEpoch,
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No orders found"));
          }

          List<TableGroup> allGroups = [];

          for (var doc in snapshot.data!.docs) {
            final tableName = doc['name'] ?? "Unknown Table";
            final itemsFromDb = doc.data().toString().contains('items')
                ? (doc['items'] as List<dynamic>)
                : [];
            allGroups.addAll(_reconstructGroups(tableName, itemsFromDb));
          }

          // Sort by addedAt time
          allGroups.sort((a, b) => a.groupTime.compareTo(b.groupTime));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: allGroups.length,
            separatorBuilder: (context, index) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: DottedLine(
                dashLength: 6,
                dashGapLength: 4,
                lineThickness: 2,
                dashColor: Colors.grey,
              ),
            ),
            itemBuilder: (context, index) {
              final group = allGroups[index];
              final time = DateTime.fromMillisecondsSinceEpoch(group.groupTime);

              String formattedTime = DateFormat('hh:mm a').format(time);
              String formattedDate = DateFormat('dd MMM yyyy').format(time);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${group.tableName}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
                              style: const TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                      ,
                    );
                  }).toList(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}












