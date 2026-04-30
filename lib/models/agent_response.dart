import 'package:demo/services/ai_order_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum AgentAction {
  /// Confidence ≥ 0.8 — add items directly, go to confirmation screen.
  auto,

  /// Confidence 0.5–0.8 — show "Did you mean?" sheet for user confirmation.
  suggest,

  /// Confidence < 0.5 — ask user to speak again.
  retry,
}

enum AgentIntent {
  /// "same as last time", "usual", etc.
  repeat,

  /// "less spicy", "no onion", etc.
  modify,

  /// Normal new order.
  newOrder,
}

// ─────────────────────────────────────────────────────────────────────────────
// AgentResponse
// ─────────────────────────────────────────────────────────────────────────────

class AgentResponse {
  /// Parsed and preference-enriched order items.
  final List<OrderResult> items;

  /// Confidence score in [0.0, 1.0].
  final double confidence;

  /// Decision: auto / suggest / retry.
  final AgentAction action;

  /// Alternative suggestions shown in the "Did you mean?" sheet (suggest mode).
  final List<OrderResult> suggestions;

  /// Human-readable message shown to the user (for suggest / retry).
  final String message;

  /// What the user intended.
  final AgentIntent intent;

  const AgentResponse({
    required this.items,
    required this.confidence,
    required this.action,
    this.suggestions = const [],
    this.message = '',
    this.intent = AgentIntent.newOrder,
  });

  /// Convenience constructor for retry responses.
  factory AgentResponse.retry(String message) => AgentResponse(
        items: const [],
        confidence: 0.0,
        action: AgentAction.retry,
        message: message,
        intent: AgentIntent.newOrder,
      );

  @override
  String toString() =>
      'AgentResponse(action: $action, confidence: ${confidence.toStringAsFixed(2)}, '
      'items: ${items.length}, intent: $intent)';
}
