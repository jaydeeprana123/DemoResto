import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Order parser — PRIMARY: Gemini REST API (v1, direct HTTP, no SDK issues)
//               FALLBACK: local fuzzy parser if API unavailable
// ─────────────────────────────────────────────────────────────────────────────

class OrderResult {
  final Map<String, dynamic> item;
  final int quantity;
  final String remarks;
  OrderResult({required this.item, required this.quantity, this.remarks = ''});
}

class AiOrderService {
  static final AiOrderService _instance = AiOrderService._internal();
  factory AiOrderService() => _instance;
  AiOrderService._internal();

  // Gemini REST — v1 endpoint (avoids the v1beta SDK issue)
  static const _apiKey = 'AIzaSyBz_YVM6SrTCL-HFA3FG6SkHZ3T5h6VgBc';
  static const _model = 'gemini-2.0-flash';
  static const _url =
      'https://generativelanguage.googleapis.com/v1/models/$_model:generateContent?key=$_apiKey';

  // Sarvam Chat REST
  static const _sarvamApiKey = 'sk_jm9xxf0p_09FKG715K2n9hXMGKjmIlAIS';
  static const _sarvamModel = 'sarvam-105b';
  static const _sarvamUrl = 'https://api.sarvam.ai/v1/chat/completions';

  // ── Public entry ────────────────────────────────────────────────────────
  Future<List<OrderResult>> parseOrder(
    String text,
    List<Map<String, dynamic>> menuItems,
  ) async {
    if (text.trim().isEmpty) return [];
    debugPrint('[AiOrderService] ── parseOrder called ──────────────────');
    debugPrint('[AiOrderService] Input text: "$text"');
    debugPrint('[AiOrderService] Menu size: ${menuItems.length} items');

    // ── PRIMARY: Sarvam Chat AI parser ────────────────────────────────────────
    try {
      final sarvamResults = await _callSarvamChat(text, menuItems);
      if (sarvamResults.isNotEmpty) {
        debugPrint(
          '[AiOrderService] ✅ Sarvam returned ${sarvamResults.length} items.',
        );
        return sarvamResults;
      }
      debugPrint('[AiOrderService] ⚠️ Sarvam returned empty — falling back to Gemini.');
    } catch (e) {
      debugPrint('[AiOrderService] ❌ Sarvam failed ($e) — falling back to Gemini.');
    }

    // ── SECONDARY: Gemini AI parser ────────────────────────────────────────
    try {
      final geminiResults = await _callGemini(text, menuItems);
      if (geminiResults.isNotEmpty) {
        debugPrint(
          '[AiOrderService] ✅ Gemini returned ${geminiResults.length} items.',
        );
        return geminiResults;
      }
      debugPrint('[AiOrderService] ⚠️ Gemini returned empty — falling back to local parser.');
    } catch (e) {
      debugPrint('[AiOrderService] ❌ Gemini failed ($e) — falling back to local parser.');
    }

    // ── FALLBACK: local fuzzy parser (works offline) ─────────────────────
    final localResults = _parseLocally(text, menuItems);
    debugPrint(
      '[AiOrderService] Local parser returned ${localResults.length} items.',
    );
    return localResults;
  }

