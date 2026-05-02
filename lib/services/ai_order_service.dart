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
  static const _model   = 'gemini-1.5-flash';
  static const _url =
      'https://generativelanguage.googleapis.com/v1/models/$_model:generateContent?key=$_apiKey';

  // ── Public entry ────────────────────────────────────────────────────────
  Future<List<OrderResult>> parseOrder(
    String text,
    List<Map<String, dynamic>> menuItems,
  ) async {
    if (text.trim().isEmpty) return [];
    debugPrint('[AiOrderService] ── parseOrder called ──────────────────');
    debugPrint('[AiOrderService] Input text: "$text"');
    debugPrint('[AiOrderService] Menu size: ${menuItems.length} items');

    try {
      debugPrint('[AiOrderService] Trying Gemini API...');
      final aiResults = await _callGemini(text, menuItems);
      if (aiResults.isNotEmpty) {
        debugPrint('[AiOrderService] ✅ Gemini succeeded with ${aiResults.length} items.');
        return aiResults;
      }
      debugPrint('[AiOrderService] ⚠️ Gemini returned 0 items — falling back to local parser.');
    } catch (e) {
      debugPrint('[AiOrderService] ❌ Gemini FAILED: $e');
      debugPrint('[AiOrderService] Falling back to local parser...');
    }
    final localResults = _parseLocally(text, menuItems);
    debugPrint('[AiOrderService] Local parser returned ${localResults.length} items.');
    return localResults;
  }

  // ── Gemini REST call ────────────────────────────────────────────────────
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
      return cat.isNotEmpty ? '- [$cat] $name' : '- $name';
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
   - Example: user says "paneer tikka don't make it spicy" → remarks = "don't make it spicy" (verbatim)
   - Example: user says "two peri peri wraps keep it less spicy" → remarks = "keep it less spicy" (verbatim)
   - If no modifier is spoken, remarks = ""

Important:
- Use common Indian restaurant understanding
- Use context to guess missing words (example: "butter" → "butter paneer")
- Ignore items not in menu
- Be tolerant to errors and incomplete input
- Number words: ek/one=1, be/do/two=2, tran/teen/three=3, chaar/char/four=4, paanch/panch/five=5, chha/chhe/six=6, saat/sat/seven=7, aath/eight=8, nav/nine=9, das/ten=10
- Menu items are shown with a [Category] prefix to help you disambiguate.
  Example: if user says "chicken rice", prefer items in [Fried Rice and Noodles] over [Hamara Specials].
  The category prefix is for context ONLY — the "name" in your JSON output must NOT include it.
- Shawarma wraps appear as e.g. "Crispy Samoli (Bun)" — the part in () is just a
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
        debugPrint('[AiOrderService] ❌ Gemini error body: $responseBody');
        throw Exception('Gemini HTTP ${response.statusCode}: $responseBody');
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final raw = (json['candidates'] as List?)
              ?.firstOrNull?['content']?['parts']
              ?.firstOrNull?['text'] as String? ??
          '';
      debugPrint('[AiOrderService] 📦 Gemini raw response: "$raw"');

      return _parseGeminiJson(raw.trim(), menuItems);
    } finally {
      client.close();
    }
  }

  // ── Parse Gemini JSON response ──────────────────────────────────────────
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
      final remarks = rawRemarks;

      debugPrint('[AiOrderService] Gemini identified: name="$rawName" qty=$qty remarks="$rawRemarks"');

      // Find exact match first
      Map<String, dynamic>? matched = _exactMatch(rawName, menuItems);
      // Then fuzzy
      matched ??= _fuzzyMatch(rawName, menuItems);

      if (matched != null) {
        debugPrint('[AiOrderService]   ✅ Matched to menu item: "${matched['name']}"');
        results.add(OrderResult(item: matched, quantity: qty, remarks: remarks));
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
      String name, List<Map<String, dynamic>> items) {
    final lower = _normalizeAmp(name).toLowerCase();
    try {
      return items.firstWhere(
          (m) => _normalizeAmp(m['name'].toString()).toLowerCase() == lower);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _fuzzyMatch(
      String name, List<Map<String, dynamic>> items) {
    // Normalise the query: strip parens + & so "(Bun)" etc. don't hurt score
    final lower = _normalizeAmp(_stripParens(name)).toLowerCase();

    // 1. Contains match (normalised both sides)
    try {
      return items.firstWhere((m) {
        final mNorm = _normalizeAmp(_stripParens(m['name'].toString())).toLowerCase();
        return mNorm.contains(lower) || lower.contains(mNorm);
      });
    } catch (_) {}

    // 2. Word-overlap scoring
    final qWords = lower.split(' ').where((w) => w.length > 2).toSet();
    Map<String, dynamic>? best;
    int bestScore = 0;

    for (final item in items) {
      final iName =
          _normalizeAmp(_stripParens(item['name'].toString())).toLowerCase();
      final iWords =
          iName.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();

      int score = 0;
      for (final qw in qWords) {
        for (final iw in iWords) {
          if (qw == iw) {
            score += 10; // exact word match
          } else if (qw.startsWith(iw) || iw.startsWith(qw)) {
            score += 5;  // stem / prefix match
          } else if (qw.contains(iw) || iw.contains(qw)) {
            score += 2;  // partial match
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
    // Only return if we have a reasonably good match
    return bestScore > 5 ? best : null;
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

  static const Set<String> _seps = {',', '.', 'plus', '&', 'aur', 'va', 'also', 'then',
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
    'manchurian': 'manchurian', 'manchuri': 'manchurian', 'manchoori': 'manchurian',
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
    'shower': 'shawarma', 'morning': 'shawarma', 'shavarma': 'shawarma', 'shwarma': 'shawarma',
  };

  List<OrderResult> _parseLocally(
      String raw, List<Map<String, dynamic>> menu) {
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
          OrderResult(item: matched, quantity: seg.qty, remarks: rawRemark));
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
      if (_seps.contains(t)) { flush(); continue; }
      
      // Special handle for 'and'
      if (t == 'and') {
        if (i + 1 < tokens.length && _nums[tokens[i+1]] != null) {
          flush();
        } else {
          buf.add(t);
        }
        continue;
      }

      final n = _nums[t];
      if (n != null) {
        if (!hasQty && buf.isEmpty) { pQty = n; hasQty = true; }
        else if (!hasQty && buf.isNotEmpty) { flush(ov: n); }
        else { flush(); pQty = n; hasQty = true; }
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
          .toString().toLowerCase().split(' ')
          .where((w) => w.length > 1).toList();
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
      if (norm > bestScore) { bestScore = norm; best = item; }
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
