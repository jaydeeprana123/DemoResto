import 'package:demo/features/ordering/services/text_normalizer.dart';

class QuantitySegment {
  const QuantitySegment({
    required this.qty,
    required this.text,
  });

  final int qty;
  final String text;
}

/// Extracts quantity + item phrase segments from normalised speech text.
class QuantityParser {
  QuantityParser._();

  static const Map<String, int> _numbers = {
    '1': 1,
    '2': 2,
    '3': 3,
    '4': 4,
    '5': 5,
    '6': 6,
    '7': 7,
    '8': 8,
    '9': 9,
    '10': 10,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'to': 2,
    'too': 2,
    'for': 4,
    'free': 3,
    'ek': 1,
    'aek': 1,
    'do': 2,
    'teen': 3,
    'tran': 3,
    'chaar': 4,
    'char': 4,
    'paanch': 5,
    'panch': 5,
    'pach': 5,
    'chhah': 6,
    'chhe': 6,
    'chha': 6,
    'saat': 7,
    'sat': 7,
    'saath': 7,
    'aath': 8,
    'aat': 8,
    'nau': 9,
    'nav': 9,
    'das': 10,
    'be': 2,
  };

  static const Set<String> _separators = {
    ',',
    '.',
    'plus',
    'and',
    'aur',
    'va',
    'also',
    'then',
    'ne',
    'tatha',
    'sathe',
    'with',
  };

  static List<QuantitySegment> parseSegments(String normalizedText) {
    final tokens = TextNormalizer.tokens(normalizedText);
    if (tokens.isEmpty) return const [];

    final segments = <QuantitySegment>[];
    var pendingQty = 1;
    var hasQty = false;
    final buffer = <String>[];

    void flush({int? overrideQty}) {
      if (buffer.isEmpty) return;
      segments.add(
        QuantitySegment(
          qty: overrideQty ?? pendingQty,
          text: buffer.join(' ').trim(),
        ),
      );
      buffer.clear();
      pendingQty = 1;
      hasQty = false;
    }

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      if (_separators.contains(token)) {
        flush();
        continue;
      }

      final asNumber = _numbers[token];
      if (asNumber != null) {
        if (!hasQty && buffer.isEmpty) {
          pendingQty = asNumber;
          hasQty = true;
        } else if (!hasQty && buffer.isNotEmpty) {
          flush(overrideQty: asNumber);
        } else {
          flush();
          pendingQty = asNumber;
          hasQty = true;
        }
        continue;
      }

      buffer.add(token);
    }

    flush();

    if (segments.isEmpty && tokens.isNotEmpty) {
      return [QuantitySegment(qty: 1, text: tokens.join(' '))];
    }

    return segments.where((s) => s.text.isNotEmpty).toList();
  }
}
