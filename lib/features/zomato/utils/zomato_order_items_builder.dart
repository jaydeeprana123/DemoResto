import 'package:cloud_firestore/cloud_firestore.dart';

class ZomatoOrderItemsBuilder {
  ZomatoOrderItemsBuilder._();

  static Map<String, dynamic> fromMenuMatch({
    required Map<String, dynamic> menuItem,
    required int qty,
    String remarks = '',
  }) {
    return {
      'name': menuItem['name'],
      'price': menuItem['price'],
      'qty': qty,
      'category': menuItem['category'],
      if (menuItem['categoryId'] != null) 'categoryId': menuItem['categoryId'],
      if (menuItem['itemId'] != null) 'itemId': menuItem['itemId'],
      if (remarks.isNotEmpty) 'remarks': remarks,
    };
  }

  static List<Map<String, dynamic>> flattenForFirestore(
    List<Map<String, dynamic>> groupItems, {
    int groupIndex = 0,
  }) {
    if (groupItems.isEmpty) return const [];

    final ts = Timestamp.now();
    return groupItems.map((item) {
      final copy = Map<String, dynamic>.from(item);
      copy['groupIndex'] = groupIndex;
      copy['addedAt'] = ts;
      return copy;
    }).toList();
  }
}
