import 'package:cloud_firestore/cloud_firestore.dart';

/// Sorts menu category/item Firestore docs by [sortOrder], then [createdAt], then id.
List<QueryDocumentSnapshot<Map<String, dynamic>>> sortMenuDocs(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final sorted = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
  sorted.sort(_compareMenuDocs);
  return sorted;
}

int _compareMenuDocs(
  QueryDocumentSnapshot<Map<String, dynamic>> a,
  QueryDocumentSnapshot<Map<String, dynamic>> b,
) {
  final aOrder = (a.data()['sortOrder'] as num?)?.toInt();
  final bOrder = (b.data()['sortOrder'] as num?)?.toInt();
  if (aOrder != null && bOrder != null) {
    final cmp = aOrder.compareTo(bOrder);
    if (cmp != 0) return cmp;
  } else if (aOrder != null) {
    return -1;
  } else if (bOrder != null) {
    return 1;
  }

  final aCreated = a.data()['createdAt'];
  final bCreated = b.data()['createdAt'];
  if (aCreated is Timestamp && bCreated is Timestamp) {
    final cmp = aCreated.compareTo(bCreated);
    if (cmp != 0) return cmp;
  }

  return a.id.compareTo(b.id);
}

/// Next [sortOrder] value for a collection (max existing + 1).
Future<int> nextSortOrder(CollectionReference<Map<String, dynamic>> ref) async {
  final snap = await ref.get();
  var max = -1;
  for (final doc in snap.docs) {
    final order = (doc.data()['sortOrder'] as num?)?.toInt();
    if (order != null && order > max) max = order;
  }
  return max + 1;
}
