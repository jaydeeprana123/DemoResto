import 'package:flutter/foundation.dart';

/// Extracts orders by matching longest menu names directly in the transcript
/// (before Gemini), reducing wrong rice / phantom burger matches.
class MenuFirstParser {
  static const _nums = {
    '1': 1, '2': 2, '3': 3, '4': 4, '5': 5,
    '6': 6, '7': 7, '8': 8, '9': 9, '10': 10,
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    'to': 2, 'too': 2, 'for': 4,
    'ek': 1, 'do': 2, 'teen': 3, 'chaar': 4, 'char': 4,
    'paanch': 5, 'panch': 5, 'chhe': 6, 'chha': 6,
    'saat': 7, 'sat': 7, 'aath': 8, 'nau': 9, 'das': 10,
    'be': 2, 'tran': 3, 'nav': 9,
  };

  static const _generic = {
    'rice', 'chicken', 'fried', 'noodle', 'noodles', 'burger', 'soup',
    'tikka', 'crispy', 'grill', 'special', 'masala', 'garlic',
  };

  static const _alias = {
    'alfam': 'alfaham',
    'alfaam': 'alfaham',
    'alpham': 'alfaham',
    'alphaam': 'alfaham',
    'tokda': 'tukda',
  };

  static List<MenuFirstHit> extract(
    String transcript,
    List<Map<String, dynamic>> menuItems,
  ) {
    if (transcript.trim().isEmpty || menuItems.isEmpty) return [];

    final text = _normalize(transcript);
    final sorted = List<Map<String, dynamic>>.from(menuItems)
      ..sort((a, b) =>
          b['name'].toString().length.compareTo(a['name'].toString().length));

    final hits = <_Hit>[];

    for (final item in sorted) {
      final nameNorm = _normalize(item['name'].toString());
      if (nameNorm.isEmpty) continue;

      final pattern = RegExp(
        r'(?<!\w)' + RegExp.escape(nameNorm) + r'(?!\w)',
        caseSensitive: false,
      );

      for (final m in pattern.allMatches(text)) {
        hits.add(_Hit(
          start: m.start,
          end: m.end,
          item: item,
          qty: _qtyBefore(text, m.start),
        ));
      }
    }

    if (hits.isEmpty) {
      hits.addAll(_fuzzyHits(text, sorted));
    }

    hits.sort((a, b) => a.start.compareTo(b.start));

    final results = <MenuFirstHit>[];
    var lastEnd = -1;

    for (final h in hits) {
      if (h.start < lastEnd) continue;
      results.add(MenuFirstHit(item: h.item, quantity: h.qty));
      lastEnd = h.end;
      debugPrint(
        '[MenuFirstParser] ✅ ${h.item['name']} x${h.qty}',
      );
    }

    return results;
  }

  static List<_Hit> _fuzzyHits(
    String text,
    List<Map<String, dynamic>> sortedMenu,
  ) {
    final tokens = _tokenize(text);
    if (tokens.isEmpty) return [];

    final hits = <_Hit>[];

    for (final item in sortedMenu) {
      final nameTokens = _tokenize(_normalize(item['name'].toString()));
      if (nameTokens.isEmpty) continue;

      final distinctive =
          nameTokens.map((t) => t.word).where((w) => !_generic.contains(w)).toList();
      if (distinctive.isEmpty) continue;

      for (var i = 0; i < tokens.length; i++) {
        var matched = false;
        for (var len = nameTokens.length;
            len <= nameTokens.length + 1 && i + len <= tokens.length;
            len++) {
          final slice = tokens.sublist(i, i + len);
          final spoken = slice.map((e) => e.word).join(' ');
          final target = nameTokens.map((e) => e.word).join(' ');
          final score = _similarity(spoken, target);
          if (score < 0.72) continue;

          final strongInSlice =
              distinctive.where((d) => slice.any((t) => t.word == d)).length;
          if (strongInSlice == 0) continue;

          hits.add(_Hit(
            start: slice.first.start,
            end: slice.last.end,
            item: item,
            qty: _qtyBefore(text, slice.first.start),
          ));
          matched = true;
          break;
        }
        if (matched) break;
      }
    }

    return hits;
  }

  static int _qtyBefore(String text, int itemStart) {
    final before = text.substring(0, itemStart).trim();
    if (before.isEmpty) return 1;

    final tokens =
        before.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    for (var i = tokens.length - 1; i >= 0 && i >= tokens.length - 4; i--) {
      final t = _alias[tokens[i]] ?? tokens[i];
      final n = _nums[t];
      if (n != null) return n.clamp(1, 99);
    }
    return 1;
  }

  static String _normalize(String s) {
    var t = s.toLowerCase().replaceAll('&', 'and');
    t = t.replaceAll(RegExp(r'\s*\(.*?\)'), '');
    for (final e in _alias.entries) {
      t = t.replaceAll(RegExp('\\b${e.key}\\b'), e.value);
    }
    return t
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<_Tok> _tokenize(String text) {
    final out = <_Tok>[];
    final re = RegExp(r'[a-z0-9]+', caseSensitive: false);
    for (final m in re.allMatches(text)) {
      final raw = m.group(0)!;
      final word = _alias[raw] ?? raw;
      if (word.length < 2 && !_nums.containsKey(word)) continue;
      out.add(_Tok(word: word, start: m.start, end: m.end));
    }
    return out;
  }

  static double _similarity(String a, String b) {
    if (a == b) return 1.0;
    final aw = a.split(' ');
    final bw = b.split(' ');
    var matched = 0;
    for (final w in aw) {
      if (bw.any((x) => x == w || x.startsWith(w) || w.startsWith(x))) {
        matched++;
      }
    }
    return aw.isEmpty ? 0 : matched / aw.length;
  }
}

class MenuFirstHit {
  final Map<String, dynamic> item;
  final int quantity;
  const MenuFirstHit({required this.item, required this.quantity});
}

class _Hit {
  final int start;
  final int end;
  final Map<String, dynamic> item;
  final int qty;
  const _Hit({
    required this.start,
    required this.end,
    required this.item,
    required this.qty,
  });
}

class _Tok {
  final String word;
  final int start;
  final int end;
  const _Tok({required this.word, required this.start, required this.end});
}
