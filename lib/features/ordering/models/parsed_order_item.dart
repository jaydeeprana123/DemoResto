import 'dart:convert';

class ParsedOrderItem {
  const ParsedOrderItem({
    required this.name,
    required this.qty,
    this.notes = '',
    this.confidence = 1.0,
    this.menuItem,
  });

  final String name;
  final int qty;
  final String notes;
  final double confidence;

  /// Matched menu row from Firestore/normalized menu list.
  final Map<String, dynamic>? menuItem;

  Map<String, dynamic> toJson() => {
        'name': name,
        'qty': qty,
        'notes': notes,
        if (confidence != 1.0) 'confidence': confidence,
      };

  static ParsedOrderItem fromJson(Map<String, dynamic> json) {
    return ParsedOrderItem(
      name: json['name']?.toString() ?? '',
      qty: ((json['qty'] as num?) ?? json['quantity'] as num? ?? 1)
          .toInt()
          .clamp(1, 99),
      notes: json['notes']?.toString() ??
          json['remarks']?.toString() ??
          '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
