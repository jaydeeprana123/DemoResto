import 'package:flutter/foundation.dart';

import 'package:demo/models/agent_response.dart';
import 'package:demo/models/user_data.dart';
import 'package:demo/services/ai_order_service.dart';
import 'package:demo/services/user_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RestaurantAgentService
//
// Sits ON TOP of AiOrderService — does NOT replace it.
// Adds: intent detection, Firestore memory, confidence scoring,
//       menu filtering, preference injection, and 3-path decision engine.
// ─────────────────────────────────────────────────────────────────────────────

class RestaurantAgentService {
  static final RestaurantAgentService _instance =
      RestaurantAgentService._internal();
  factory RestaurantAgentService() => _instance;
  RestaurantAgentService._internal();

  final AiOrderService _aiService = AiOrderService();
  final UserDataService _userDataService = UserDataService();

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC: handleInput
  // ══════════════════════════════════════════════════════════════════════════

  /// Main entry point called from MenuPage instead of AiOrderService.parseOrder().
  ///
  /// [userText]  — raw speech-to-text result
  /// [menuItems] — full menu list from Firestore / local state
  /// [userData]  — pass if already loaded; will be fetched if null
  Future<AgentResponse> handleInput({
    required String userText,
    required List<Map<String, dynamic>> menuItems,
    UserData? userData,
  }) async {
    final text = userText.trim();

    if (text.isEmpty) {
      return AgentResponse.retry('Please speak your order clearly.');
    }

    // 1. Load user data (memory)
    final data = userData ?? await _userDataService.getUserData();

    // 2. Detect intent
    final intent = detectIntent(text);
    debugPrint('[Agent] Intent=$intent  text="$text"');

    // 3. Repeat order — load last order directly
    if (intent == AgentIntent.repeat) {
      final lastItems = await getLastOrder(menuItems, data);
      if (lastItems.isNotEmpty) {
        final enriched = applyPreferences(lastItems, data.preferences);
        return AgentResponse(
          items: enriched,
          confidence: 0.92, // repeat is inherently high confidence
          action: AgentAction.auto,
          intent: intent,
          message: 'Repeating your last order.',
        );
      }
      // No prior order in memory — fall through to normal parse
    }

    // 4. Filter menu to top-30 relevant items (faster + more accurate AI)
    // Use full menu for max accuracy (Gemini handles large context easily)
    final filteredMenu = menuItems;

    // 5. Parse via AiOrderService (Gemini → local fallback)
    List<OrderResult> results;
    try {
      results = await _aiService.parseOrder(text, filteredMenu);
    } catch (e) {
      debugPrint('[Agent] AiOrderService threw: $e — using empty results');
      results = [];
    }

    // 6. Inject user preferences into remarks
    var enriched = applyPreferences(results, data.preferences);

    // 7. Score confidence
    final confidence = calculateConfidence(
      results: enriched,
      intent: intent,
      menuItems: menuItems,
      favorites: data.favoriteItems,
      inputText: text,
    );

    debugPrint(
      '[Agent] confidence=${confidence.toStringAsFixed(2)}  '
      'items=${enriched.length}',
    );

    // 8. Decision engine
    if (enriched.isEmpty) {
      return AgentResponse.retry(
        "Sorry, I couldn't recognise those items. Please try again.",
      );
    }

    if (confidence >= 0.8) {
      return AgentResponse(
        items: enriched,
        confidence: confidence,
        action: AgentAction.auto,
        intent: intent,
      );
    }

    if (confidence >= 0.5) {
      return AgentResponse(
        items: enriched,
        confidence: confidence,
        action: AgentAction.suggest,
        suggestions: enriched,
        intent: intent,
        message: _buildSuggestMessage(enriched),
      );
    }

    return AgentResponse(
      items: enriched,
      confidence: confidence,
      action: AgentAction.retry,
      intent: intent,
      message: "I'm not sure what you ordered. Please speak again.",
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // detectIntent
  // ══════════════════════════════════════════════════════════════════════════

  AgentIntent detectIntent(String text) {
    final lower = text.toLowerCase();

    const repeatPhrases = [
      'same as last time',
      'same as before',
      'usual',
      'same again',
      'same order',
      'previous order',
      'last order',
      'repeat order',
      'repeat',
      'phir same',
      'same laao',
      'pehle jaisa',
      'pahela jevi',
      'same apo',
      'aapu che je aavtu',
    ];
    for (final p in repeatPhrases) {
      if (lower.contains(p)) return AgentIntent.repeat;
    }

    const modifyPhrases = [
      'less spicy',
      'more spicy',
      'no onion',
      'without onion',
      'no garlic',
      'without garlic',
      'change',
      'modify',
      'instead',
      'replace',
      'swap',
      'not spicy',
      'jain',
      'without',
    ];
    for (final p in modifyPhrases) {
      if (lower.contains(p)) return AgentIntent.modify;
    }

    return AgentIntent.newOrder;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // filterMenuByContext — pre-AI menu pruning
  // ══════════════════════════════════════════════════════════════════════════

  List<Map<String, dynamic>> filterMenuByContext(
    String text,
    List<Map<String, dynamic>> menu,
  ) {
    // Only filter when menu is large enough to matter
    if (menu.length <= 30) return menu;

    final inputWords = text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toSet();

    if (inputWords.isEmpty) return menu.take(30).toList();

    final scored = menu.map((item) {
      final nameWords = item['name']
          .toString()
          .toLowerCase()
          .split(' ')
          .where((w) => w.length > 1)
          .toSet();

      // Exact word overlap (weighted 3×)
      int score = inputWords.intersection(nameWords).length * 3;

      // Partial / prefix match (weighted 1×)
      for (final iw in inputWords) {
        for (final nw in nameWords) {
          if (nw.contains(iw) || iw.contains(nw)) score += 1;
        }
      }
      return (item: item, score: score);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return scored.take(30).map((e) => e.item).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // applyPreferences — inject user prefs into OrderResult remarks
  // ══════════════════════════════════════════════════════════════════════════

  List<OrderResult> applyPreferences(
    List<OrderResult> results,
    UserPreferences? prefs,
  ) {
    if (prefs == null) return results;

    return results.map((r) {
      final parts = <String>[];
      if (r.remarks.isNotEmpty) parts.add(r.remarks);

      final remarksLower = r.remarks.toLowerCase();

      // Spicy level — only inject if not already mentioned
      if (!remarksLower.contains('spic')) {
        switch (prefs.spicyLevel) {
          case 'none':
            parts.add('Not spicy');
            break;
          case 'less':
            parts.add('Less spicy');
            break;
          case 'extra':
            parts.add('Extra spicy');
            break;
          default:
            break; // 'medium' → no remark needed
        }
      }

      if (prefs.noOnion && !remarksLower.contains('onion')) {
        parts.add('No onion');
      }
      if (prefs.noGarlic && !remarksLower.contains('garlic')) {
        parts.add('No garlic');
      }
      if (prefs.isParcel &&
          !remarksLower.contains('parcel') &&
          !remarksLower.contains('take')) {
        parts.add('Parcel');
      }

      return OrderResult(
        item: r.item,
        quantity: r.quantity,
        remarks: parts.join(', '),
      );
    }).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // calculateConfidence
  // ══════════════════════════════════════════════════════════════════════════

  double calculateConfidence({
    required List<OrderResult> results,
    required AgentIntent intent,
    required List<Map<String, dynamic>> menuItems,
    required List<FavoriteItem> favorites,
    required String inputText,
  }) {
    if (results.isEmpty) return 0.1;

    double score = 0.30; // base — non-empty results

    // Intent signal
    if (intent == AgentIntent.repeat) score += 0.25;
    if (intent == AgentIntent.modify) score += 0.05;

    // Input quality (longer = clearer speech)
    final wordCount = inputText.trim().split(RegExp(r'\s+')).length;
    if (wordCount >= 5) {
      score += 0.10;
    } else if (wordCount >= 3) {
      score += 0.05;
    }

    // Per-item quality signals
    final favNames = favorites.map((f) => f.name.toLowerCase()).toSet();
    final menuNames = menuItems
        .map((m) => m['name'].toString().toLowerCase())
        .toSet();

    double itemBonus = 0.0;
    for (final r in results) {
      final name = r.item['name'].toString().toLowerCase();
      if (menuNames.contains(name)) itemBonus += 0.08; // validated in menu
      if (favNames.contains(name)) itemBonus += 0.12; // user orders this often
    }

    score += itemBonus.clamp(0.0, 0.35);

    return score.clamp(0.0, 1.0);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // getLastOrder — resolve last order items against current menu
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<OrderResult>> getLastOrder(
    List<Map<String, dynamic>> menuItems,
    UserData? userData,
  ) async {
    final data = userData ?? await _userDataService.getUserData();

    if (data.lastOrders.isEmpty) return [];

    final lastOrder = data.lastOrders.first; // most recent
    final results = <OrderResult>[];

    for (final li in lastOrder.items) {
      // Find corresponding live menu item (price may have changed)
      final menuItem = _findInMenu(li.name, menuItems);
      if (menuItem != null) {
        results.add(OrderResult(
          item: menuItem,
          quantity: li.quantity,
          remarks: li.remarks,
        ));
      }
    }

    return results;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // saveOrderToHistory — call after user confirms order
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> saveOrderToHistory(List<OrderResult> results) async {
    await _userDataService.saveLastOrder(results);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Private helpers
  // ══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic>? _findInMenu(
    String name,
    List<Map<String, dynamic>> menu,
  ) {
    final lower = name.toLowerCase();
    try {
      return menu.firstWhere(
        (m) => m['name'].toString().toLowerCase() == lower,
      );
    } catch (_) {}
    // Fuzzy: contains
    try {
      return menu.firstWhere(
        (m) => m['name'].toString().toLowerCase().contains(lower),
      );
    } catch (_) {}
    return null;
  }

  String _buildSuggestMessage(List<OrderResult> items) {
    if (items.isEmpty) return 'Did you mean something from the menu?';
    final names = items.map((r) => r.item['name']).join(', ');
    return 'Did you mean: $names?';
  }
}
