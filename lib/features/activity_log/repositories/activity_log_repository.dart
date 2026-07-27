import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/features/activity_log/models/activity_log_entry.dart';

class ActivityLogPageResult {
  const ActivityLogPageResult({
    required this.docs,
    required this.hasMore,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool hasMore;
}

class ActivityLogRepository {
  static const pageSize = 15;

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirestorePaths.scoped('activity_logs');

  Future<void> createLog({
    required String action,
    required String userName,
    String? userId,
    String? tableName,
    String? tableDocId,
    String? details,
    String? source,
    List<Map<String, dynamic>>? items,
  }) async {
    final normalizedItems = (items ?? const <Map<String, dynamic>>[])
        .map((item) {
          final qty = item['qty'];
          final qtyInt = qty is int
              ? qty
              : qty is num
                  ? qty.round()
                  : int.tryParse(qty?.toString() ?? '') ?? 0;
          return <String, dynamic>{
            'name': item['name']?.toString() ?? '-',
            'qty': qtyInt,
            if (item['price'] != null) 'price': item['price'],
          };
        })
        .toList();

    await _collection.add({
      'action': action,
      'userName': userName.trim().isEmpty ? 'Unknown' : userName.trim(),
      if (userId != null && userId.trim().isNotEmpty) 'userId': userId.trim(),
      if (tableName != null && tableName.trim().isNotEmpty)
        'tableName': tableName.trim(),
      if (tableDocId != null && tableDocId.trim().isNotEmpty)
        'tableDocId': tableDocId.trim(),
      if (details != null && details.trim().isNotEmpty)
        'details': details.trim(),
      if (source != null && source.trim().isNotEmpty) 'source': source.trim(),
      'items': normalizedItems,
      'itemCount': normalizedItems.length,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<ActivityLogPageResult> fetchPage({
    required DateTime from,
    required DateTime to,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = pageSize,
  }) async {
    Query<Map<String, dynamic>> query = _collection
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(from),
        )
        .where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(to),
        )
        .orderBy('createdAt', descending: true);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.limit(limit).get();
    return ActivityLogPageResult(
      docs: snapshot.docs,
      hasMore: snapshot.docs.length >= limit,
    );
  }

  static List<ActivityLogEntry> mapDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map(ActivityLogEntry.fromDoc).toList();
  }
}
