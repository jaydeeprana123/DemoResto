import 'dart:convert';
import 'dart:io';

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

    try {
      final aiResults = await _callGemini(text, menuItems);
      if (aiResults.isNotEmpty) return aiResults;
    } catch (_) {
      // fall through to local parser
    }
    return _parseLocally(text, menuItems);
  }

  // ── Gemini REST call ────────────────────────────────────────────────────
  Future<List<OrderResult>> _callGemini(
    String userText,
    List<Map<String, dynamic>> menuItems,
  ) async {
    // Build compact menu list for the prompt
    final menuStr = menuItems
        .map((m) => '"${m['name']}"')
        .join(', ');

    final prompt = '''
You are a smart restaurant ordering assistant for an Indian restaurant.

MENU ITEMS (use EXACT names):
$menuStr

CUSTOMER SAID: "$userText"

The customer may speak in English, Hindi, Gujarati, or a mix.
Number words: ek/one=1, be/do/two=2, tran/teen/three=3, chaar/char/four=4, paanch/panch/five=5, chha/chhe/six=6, saat/sat/seven=7.

Task:
1. Match each spoken item to the EXACT menu item name above (fuzzy/phonetic match allowed).
2. Extract quantity (default 1 if not stated).
3. Extract any remarks per item (e.g. "less spicy", "no onion", "extra cheese").

Respond with ONLY a raw JSON array — no markdown, no explanation:
[{"name":"EXACT_MENU_NAME","quantity":NUMBER,"remarks":"REMARK_OR_EMPTY"}]

Return [] if nothing matches.''';

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
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set(HttpHeaders.acceptHeader, 'application/json');
      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        // API error — let fallback handle it
        throw Exception('Gemini HTTP ${response.statusCode}: $responseBody');
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final raw = (json['candidates'] as List?)
              ?.firstOrNull?['content']?['parts']
              ?.firstOrNull?['text'] as String? ??
          '';

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
      final remarks = (entry['remarks'] as String? ?? '').trim();

      // Find exact match first
      Map<String, dynamic>? matched = _exactMatch(rawName, menuItems);
      // Then fuzzy
      matched ??= _fuzzyMatch(rawName, menuItems);

      if (matched != null) {
        results.add(OrderResult(item: matched, quantity: qty, remarks: remarks));
      }
    }
    return results;
  }

  Map<String, dynamic>? _exactMatch(
      String name, List<Map<String, dynamic>> items) {
    final lower = name.toLowerCase();
    try {
      return items.firstWhere(
          (m) => m['name'].toString().toLowerCase() == lower);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _fuzzyMatch(
      String name, List<Map<String, dynamic>> items) {
    final lower = name.toLowerCase();
    // Contains match
    try {
      return items.firstWhere(
          (m) => m['name'].toString().toLowerCase().contains(lower));
    } catch (_) {}
    // Word overlap
    final qWords =
        lower.split(' ').where((w) => w.length > 2).toSet();
    Map<String, dynamic>? best;
    int bestScore = 0;
    for (final item in items) {
      final iWords = item['name']
          .toString()
          .toLowerCase()
          .split(' ')
          .where((w) => w.length > 2)
          .toSet();
      final score = qWords.intersection(iWords).length;
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }
    return bestScore > 0 ? best : null;
  }

  // ════════════════════════════════════════════════════════════════════════
  // LOCAL FALLBACK PARSER (works offline, no API needed)
  // ════════════════════════════════════════════════════════════════════════

  static const Map<String, int> _nums = {
    '1': 1, '2': 2, '3': 3, '4': 4, '5': 5,
    '6': 6, '7': 7, '8': 8, '9': 9, '10': 10,
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    'to': 2, 'too': 2, 'for': 4, 'free': 3,
    'ek': 1, 'do': 2, 'teen': 3, 'chaar': 4, 'char': 4,
    'paanch': 5, 'panch': 5, 'chhah': 6, 'chhe': 6,
    'saat': 7, 'sat': 7, 'aath': 8, 'nau': 9, 'das': 10,
    'be': 2, 'tran': 3, 'chha': 6,
  };

  static const Set<String> _seps = {
    'and', 'aur', 'ane', 'va', 'plus', 'also', 'then',
  };

  static const List<String> _remarks = [
    'no onion no garlic', 'less spicy please', 'more spicy please',
    'less spicy', 'more spicy', 'extra spicy', 'not spicy', 'no spicy',
    'without spice', 'no spice', 'no onion', 'without onion',
    'no garlic', 'without garlic', 'extra cheese', 'no cheese',
    'well done', 'half done', 'less oil', 'no oil',
    'less salt', 'no salt', 'take away', 'takeaway', 'parcel',
    'extra sauce', 'no sauce', 'spicy',
  ];

  static const Map<String, String> _fix = {
    'soap': 'soup', 'soop': 'soup',
    'chikin': 'chicken', 'chiken': 'chicken',
    'tika': 'tikka', 'tica': 'tikka',
    'alfam': 'alfaham', 'alfaam': 'alfaham', 'alphaam': 'alfaham',
    'thok': 'thukpa', 'malei': 'malai',
    'khubus': 'khaboos', 'berger': 'burger',
    'manchuri': 'manchurian', 'singapur': 'singapuri',
    'shezvan': 'shezwan', 'nudels': 'noodles',
  };

  List<OrderResult> _parseLocally(
      String raw, List<Map<String, dynamic>> menu) {
    String text = raw.toLowerCase().trim();
    _fix.forEach((w, r) => text = text.replaceAll(RegExp('\\b$w\\b'), r));

    // Extract global remarks
    final globalRemarks = <String>[];
    for (final rp in _remarks) {
      if (text.contains(rp)) {
        globalRemarks.add(_cap(rp));
        text = text.replaceAll(rp, ' ');
      }
    }

    final tokens = text
        .replaceAll(RegExp(r'[,\.]'), ' ')
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
      String segText = seg.words.join(' ');
      final segRemarks = <String>[];
      for (final rp in _remarks) {
        if (segText.contains(rp)) {
          segRemarks.add(_cap(rp));
          segText = segText.replaceAll(rp, ' ');
        }
      }
      final cleanWords = segText
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();

      final matched = _bestMatch(cleanWords, menu, used);
      if (matched == null) continue;
      used.add(matched['name'].toString());

      final remark = segRemarks.isNotEmpty
          ? segRemarks.join(', ')
          : segments.length == 1
              ? globalRemarks.join(', ')
              : '';
      results.add(
          OrderResult(item: matched, quantity: seg.qty, remarks: remark));
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

    for (final t in tokens) {
      if (_seps.contains(t)) { flush(); continue; }
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
      final norm = sc / iw.length;
      if (norm > bestScore) { bestScore = norm; best = item; }
    }
    return bestScore >= 0.55 ? best : null;
  }

  double _wSim(String a, String b) {
    if (a == b) return 2.0;
    if (b.startsWith(a) || a.startsWith(b)) return 1.5;
    int m = 0;
    final s = a.length <= b.length ? a : b;
    final l = a.length <= b.length ? b : a;
    for (int i = 0; i < s.length && i < l.length; i++) {
      if (s[i] == l[i]) m++;
    }
    return m / l.length;
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
