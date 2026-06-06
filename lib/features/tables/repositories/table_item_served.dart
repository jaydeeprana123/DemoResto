import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:demo/Styles/my_font.dart';

/// Identifies one line item within a table document.
class TableItemKey {
  const TableItemKey({
    required this.docId,
    required this.groupIndex,
    required this.itemIndexInGroup,
  });

  final String docId;
  final int groupIndex;
  final int itemIndexInGroup;

  String get id => '$docId|$groupIndex|$itemIndexInGroup';

  @override
  bool operator ==(Object other) =>
      other is TableItemKey &&
      docId == other.docId &&
      groupIndex == other.groupIndex &&
      itemIndexInGroup == other.itemIndexInGroup;

  @override
  int get hashCode => Object.hash(docId, groupIndex, itemIndexInGroup);
}

class TableItemServed {
  static bool isServed(Map<String, dynamic> item) =>
      item['isServed'] == true;

  static bool allServedInGroups(List<List<Map<String, dynamic>>> groups) {
    final items = groups.expand((g) => g);
    if (items.isEmpty) return false;
    return items.every(isServed);
  }

  static Future<bool> markItemsServed(List<TableItemKey> keys) async {
    if (keys.isEmpty) return false;

    final byDoc = <String, List<TableItemKey>>{};
    for (final key in keys) {
      byDoc.putIfAbsent(key.docId, () => []).add(key);
    }

    var anyUpdated = false;

    for (final entry in byDoc.entries) {
      final docRef =
          FirebaseFirestore.instance.collection('tables').doc(entry.key);
      final snap = await docRef.get();
      if (!snap.exists) continue;

      final rawItems = snap.data()?['items'];
      if (rawItems is! List) continue;

      final items = rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final groupCounters = <int, int>{};
      var changed = false;

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final groupIndex = (item['groupIndex'] as int?) ?? 0;
        final indexInGroup = groupCounters[groupIndex] ?? 0;
        groupCounters[groupIndex] = indexInGroup + 1;

        final shouldServe = entry.value.any(
          (key) =>
              key.groupIndex == groupIndex &&
              key.itemIndexInGroup == indexInGroup,
        );

        if (!shouldServe || isServed(item)) continue;

        items[i]['isServed'] = true;
        items[i]['servedAt'] = Timestamp.now();
        changed = true;
      }

      if (changed) {
        await docRef.update({
          'items': items,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        anyUpdated = true;
      }
    }

    return anyUpdated;
  }

  static Future<bool> markItemsUnserved(List<TableItemKey> keys) async {
    if (keys.isEmpty) return false;

    final byDoc = <String, List<TableItemKey>>{};
    for (final key in keys) {
      byDoc.putIfAbsent(key.docId, () => []).add(key);
    }

    var anyUpdated = false;

    for (final entry in byDoc.entries) {
      final docRef =
          FirebaseFirestore.instance.collection('tables').doc(entry.key);
      final snap = await docRef.get();
      if (!snap.exists) continue;

      final rawItems = snap.data()?['items'];
      if (rawItems is! List) continue;

      final items = rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final groupCounters = <int, int>{};
      var changed = false;

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final groupIndex = (item['groupIndex'] as int?) ?? 0;
        final indexInGroup = groupCounters[groupIndex] ?? 0;
        groupCounters[groupIndex] = indexInGroup + 1;

        final shouldUnserve = entry.value.any(
          (key) =>
              key.groupIndex == groupIndex &&
              key.itemIndexInGroup == indexInGroup,
        );

        if (!shouldUnserve || !isServed(item)) continue;

        items[i]['isServed'] = false;
        items[i].remove('servedAt');
        changed = true;
      }

      if (changed) {
        await docRef.update({
          'items': items,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        anyUpdated = true;
      }
    }

    return anyUpdated;
  }

  /// Compact row: ✓ qty badge + name, or checkbox during selection mode.
  static Widget buildItemLine({
    required int qty,
    required String name,
    required bool served,
    String? remarks,
    required Widget qtyBadge,
    required TextStyle nameStyle,
    TextStyle? remarksStyle,
    bool showSelectionIndicator = false,
    bool selectionSelected = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showSelectionIndicator)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              selectionSelected
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              size: 20,
              color: selectionSelected
                  ? Colors.green.shade600
                  : Colors.grey.shade500,
            ),
          )
        else if (served) ...[
          Icon(Icons.check, size: 16, color: Colors.green.shade600),
          const SizedBox(width: 4),
        ],
        qtyBadge,
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: nameStyle.copyWith(
                  color: served ? Colors.green.shade700 : nameStyle.color,
                ),
              ),
              if (remarks != null && remarks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '* $remarks',
                    style: (remarksStyle ?? nameStyle).copyWith(
                      fontSize: 12,
                      color: served
                          ? Colors.green.shade400
                          : remarksStyle?.color,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
