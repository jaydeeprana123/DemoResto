import 'dart:convert';
import 'dart:io';

void main() async {
  const _apiKey = 'AIzaSyBz_YVM6SrTCL-HFA3FG6SkHZ3T5h6VgBc';
  const _model   = 'gemini-2.0-flash';
  const _url = 'https://generativelanguage.googleapis.com/v1/models/$_model:generateContent?key=$_apiKey';

  final menuItems = [
    {'name': 'Veg Fried Rice', 'category': 'Fried Rice and Noodles'},
    {'name': 'Chicken Schezwan Fried Rice', 'category': 'Fried Rice and Noodles'},
    {'name': 'Veg Schezwan Fried Rice', 'category': 'Fried Rice and Noodles'},
    {'name': 'Chicken Chilli Garlic Noodles', 'category': 'Fried Rice and Noodles'},
    {'name': 'Crispy Open Shawarma', 'category': 'Shawarma'},
    {'name': 'Plate Shawarma', 'category': 'Shawarma'},
    {'name': 'Malai Tikka', 'category': 'Starters'},
    {'name': 'Crispy Chicken Strips', 'category': 'Starters'},
    {'name': 'Afghani Popcorn', 'category': 'Starters'},
    {'name': 'Tower Burger', 'category': 'Burgers'}
  ];

  final menuStr = menuItems.map((m) {
    final cat = (m['category'] as String? ?? '').trim();
    final name = (m['name'] as String? ?? '').trim();
    return cat.isNotEmpty ? '- [$cat] $name' : '- $name';
  }).join('\n');

  final prompt = '''
You are an intelligent restaurant order assistant.

Your job is to convert user speech text into structured order JSON.

The input may contain:
- Gujarati, Hindi, English or mixed language
- Wrong words due to speech recognition (example: "cook" may mean "coke", "bear" may mean "beer", "soap" may mean "soup")
- Half words (example: "pan" may mean "paneer", "chik" may mean "chicken")
- Spelling mistakes

You must:
1. Correct wrong or similar sounding words
2. Predict the most likely food item from the menu
3. Match ONLY from the provided menu
4. Detect quantity (default = 1 if not mentioned)
5. ALWAYS extract the remark/modifier portion into the "remarks" field:
   - Copy the EXACT words the user spoke for the modifier (verbatim), do NOT summarize or paraphrase
   - If no modifier is spoken, remarks = ""

Important:
- Use common Indian restaurant understanding
- Use context to guess missing words (example: "butter" → "butter paneer")
- Ignore items not in menu
- Number words: ek/one=1, be/do/two=2, tran/teen/three=3, chaar/char/four=4, paanch/panch/five=5, chha/chhe/six=6, saat/sat/seven=7, aath/eight=8, nav/nine=9, das/ten=10
- Menu items are shown with a [Category] prefix to help you disambiguate.
  The category prefix is for context ONLY — the "name" in your JSON output must NOT include it.

CORRECTIONS & OVERRIDES:
- Handle natural language corrections within the same input.
- If the user says "make it 4 instead of 3", your output must contain ONLY the final quantity (4).
- QUANTITY RULE: If a quantity is mentioned for one item, do NOT apply it to other items unless explicitly stated.
- DEFAULT RULE: If no quantity is mentioned for an item, the quantity is ALWAYS 1.
- Note that in Indian languages, the quantity often comes AFTER the item name (e.g. "Burger five"). 
  Do NOT assign a quantity to the next item by mistake.

STRICT RULES:
- Return ONLY valid JSON array, no markdown, no explanation
- "name" must exactly match one of the provided menu names

MENU (match ONLY from these exact names):
$menuStr

Return format (strict):
[{"name":"EXACT_MENU_NAME","quantity":NUMBER,"remarks":"MODIFIER_OR_EMPTY_STRING"}]

User input:
"Two Veg Fried Rice, Chicken Schezwan Fried Rice five, Chicken Chilli Garlic Noodles one, Crispy Open in the morning four, Plate in the shower six, Malai Tikka three, Crispy Chicken Strips one, Afghani Popcorn two, Tower Burger five."''';

  final body = jsonEncode({
    'contents': [
      {
        'parts': [
          {'text': prompt}
        ]
      }
    ],
    'generationConfig': {
      'temperature': 0.1,
      'maxOutputTokens': 1024,
      'topP': 0.9,
    },
  });

  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse(_url));
    request.headers
      ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8')
      ..set(HttpHeaders.acceptHeader, 'application/json');
    request.add(utf8.encode(body));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    print('Status: ${response.statusCode}');
    print('Body: $responseBody');
  } finally {
    client.close();
  }
}
