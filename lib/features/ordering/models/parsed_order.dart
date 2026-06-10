import 'dart:convert';

import 'package:demo/features/ordering/models/parsed_order_item.dart';

class ParsedOrder {
  const ParsedOrder({
    required this.items,
    this.transcript = '',
    this.confidence = 0.0,
    this.source = ParsedOrderSource.local,
  });

  final List<ParsedOrderItem> items;
  final String transcript;
  final double confidence;
  final ParsedOrderSource source;

  bool get isEmpty => items.isEmpty;

  double get averageItemConfidence {
    if (items.isEmpty) return 0;
    return items.map((e) => e.confidence).reduce((a, b) => a + b) /
        items.length;
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        if (transcript.isNotEmpty) 'transcript': transcript,
        'confidence': confidence,
        'source': source.name,
      };

  @override
  String toString() => const JsonEncoder.withIndent('  ').convert(toJson());
}

enum ParsedOrderSource {
  local,
  gemini,
  repeat,
}
