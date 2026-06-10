import 'package:demo/features/ordering/services/text_normalizer.dart';

class NotesParseResult {
  const NotesParseResult({
    required this.itemText,
    required this.notes,
  });

  final String itemText;
  final String notes;
}

/// Extracts modifier / remark phrases from an item segment.
class NotesParser {
  NotesParser._();

  static const List<(String, String)> _phraseToNote = [
    ('teekha kam', 'Less spicy'),
    ('tikha kam', 'Less spicy'),
    ('thoda kam tikha', 'Less spicy'),
    ('thoda kam spicy', 'Less spicy'),
    ('kam tikha', 'Less spicy'),
    ('kam spicy', 'Less spicy'),
    ('kam masala', 'Less spicy'),
    ('less spicy', 'Less spicy'),
    ('not spicy', 'Not spicy'),
    ('no spicy', 'Not spicy'),
    ('bilkul kam tikha', 'Not spicy'),
    ('zyada tikha', 'Extra spicy'),
    ('zyada spicy', 'Extra spicy'),
    ('extra spicy', 'Extra spicy'),
    ('extra cheese', 'Extra cheese'),
    ('kam tel', 'Less oil'),
    ('kam namak', 'Less salt'),
    ('no onion', 'No onion'),
    ('without onion', 'No onion'),
    ('no garlic', 'No garlic'),
    ('without garlic', 'No garlic'),
    ('no onion no garlic', 'No onion no garlic'),
    ('jain food', 'Jain'),
    ('jain item', 'Jain'),
    ('parcel karo', 'Parcel'),
    ('parcel me', 'Parcel'),
    ('packing', 'Parcel'),
    ('extra butter', 'Extra butter'),
    ('well done', 'Well done'),
  ];

  static const Set<String> _noteTokens = {
    'less',
    'extra',
    'no',
    'without',
    'parcel',
    'jain',
    'spicy',
    'tikha',
    'teekha',
    'kam',
    'zyada',
    'jyada',
    'butter',
    'onion',
    'garlic',
    'oil',
    'salt',
    'done',
    'packing',
  };

  static NotesParseResult split(String segmentText) {
    var text = TextNormalizer.normalize(segmentText);
    final notes = <String>[];

    for (final (phrase, note) in _phraseToNote) {
      if (text.contains(phrase)) {
        text = text.replaceAll(phrase, ' ').trim();
        if (!notes.contains(note)) notes.add(note);
      }
    }

    final tokens = TextNormalizer.tokens(text);
    final itemTokens = <String>[];
    final trailingNotes = <String>[];

    var inNoteTail = false;
    for (final token in tokens) {
      if (!inNoteTail &&
          (_noteTokens.contains(token) ||
              token == 'and' && trailingNotes.isNotEmpty)) {
        inNoteTail = true;
      }
      if (inNoteTail) {
        trailingNotes.add(token);
      } else {
        itemTokens.add(token);
      }
    }

    if (trailingNotes.isNotEmpty) {
      final tail = trailingNotes.join(' ');
      final mapped = _mapTailToNote(tail);
      if (mapped.isNotEmpty && !notes.contains(mapped)) {
        notes.add(mapped);
      }
    }

    final itemText = itemTokens.join(' ').trim();
    return NotesParseResult(
      itemText: itemText.isEmpty ? text : itemText,
      notes: notes.join(', '),
    );
  }

  static String normalizeNotes(String raw) {
    if (raw.trim().isEmpty) return '';
    final result = split(raw);
    if (result.notes.isNotEmpty) return result.notes;
    final text = raw.trim();
    return text.isEmpty ? '' : text[0].toUpperCase() + text.substring(1);
  }

  static String _mapTailToNote(String tail) {
    final normalizedTail = TextNormalizer.normalize(tail);
    for (final (phrase, note) in _phraseToNote) {
      if (normalizedTail.contains(phrase)) return note;
    }
    if (normalizedTail.contains('kam') &&
        (normalizedTail.contains('spicy') ||
            normalizedTail.contains('tikha') ||
            normalizedTail.contains('teekha'))) {
      return 'Less spicy';
    }
    if (normalizedTail.contains('zyada') &&
        (normalizedTail.contains('spicy') ||
            normalizedTail.contains('tikha'))) {
      return 'Extra spicy';
    }
    if (tail.isEmpty) return '';
    return tail[0].toUpperCase() + tail.substring(1);
  }
}
