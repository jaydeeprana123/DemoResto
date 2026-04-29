import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Styles/my_font.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Al-Haadi Diwalipura — Full menu scraped from Zomato menu images
// ─────────────────────────────────────────────────────────────────────────────
const List<Map<String, dynamic>> _alHaadiMenu = [
  {
    'category': 'Hamara Specials',
    'items': [
      {'name': 'Alfaham Tukda Rice', 'price': 630.0},
      {'name': 'Fish Tukda Rice', 'price': 630.0},
      {'name': 'Arabic Rice', 'price': 300.0},
      {'name': 'Char Bag Rice', 'price': 300.0},
      {'name': 'Garden Rice', 'price': 300.0},
      {'name': 'Afghani Dum Rice', 'price': 350.0},
      {'name': 'Gulmarg Rice', 'price': 350.0},
      {'name': 'Helmet Rice', 'price': 300.0},
      {'name': 'Tripple Rice', 'price': 450.0},
      {'name': 'Chicken Tikka Rice', 'price': 300.0},
      {'name': 'Popcorn Rice', 'price': 300.0},
      {'name': 'Talmari Rice', 'price': 280.0},
    ],
  },
  {
    'category': 'Soups',
    'items': [
      {'name': 'Chicken Hot & Sour Soup', 'price': 160.0},
      {'name': 'Chicken Garlic Soup', 'price': 160.0},
      {'name': 'Chicken Manchaw Soup', 'price': 160.0},
      {'name': 'Chicken Ginger Soup', 'price': 160.0},
      {'name': 'Chicken Thukpa Soup', 'price': 200.0},
      {'name': 'Lung Fung Soup', 'price': 200.0},
    ],
  },
  {
    'category': 'Starters',
    'items': [
      {'name': 'Crispy Chicken Popcorn', 'price': 180.0},
      {'name': 'Crispy Cheezy Popcorn', 'price': 250.0},
      {'name': 'Crispy Peri Peri Popcorn', 'price': 250.0},
      {'name': 'Crispy Makhni Popcorn', 'price': 250.0},
      {'name': 'Crispy Chicken Wings', 'price': 180.0},
      {'name': 'Crispy Cheezy Wings', 'price': 250.0},
      {'name': 'Crispy Peri Peri Wings', 'price': 250.0},
      {'name': 'Crispy Makhni Wings', 'price': 250.0},
      {'name': 'Crispy Chicken Drumsticks', 'price': 180.0},
      {'name': 'Dry Manchurian', 'price': 150.0},
      {'name': 'Chicken Chilly', 'price': 240.0},
      {'name': 'Prawns Chilly', 'price': 340.0},
      {'name': 'Fish Chilly', 'price': 340.0},
      {'name': 'Chicken 65', 'price': 240.0},
      {'name': 'Chicken Lolipop', 'price': 350.0},
      {'name': 'Popcorn Chilly', 'price': 240.0},
      {'name': 'Tandoori Tikka', 'price': 160.0},
      {'name': 'Pahadi Tikka', 'price': 160.0},
      {'name': 'Malai Tikka', 'price': 260.0},
      {'name': 'Combo Tikka', 'price': 260.0},
      {'name': 'Zafrani Tikka', 'price': 310.0},
      {'name': 'Hydrabadi Tikka', 'price': 310.0},
      {'name': 'Surti Tikka', 'price': 310.0},
      {'name': 'Lemon Garlic Tikka', 'price': 310.0},
      {'name': 'Chicken Alfaham', 'price': 370.0},
      {'name': 'Grill Chicken', 'price': 370.0},
      {'name': 'Fish Alfaham', 'price': 600.0},
      {'name': 'Crackle Fish', 'price': 370.0},
      {'name': 'Zafrani Alfaham', 'price': 450.0},
      {'name': 'Peri Peri Alfaham', 'price': 450.0},
      {'name': 'Honey Chilly Alfaham', 'price': 450.0},
      {'name': 'Classic Alfaham', 'price': 450.0},
      {'name': 'Peri Peri Grill Chicken', 'price': 450.0},
    ],
  },
  {
    'category': 'Fried Rice and Noodles',
    'items': [
      {'name': 'Chicken Fried Rice', 'price': 140.0},
      {'name': 'Chicken Alfaham Masala Rice', 'price': 150.0},
      {'name': 'Chicken Singapuri Rice', 'price': 150.0},
      {'name': 'Chicken Bombay Rice', 'price': 150.0},
      {'name': 'Chicken Shezwan Rice', 'price': 150.0},
      {'name': 'Chicken Garlic Rice', 'price': 150.0},
      {'name': 'Chicken Chilli Rice', 'price': 340.0},
      {'name': 'Chicken Lolipop Rice', 'price': 340.0},
      {'name': 'Egg Fried Rice', 'price': 100.0},
      {'name': 'Chicken Fried Noodles', 'price': 140.0},
      {'name': 'Chicken Alfaham Masala Noodles', 'price': 150.0},
      {'name': 'Chicken Singapuri Noodles', 'price': 150.0},
      {'name': 'Chicken Bombay Noodles', 'price': 150.0},
      {'name': 'Chicken Shezwan Noodles', 'price': 150.0},
      {'name': 'Chicken Garlic Noodles', 'price': 150.0},
      {'name': 'Chicken Chilli Noodles', 'price': 340.0},
      {'name': 'Chicken Lolipop Noodles', 'price': 340.0},
      {'name': 'Egg Fried Noodles', 'price': 100.0},
      {'name': 'Manchurian Fried Rice', 'price': 100.0},
      {'name': 'Manchurian Singapuri Rice', 'price': 120.0},
      {'name': 'Manchurian Bombay Rice', 'price': 120.0},
      {'name': 'Manchurian Shezwan Rice', 'price': 120.0},
      {'name': 'Manchurian Garlic Rice', 'price': 120.0},
      {'name': 'Manchurian Talmari Rice', 'price': 140.0},
      {'name': 'Manchurian Fried Noodle', 'price': 100.0},
      {'name': 'Manchurian Singapuri Noodle', 'price': 120.0},
      {'name': 'Manchurian Bombay Noodle', 'price': 120.0},
      {'name': 'Manchurian Shezwan Noodle', 'price': 120.0},
      {'name': 'Manchurian Garlic Noodle', 'price': 120.0},
      {'name': 'Manchurian Talmari Noodle', 'price': 140.0},
      {'name': 'Hakka Noodle', 'price': 100.0},
    ],
  },
  {
    'category': 'Burgers',
    'items': [
      {'name': 'Crispy Chicken Burger', 'price': 110.0},
      {'name': 'Crispy Peri Peri Burger', 'price': 120.0},
      {'name': 'Crispy Makhni Burger', 'price': 120.0},
      {'name': 'Crispy Tandoori Burger', 'price': 120.0},
      {'name': 'Crispy Schezwan Burger', 'price': 120.0},
      {'name': 'Crispy Cheezy Burger', 'price': 140.0},
      {'name': 'Crispy Tangy Burger', 'price': 140.0},
      {'name': 'Al Haadi Special Burger', 'price': 180.0},
    ],
  },
  {
    'category': 'Snacks',
    'items': [
      {'name': 'Salted Fries', 'price': 90.0},
      {'name': 'Peri Peri Fries', 'price': 110.0},
      {'name': 'Cheezy Fries', 'price': 130.0},
      {'name': 'Chicken Fried Bhel', 'price': 140.0},
      {'name': 'Chicken Alfaham Masala Bhel', 'price': 150.0},
      {'name': 'Chicken Singapuri Bhel', 'price': 150.0},
      {'name': 'Chicken Bombay Bhel', 'price': 150.0},
      {'name': 'Chicken Shezwan Bhel', 'price': 150.0},
      {'name': 'Chicken Garlic Bhel', 'price': 150.0},
      {'name': 'Chicken Chilli Bhel', 'price': 340.0},
      {'name': 'Chicken Lolipop Bhel', 'price': 340.0},
      {'name': 'Egg Fried Bhel', 'price': 100.0},
    ],
  },
  {
    'category': 'Shawarmas',
    'items': [
      {'name': 'Crispy Samoli (Bun)', 'price': 90.0},
      {'name': 'Crispy Lebnani (Chapati)', 'price': 100.0},
      {'name': 'Crispy Khaboos (Pita)', 'price': 120.0},
      {'name': 'Crispy Open Shawarma', 'price': 250.0},
      {'name': 'Samoli (Bun)', 'price': 80.0},
      {'name': 'Lebnani (Chapati)', 'price': 90.0},
      {'name': 'Khaboos (Pita)', 'price': 110.0},
      {'name': 'Open Shawarma', 'price': 170.0},
    ],
  },
];

