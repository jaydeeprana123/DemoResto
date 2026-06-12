import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/Styles/my_font.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Al-Haadi Diwalipura — Full menu scraped from Zomato menu images
//
// Half/Full items: use ONE row per dish (MenuPage shows a Half/Full popup):
//   {'name': 'Chicken Alfaham', 'halfPrice': 270.0, 'fullPrice': 500.0}
// Legacy pairs like "Name (Half)" + "Name (Full)" are merged automatically.
// ─────────────────────────────────────────────────────────────────────────────
const List<Map<String, dynamic>> _alHaadiMenu = [
  {
    'category': 'Crispy Starters',
    'items': [
      {'name': 'Crispy Chicken Popcorn (14 pcs)', 'price': 130.0},
      {'name': 'Crispy Cheezy Popcorn (14 pcs)', 'price': 180.0},
      {'name': 'Crispy Peri Peri Popcorn (14 pcs)', 'price': 180.0},
      {'name': 'Crispy Makhni Popcorn (14 pcs)', 'price': 180.0},
      {'name': 'Crispy Chicken Wings (6 pcs)', 'price': 130.0},
      {'name': 'Crispy Cheezy Wings (6 pcs)', 'price': 180.0},
      {'name': 'Crispy Peri Peri Wings (6 pcs)', 'price': 180.0},
      {'name': 'Crispy Makhni Wings (6 pcs)', 'price': 180.0},
      {'name': 'Crispy Chicken Drumsticks (2 pcs)', 'price': 130.0},
      {'name': 'Special Platter', 'price': 220.0},
    ],
  },

  {
    'category': 'Crispy Shawarmas',
    'items': [
      {'name': 'Crispy Samoli (Bun)', 'price': 70.0},
      {'name': 'Crispy Lebnani (Chapati)', 'price': 80.0},
      {'name': 'Crispy Khaboos (Pita)', 'price': 90.0},
      {'name': 'Crispy Open Shawarma (450ml)', 'price': 190.0},

    ],
  },
  {
    'category': 'Regular Shawarmas',
    'items': [
      {'name': 'Samoli (Bun)', 'price': 60.0},
      {'name': 'Lebnani (Chapati)', 'price': 70.0},
      {'name': 'Khaboos (Pita)', 'price': 80.0},
      {'name': 'Open Shawarma (450ml)', 'price': 190.0},
    ],
  },


  {
    'category': 'Crispy Burgers',
    'items': [
      {'name': 'Veg Burger', 'price': 70.0},
      {'name': 'Crispy Chicken Burger', 'price': 80.0},
      {'name': 'Crispy Peri Peri Burger', 'price': 90.0},
      {'name': 'Crispy Makhni Burger', 'price': 90.0},
      {'name': 'Crispy Tandoori Burger', 'price': 90.0},
      {'name': 'Crispy Schezwan Burger', 'price': 90.0},
      {'name': 'Crispy Cheezy Burger', 'price': 100.0},
      {'name': 'Crispy Tangy Burger', 'price': 100.0},
      {'name': 'Al Haadi Special Burger', 'price': 130.0},
    ],
  },


  {
    'category': 'French Fries',
    'items': [
      {'name': 'Salted Fries', 'price': 70.0},
      {'name': 'Peri Peri Fries', 'price': 80.0},
      {'name': 'Cheezy Fries', 'price': 90.0},
    ],
  },


  {
    'category': 'Chinese Starters',
    'items': [
      {'name': 'Dry Manchurian', 'price': 120.0},
      {'name': 'Chicken Chilly', 'halfPrice': 170.0, 'fullPrice': 270.0},
      {'name': 'Prawns Chilly', 'halfPrice': 220.0, 'fullPrice': 370.0},
      {'name': 'Fish Chilly', 'halfPrice': 220.0, 'fullPrice': 370.0},
      {'name': 'Chicken 65', 'halfPrice': 170.0, 'fullPrice': 270.0},
      {'name': 'Chicken Lolipop', 'halfPrice': 170.0, 'fullPrice': 270.0},
      {'name': 'Popcorn Chilly', 'halfPrice': 170.0, 'fullPrice': 270.0},
    ],
  },


  {
    'category': 'Tikka Khazana',
    'items': [
      {'name': 'Tandoori Tikka', 'halfPrice': 140.0, 'fullPrice': 220.0},
      {'name': 'Pahadi Tikka', 'halfPrice': 140.0, 'fullPrice': 220.0},
      {'name': 'Malai Tikka', 'halfPrice': 170.0, 'fullPrice': 270.0},
      {'name': 'Combo Tikka', 'halfPrice': 170.0, 'fullPrice': 270.0},
      {'name': 'Zafrani Tikka', 'halfPrice': 200.0, 'fullPrice': 360.0},
      {'name': 'Hydrabadi Tikka', 'halfPrice': 200.0, 'fullPrice': 360.0},
      {'name': 'Surti Tikka', 'halfPrice': 200.0, 'fullPrice': 360.0},
      {'name': 'Lemon Garlic Tikka', 'halfPrice': 200.0, 'fullPrice': 360.0},
      {'name': 'Fish Tikka', 'price': 300.0},
    ],
  },


  {
    'category': 'Chicken Alfaham',
    'items': [
      {'name': 'Chicken Alfaham', 'halfPrice': 270.0, 'fullPrice': 500.0},
      {'name': 'Grill Chicken', 'halfPrice': 270.0, 'fullPrice': 500.0},
      {'name': 'Fish Alfaham', 'price': 450.0},
      {'name': 'Crackle Fish', 'price': 300.0},
      {'name': 'Zafrani Grill Chicken', 'halfPrice': 320.0, 'fullPrice': 570.0},
      {'name': 'Peri Peri Alfaham', 'halfPrice': 320.0, 'fullPrice': 570.0},
      {'name': 'Honey Chilly Alfaham', 'halfPrice': 320.0, 'fullPrice': 570.0},
      {'name': 'Classic Alfaham', 'halfPrice': 320.0, 'fullPrice': 570.0},
      {'name': 'Peri Peri Grill Chicken', 'halfPrice': 320.0, 'fullPrice': 570.0},
    ],
  },


  {
    'category': 'Soups',
    'items': [
      {'name': 'Chicken Hot & Sour Soup', 'price': 120.0},
      {'name': 'Chicken Garlic Soup', 'price': 120.0},
      {'name': 'Chicken Manchaw Soup', 'price': 120.0},
      {'name': 'Chicken Ginger Soup', 'price': 120.0},
      {'name': 'Chicken Thukpa Soup', 'price': 130.0},
      {'name': 'Lung Fung Soup', 'price': 130.0},
    ],
  },


  {
    'category': 'Rice',
    'items': [
      {'name': 'Chicken Fried Rice', 'halfPrice': 110.0, 'fullPrice': 170.0},
      {'name': 'Chicken Hakka Rice', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Talmari Rice', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Chicken Alfaham Masala Rice', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Chicken Singapuri Rice', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Chicken Bombay Rice', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Chicken Shezwan Rice', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Chicken Garlic Rice', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Chicken Chilli Rice', 'halfPrice': 270.0, 'fullPrice': 370.0},
      {'name': 'Chicken Lolipop Rice', 'halfPrice': 270.0, 'fullPrice': 370.0},
      {'name': 'Egg Fried Rice', 'halfPrice': 70.0, 'fullPrice': 120.0},
    ],
  },


  {
    'category': 'Noodles',
    'items': [
      {'name': 'Chicken Fried Noodles', 'halfPrice': 110.0, 'fullPrice': 170.0},
      {'name': 'Chicken Hakka Noodles', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Talmari Noodles', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Chicken Alfaham Masala Noodles', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Chicken Singapuri Noodles', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Chicken Bombay Noodles', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Chicken Shezwan Noodles', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Chicken Garlic Noodles', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Chicken Chilli Noodles', 'halfPrice': 270.0, 'fullPrice': 370.0},
      {'name': 'Chicken Lolipop Noodles', 'halfPrice': 270.0, 'fullPrice': 370.0},
      {'name': 'Egg Fried Noodles', 'halfPrice': 70.0, 'fullPrice': 120.0},
    ],
  },


  {
    'category': 'Veg Rice',
    'items': [
      {'name': 'Manchurian Fried Rice', 'halfPrice': 80.0, 'fullPrice': 140.0},
      {'name': 'Manchurian Singapuri Rice', 'halfPrice': 90.0, 'fullPrice': 160.0},
      {'name': 'Manchurian Bombay Rice', 'halfPrice': 90.0, 'fullPrice': 160.0},
      {'name': 'Manchurian Shezwan Rice', 'halfPrice': 90.0, 'fullPrice': 160.0},
      {'name': 'Manchurian Garlic Rice', 'halfPrice': 90.0, 'fullPrice': 160.0},
      {'name': 'Manchurian Talmari Rice', 'halfPrice': 90.0, 'fullPrice': 160.0},
    ],
  },
  {
    'category': 'Veg Noodles',
    'items': [
      {'name': 'Manchurian Fried Noodle', 'halfPrice': 80.0, 'fullPrice': 140.0},
      {'name': 'Manchurian Singapuri Noodle', 'halfPrice': 90.0, 'fullPrice': 160.0},
      {'name': 'Manchurian Bombay Noodle', 'halfPrice': 90.0, 'fullPrice': 160.0},
      {'name': 'Manchurian Shezwan Noodle', 'halfPrice': 90.0, 'fullPrice': 160.0},
      {'name': 'Manchurian Garlic Noodle', 'halfPrice': 90.0, 'fullPrice': 160.0},
      {'name': 'Manchurian Talmari Noodle', 'halfPrice': 90.0, 'fullPrice': 160.0},
      {'name': 'Hakka Noodle', 'halfPrice': 80.0, 'fullPrice': 140.0},
    ],
  },


  {
    'category': 'Mix Bhel',
    'items': [
      {'name': 'Chicken Fried Bhel', 'halfPrice': 110.0, 'fullPrice': 170.0},
      {'name': 'Chicken Alfaham Masala Bhel', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Chicken Singapuri Bhel', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Chicken Bombay Bhel', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Chicken Shezwan Bhel', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Chicken Garlic Bhel', 'halfPrice': 120.0, 'fullPrice': 190.0},
      {'name': 'Chicken Chilli Bhel', 'halfPrice': 270.0, 'fullPrice': 370.0},
      {'name': 'Chicken Lolipop Bhel', 'halfPrice': 270.0, 'fullPrice': 370.0},
      {'name': 'Egg Fried Bhel', 'halfPrice': 70.0, 'fullPrice': 120.0},
    ],
  },



  {
    'category': 'Hamara Specials',
    'items': [
      {'name': 'Alfaham Tukda Rice', 'halfPrice': 450.0, 'fullPrice': 800.0},
      {'name': 'Fish Tukda Rice', 'price': 800.0},
      {'name': 'Arabic Rice', 'halfPrice': 220.0, 'fullPrice': 320.0},
      {'name': 'Char Bag Rice', 'halfPrice': 220.0, 'fullPrice': 320.0},
      {'name': 'Garden Rice', 'halfPrice': 220.0, 'fullPrice': 320.0},
      {'name': 'Afghani Dum Rice', 'halfPrice': 270.0, 'fullPrice': 370.0},
      {'name': 'Gulmarg Rice', 'halfPrice': 270.0, 'fullPrice': 370.0},
      {'name': 'Helmet Rice', 'price': 220.0},
      {'name': 'Tripple Rice', 'price': 320.0},
      {'name': 'Chicken Tikka Rice', 'price': 250.0},
      {'name': 'Popcorn Rice', 'price': 220.0},
      {'name': 'Afghani Dum Noodles', 'halfPrice': 200.0, 'fullPrice': 350.0},
      {'name': 'Arabic Noodles', 'halfPrice': 220.0, 'fullPrice': 320.0},
    ],
  },


  {
    'category': 'Soda',
    'items': [
      {'name': 'Plain Soda', 'price': 10.0},
      {'name': 'Jeera Masala', 'price': 10.0},
      {'name': 'Orange', 'price': 10.0},
      {'name': 'Seven Up', 'price': 10.0},
      {'name': 'Fruit Beer', 'price': 10.0},
      {'name': 'Lichi', 'price': 10.0},
      {'name': 'Lemon', 'price': 10.0},
      {'name': 'Blue Berry', 'price': 10.0},
      {'name': 'Mango', 'price': 10.0},
      {'name': 'Apple', 'price': 10.0},
      {'name': 'Kashmiri Soda', 'price': 20.0},
      {'name': 'Kashmiri Lemon', 'price': 20.0},
      {'name': 'Kashmiri Jeera', 'price': 20.0},
      {'name': 'Limbu Soda', 'price': 20.0},
      {'name': 'Limbu Sharbat', 'price': 20.0},
    ],
  },
  {
    'category': 'Mocktails',
    'items': [
      {'name': 'Mojeeto Mocktail', 'price': 40.0},
      {'name': 'Taquila Mocktail', 'price': 50.0},
      {'name': 'Green Mocktail', 'price': 50.0},
      {'name': 'Rainbow Mocktail', 'price': 70.0},
      {'name': 'Pineapple Mocktail', 'price': 50.0},
      {'name': 'Guava Mocktail', 'price': 50.0},
      {'name': 'Black Current', 'price': 50.0},
      {'name': 'Peach Mocktail', 'price': 50.0},
      {'name': 'Cherry Mocktail', 'price': 50.0},
      {'name': 'Mango Mocktail', 'price': 50.0},
      {'name': 'Banana Mocktail', 'price': 50.0},
      {'name': 'Patiala Mocktail', 'price': 70.0},
      {'name': 'Chilly Lemon', 'price': 70.0},
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

    try {
      // ── Step 1: Delete all existing categories + their items ──────────────
      _log_('🗑️  Deleting existing menu...');
      final existing = await FirestorePaths.scoped('menus').get();
      for (final doc in existing.docs) {
        // Delete subcollection items first
        final items = await FirestorePaths
            .scopedSubCollection('menus', doc.id, 'items')
            .get();
        for (final item in items.docs) {
          await item.reference.delete();
        }
        await doc.reference.delete();
      }
      _log_('✅ Cleared ${existing.docs.length} old categories.');

      // ── Step 2: Insert categories + items in _alHaadiMenu order ───────────
      for (var catIndex = 0; catIndex < _alHaadiMenu.length; catIndex++) {
        final categoryData = _alHaadiMenu[catIndex];
        final categoryName = categoryData['category'] as String;
        final items = categoryData['items'] as List<Map<String, dynamic>>;

        _log_('📂 [$catIndex] $categoryName');

        final catRef = await FirestorePaths.scoped('menus').add({
          'name': categoryName,
          'sortOrder': catIndex,
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() => _categoriesAdded++);

        for (var itemIndex = 0; itemIndex < items.length; itemIndex++) {
          final item = items[itemIndex];
          final itemName = item['name'] as String;
          final payload = <String, dynamic>{
            'name': itemName,
            'sortOrder': itemIndex,
            'createdAt': FieldValue.serverTimestamp(),
          };

          if (item.containsKey('halfPrice') && item.containsKey('fullPrice')) {
            payload['halfPrice'] = (item['halfPrice'] as num).toDouble();
            payload['fullPrice'] = (item['fullPrice'] as num).toDouble();
            payload['price'] = (item['halfPrice'] as num).toDouble();
          } else {
            payload['price'] = (item['price'] as num).toDouble();
          }

          await FirestorePaths
              .scopedSubCollection('menus', catRef.id, 'items')
              .add(payload);

          _log_('    • $itemName');
          setState(() => _itemsAdded++);
        }
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
