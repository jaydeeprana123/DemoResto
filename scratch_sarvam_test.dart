import 'dart:convert';
import 'dart:io';

void main() async {
  // Input completely unrelated to menu
  final userText = 'One paneer tikka masala and two butter naan.';
  final menuItems = [
    {'name': 'Arabic Rice', 'category': 'Specials'},
    {'name': 'Chicken Fried Rice', 'category': 'Rice'},
    {'name': 'Afghani Fried Rice', 'category': 'Rice'},
  ];

  final menuStr = menuItems
      .map((m) {
        final cat = (m['category'] as String? ?? '').trim();
        final name = (m['name'] as String? ?? '').trim();
        return cat.isNotEmpty ? '- [$cat] $name' : '- $name';
      })
      .join('\n');

  final prompt = '''
You are a restaurant order-taking assistant. Convert spoken/typed user input into structured JSON orders.

═══════════════════════════════════════════
MENU (you MUST only match from these items)
═══════════════════════════════════════════
$menuStr

═══════════════════════════════
LANGUAGE & SPEECH CORRECTION
═══════════════════════════════
Input may be in English, Hindi, Gujarati or mixed. Speech-to-text errors are common.

KEY TERM DICTIONARY (spoken word → menu meaning):
- alfam / alfaam / alpham / dohol farm / dohol / dohol pham → "Alfaham"
- tukda / tokda → "Tukda" (a portion type — keep it in the name)
- charbake / charbag / char bag / charback → "Char Bag"
- samoli / samoly → "Samoli"
- lebnani / libnani → "Lebnani"
- khaboos / khubus / khabus → "Khaboos"
- zafrani / jafrani → "Zafrani"
- pahadi / pahari → "Pahadi"
- surti / surthi → "Surti"
- singapur → "Singapuri"
- shezvan / schezwan → "Shezwan"
- manchuri / manchoori → "Manchurian"
- shower / shavarma / shwarma / morning → "Shawarma"
- soap / soop → "Soup"
- cook / kok → "Coke"
- pan / paner → "Paneer"
- biriyani / briyani / birani → "Biryani"
- arabic rice / arbic rice → whichever menu item contains "Arabic Rice"

NUMBER DICTIONARY:
- ek / one / aek = 1
- be / do / two = 2  
- tran / teen / three = 3
- chaar / char / four = 4
- paanch / panch / five = 5
- chha / chhe / six = 6
- saat / sat / seven = 7
- aath / eight = 8
- nav / nine = 9
- das / ten = 10

═══════════════════════════════
MATCHING RULES (follow strictly)
═══════════════════════════════
1. KEYWORD MATCHING: Match by identifying KEY WORDS in user input.
   - Example: "alfam tukda rice" → keywords: alfam=Alfaham, tukda=Tukda, rice=Rice → "Alfaham Tukda Rice" ✅
   - Example: "fish tukda rice" → keywords: fish=Fish, tukda=Tukda, rice=Rice → "Fish Tukda Rice" ✅
   - Example: "charbake rice" → keywords: charbake≈charbag=Char Bag, rice=Rice → "Char Bag Rice" ✅

2. CATEGORY HINT: The [Category] prefix helps disambiguate similar names.
   - "chicken rice" → prefer [Fried Rice and Noodles] over [Hamara Specials]
   - The category prefix must NOT appear in your output "name" field

3. COMPOUND NAMES: Never drop parts of a compound menu name.
   - "tukda rice" must match "Alfaham Tukda Rice" or "Fish Tukda Rice", NOT just "Arabic Rice"
   - "fried rice" is different from "Tukda Rice"

4. FUZZY SPELLING: Be tolerant of spelling/pronunciation errors.
   - "charbake" ≈ "Char Bag" (sounds similar, same category)
   - "alfam" = "Alfaham" (well-known abbreviation)

5. QUANTITY: 
   - Default quantity = 1 if not mentioned
   - Apply quantity ONLY to the item it was spoken with
   - Use the LAST mentioned quantity if corrected ("make it 4 instead of 3" → 4)

6. REMARKS: 
   - Extract VERBATIM any modifier/preference the user spoke
   - Examples: spice level, oil, onion, garlic, parcel, cooking style
   - If no modifier spoken → remarks = "" (empty string, never null)

═══════════════════════════════
OUTPUT FORMAT (strict)
═══════════════════════════════
Return ONLY a valid JSON array. No markdown, no explanation, no extra text.
The "name" field must EXACTLY match one of the menu names above (copy-paste exact spelling).
CRITICAL: If the user orders something that is NOT in the MENU list provided above, DO NOT include it in the JSON output. Ignore it entirely.

[{"name":"EXACT_MENU_NAME","quantity":NUMBER,"remarks":"MODIFIER_OR_EMPTY"}]

═══════════════════════════════
EXAMPLES
═══════════════════════════════
Menu has: "Alfaham Tukda Rice", "Fish Tukda Rice", "Char Bag Rice", "Garden Rice"

Input: "one alfam tukda rice, two fish tukda rice, three charbake rice, one garden Rice"
Output: [
  {"name":"Alfaham Tukda Rice","quantity":1,"remarks":""},
  {"name":"Fish Tukda Rice","quantity":2,"remarks":""},
  {"name":"Char Bag Rice","quantity":3,"remarks":""},
  {"name":"Garden Rice","quantity":1,"remarks":""}
]

Input: "do chicken fried rice kam tikha, ek hakka noodle"
Output: [
  {"name":"Chicken Fried Rice","quantity":2,"remarks":"kam tikha"},
  {"name":"Hakka Noodle","quantity":1,"remarks":""}
]

Input: "teen samoli, ek open shawarma parcel karo"
Output: [
  {"name":"Samoli (Bun)","quantity":3,"remarks":""},
  {"name":"Open Shawarma","quantity":1,"remarks":"parcel karo"}
]

═══════════════════════════════
USER INPUT TO PROCESS
═══════════════════════════════
"$userText"
''';

  await _testModel('sarvam-105b', prompt, userText);
}

Future<void> _testModel(String model, String prompt, String userText) async {
  final body = jsonEncode({
    'model': model,
    'messages': [
      {'role': 'system', 'content': prompt},
      {'role': 'user', 'content': userText}
    ],
    'temperature': 0.1,
    'max_tokens': 1024,
    'top_p': 0.9,
  });

  final client = HttpClient();
  
  try {
    final request = await client.postUrl(Uri.parse('https://api.sarvam.ai/v1/chat/completions'));
    request.headers
      ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8')
      ..set(HttpHeaders.acceptHeader, 'application/json')
      ..set(HttpHeaders.authorizationHeader, 'Bearer sk_jm9xxf0p_09FKG715K2n9hXMGKjmIlAIS');
      
    request.add(utf8.encode(body));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    if (response.statusCode != 200) {
      print("Error: $responseBody");
      return;
    }
    
    final json = jsonDecode(responseBody);
    final raw = (json['choices'] as List?)?.firstOrNull?['message']?['content'] as String? ?? '';
    print("Response: $raw");
  } finally {
    client.close();
  }
}
