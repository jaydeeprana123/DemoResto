import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartKitchen/core/firestore/firestore_paths.dart';
import 'package:smartKitchen/core/utils/platform_utils.dart';
import 'package:smartKitchen/features/activity_log/services/activity_log_service.dart';
import 'package:flutter/material.dart';

import 'package:smartKitchen/features/tables/widgets/portion_indicator.dart';

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
  /// Normalizes Firestore / web interop values into a Dart map.
  static Map<String, dynamic>? asItemMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      try {
        return Map<String, dynamic>.from(raw);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static int parseGroupIndex(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  static int itemIndexInGroupFor(Map<String, dynamic> item, int fallback) {
    final raw = item['__itemIndex'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return fallback;
  }

  static int firestoreGroupIndexFor(Map<String, dynamic> item, int fallback) {
    final raw = item['__firestoreGroupIndex'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return fallback;
  }

  static TableItemKey keyForItem({
    required String docId,
    required Map<String, dynamic> item,
    required int groupIndexFallback,
    required int itemIndexFallback,
  }) {
    return TableItemKey(
      docId: docId,
      groupIndex: firestoreGroupIndexFor(item, groupIndexFallback),
      itemIndexInGroup: itemIndexInGroupFor(item, itemIndexFallback),
    );
  }

  static bool isServed(dynamic item) {
    final map = asItemMap(item);
    return map?['isServed'] == true;
  }

  static bool allServedInGroups(List<List<Map<String, dynamic>>> groups) {
    final items = groups.expand((g) => g);
    if (items.isEmpty) return false;
    return items.every(isServed);
  }

  static List<Map<String, dynamic>> parseItemList(dynamic rawItems) {
    if (rawItems is! List) return const [];
    final parsed = <Map<String, dynamic>>[];
    for (final raw in rawItems) {
      final map = asItemMap(raw);
      if (map != null) parsed.add(map);
    }
    return parsed;
  }

  static Map<String, List<TableItemKey>> _keysByDoc(List<TableItemKey> keys) {
    final byDoc = <String, List<TableItemKey>>{};
    for (final key in keys) {
      byDoc.putIfAbsent(key.docId, () => []).add(key);
    }
    return byDoc;
  }

  /// Applies [build] to the latest table document.
  ///
  /// Returning null leaves the table unchanged. Mobile and web use a
  /// transaction so a bill-clear cannot be overwritten by an older save.
  /// Desktop avoids transactions because they crash the Firestore plugin
  /// while a tables listener is active.
  static Future<int?> commitTableUpdate({
    required DocumentReference<Map<String, dynamic>> docRef,
    required Map<String, dynamic>? Function(
      Map<String, dynamic> data,
      int nextRevision,
    )
    build,
  }) async {
    ({int revision, Map<String, dynamic> update})? apply(
      DocumentSnapshot<Map<String, dynamic>> snap,
    ) {
      if (!snap.exists) return null;
      final data = snap.data() ?? <String, dynamic>{};
      final current = (data['orderRevision'] as num?)?.toInt() ?? 0;
      final update = build(data, current + 1);
      if (update == null) return null;
      return (revision: current + 1, update: update);
    }

    if (isDesktopPlatform) {
      DocumentSnapshot<Map<String, dynamic>> snap;
      try {
        snap = await docRef.get(const GetOptions(source: Source.server));
      } catch (_) {
        snap = await docRef.get();
      }
      final result = apply(snap);
      if (result == null) return null;
      await docRef.update(result.update);
      return result.revision;
    }

    return FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final result = apply(snap);
      if (result == null) return null;
      tx.update(docRef, result.update);
      return result.revision;
    });
  }

  /// Edits only the items currently stored on the table.
  /// An empty table (just billed) is left empty.
  static Future<bool> _editStoredItems(
    String docId,
    bool Function(List<Map<String, dynamic>> items, Map<String, dynamic> data)
    edit,
  ) async {
    final revision = await commitTableUpdate(
      docRef: FirestorePaths.scopedDoc('tables', docId),
      build: (data, nextRevision) {
        final items = [
          for (final raw in parseItemList(data['items']))
            Map<String, dynamic>.from(raw),
        ];
        if (items.isEmpty) return null;
        if (!edit(items, data)) return null;
        return {
          'items': items,
          'updatedAt': FieldValue.serverTimestamp(),
          'orderRevision': nextRevision,
        };
      },
    );
    return revision != null;
  }

  static Future<bool> markItemsServed(List<TableItemKey> keys) async {
    if (keys.isEmpty) return false;

    var anyUpdated = false;
    for (final entry in _keysByDoc(keys).entries) {
      final updated = await _editStoredItems(entry.key, (items, _) {
        final groupCounters = <int, int>{};
        var changed = false;
        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          final groupIndex = parseGroupIndex(item['groupIndex']);
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
        return changed;
      });
      if (updated) anyUpdated = true;
    }
    return anyUpdated;
  }

  static Future<bool> markItemsUnserved(List<TableItemKey> keys) async {
    if (keys.isEmpty) return false;

    var anyUpdated = false;
    for (final entry in _keysByDoc(keys).entries) {
      final updated = await _editStoredItems(entry.key, (items, _) {
        final groupCounters = <int, int>{};
        var changed = false;
        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          final groupIndex = parseGroupIndex(item['groupIndex']);
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
        return changed;
      });
      if (updated) anyUpdated = true;
    }
    return anyUpdated;
  }

  static Future<bool> removeItems(List<TableItemKey> keys) async {
    if (keys.isEmpty) return false;

    var anyUpdated = false;
    for (final entry in _keysByDoc(keys).entries) {
      final removedItems = <Map<String, dynamic>>[];
      String? tableName;
      final updated = await _editStoredItems(entry.key, (items, data) {
        tableName = data['name']?.toString();
        final groupCounters = <int, int>{};
        final indicesToRemove = <int>{};
        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          final groupIndex = parseGroupIndex(item['groupIndex']);
          final indexInGroup = groupCounters[groupIndex] ?? 0;
          groupCounters[groupIndex] = indexInGroup + 1;
          final shouldRemove = entry.value.any(
            (key) =>
                key.groupIndex == groupIndex &&
                key.itemIndexInGroup == indexInGroup,
          );
          if (shouldRemove) indicesToRemove.add(i);
        }
        if (indicesToRemove.isEmpty) return false;
        removedItems
          ..clear()
          ..addAll([
            for (final i in indicesToRemove) Map<String, dynamic>.from(items[i]),
          ]);
        final remaining = [
          for (var i = 0; i < items.length; i++)
            if (!indicesToRemove.contains(i)) items[i],
        ];
        items
          ..clear()
          ..addAll(remaining);
        return true;
      });
      if (!updated) continue;
      anyUpdated = true;
      ActivityLogService.instance.logDeleteItems(
        tableName: tableName,
        tableDocId: entry.key,
        items: removedItems,
      );
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
    Widget? nameTrailing,
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
              Row(
                children: [
                  Expanded(
                    child: buildPortionAwareName(
                      name,
                      style: nameStyle.copyWith(
                        color: served ? Colors.green.shade700 : nameStyle.color,
                      ),
                    ),
                  ),
                  if (nameTrailing != null) nameTrailing,
                ],
              ),
              if (remarks != null && remarks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '* $remarks',
                    style: (remarksStyle ?? nameStyle).copyWith(
                      fontSize: remarksStyle?.fontSize ?? 12,
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
