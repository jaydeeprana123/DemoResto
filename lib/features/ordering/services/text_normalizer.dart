/// Normalises spoken / STT text for menu matching.
class TextNormalizer {
  TextNormalizer._();

  static const Map<String, String> tokenFixes = {
    'soap': 'soup',
    'soop': 'soup',
    'sop': 'soup',
    'chikin': 'chicken',
    'chiken': 'chicken',
    'chick': 'chicken',
    'chikn': 'chicken',
    'chickan': 'chicken',
    'tika': 'tikka',
    'tica': 'tikka',
    'cook': 'coke',
    'coc': 'coke',
    'bear': 'beer',
    'pan': 'paneer',
    'paner': 'paneer',
    'panner': 'paneer',
    'biriyani': 'biryani',
    'briyani': 'biryani',
    'alfam': 'alfaham',
    'alfaam': 'alfaham',
    'alpham': 'alfaham',
    'alfahm': 'alfaham',
    'alfaham': 'alfaham',
    'pieces': 'tukda',
    'piece': 'tukda',
    'tokda': 'tukda',
    'toka': 'tukda',
    'samoli': 'samoli',
    'samoly': 'samoli',
    'lebnani': 'lebnani',
    'khaboos': 'khaboos',
    'khubus': 'khaboos',
    'zafrani': 'zafrani',
    'pahadi': 'pahadi',
    'surti': 'surti',
    'lolipop': 'lolipop',
    'lollipop': 'lolipop',
    'talmari': 'talmari',
    'hakka': 'hakka',
    'manchurian': 'manchurian',
    'manchuri': 'manchurian',
    'crispi': 'crispy',
    'krispi': 'crispy',
    'singapur': 'singapuri',
    'shezvan': 'shezwan',
    'nudels': 'noodles',
    'noodels': 'noodles',
    'fryed': 'fried',
    'shower': 'shawarma',
    'shavarma': 'shawarma',
    'shwarma': 'shawarma',
  };

  /// Phrase-level replacements applied before tokenisation.
  static const List<(String, String)> phraseFixes = [
    ('alfaham rice pieces', 'alfaham tukda rice'),
    ('alfahm rice pieces', 'alfaham tukda rice'),
    ('alfaham rice piece', 'alfaham tukda rice'),
    ('open wrap', 'open shawarma'),
    ('crispy samoli', 'crispy samoli'),
  ];

  static String normalize(String raw) {
    var text = raw.toLowerCase().trim();
    text = text.replaceAll('&', ' and ');
    text = text.replaceAll(RegExp(r'\s*\([^)]*\)'), ' ');
    text = text.replaceAll(RegExp(r'[^\w\s]'), ' ');

    for (final (phrase, replacement) in phraseFixes) {
      text = text.replaceAll(phrase, replacement);
    }

    for (final entry in tokenFixes.entries) {
      text = text.replaceAll(RegExp('\\b${entry.key}\\b'), entry.value);
    }

    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<String> tokens(String normalized) =>
      normalized.split(' ').where((t) => t.isNotEmpty).toList();

  static String stripParens(String name) =>
      name.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

  static String normalizeName(String name) =>
      normalize(stripParens(name.replaceAll('&', ' and ')));
}
