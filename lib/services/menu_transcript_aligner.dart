// Aligns STT transcript fragments to exact Firebase menu names.

class MenuTranscriptAligner {
  /// Replaces fuzzy menu-like spans in [transcript] with exact [menuNames].
  static String align(String transcript, List<String> menuNames) {
    if (transcript.trim().isEmpty || menuNames.isEmpty) return transcript;

    final sorted = List<String>.from(menuNames)
      ..sort((a, b) => b.length.compareTo(a.length));

    var result = transcript;
    for (final menuName in sorted) {
      final match = _findBestSpan(result, menuName);
      if (match != null && match.score >= 0.58) {
        result = result.replaceRange(match.start, match.end, menuName);
      }
    }
    return result;
  }

  static _SpanMatch? _findBestSpan(String text, String menuName) {
    final textTokens = _indexedTokens(text.toLowerCase());
    final menuTokens = _tokens(menuName);
    if (textTokens.isEmpty || menuTokens.isEmpty) return null;

    _SpanMatch? best;
    var bestScore = 0.0;

    for (var i = 0; i < textTokens.length; i++) {
      for (var len = menuTokens.length;
          len <= menuTokens.length + 2 && i + len <= textTokens.length;
          len++) {
        final slice = textTokens.sublist(i, i + len);
        final spoken = slice.map((e) => e.token).join(' ');
        final score = _similarity(spoken, menuTokens.join(' '));
        if (score < 0.58) continue;

        if (best == null || score > bestScore) {
          bestScore = score;
          best = _SpanMatch(
            start: slice.first.start,
            end: slice.last.end,
            score: score,
          );
        }
      }
    }
    return best;
  }

  static List<_IndexedToken> _indexedTokens(String text) {
    final out = <_IndexedToken>[];
    final re = RegExp(r'[a-z0-9&]+', caseSensitive: false);
    for (final m in re.allMatches(text)) {
      final token = _normalizeToken(m.group(0)!);
      if (token.length < 2 && !_qtyWords.contains(token)) continue;
      out.add(_IndexedToken(token: token, start: m.start, end: m.end));
    }
    return out;
  }

  static List<String> _tokens(String s) =>
      s
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .map(_normalizeToken)
          .where((w) => w.isNotEmpty)
          .toList();

  static String _normalizeToken(String token) => _alias[token] ?? token;

  static double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.contains(b) || b.contains(a)) return 0.9;

    final aw = a.split(' ');
    final bw = b.split(' ');
    var matched = 0;
    for (final w in aw) {
      if (bw.any((x) => x == w || x.contains(w) || w.contains(x))) matched++;
    }
    final overlap = aw.isEmpty ? 0.0 : matched / aw.length;

    final la = a.replaceAll(' ', '');
    final lb = b.replaceAll(' ', '');
    var chars = 0;
    final minLen = la.length < lb.length ? la.length : lb.length;
    for (var i = 0; i < minLen; i++) {
      if (la[i] == lb[i]) chars++;
    }
    final positional = minLen == 0 ? 0.0 : chars / minLen;

    return (overlap * 0.7) + (positional * 0.3);
  }

  static const _qtyWords = {
    'ek', 'one', 'do', 'be', 'two', 'teen', 'tran', 'three', 'char', 'chaar',
    'four', 'panch', 'paanch', 'five', 'chhe', 'chha', 'six', 'saat', 'sat',
    'seven', 'aath', 'ath', 'eight', 'nav', 'nine', 'das', 'ten', 'table',
  };

  static const Map<String, String> _alias = {
    'alfam': 'alfaham',
    'alfaam': 'alfaham',
    'alpham': 'alfaham',
    'alphaam': 'alfaham',
    'tukda': 'tukda',
    'tokda': 'tukda',
    'alfaham': 'alfaham',
    'garden': 'garden',
    'char': 'char',
    'bag': 'bag',
    'makhni': 'makhni',
    'popcorn': 'popcorn',
  };
}

class _SpanMatch {
  final int start;
  final int end;
  final double score;
  const _SpanMatch({required this.start, required this.end, required this.score});
}

class _IndexedToken {
  final String token;
  final int start;
  final int end;
  const _IndexedToken({required this.token, required this.start, required this.end});
}
