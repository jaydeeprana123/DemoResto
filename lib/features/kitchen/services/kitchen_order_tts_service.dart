import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:smartKitchen/features/kitchen/services/kitchen_cross_table_pending_index.dart';

/// Speaks a kitchen order aloud (qty + item name for each line).
class KitchenOrderTtsService {
  KitchenOrderTtsService._();
  static final KitchenOrderTtsService instance = KitchenOrderTtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  Future<void>? _initFuture;

  Future<void> ensureInitialized() {
    return _initFuture ??= _init();
  }

  Future<void> _init() async {
    try {
      await _applyIndianEnglishVoice();
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      if (!kIsWeb) {
        await _tts.awaitSpeakCompletion(true);
      }
      _ready = true;
    } catch (e, st) {
      debugPrint('[KitchenTTS] init failed: $e\n$st');
      _ready = false;
    }
  }

  /// Prefers an Indian English (en-IN) voice when the device provides one.
  Future<void> _applyIndianEnglishVoice() async {
    try {
      final available = await _tts.isLanguageAvailable('en-IN');
      final indianLanguageReady = available == true || available == 1;
      if (indianLanguageReady) {
        await _tts.setLanguage('en-IN');
      } else {
        await _tts.setLanguage('en-US');
      }
    } catch (e) {
      debugPrint('[KitchenTTS] setLanguage failed: $e');
      try {
        await _tts.setLanguage('en-US');
      } catch (_) {}
    }

    try {
      final rawVoices = await _tts.getVoices;
      if (rawVoices is! List) return;

      final voices = <Map<String, String>>[];
      for (final voice in rawVoices) {
        if (voice is! Map) continue;
        final name = '${voice['name'] ?? ''}'.trim();
        final locale = '${voice['locale'] ?? ''}'.trim();
        if (name.isEmpty && locale.isEmpty) continue;
        voices.add({'name': name, 'locale': locale});
      }
      if (voices.isEmpty) return;

      final indian = voices.where(_isIndianEnglishVoice).toList();
      final chosen = indian.isNotEmpty ? indian.first : null;
      if (chosen == null || chosen['name']!.isEmpty) return;

      await _tts.setVoice({
        'name': chosen['name']!,
        'locale': chosen['locale']!.isEmpty ? 'en-IN' : chosen['locale']!,
      });
      debugPrint(
        '[KitchenTTS] using voice "${chosen['name']}" '
        '(${chosen['locale']})',
      );
    } catch (e) {
      debugPrint('[KitchenTTS] setVoice failed: $e');
    }
  }

  static bool _isIndianEnglishVoice(Map<String, String> voice) {
    final locale = voice['locale']!.toLowerCase().replaceAll('_', '-');
    if (locale == 'en-in' || locale.startsWith('en-in-')) return true;

    final name = voice['name']!.toLowerCase();
    return name.contains('en-in') ||
        name.contains('en_in') ||
        name.contains('india') ||
        name.contains('indian');
  }

  /// Builds speech text like: "2 Chicken Burgers, 1 French Fries, 3 Cold Coffees."
  static String buildSpeechText(List<Map<String, dynamic>> items) {
    final phrases = <String>[];
    for (final item in items) {
      final name = item['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final qty = KitchenCrossTablePendingIndex.itemQty(item);
      final spokenName = qty <= 1 ? name : _pluralizeItemName(name);
      phrases.add('$qty $spokenName');
    }
    if (phrases.isEmpty) return '';
    return '${phrases.join(', ')}.';
  }

  Future<void> speakQtyAndName({required int qty, required String name}) {
    return speakOrder([
      {'qty': qty, 'name': name},
    ]);
  }

  Future<void> speakOrder(List<Map<String, dynamic>> items) async {
    final text = buildSpeechText(items);
    if (text.isEmpty) return;

    await ensureInitialized();
    if (!_ready) return;

    // Voices are sometimes empty during first init (web / Windows).
    await _applyIndianEnglishVoice();

    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e, st) {
      debugPrint('[KitchenTTS] speak failed: $e\n$st');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
  }

  /// Pluralizes the last word of a menu item name (e.g. "Chicken Burger" → "Chicken Burgers").
  static String _pluralizeItemName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return name;
    parts[parts.length - 1] = _pluralizeWord(parts.last);
    return parts.join(' ');
  }

  static String _pluralizeWord(String word) {
    if (word.isEmpty) return word;
    final lower = word.toLowerCase();

    // Already ends with "s" (Fries, Wings) — leave unchanged.
    if (lower.endsWith('s') &&
        !lower.endsWith('ss') &&
        !lower.endsWith('us')) {
      return word;
    }

    if (lower.endsWith('ss') ||
        lower.endsWith('sh') ||
        lower.endsWith('ch') ||
        lower.endsWith('x') ||
        lower.endsWith('z')) {
      return '${word}es';
    }

    if (lower.endsWith('y') && word.length > 1) {
      final beforeY = lower[lower.length - 2];
      if (!_isVowel(beforeY)) {
        return '${word.substring(0, word.length - 1)}ies';
      }
    }

    return '${word}s';
  }

  static bool _isVowel(String ch) =>
      ch == 'a' || ch == 'e' || ch == 'i' || ch == 'o' || ch == 'u';
}
