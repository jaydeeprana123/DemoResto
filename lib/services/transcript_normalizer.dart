// Post-processes STT output before menu alignment / AI parsing.

class TranscriptNormalizer {
  /// Fixes common Indian STT mistakes (e.g. Hindi "do" → English "double").
  static String normalize(String transcript) {
    if (transcript.trim().isEmpty) return transcript;

    var text = transcript;
    text = _fixDoubleAsQuantity(text);
    text = _collapseSpaces(text);
    return text;
  }

  /// Sarvam translit often writes Hindi/Gujarati "do" (2) as English "double".
  /// Keep "double" only when user likely meant the burger (patty/burger nearby).
  static String _fixDoubleAsQuantity(String text) {
    final lower = text.toLowerCase();

    final isDoublePattyOrder = RegExp(
      r'\b(double\s+patty|patty\s+burger|double\s+burger|double\s+patty\s+burger)\b',
      caseSensitive: false,
    ).hasMatch(lower);

    if (isDoublePattyOrder) return text;

    return text.replaceAllMapped(
      RegExp(r'\bdouble\b', caseSensitive: false),
      (_) => 'two',
    );
  }

  static String _collapseSpaces(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
