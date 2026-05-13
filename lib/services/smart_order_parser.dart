import 'dart:math';
import 'package:string_similarity/string_similarity.dart';

class SmartOrderParser {
  // Common number mappings (Hindi, Gujarati, English)
  static final Map<String, int> _numberMap = {
    'half': 1, // 'half' portion mapped to 1 (can be adjusted to your business logic)
    'ek': 1, 'one': 1, 'a': 1, 'an': 1, 'ik': 1, '1': 1,
    'do': 2, 'two': 2, 'be': 2, 'bay': 2, '2': 2,
    'teen': 3, 'three': 3, 'tran': 3, 'tin': 3, '3': 3,
    'char': 4, 'four': 4, 'chaar': 4, '4': 4,
    'paanch': 5, 'five': 5, 'panch': 5, '5': 5,
    'che': 6, 'six': 6, 'chah': 6, 'chhe': 6, '6': 6,
    'saat': 7, 'seven': 7, '7': 7,
    'aath': 8, 'eight': 8, '8': 8,
    'nau': 9, 'nine': 9, 'nav': 9, '9': 9,
    'das': 10, 'ten': 10, 'dass': 10, '10': 10,
  };

  // Common conjunctions to split multiple items
  static final List<String> _splitWords = [
    ' aur ', ' and ', ' , ', ',', ' sath me ', ' sath mein ', ' then ', ' plus ', ' bhi ', ' & '
  ];

  // Note modifiers indicating a special request follows
  static final List<String> _noteModifiers = [
    'no', 'without', 'bina', 'extra', 'less', 'add', 'with'
  ];

  // Common keywords often found in food notes
  static final List<String> _noteKeywords = [
    'teekha', 'spicy', 'cheese', 'onion', 'garlic', 'mayo', 'jain', 'kam', 'jyada', 'sauce'
  ];

  // Noise words that can interfere with menu matching
  static final List<String> _noiseWords = [
    'piece', 'pieces', 'plate', 'portion', 'wala', 'wali', 'kardo', 'kar', 'do', 'chahiye', 'give', 'me'
  ];

  /// 1. normalizeText()
  /// Converts to lowercase, removes punctuation, replaces string numbers with digits
  String normalizeText(String input) {
    String normalized = input.toLowerCase();

    // Replace typical punctuations that aren't commas
    normalized = normalized.replaceAll(RegExp(r'[.?!]'), '');

    // Normalize string numbers to digits for easier regex extraction
    // Ensure we match whole words using \b so we don't replace inside words
    _numberMap.forEach((key, value) {
      normalized = normalized.replaceAll(RegExp('\\b$key\\b'), value.toString());
    });

    return normalized.trim();
  }