// ─────────────────────────────────────────────────────────────────────────────
class MenuSeederPage extends StatefulWidget {
  const MenuSeederPage({Key? key}) : super(key: key);

  @override
  State<MenuSeederPage> createState() => _MenuSeederPageState();
}

class _MenuSeederPageState extends State<MenuSeederPage> {
  bool _isRunning = false;
  bool _done = false;
  String _status = 'Press the button to start.';
  int _categoriesAdded = 0;
  int _itemsAdded = 0;
  final List<String> _log = [];

  void _log_(String msg) {
    setState(() {
      _log.add(msg);
      _status = msg;
    });
  }

  Future<void> _seedMenu() async {
    setState(() {
      _isRunning = true;
      _done = false;
      _categoriesAdded = 0;
      _itemsAdded = 0;
      _log.clear();
      _status = 'Starting...';
    });

    final db = FirebaseFirestore.instance;

    try {
      // ── Step 1: Delete all existing categories + their items ──────────────
      _log_('🗑️  Deleting existing menu...');
      final existing = await db.collection('menus').get();
      for (final doc in existing.docs) {
        // Delete subcollection items first
        final items = await db
            .collection('menus')
            .doc(doc.id)
            .collection('items')
            .get();
        for (final item in items.docs) {
          await item.reference.delete();
        }
        await doc.reference.delete();
      }
      _log_('✅ Cleared ${existing.docs.length} old categories.');

      // ── Step 2: Insert new categories + items ─────────────────────────────
      for (final categoryData in _alHaadiMenu) {
        final categoryName = categoryData['category'] as String;
        final items = categoryData['items'] as List<Map<String, dynamic>>;

        _log_('📂 Adding category: $categoryName...');

        // Add category doc
        final catRef = await db.collection('menus').add({
          'name': categoryName,
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() => _categoriesAdded++);

        // Add each item as subcollection
        for (final item in items) {
          await db
              .collection('menus')
              .doc(catRef.id)
              .collection('items')
              .add({
            'name': item['name'] as String,
            'price': (item['price'] as double),
            'createdAt': FieldValue.serverTimestamp(),
          });
          setState(() => _itemsAdded++);
        }

        _log_('  ✔ Added ${items.length} items to $categoryName');
      }

      _log_('🎉 Done! $_categoriesAdded categories, $_itemsAdded items imported.');
      setState(() {
        _done = true;
        _isRunning = false;
      });
    } catch (e) {
      _log_('❌ Error: $e');
      setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Menu Seeder',
          style: TextStyle(fontFamily: 'Mulish SemiBold', fontSize: 16),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠️  This will DELETE all existing menu data and import:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• ${_alHaadiMenu.length} categories\n'
                    '• ${_alHaadiMenu.fold<int>(0, (sum, c) => sum + (c['items'] as List).length)} menu items\n'
                    '• From: Al-Haadi Restaurant, Diwalipura',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Progress counters
            if (_isRunning || _done)
              Row(
                children: [
                  _Counter(
                    label: 'Categories',
                    value: _categoriesAdded,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  _Counter(
                    label: 'Items',
                    value: _itemsAdded,
                    color: Colors.green,
                  ),
                ],
              ),

            if (_isRunning || _done) const SizedBox(height: 16),

            // Status text
            if (_isRunning)
              Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _status,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),

            if (_done)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Log list
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _log.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _log[i],
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Seed button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRunning ? null : _seedMenu,
                icon: Icon(_done ? Icons.refresh : Icons.upload_rounded),
                label: Text(
                  _done
                      ? 'Re-Import Menu'
                      : _isRunning
                          ? 'Importing...'
                          : 'Delete Old Menu & Import Al-Haadi Menu',
                  style: const TextStyle(
                    fontFamily: 'Mulish SemiBold',
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _done ? Colors.orange : Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Counter({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
