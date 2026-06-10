import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:demo/features/ordering/services/menu_matcher_service.dart';
import 'package:demo/features/ordering/services/notes_parser.dart';
import 'package:demo/features/ordering/services/quantity_parser.dart';
import 'package:demo/features/ordering/services/text_normalizer.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Order parser â€” PRIMARY: Gemini REST API (v1, direct HTTP, no SDK issues)
//               FALLBACK: local fuzzy parser if API unavailable
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class OrderResult {
  final Map<String, dynamic> item;
  final int quantity;
  final String remarks;

  /// When set, used as the line name for cart apply (e.g. Half/Full variant).
  final String? applyName;

  OrderResult({
    required this.item,
    required this.quantity,
    this.remarks = '',
    this.applyName,
  });
}

class AiOrderService {
  static final AiOrderService _instance = AiOrderService._internal();
  factory AiOrderService() => _instance;
  AiOrderService._internal();

  // Gemini REST â€” v1 endpoint (avoids the v1beta SDK issue)
  static const _apiKey = 'AIzaSyBz_YVM6SrTCL-HFA3FG6SkHZ3T5h6VgBc';
  static const _model   = 'gemini-1.5-flash';
  static const _url =
      'https://generativelanguage.googleapis.com/v1/models/$_model:generateContent?key=$_apiKey';

  final MenuMatcherService _matcher = MenuMatcherService.instance;

  static const double _localConfidenceThreshold = 0.62;