  /// 2. splitOrderChunks()
  /// Splits the normalized text into separate items using conjunctions
  List<String> splitOrderChunks(String text) {
    String tempText = text;
    for (String word in _splitWords) {
      tempText = tempText.replaceAll(word, '|');
    }

    // Split by our delimiter and remove empty/whitespace chunks
    return tempText
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// 3. extractQuantity()
  /// Extracts the quantity from a chunk, defaulting to 1 if not found
  int extractQuantity(String chunk) {
    // Look for digits in the chunk (since we already normalized 'teen' -> '3')
    final regex = RegExp(r'\b(\d+)\b');
    final match = regex.firstMatch(chunk);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '1') ?? 1;
    }
    return 1; // Default to 1 if no quantity is found
  }

  /// 4. extractNotes()
  /// Extracts typical modification notes from the chunk
  String? extractNotes(String chunk) {
    List<String> notesFound = [];
    List<String> words = chunk.split(' ');

    for (int i = 0; i < words.length; i++) {
      String word = words[i];

      // Handle modifiers like "extra cheese", "no onion"
      if (_noteModifiers.contains(word)) {
        if (i + 1 < words.length) {
          notesFound.add('$word ${words[i + 1]}');
          i++; // Skip next word as it's paired
        }
      } 
      // Handle isolated keywords or trailing modifiers like "teekha kam"
      else if (_noteKeywords.contains(word)) {
        if (i + 1 < words.length && ['kam', 'jyada'].contains(words[i + 1])) {
          notesFound.add('$word ${words[i + 1]}'); // e.g., "teekha kam"
          i++;
        } else if (i > 0 && ['kam', 'jyada'].contains(words[i - 1])) {
          // Handled above usually, but skip if reversed
          if (!notesFound.contains('${words[i - 1]} $word')) {
            notesFound.add(word);
          }
        } else {
          notesFound.add(word); // e.g., "jain", "spicy"
        }
      }
    }

    if (notesFound.isNotEmpty) {
      return notesFound.toSet().join(', '); // Use Set to prevent duplicates
    }
    return null;
  }

  /// Cleans the chunk by removing numbers and modifiers to leave only the item name
  String _cleanItemNameForMatching(String chunk) {
    String cleaned = chunk;

    // Remove numbers
    cleaned = cleaned.replaceAll(RegExp(r'\b\d+\b'), ' ');

    // Remove noise words
    for (String word in _noiseWords) {
      cleaned = cleaned.replaceAll(RegExp('\\b$word\\b'), ' ');
    }

    // Remove note modifiers and keywords to isolate the food name
    for (String word in _noteModifiers) {
      cleaned = cleaned.replaceAll(RegExp('\\b$word\\b'), ' ');
    }
    for (String word in _noteKeywords) {
      cleaned = cleaned.replaceAll(RegExp('\\b$word\\b'), ' ');
    }

    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 5. findBestMenuMatch()
  /// Uses String Similarity (Dice's Coefficient) and Keyword matching
  Map<String, dynamic>? findBestMenuMatch(String searchString, List<Map<String, dynamic>> menuItems) {
    if (searchString.isEmpty) return null;

    double bestScore = 0.0;
    Map<String, dynamic>? bestMatch;

    for (var item in menuItems) {
      String itemName = (item['name'] as String).toLowerCase();
      List<dynamic> aliasesDynamic = item['aliases'] ?? [];
      List<String> aliases = aliasesDynamic.map((e) => e.toString().toLowerCase()).toList();

      // Check primary name
      double nameScore = _calculateSimilarityScore(searchString, itemName);

      // Check all aliases
      double bestAliasScore = 0.0;
      for (String alias in aliases) {
        double score = _calculateSimilarityScore(searchString, alias);
        if (score > bestAliasScore) bestAliasScore = score;
      }

      double maxScore = max(nameScore, bestAliasScore);

      if (maxScore > bestScore) {
        bestScore = maxScore;
        bestMatch = item;
      }
    }

    // Threshold for matching (adjustable based on required strictness)
    if (bestScore >= 0.45) {
      return bestMatch;
    }
    
    return null;
  }

  /// Calculates a robust similarity score using string_similarity package
  double _calculateSimilarityScore(String searchStr, String targetStr) {
    if (searchStr == targetStr) return 1.0;

    // 1. Substring match gives a very high baseline
    if (targetStr.contains(searchStr) || searchStr.contains(targetStr)) {
      double lengthRatio = min(searchStr.length, targetStr.length) / max(searchStr.length, targetStr.length);
      return 0.8 + (0.2 * lengthRatio);
    }

    // 2. String similarity (Dice's Coefficient from package)
    double diceScore = searchStr.similarityTo(targetStr);

    // 3. Token-based matching (Keyword intersection)
    List<String> searchTokens = searchStr.split(' ').where((e) => e.isNotEmpty).toList();
    List<String> targetTokens = targetStr.split(' ').where((e) => e.isNotEmpty).toList();

    int matchedTokens = 0;
    for (String st in searchTokens) {
      double bestTokenScore = 0.0;
      for (String tt in targetTokens) {
        double score = st.similarityTo(tt);
        if (score > bestTokenScore) bestTokenScore = score;
      }
      if (bestTokenScore >= 0.6) { // Token is considered a fuzzy match
        matchedTokens++;
      }
    }

    double tokenScore = searchTokens.isEmpty ? 0 : matchedTokens / searchTokens.length;

    // Weight combination: 40% overall string resemblance, 60% individual word hits
    return (diceScore * 0.4) + (tokenScore * 0.6);
  }

  /// 6. parseSpeechOrder()
  /// The main pipeline tying everything together
  Map<String, dynamic> parseSpeechOrder(String speechText, List<Map<String, dynamic>> menuItems) {
    String normalized = normalizeText(speechText);
    List<String> chunks = splitOrderChunks(normalized);

    List<Map<String, dynamic>> finalItems = [];

    for (String chunk in chunks) {
      int qty = extractQuantity(chunk);
      String? notes = extractNotes(chunk);
      String searchName = _cleanItemNameForMatching(chunk);

      var matchedItem = findBestMenuMatch(searchName, menuItems);

      if (matchedItem != null) {
        finalItems.add({
          "name": matchedItem["name"],
          "qty": qty,
          if (notes != null) "note": notes
        });
      } else {
        // If we couldn't match a food item, but we found notes/modifiers, 
        // they likely belong to the PREVIOUS item due to a conjunction split.
        // Example: "1 Shawarma aur extra cheese" -> "aur" splits it, "extra cheese" is left alone.
        if (notes != null && finalItems.isNotEmpty) {
          String currentNote = finalItems.last["note"] ?? "";
          finalItems.last["note"] = currentNote.isEmpty ? notes : "$currentNote, $notes";
        }
      }
    }

    return {
      "items": finalItems
    };
  }
}
