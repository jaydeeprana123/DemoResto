import 'package:demo/features/ordering/models/parsed_order.dart';
import 'package:demo/features/ordering/models/parsed_order_item.dart';
import 'package:demo/features/ordering/services/menu_matcher_service.dart';
import 'package:demo/features/ordering/services/notes_parser.dart';
import 'package:demo/features/ordering/services/quantity_parser.dart';
import 'package:demo/features/ordering/services/text_normalizer.dart';
import 'package:demo/models/agent_response.dart';
import 'package:demo/services/ai_order_service.dart';
import 'package:demo/services/restaurant_agent_service.dart';
import 'package:demo/services/sarvam_stt_service.dart';
import 'package:flutter/foundation.dart';

/// Orchestrates STT, local fuzzy parsing, and AI/agent routing.
class SpeechOrderRepository {
  SpeechOrderRepository({
    SarvamSttService? sttService,
    RestaurantAgentService? agentService,
    AiOrderService? aiOrderService,
    MenuMatcherService? menuMatcher,
  })  : _sttService = sttService ?? SarvamSttService(),
        _agentService = agentService ?? RestaurantAgentService(),
        _aiOrderService = aiOrderService ?? AiOrderService(),
        _menuMatcher = menuMatcher ?? MenuMatcherService.instance;

  final SarvamSttService _sttService;
  final RestaurantAgentService _agentService;
  final AiOrderService _aiOrderService;
  final MenuMatcherService _menuMatcher;

  SarvamSttService get sttService => _sttService;

  Future<bool> hasMicrophonePermission() => _sttService.hasPermission();

  Future<bool> startRecording() => _sttService.startRecording();

  Future<void> cancelRecording() => _sttService.cancelRecording();

  Future<double> currentAmplitude() => _sttService.getAmplitude();

  Future<String?> stopAndTranscribe() => _sttService.stopAndTranscribe();

  ParsedOrder parseLocally(
    String transcript,
    List<Map<String, dynamic>> menuItems,
  ) {
    final normalized = TextNormalizer.normalize(transcript);
    final segments = QuantityParser.parseSegments(normalized);
    final usedNames = <String>{};
    final parsedItems = <ParsedOrderItem>[];

    for (final segment in segments) {
      final split = NotesParser.split(segment.text);
      final match = _menuMatcher.matchQuery(
        split.itemText,
        menuItems,
        usedNames: usedNames,
      );

      if (match == null) continue;

      usedNames.add(match.orderName ?? match.matchedName);
      parsedItems.add(
        ParsedOrderItem(
          name: match.orderName ?? match.matchedName,
          qty: segment.qty,
          notes: split.notes,
          confidence: match.confidence,
          menuItem: match.item,
        ),
      );
    }

    final confidence = parsedItems.isEmpty
        ? 0.0
        : parsedItems.map((e) => e.confidence).reduce((a, b) => a + b) /
            parsedItems.length;

    return ParsedOrder(
      items: parsedItems,
      transcript: transcript,
      confidence: confidence,
      source: ParsedOrderSource.local,
    );
  }

  Future<ParsedOrder> parseTranscript(
    String transcript,
    List<Map<String, dynamic>> menuItems,
  ) async {
    final local = parseLocally(transcript, menuItems);
    if (local.items.isNotEmpty && local.averageItemConfidence >= 0.62) {
      return local;
    }

    final aiResults = await _aiOrderService.parseOrder(transcript, menuItems);
    if (aiResults.isEmpty) return local;

    return ParsedOrder(
      items: aiResults
          .map(
            (r) => ParsedOrderItem(
              name: r.applyName ?? r.item['name']?.toString() ?? '',
              qty: r.quantity,
              notes: r.remarks,
              confidence: 0.78,
              menuItem: r.item,
            ),
          )
          .toList(),
      transcript: transcript,
      confidence: 0.78,
      source: ParsedOrderSource.gemini,
    );
  }

  Future<AgentResponse> processVoiceOrder({
    required String transcript,
    required List<Map<String, dynamic>> menuItems,
  }) {
    return _agentService.handleInput(
      userText: transcript,
      menuItems: menuItems,
    );
  }

  List<OrderResult> parsedOrderToResults(ParsedOrder order) {
    return order.items
        .where((item) => item.menuItem != null)
        .map(
          (item) => OrderResult(
            item: item.menuItem!,
            quantity: item.qty,
            remarks: item.notes,
            applyName: item.name,
          ),
        )
        .toList();
  }
}