  String _buildPrompt(String userText, List<Map<String, dynamic>> menuItems) {
    // Build category-annotated menu string so the model can disambiguate
    // similar names (e.g. "Chicken Fried Rice" vs "Chicken Singapuri Rice").
    // Items that carry a 'category' field get a [Category] prefix; others
    // are listed plain so the prompt stays clean.
    final menuStr = menuItems
        .map((m) {
          final cat = (m['category'] as String? ?? '').trim();
          final name = (m['name'] as String? ?? '').trim();
          return cat.isNotEmpty ? '- [$cat] $name' : '- $name';
        })
        .join('\n');

    return '''
You are a restaurant order-taking assistant. Convert spoken/typed user input into structured JSON orders.

═══════════════════════════════════════════
MENU (you MUST only match from these items)
═══════════════════════════════════════════
$menuStr

═══════════════════════════════
LANGUAGE & SPEECH CORRECTION
═══════════════════════════════
Input may be in English, Hindi, Gujarati or mixed. Speech-to-text errors are common.

KEY TERM DICTIONARY (spoken word → menu meaning):
- alfam / alfaam / alpham / dohol farm / dohol / dohol pham → "Alfaham"
- tukda / tokda → "Tukda" (a portion type — keep it in the name)
- charbake / charbag / char bag / charback → "Char Bag"
- samoli / samoly → "Samoli"
- lebnani / libnani → "Lebnani"
- khaboos / khubus / khabus → "Khaboos"
- zafrani / jafrani → "Zafrani"
- pahadi / pahari → "Pahadi"
- surti / surthi → "Surti"
- singapur → "Singapuri"
- shezvan / schezwan → "Shezwan"
- manchuri / manchoori → "Manchurian"
- shower / shavarma / shwarma / morning → "Shawarma"
- soap / soop → "Soup"
- cook / kok → "Coke"
- pan / paner → "Paneer"
- biriyani / briyani / birani → "Biryani"
- arabic rice / arbic rice → whichever menu item contains "Arabic Rice"

NUMBER DICTIONARY:
- ek / one / aek = 1
- be / do / two = 2  
- tran / teen / three = 3
- chaar / char / four = 4
- paanch / panch / five = 5
- chha / chhe / six = 6
- saat / sat / seven = 7
- aath / eight = 8
- nav / nine = 9
- das / ten = 10

═══════════════════════════════
MATCHING RULES (follow strictly)
═══════════════════════════════
1. KEYWORD MATCHING: Match by identifying KEY WORDS in user input.
   - Example: "alfam tukda rice" → keywords: alfam=Alfaham, tukda=Tukda, rice=Rice → "Alfaham Tukda Rice" ✅
   - Example: "fish tukda rice" → keywords: fish=Fish, tukda=Tukda, rice=Rice → "Fish Tukda Rice" ✅
   - Example: "charbake rice" → keywords: charbake≈charbag=Char Bag, rice=Rice → "Char Bag Rice" ✅

2. CATEGORY HINT: The [Category] prefix helps disambiguate similar names.
   - "chicken rice" → prefer [Fried Rice and Noodles] over [Hamara Specials]
   - The category prefix must NOT appear in your output "name" field

3. COMPOUND NAMES: Never drop parts of a compound menu name.
   - "tukda rice" must match "Alfaham Tukda Rice" or "Fish Tukda Rice", NOT just "Arabic Rice"
   - "fried rice" is different from "Tukda Rice"

4. FUZZY SPELLING: Be tolerant of spelling/pronunciation errors.
   - "charbake" ≈ "Char Bag" (sounds similar, same category)
   - "alfam" = "Alfaham" (well-known abbreviation)

5. QUANTITY: 
   - Default quantity = 1 if not mentioned
   - Apply quantity ONLY to the item it was spoken with
   - Use the LAST mentioned quantity if corrected ("make it 4 instead of 3" → 4)

6. REMARKS: 
   - Extract VERBATIM any modifier/preference the user spoke
   - Examples: spice level, oil, onion, garlic, parcel, cooking style
   - If no modifier spoken → remarks = "" (empty string, never null)

═══════════════════════════════
OUTPUT FORMAT (strict)
═══════════════════════════════
Return ONLY a valid JSON array. No markdown, no explanation, no extra text.
The "name" field must EXACTLY match one of the menu names above (copy-paste exact spelling).
CRITICAL: If the user orders something that is NOT in the MENU list provided above, DO NOT include it in the JSON output. Ignore it entirely.
If absolutely no items from the input match the menu, you MUST still return an empty JSON array: []

[{"name":"EXACT_MENU_NAME","quantity":NUMBER,"remarks":"MODIFIER_OR_EMPTY"}]

═══════════════════════════════
EXAMPLES
═══════════════════════════════
Menu has: "Alfaham Tukda Rice", "Fish Tukda Rice", "Char Bag Rice", "Garden Rice"

Input: "one alfam tukda rice, two fish tukda rice, three charbake rice, one garden rice"
Output: [
  {"name":"Alfaham Tukda Rice","quantity":1,"remarks":""},
  {"name":"Fish Tukda Rice","quantity":2,"remarks":""},
  {"name":"Char Bag Rice","quantity":3,"remarks":""},
  {"name":"Garden Rice","quantity":1,"remarks":""}
]

Input: "do chicken fried rice kam tikha, ek hakka noodle"
Output: [
  {"name":"Chicken Fried Rice","quantity":2,"remarks":"kam tikha"},
  {"name":"Hakka Noodle","quantity":1,"remarks":""}
]

Input: "teen samoli, ek open shawarma parcel karo"
Output: [
  {"name":"Samoli (Bun)","quantity":3,"remarks":""},
  {"name":"Open Shawarma","quantity":1,"remarks":"parcel karo"}
]

═══════════════════════════════
USER INPUT TO PROCESS
═══════════════════════════════
"$userText"
''';
  }

