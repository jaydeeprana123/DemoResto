import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogEntry {
  const ActivityLogEntry({
    required this.id,
    required this.action,
    required this.userName,
    this.userId,
    this.tableName,
    this.tableDocId,
    this.details,
    this.source,
    this.items = const [],
    this.itemCount = 0,
    this.createdAt,
  });

  final String id;
  final String action;
  final String userName;
  final String? userId;
  final String? tableName;
  final String? tableDocId;
  final String? details;
  final String? source;
  final List<Map<String, dynamic>> items;
  final int itemCount;
  final DateTime? createdAt;

  factory ActivityLogEntry.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    final rawItems = data['items'];
    final items = <Map<String, dynamic>>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is Map) {
          items.add(Map<String, dynamic>.from(entry));
        }
      }
    }

    return ActivityLogEntry(
      id: doc.id,
      action: data['action']?.toString() ?? 'Unknown',
      userName: (data['userName']?.toString().trim().isNotEmpty ?? false)
          ? data['userName'].toString().trim()
          : 'Unknown',
      userId: data['userId']?.toString(),
      tableName: data['tableName']?.toString(),
      tableDocId: data['tableDocId']?.toString(),
      details: data['details']?.toString(),
      source: data['source']?.toString(),
      items: items,
      itemCount: (data['itemCount'] as num?)?.toInt() ?? items.length,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }

  String get summaryLine {
    final parts = <String>[];
    final table = tableName?.trim();
    if (table != null && table.isNotEmpty) {
      parts.add(table);
    }
    if (itemCount > 0) {
      parts.add(
        itemCount == 1 ? '1 item' : '$itemCount items',
      );
    }
    final detail = details?.trim();
    if (detail != null && detail.isNotEmpty) {
      parts.add(detail);
    }
    return parts.join(' · ');
  }
}

/// Canonical action labels shown in the Activity Log UI.
class ActivityLogActions {
  const ActivityLogActions._();

  static const deleteItems = 'Delete Items';
  static const deleteMenuItems = 'Delete Menu Items';
  static const deleteTable = 'Delete Table';
}
