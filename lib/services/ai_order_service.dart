import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class OrderResult {
  final Map<String, dynamic> item;
  final int quantity;
  final String remarks;

  OrderResult({
    required this.item,
    required this.quantity,
    this.remarks = '',
  });
}

class AiOrderService {
  static final AiOrderService _instance = AiOrderService._internal();
  factory AiOrderService() => _instance;
  AiOrderService._internal();

  GenerativeModel? _model;

  static const String geminiApiKey = 'AIzaSyBz_YVM6SrTCL-HFA3FG6SkHZ3T5h6VgBc';

  GenerativeModel get _gemini {
    _model ??= GenerativeModel(
      model: 'gemini-pro',
      apiKey: geminiApiKey,
    );
    return _model!;
  }

  Future<List<OrderResult>> parseOrder(
    String userText,
    List<Map<String, dynamic>> menuItems,
  ) async {
    if (userText.trim().isEmpty) return [];

    final menuListStr = menuItems
        .map((item) => 'Name="${item['name']}"')
        .join('\n');

    final prompt = '''
You are a food ordering assistant. The restaurant menu is:
$menuListStr

The user said: "$userText"
(The user may speak in English, Hindi, Gujarati, or a mix of languages.)

Instructions:
- Match what the user said to menu items above.
- Use the EXACT Name from the menu.
- Extract quantity. Default to 1 if not mentioned.
- Extract any special instructions or remarks (e.g., "Less spicy", "No onion"). If none, use "".
- Number words in Hindi: ek=1, do=2, teen=3, char=4, panch=5
- Number words in Gujarati: ek=1, be=2, tran=3, char=4, panch=5

Return ONLY a raw JSON array, no markdown, no explanation:
[{"name":"EXACT_ITEM_NAME","quantity":NUMBER,"remarks":"REMARKS"}]

Return [] if nothing matches.
''';

    try {
      final response = await _gemini.generateContent([Content.text(prompt)]);
      final raw = (response.text ?? '').trim();

      String cleaned = raw
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final arrayMatch = RegExp(r'\[.*\]', dotAll: true).firstMatch(cleaned);
      if (arrayMatch != null) {
        cleaned = arrayMatch.group(0)!;
      }

      final List<dynamic> parsed = jsonDecode(cleaned);
      final results = <OrderResult>[];

      for (final entry in parsed) {
        final rawName = (entry['name'] as String? ?? '').trim().toLowerCase();
        final qty = ((entry['quantity'] as num?) ?? 1).toInt().clamp(1, 99);
        final remarks = (entry['remarks'] as String? ?? '').trim();

        Map<String, dynamic>? matched;

        // Exact name match (case-insensitive)
        try {
          matched = menuItems.firstWhere(
            (m) => m['name'].toString().toLowerCase() == rawName,
          );
        } catch (_) {}

        // Menu item name contains AI name
        if (matched == null && rawName.isNotEmpty) {
          try {
            matched = menuItems.firstWhere(
              (m) => m['name'].toString().toLowerCase().contains(rawName),
            );
          } catch (_) {}
        }

        // Fuzzy match
        if (matched == null && rawName.isNotEmpty) {
          final aiWords = rawName.split(' ').where((w) => w.length > 2).toSet();
          Map<String, dynamic>? best;
          int bestScore = 0;
          for (final item in menuItems) {
            final itemWords = item['name']
                .toString()
                .toLowerCase()
                .split(' ')
                .where((w) => w.length > 2)
                .toSet();
            final overlap = aiWords.intersection(itemWords).length;
            final threshold = (itemWords.length / 2).ceil();
            if (overlap >= threshold && overlap > bestScore) {
              bestScore = overlap;
              best = item;
            }
          }
          matched = best;
        }

        if (matched != null) {
          results.add(OrderResult(
            item: matched,
            quantity: qty,
            remarks: remarks,
          ));
        }
      }
      return results;
    } catch (e) {
      rethrow;
    }
  }
}