  // ── Sarvam Chat REST call ───────────────────────────────────────────────
  Future<List<OrderResult>> _callSarvamChat(
    String userText,
    List<Map<String, dynamic>> menuItems,
  ) async {
    final prompt = _buildPrompt(userText, menuItems);

    final body = jsonEncode({
      'model': _sarvamModel,
      'messages': [
        {'role': 'system', 'content': prompt},
        {'role': 'user', 'content': userText}
      ],
      'temperature': 0.1,
      'max_tokens': 1024,
      'top_p': 0.9,
    });

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final request = await client.postUrl(Uri.parse(_sarvamUrl));
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8')
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.authorizationHeader, 'Bearer $_sarvamApiKey');
        
      request.add(utf8.encode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      debugPrint('[AiOrderService] Sarvam HTTP ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('[AiOrderService] ❌ Sarvam error body: $responseBody');
        throw Exception('Sarvam HTTP ${response.statusCode}: $responseBody');
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final raw = (json['choices'] as List?)?.firstOrNull?['message']?['content'] as String? ?? '';
      
      debugPrint('[AiOrderService] 📦 Sarvam raw response: "$raw"');

      return _parseJsonOutput(raw.trim(), menuItems);
    } finally {
      client.close();
    }
  }

  // ── Gemini REST call ────────────────────────────────────────────────────
  Future<List<OrderResult>> _callGemini(
    String userText,
    List<Map<String, dynamic>> menuItems,
  ) async {
    final prompt = _buildPrompt(userText, menuItems);

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
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
        debugPrint('[AiOrderService] ❌ Gemini error body: $responseBody');
        throw Exception('Gemini HTTP ${response.statusCode}: $responseBody');
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final raw =
          (json['candidates'] as List?)
                  ?.firstOrNull?['content']?['parts']
                  ?.firstOrNull?['text']
              as String? ??
          '';
      debugPrint('[AiOrderService] 📦 Gemini raw response: "$raw"');

      return _parseJsonOutput(raw.trim(), menuItems);
    } finally {
      client.close();
    }
  }

  // ── Parse JSON response ──────────────────────────────────────────
  List<OrderResult> _parseJsonOutput(
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
      final remarks = rawRemarks;

      debugPrint(
        '[AiOrderService] AI identified: name="$rawName" qty=$qty remarks="$rawRemarks"',
      );

      // Find exact match first
      Map<String, dynamic>? matched = _exactMatch(rawName, menuItems);
      // Then fuzzy
      matched ??= _fuzzyMatch(rawName, menuItems);

      if (matched != null) {
        debugPrint(
          '[AiOrderService]   ✅ Matched to menu item: "${matched['name']}"',
        );
        results.add(
          OrderResult(item: matched, quantity: qty, remarks: remarks),
        );
      } else {
        debugPrint('[AiOrderService]   ❌ No menu match found for: "$rawName"');
      }
    }
    return results;
  }

  /// Strips parenthetical descriptors from a menu name so they don't
  /// interfere with matching.  e.g. "Crispy Samoli (Bun)" → "Crispy Samoli"
  static String _stripParens(String name) =>
      name.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

  /// Normalises & → and so tokenisers don't choke on it.
  static String _normalizeAmp(String s) => s.replaceAll('&', 'and');

  Map<String, dynamic>? _exactMatch(
    String name,
    List<Map<String, dynamic>> items,
  ) {
    final lower = _normalizeAmp(name).toLowerCase();
    try {
      return items.firstWhere(
        (m) => _normalizeAmp(m['name'].toString()).toLowerCase() == lower,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _fuzzyMatch(
    String name,
    List<Map<String, dynamic>> items,
  ) {
    // Normalise the query: strip parens + & so "(Bun)" etc. don't hurt score
    final lower = _normalizeAmp(_stripParens(name)).toLowerCase();

    // 1. Contains match (normalised both sides)
    try {
      return items.firstWhere((m) {
        final mNorm = _normalizeAmp(
          _stripParens(m['name'].toString()),
        ).toLowerCase();
        return mNorm.contains(lower) || lower.contains(mNorm);
      });
    } catch (_) {}

    // 2. Word-overlap scoring
    final qWords = lower.split(' ').where((w) => w.length > 2).toSet();
    Map<String, dynamic>? best;
    int bestScore = 0;

    for (final item in items) {
      final iName = _normalizeAmp(
        _stripParens(item['name'].toString()),
      ).toLowerCase();
      final iWords = iName
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 1)
          .toSet();

      int score = 0;
      for (final qw in qWords) {
        for (final iw in iWords) {
          if (qw == iw) {
            score += 10; // exact word match
          } else if (qw.startsWith(iw) || iw.startsWith(qw)) {
            score += 5; // stem / prefix match
          } else if (qw.contains(iw) || iw.contains(qw)) {
            score += 2; // partial match
          }
        }
      }

      // Bonus when one string fully contains the other
      if (iName.contains(lower) || lower.contains(iName)) score += 15;

      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }
    // Require a score that scales with the number of query words.
    // This prevents generic single-word matches (e.g. "Rice" = 10) 
    // from matching entirely different compound names.
    final threshold = (qWords.length * 6).clamp(8, 25);
    return bestScore >= threshold ? best : null;
  }

  // ════════════════════════════════════════════════════════════════════════
  // LOCAL FALLBACK PARSER (works offline, no API needed)
  // ════════════════════════════════════════════════════════════════════════

  static const Map<String, int> _nums = {
    '1': 1, '2': 2, '3': 3, '4': 4, '5': 5,
    '6': 6, '7': 7, '8': 8, '9': 9, '10': 10,
    // English
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    // STT English homophones
    'to': 2, 'too': 2, 'for': 4, 'free': 3,
    // Hindi numbers
    'ek': 1, 'do': 2, 'teen': 3, 'chaar': 4, 'char': 4,
    'paanch': 5, 'panch': 5, 'chhah': 6, 'chhe': 6,
    'saat': 7, 'sat': 7, 'aath': 8, 'nau': 9, 'das': 10,
    // Gujarati numbers
    'be': 2, 'tran': 3, 'chha': 6, 'nav': 9,
    'aek': 1, 'ek1': 1, 'pach': 5, 'saath': 7, 'aat': 8,
  };

  static const Set<String> _seps = {
    ',', '.', 'plus', '&', 'aur', 'va', 'also', 'then',
    'ne', 'tatha', 'sathe', // Gujarati/Hindi conjunctions
  };

  /// Maps Hindi/Gujarati spoken remark phrases → standard English remarks.
  /// Order matters: longer/more-specific phrases must come first.
  static const List<(String, String)> _remarkPhraseMap = [
    // "less spicy" variants
    ('thoda kam tikha', 'less spicy'),
    ('thoda kam spicy', 'less spicy'),
    ('kam tikha', 'less spicy'),
    ('kam spicy', 'less spicy'),
    ('kam masala', 'less spicy'),
    ('zyada kam tikha', 'less spicy'),
    ('bilkul kam tikha', 'not spicy'),
    ('bilkul nahi tikha', 'not spicy'),
    ('thoda spicy', 'less spicy'),
    // "more spicy" variants
    ('zyada tikha', 'extra spicy'),
    ('zyada spicy', 'extra spicy'),
    ('bahut tikha', 'extra spicy'),
    ('jyada tikha', 'extra spicy'),
    ('jyada spicy', 'extra spicy'),
    // "less oil" variants
    ('kam tel', 'less oil'),
    ('zyada tel', 'extra oil'),
    // "less salt" variants
    ('kam namak', 'less salt'),
    ('no namak', 'no salt'),
    // "no onion no garlic" variants
    ('jain food', 'jain'),
    ('jain item', 'jain'),
    ('without onion garlic', 'no onion no garlic'),
    ('no onion garlic', 'no onion no garlic'),
    ('lasan dungri nahi', 'no onion no garlic'),
    // "parcel" variants
    ('parcel karo', 'parcel'),
    ('packing', 'parcel'),
    // "extra butter"
    ('extra butter lagao', 'extra butter'),
    ('butter lagao', 'extra butter'),
    // "well done"
    ('achha bano', 'well done'),
    ('full done', 'well done'),
  ];

  /// Normalises a raw spoken remark string by converting Hindi/Gujarati
  /// phrases into standard English. Call this on Gemini output remarks too.
  static String normalizeRemarks(String raw) {
    String text = raw.toLowerCase().trim();
    for (final (phrase, replacement) in _remarkPhraseMap) {
      text = text.replaceAll(phrase, replacement);
    }
    // Collapse multiple spaces
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.isEmpty ? '' : text[0].toUpperCase() + text.substring(1);
  }

  static const Map<String, String> _fix = {
    // Soup
    'soap': 'soup', 'soop': 'soup', 'sob': 'soup', 'sop': 'soup',
    // Chicken
    'chikin': 'chicken', 'chiken': 'chicken', 'chick': 'chicken',
    'chikn': 'chicken', 'chickan': 'chicken',
    // Tikka
    'tika': 'tikka', 'tica': 'tikka', 'tican': 'tikka',
    // Coke / Drinks
    'cook': 'coke', 'coc': 'coke', 'kok': 'coke',
    'bear': 'beer', 'bir': 'beer',
    // Paneer
    'pan': 'paneer', 'paner': 'paneer', 'panner': 'paneer',
    'panier': 'paneer', 'panir': 'paneer',
    // Naan / Bread
    'nan': 'naan', 'naaan': 'naan', 'roti': 'roti',
    // Rice dishes
    'biriyani': 'biryani', 'briyani': 'biryani', 'bryani': 'biryani',
    'birani': 'biryani', 'beriani': 'biryani',
    // Dal
    'daal': 'dal', 'dall': 'dal', 'dhal': 'dal',
    // Malai
    'malei': 'malai', 'malie': 'malai', 'malay': 'malai',
    // ── Al-Haadi specific ────────────────────────────────────────────────────
    // Alfaham (grilled chicken)
    'alfam': 'alfaham', 'alfaam': 'alfaham', 'alphaam': 'alfaham',
    'alpham': 'alfaham', 'alfaham': 'alfaham',
    // Shawarma wrap types
    'samoli': 'samoli', 'samoly': 'samoli', 'samolee': 'samoli',
    'lebnani': 'lebnani', 'libnani': 'lebnani', 'lebni': 'lebnani',
    'khaboos': 'khaboos', 'khubus': 'khaboos', 'khabus': 'khaboos',
    'khuboos': 'khaboos', 'kaboos': 'khaboos',
    // Specials / starters
    'tukda': 'tukda', 'tokda': 'tukda',
    'zafrani': 'zafrani', 'zafran': 'zafrani', 'jafrani': 'zafrani',
    'pahadi': 'pahadi', 'pehadi': 'pahadi', 'pahari': 'pahadi',
    'surti': 'surti', 'surthi': 'surti',
    'lolipop': 'lolipop', 'lollipop': 'lolipop',
    'popcorn': 'popcorn', 'pop corn': 'popcorn',
    'talmari': 'talmari', 'talmary': 'talmari',
    'hakka': 'hakka', 'haka': 'hakka',
    'manchurian': 'manchurian',
    'manchuri': 'manchurian',
    'manchoori': 'manchurian',
    // Crispy prefix (very common in this menu)
    'crispy': 'crispy', 'crispi': 'crispy', 'krispi': 'crispy',
    // Grill
    'grill': 'grill', 'grilled': 'grill',
    // ── General fixes ────────────────────────────────────────────────────────
    'thok': 'thukpa', 'berger': 'burger',
    'singapur': 'singapuri', 'shezvan': 'shezwan',
    'nudels': 'noodles', 'noodels': 'noodles', 'nudal': 'noodles',
    'fryed': 'fried', 'fride': 'fried',
    'sambar': 'sambar', 'sambhar': 'sambar',
    'lassi': 'lassi', 'lasi': 'lassi',
    'mojito': 'mojito', 'mohito': 'mojito',
    'shower': 'shawarma',
    'morning': 'shawarma',
    'shavarma': 'shawarma',
    'shwarma': 'shawarma',
    // Char Bag rice variants
    'bagged': 'char bag', 'bag': 'char bag',
  };

  /// Filler words that carry no menu-item meaning and should be dropped
  /// before fuzzy matching (e.g. "two chicken pieces" → "two chicken").
  static const Set<String> _stopWords = {
    'piece', 'pieces', 'pcs', 'pc', 'item', 'items', 'plate', 'plates',
    'serving', 'servings', 'order', 'orders',
  };

  List<OrderResult> _parseLocally(String raw, List<Map<String, dynamic>> menu) {
    // Normalise ampersand before tokenising so "Hot & Sour" doesn't split wrong
    String text = _normalizeAmp(raw).toLowerCase().trim();
    _fix.forEach((w, r) => text = text.replaceAll(RegExp('\\b$w\\b'), r));

    final tokens = text
        .replaceAll(',', ' , ')
        .replaceAll('.', ' . ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final segments = _buildSegments(tokens);
    if (segments.isEmpty && tokens.isNotEmpty) {
      segments.add((qty: 1, words: tokens));
    }

    final results = <OrderResult>[];
    final used = <String>{};

    for (final seg in segments) {
      if (seg.words.isEmpty) continue;

      final cleanWords = seg.words.toList();

      final matched = _bestMatch(cleanWords, menu, used);
      if (matched == null) continue;
      used.add(matched['name'].toString());

      // Get words that make up the item name to filter them out
      final itemWords = matched['name']
          .toString()
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 2)
          .toSet();

      // The remaining words in the segment are the verbatim remark!
      final remarkWords = cleanWords.where((w) {
        // Skip words that look like they belong to the item name
        return !itemWords.any((iw) => iw.contains(w) || w.contains(iw));
      }).toList();

      // Re-capitalize the first letter
      String rawRemark = remarkWords.join(' ');
      if (rawRemark.isNotEmpty) {
        rawRemark = rawRemark[0].toUpperCase() + rawRemark.substring(1);
      }

      results.add(
        OrderResult(item: matched, quantity: seg.qty, remarks: rawRemark),
      );
    }
    return results;
  }

  List<({int qty, List<String> words})> _buildSegments(List<String> tokens) {
    final out = <({int qty, List<String> words})>[];
    int pQty = 1;
    List<String> buf = [];
    bool hasQty = false;

    void flush({int? ov}) {
      if (buf.isEmpty) return;
      out.add((qty: ov ?? pQty, words: List.from(buf)));
      buf = [];
      pQty = 1;
      hasQty = false;
    }

    for (int i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (_seps.contains(t)) {
        flush();
        continue;
      }

      // Skip filler / stop words — they add noise to fuzzy matching
      if (_stopWords.contains(t)) continue;

      // 'and' before a number → segment boundary
      if (t == 'and') {
        if (i + 1 < tokens.length && _nums[tokens[i + 1]] != null) {
          flush();
        } else {
          buf.add(t);
        }
        continue;
      }

      // 'or' between numbers: "three or four" → override qty with later number
      if (t == 'or') {
        if (hasQty && i + 1 < tokens.length && _nums[tokens[i + 1]] != null) {
          pQty = _nums[tokens[i + 1]]!;
          i++; // consume the next number token
        }
        // either way, don't add 'or' to the word buffer
        continue;
      }

      final n = _nums[t];
      if (n != null) {
        if (!hasQty && buf.isEmpty) {
          pQty = n;
          hasQty = true;
        } else if (!hasQty && buf.isNotEmpty) {
          flush(ov: n);
        } else {
          flush();
          pQty = n;
          hasQty = true;
        }
      } else {
        buf.add(t);
      }
    }
    flush();
    return out;
  }

  Map<String, dynamic>? _bestMatch(
    List<String> qWords,
    List<Map<String, dynamic>> menu,
    Set<String> used,
  ) {
    final q = qWords
        .where((w) => w.length > 1 && _nums[w] == null && !_seps.contains(w))
        .toList();
    if (q.isEmpty) return null;
    Map<String, dynamic>? best;
    double bestScore = 0;
    for (final item in menu) {
      if (used.contains(item['name'].toString())) continue;
      final iw = item['name']
          .toString()
          .toLowerCase()
          .split(' ')
          .where((w) => w.length > 1)
          .toList();
      if (iw.isEmpty) continue;
      double sc = 0;
      for (final qw in q) {
        double top = 0;
        for (final w in iw) {
          final s = _wSim(qw, w);
          if (s > top) top = s;
        }
        sc += top;
      }
      final norm = sc / q.length;
      if (norm > bestScore) {
        bestScore = norm;
        best = item;
      }
    }
    return bestScore >= 0.55 ? best : null;
  }

  double _wSim(String a, String b) {
    if (a == b) return 2.0;
    if (b.contains(a) || a.contains(b)) return 1.5;

    // Character overlap score (ignoring position)
    final aSet = a.runes.toSet();
    final bSet = b.runes.toSet();
    final intersection = aSet.intersection(bSet).length;
    final overlap = (intersection * 2.0) / (aSet.length + bSet.length);

    // Positional match
    int m = 0;
    final s = a.length <= b.length ? a : b;
    final l = a.length <= b.length ? b : a;
    for (int i = 0; i < s.length; i++) {
      if (s[i] == l[i]) m++;
    }
    final positional = m / l.length;

    return (overlap + positional) / 1.0; // Max possible ~2.0
  }
}