  // â”€â”€ Public entry â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<List<OrderResult>> parseOrder(
    String text,
    List<Map<String, dynamic>> menuItems,
  ) async {
    if (text.trim().isEmpty) return [];
    debugPrint('[AiOrderService] â”€â”€ parseOrder called â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€');
    debugPrint('[AiOrderService] Input text: "$text"');
    debugPrint('[AiOrderService] Menu size: ${menuItems.length} items');

    final localResults = _parseLocally(text, menuItems);
    final localConfidence = _averageMatchConfidence(localResults);
    debugPrint(
      '[AiOrderService] Local parser: ${localResults.length} items, '
      'confidence=${localConfidence.toStringAsFixed(2)}',
    );

    if (localResults.isNotEmpty &&
        localConfidence >= _localConfidenceThreshold) {
      return localResults;
    }

    try {
      debugPrint('[AiOrderService] Trying Gemini API (fallback)â€¦');
      final aiResults = await _callGemini(text, menuItems);
      if (aiResults.isNotEmpty) {
        debugPrint(
          '[AiOrderService] âœ… Gemini succeeded with ${aiResults.length} items.',
        );
        return aiResults;
      }
      debugPrint('[AiOrderService] âš ï¸ Gemini returned 0 items.');
    } catch (e) {
      debugPrint('[AiOrderService] âŒ Gemini FAILED: $e');
    }

    if (localResults.isNotEmpty) {
      debugPrint('[AiOrderService] Using local parser results as fallback.');
      return localResults;
    }
    return [];
  }

  double _averageMatchConfidence(List<OrderResult> results) {
    if (results.isEmpty) return 0;
    return results.map((r) => (r.item['_matchConfidence'] as num?)?.toDouble() ?? 0.72)
            .reduce((a, b) => a + b) /
        results.length;
  }

  // â”€â”€ Gemini REST call â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<List<OrderResult>> _callGemini(
    String userText,
    List<Map<String, dynamic>> menuItems,
  ) async {
    // Build category-annotated menu string so Gemini can disambiguate
    // similar names (e.g. "Chicken Fried Rice" vs "Chicken Singapuri Rice").
    // Items that carry a 'category' field get a [Category] prefix; others
    // are listed plain so the prompt stays clean.
    final menuStr = menuItems.map((m) {
      final cat = (m['category'] as String? ?? '').trim();
      final name = (m['name'] as String? ?? '').trim();
      final label = name.isNotEmpty ? name : cat;
      return cat.isNotEmpty ? '- [$cat] $label' : '- $label';
    }).join('\n');

    final prompt = '''
You are an intelligent restaurant order assistant.

Your job is to convert user speech text into structured order JSON.

The input may contain:
- Gujarati, Hindi, English or mixed language
- Wrong words due to speech recognition (example: "cook" may mean "coke", "bear" may mean "beer", "soap" may mean "soup")
- Half words (example: "pan" may mean "paneer", "chik" may mean "chicken")
- Spelling mistakes
- IMPORTANT: The provided MENU may itself contain spelling mistakes (example: "Chciken" instead of "Chicken"). You must match the user's intent to the EXISTING menu name, even if the menu name is spelled incorrectly.

You must:
1. Correct wrong or similar sounding words
2. Predict the most likely food item from the menu
3. Match ONLY from the provided menu
4. Detect quantity (default = 1 if not mentioned)
5. ALWAYS extract the remark/modifier portion into the "remarks" field:
   - Copy the EXACT words the user spoke for the modifier (verbatim), do NOT summarize or paraphrase
   - Examples of modifiers: spice level, oil, onion, garlic, parcel, cooking style, any preference
   - IMPORTANT: Even if the modifier is attached to the item name, extract it as-is into remarks
   - Example: user says "paneer tikka don't make it spicy" â†’ remarks = "don't make it spicy" (verbatim)
   - Example: user says "two peri peri wraps keep it less spicy" â†’ remarks = "keep it less spicy" (verbatim)
   - If no modifier is spoken, remarks = ""

Important:
- Use common Indian restaurant understanding
- Use context to guess missing words (example: "butter" â†’ "butter paneer")
- Ignore items not in menu
- Be tolerant to errors and incomplete input
- Number words: ek/one=1, be/do/two=2, tran/teen/three=3, chaar/char/four=4, paanch/panch/five=5, chha/chhe/six=6, saat/sat/seven=7, aath/eight=8, nav/nine=9, das/ten=10
- Menu items are shown with a [Category] prefix to help you disambiguate.
  Example: if user says "chicken rice", prefer items in [Fried Rice and Noodles] over [Hamara Specials].
  The category prefix is for context ONLY â€” the "name" in your JSON output must NOT include it.
- Shawarma wraps appear as e.g. "Crispy Samoli (Bun)" â€” the part in () is just a
  descriptor; if user says "samoli" or "bun shawarma", match to the full exact menu name.
- Al-Haadi specific terms: alfaham/alfam = grilled chicken; tukda = a large portion;
  samoli = a bun-style shawarma wrap; lebnani = chapati wrap; khaboos = pita wrap;
  zafrani = saffron; pahadi = hills-style; surti = Surat style.

CORRECTIONS & OVERRIDES:
- Handle natural language corrections within the same input.
- If the user says "make it 4 instead of 3", your output must contain ONLY the final quantity (4).
- If the user says "not X, give me Y", your output must contain ONLY Y.
- If the user repeats an item with a different quantity, use the LAST mentioned quantity as the source of truth.
- "to be added" or "add X" means the final count for that item should be identified.
- QUANTITY RULE: If a quantity is mentioned for one item, do NOT apply it to other items unless explicitly stated.
- DEFAULT RULE: If no quantity is mentioned for an item, the quantity is ALWAYS 1.
- DO NOT multiply or sum quantities unless the user explicitly says "plus" or "more".

STRICT RULES:
- Return ONLY valid JSON array, no markdown, no explanation
- "name" must exactly match one of the provided menu names
- "remarks" must be empty string if no modifier spoken, NOT null
- If unsure about item, choose the closest matching item from menu
- Number words: ek=1, be/do=2, tran/teen=3, char=4, panch=5, chhe=6, sat=7, ath=8, nav=9, das=10

MENU (match ONLY from these exact names):
$menuStr

Return format (strict):
[{"name":"EXACT_MENU_NAME","quantity":NUMBER,"remarks":"MODIFIER_OR_EMPTY_STRING"}]

User input:
"$userText"''';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 1024,
        'topP': 0.9,
      },
    });

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final request = await client.postUrl(Uri.parse(_url));
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8')
        ..set(HttpHeaders.acceptHeader, 'application/json');
      // Use utf8.encode to safely handle special characters (like & in menu names)
      request.add(utf8.encode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      debugPrint('[AiOrderService] Gemini HTTP ${response.statusCode}');
      
      if (response.statusCode != 200) {
        debugPrint('[AiOrderService] âŒ Gemini error body: $responseBody');
        throw Exception('Gemini HTTP ${response.statusCode}: $responseBody');
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final raw = (json['candidates'] as List?)
              ?.firstOrNull?['content']?['parts']
              ?.firstOrNull?['text'] as String? ??
          '';
      debugPrint('[AiOrderService] ðŸ“¦ Gemini raw response: "$raw"');

      return _parseGeminiJson(raw.trim(), menuItems);
    } finally {
      client.close();
    }
  }

  // â”€â”€ Parse Gemini JSON response â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<OrderResult> _parseGeminiJson(
    String raw,
    List<Map<String, dynamic>> menuItems,
  ) {
    // Strip markdown fences if present
    String cleaned = raw
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    final arrayMatch = RegExp(r'\[.*\]', dotAll: true).firstMatch(cleaned);
    if (arrayMatch == null) return [];
    cleaned = arrayMatch.group(0)!;

    final List<dynamic> parsed;
    try {
      parsed = jsonDecode(cleaned) as List<dynamic>;
    } catch (_) {
      return [];
    }

    final results = <OrderResult>[];
    for (final entry in parsed) {
      final rawName = (entry['name'] as String? ?? '').trim();
      final qty = ((entry['quantity'] as num?) ?? 1).toInt().clamp(1, 99);
      final rawRemarks = (entry['remarks'] as String? ?? '').trim();
      final remarks = NotesParser.normalizeNotes(rawRemarks);

      debugPrint('[AiOrderService] Gemini identified: name="$rawName" qty=$qty remarks="$rawRemarks"');

      // Find exact match first
      Map<String, dynamic>? matched = _matcher.exactMatch(rawName, menuItems);
      MenuMatchResult? matchResult;
      if (matched == null) {
        matchResult = _matcher.fuzzyMatch(rawName, menuItems);
        matched = matchResult?.item;
      } else {
        matchResult = MenuMatchResult(
          item: matched,
          matchedName: rawName,
          confidence: 1.0,
          orderName: rawName,
        );
      }

      if (matched != null) {
        debugPrint('[AiOrderService]   âœ… Matched to menu item: "${matched['name']}"');
        results.add(
          OrderResult(
            item: matched,
            quantity: qty,
            remarks: remarks,
            applyName: matchResult?.orderName,
          ),
        );
      } else {
        debugPrint('[AiOrderService]   âŒ No menu match found for: "$rawName"');
      }
    }
    return results;
  }

  static String normalizeRemarks(String raw) => NotesParser.normalizeNotes(raw);

  List<OrderResult> _parseLocally(
    String raw,
    List<Map<String, dynamic>> menu,
  ) {
    final normalized = TextNormalizer.normalize(raw);
    final segments = QuantityParser.parseSegments(normalized);
    final results = <OrderResult>[];
    final used = <String>{};

    for (final segment in segments) {
      final split = NotesParser.split(segment.text);
      final match = _matcher.matchQuery(
        split.itemText,
        menu,
        usedNames: used,
      );
      if (match == null) continue;

      used.add(match.orderName ?? match.matchedName);
      final itemWithConfidence = Map<String, dynamic>.from(match.item)
        ..['_matchConfidence'] = match.confidence;

      results.add(
        OrderResult(
          item: itemWithConfidence,
          quantity: segment.qty,
          remarks: split.notes,
          applyName: match.orderName,
        ),
      );
    }

    return results;
  }
}
