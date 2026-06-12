class ZomatoExtractedItem {
  ZomatoExtractedItem({
    required this.extractedName,
    required this.quantity,
    this.remarks = '',
    this.matchedMenuItem,
  });

  final String extractedName;
  int quantity;
  String remarks;
  Map<String, dynamic>? matchedMenuItem;

  bool get isMatched => matchedMenuItem != null;
}

class ZomatoExtractedOrder {
  ZomatoExtractedOrder({
    this.zomatoOrderNumber,
    this.orderTime,
    this.totalAmount,
    required this.items,
  });

  final String? zomatoOrderNumber;
  final String? orderTime;
  final double? totalAmount;
  final List<ZomatoExtractedItem> items;

  bool get hasItems => items.isNotEmpty;
}
