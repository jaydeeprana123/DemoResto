import 'dart:convert';
import 'dart:typed_data';

import 'package:demo/features/zomato/models/zomato_extracted_order.dart';
import 'package:demo/services/ai_order_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ZomatoScreenshotExtractionService {
  static const _apiKey = 'AIzaSyBz_YVM6SrTCL-HFA3FG6SkHZ3T5h6VgBc';
  static const _model = 'gemini-1.5-flash';
  static const _url =
      'https://generativelanguage.googleapis.com/v1/models/$_model:generateContent?key=$_apiKey';

  final AiOrderService _aiOrderService = AiOrderService();

  Future<ZomatoExtractedOrder> extractAndMatch({
    required Uint8List imageBytes,
    required List<Map<String, dynamic>> menuItems,
    String? fileName,
  }) async {
    final raw = await _callGeminiVision(imageBytes, fileName: fileName);
    return _parseAndMatch(raw, menuItems);
  }

  Future<Map<String, dynamic>> _callGeminiVision(
    Uint8List imageBytes, {
    String? fileName,
  }) async {
    final mimeType = _mimeType(imageBytes, fileName);
    final base64Data = base64Encode(imageBytes);

    const prompt = '''
You are reading a Zomato partner / restaurant order screenshot.

Extract the order details and return ONLY valid JSON (no markdown, no explanation).

Rules:
- Read every food item line visible on the screenshot.
- "quantity" is the numeric count (default 1 if not shown).
- "name" is the dish name exactly as shown (without quantity prefix like "2 x").
- "remarks" captures add-ons, customizations, cooking notes, variants (empty string if none).
- "zomatoOrderNumber" is the Zomato order ID if visible (digits only, no #), else null.
- "orderTime" is the time shown on the order if visible, else null.
- "totalAmount" is the order total/grand total as a number if visible, else null.
- Ignore delivery fees, taxes breakdown, rider info, and UI chrome.
- If the image is not a Zomato order screenshot, return {"items":[]}.

Return format (strict):
{
  "zomatoOrderNumber": "STRING_OR_NULL",
  "orderTime": "STRING_OR_NULL",
  "totalAmount": NUMBER_OR_NULL,
  "items": [
    {"name":"ITEM_NAME","quantity":NUMBER,"remarks":"MODIFIER_OR_EMPTY_STRING"}
  ]
}''';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Data,
              },
            },
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 2048,
        'topP': 0.9,
      },
    });

    final response = await http
        .post(
          Uri.parse(_url),
          headers: const {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 45));

    debugPrint(
      '[ZomatoScreenshotExtractionService] Gemini HTTP ${response.statusCode}',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Could not read screenshot (Gemini HTTP ${response.statusCode}).',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final rawText = (json['candidates'] as List?)
            ?.firstOrNull?['content']?['parts']
            ?.firstOrNull?['text'] as String? ??
        '';

    debugPrint('[ZomatoScreenshotExtractionService] Raw: "$rawText"');
    return _parseJsonObject(rawText);
  }

  ZomatoExtractedOrder _parseAndMatch(
    Map<String, dynamic> parsed,
    List<Map<String, dynamic>> menuItems,
  ) {
    final itemsRaw = parsed['items'];
    final extractedItems = <ZomatoExtractedItem>[];

    if (itemsRaw is List) {
      for (final entry in itemsRaw) {
        if (entry is! Map) continue;
        final name = (entry['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;

        final qty = ((entry['quantity'] as num?) ?? 1).toInt().clamp(1, 99);
        final remarks = (entry['remarks'] as String? ?? '').trim();
        final matched = _aiOrderService.matchMenuItem(name, menuItems);

        extractedItems.add(
          ZomatoExtractedItem(
            extractedName: name,
            quantity: qty,
            remarks: remarks,
            matchedMenuItem: matched != null
                ? Map<String, dynamic>.from(matched)
                : null,
          ),
        );
      }
    }

    final orderNumber = parsed['zomatoOrderNumber'];
    final orderTime = parsed['orderTime'];
    final totalRaw = parsed['totalAmount'];

    return ZomatoExtractedOrder(
      zomatoOrderNumber: orderNumber?.toString().trim().isNotEmpty == true
          ? orderNumber.toString().trim()
          : null,
      orderTime: orderTime?.toString().trim().isNotEmpty == true
          ? orderTime.toString().trim()
          : null,
      totalAmount: totalRaw is num ? totalRaw.toDouble() : null,
      items: extractedItems,
    );
  }

  Map<String, dynamic> _parseJsonObject(String raw) {
    var cleaned = raw
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    final objectMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(cleaned);
    if (objectMatch != null) {
      cleaned = objectMatch.group(0)!;
    }

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('[ZomatoScreenshotExtractionService] JSON parse failed: $e');
    }
    return {'items': <dynamic>[]};
  }

  static String _mimeType(Uint8List bytes, String? fileName) {
    final lower = fileName?.toLowerCase() ?? '';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    return 'image/jpeg';
  }
}
