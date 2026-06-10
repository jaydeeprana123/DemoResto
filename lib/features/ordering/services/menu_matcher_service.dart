import 'package:demo/features/ordering/services/text_normalizer.dart';
import 'package:demo/features/ordering/utils/menu_item_variants.dart';

class MenuMatchResult {
  const MenuMatchResult({
    required this.item,
    required this.matchedName,
    required this.confidence,
    this.orderName,
  });

  final Map<String, dynamic> item;
  final String matchedName;
  final double confidence;

  /// Name passed to cart apply (variant line name when applicable).
  final String? orderName;
}

/// Fuzzy menu matching with aliases, token overlap, and string similarity.
class MenuMatcherService {
  MenuMatcherService._();
  static final MenuMatcherService instance = MenuMatcherService._();

  static const Set<String> _stopWords = {
    'and',
    'with',
    'the',
    'a',
    'an',
    'of',
    'for',
    'in',
    'on',
    'item',
    'order',
    'please',
    'give',
    'me',
    'one',
    'plate',
  };

  static const Map<String, String> _aliases = {
    'alfahm': 'alfaham',
    'alfam': 'alfaham',
    'alfaham rice': 'alfaham tukda rice',
    'tukda rice': 'alfaham tukda rice',
    'alfaham pieces': 'alfaham tukda rice',
    'alfaham piece': 'alfaham tukda rice',
    'open wrap': 'open shawarma',
    'peri peri wrap': 'peri peri shawarma',
    'peri peri fries': 'peri peri fries',
    'samoli bun': 'crispy samoli',
    'samoli': 'crispy samoli',
    'manchurian': 'manchurian',
    'fried rice': 'fried rice',
  };

  List<_IndexedMenuItem> buildIndex(List<Map<String, dynamic>> menuItems) {
    final index = <_IndexedMenuItem>[];
    for (final item in menuItems) {
      final names = <String>{};

      final display = MenuItemVariants.displayName(item);
      if (display.isNotEmpty) names.add(display);

      final rawName = item['name']?.toString() ?? '';
      if (rawName.isNotEmpty) names.add(rawName);

      if (MenuItemVariants.hasVariants(item)) {
        for (final variant in MenuItemVariants.variantsOf(item)) {
          final vName = variant['name']?.toString() ?? '';
          if (vName.isNotEmpty) names.add(vName);
        }
      }

      for (final name in names) {
        index.add(
          _IndexedMenuItem(
            item: item,
            searchableName: name,
            orderName: name,
            normalized: TextNormalizer.normalizeName(name),
            tokens: _meaningfulTokens(TextNormalizer.normalizeName(name)),
          ),
        );
      }
    }
    return index;
  }

  MenuMatchResult? matchQuery(
    String query,
    List<Map<String, dynamic>> menuItems, {
    Set<String> usedNames = const {},
  }) {
    if (query.trim().isEmpty) return null;

    var normalizedQuery = TextNormalizer.normalize(query);
    for (final entry in _aliases.entries) {
      if (normalizedQuery.contains(entry.key)) {
        normalizedQuery = normalizedQuery.replaceAll(entry.key, entry.value);
      }
    }

    final queryTokens = _meaningfulTokens(normalizedQuery);
    if (queryTokens.isEmpty) return null;

    final index = buildIndex(menuItems);
    MenuMatchResult? best;
    var bestScore = 0.0;

    for (final candidate in index) {
      if (usedNames.contains(candidate.orderName)) continue;

      final score = _scoreCandidate(
        normalizedQuery: normalizedQuery,
        queryTokens: queryTokens,
        candidate: candidate,
      );

      if (score > bestScore) {
        bestScore = score;
        best = MenuMatchResult(
          item: candidate.item,
          matchedName: candidate.searchableName,
          orderName: candidate.orderName,
          confidence: score.clamp(0.0, 1.0),
        );
      }
    }

    return bestScore >= 0.52 ? best : null;
  }

  Map<String, dynamic>? exactMatch(
    String name,
    List<Map<String, dynamic>> menuItems,
  ) {
    final normalized = TextNormalizer.normalizeName(name);
    for (final entry in buildIndex(menuItems)) {
      if (entry.normalized == normalized) return entry.item;
    }
    return null;
  }

  MenuMatchResult? fuzzyMatch(
    String name,
    List<Map<String, dynamic>> menuItems,
  ) =>
      matchQuery(name, menuItems);

  double _scoreCandidate({
    required String normalizedQuery,
    required List<String> queryTokens,
    required _IndexedMenuItem candidate,
  }) {
    var score = 0.0;

    if (candidate.normalized == normalizedQuery) return 1.0;

    if (candidate.normalized.contains(normalizedQuery) ||
        normalizedQuery.contains(candidate.normalized)) {
      score += 0.82;
    }

    final stringSim = _stringSimilarity(normalizedQuery, candidate.normalized);
    score += stringSim * 0.45;

    final overlap = _tokenOverlap(queryTokens, candidate.tokens);
    score += overlap * 0.55;

    for (final alias in _aliases.entries) {
      if (normalizedQuery.contains(alias.key) &&
          candidate.normalized.contains(alias.value)) {
        score += 0.12;
      }
    }

    return score;
  }

  List<String> _meaningfulTokens(String normalized) {
    return TextNormalizer.tokens(normalized)
        .where((t) => t.length > 1 && !_stopWords.contains(t))
        .toList();
  }

  double _tokenOverlap(List<String> queryTokens, List<String> menuTokens) {
    if (queryTokens.isEmpty || menuTokens.isEmpty) return 0;

    var matchedWeight = 0.0;
    for (final menuToken in menuTokens) {
      var best = 0.0;
      for (final queryToken in queryTokens) {
        best = [
          best,
          _stringSimilarity(queryToken, menuToken),
          menuToken.contains(queryToken) || queryToken.contains(menuToken)
              ? 0.85
              : 0.0,
        ].reduce((a, b) => a > b ? a : b);
      }
      matchedWeight += best;
    }

    return matchedWeight / menuTokens.length;
  }

  double _stringSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;

    if (a.contains(b) || b.contains(a)) {
      final shorter = a.length < b.length ? a.length : b.length;
      final longer = a.length > b.length ? a.length : b.length;
      return shorter / longer;
    }

    final distance = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    return 1.0 - (distance / maxLen);
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i++) {
      var current = i + 1;
      for (var j = 0; j < b.length; j++) {
        final insertCost = previous[j + 1] + 1;
        final deleteCost = current + 1;
        final replaceCost = previous[j] + (a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1);
        final next = [insertCost, deleteCost, replaceCost]
            .reduce((x, y) => x < y ? x : y);
        previous[j] = current;
        current = next;
      }
      previous[b.length] = current;
    }
    return previous[b.length];
  }
}

class _IndexedMenuItem {
  const _IndexedMenuItem({
    required this.item,
    required this.searchableName,
    required this.orderName,
    required this.normalized,
    required this.tokens,
  });

  final Map<String, dynamic> item;
  final String searchableName;
  final String orderName;
  final String normalized;
  final List<String> tokens;
}
