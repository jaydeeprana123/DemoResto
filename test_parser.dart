void main() {
  final text = "Two Veg Fried Rice, Chicken Schezwan Fried Rice five, Chicken Chilli Garlic Noodles one, Crispy Open in the morning four, Plate in the shower six, Malai Tikka three, Crispy Chicken Strips one, Afghani Popcorn two, Tower Burger five.";
  
  final tokens = text.toLowerCase()
      .replaceAll('shower', 'shawarma')
      .replaceAll('morning', 'shawarma')
      .replaceAll(',', ' , ')
      .replaceAll('.', ' . ')
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
      
  print('Tokens: $tokens');
  
  final Set<String> _seps = {',', '.', 'plus', '&', 'aur', 'va', 'also', 'then', 'ne', 'tatha', 'sathe'};
  final Map<String, int> _nums = {
    '1': 1, '2': 2, '3': 3, '4': 4, '5': 5,
    '6': 6, '7': 7, '8': 8, '9': 9, '10': 10,
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
  };
  
  final out = <({int qty, List<String> words})>[];
  int pQty = 1;
  List<String> buf = [];
  bool hasQty = false;

  void flush({int? ov}) {
    if (buf.isEmpty) return;
    out.add((qty: ov ?? pQty, words: List.from(buf)));
    buf = [];
    pQty = 1;
    hasQty = false;
  }

  for (int i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (_seps.contains(t)) { flush(); continue; }
    
    final n = _nums[t];
    if (n != null) {
      if (!hasQty && buf.isEmpty) { pQty = n; hasQty = true; }
      else if (!hasQty && buf.isNotEmpty) { flush(ov: n); }
      else { flush(); pQty = n; hasQty = true; }
    } else {
      buf.add(t);
    }
  }
  flush();
  
  for (var seg in out) {
    print('Qty: ${seg.qty}, Words: ${seg.words}');
  }
}
