import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/Styles/my_font.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Al-Haadi Diwalipura — Full menu scraped from Zomato menu images
// ─────────────────────────────────────────────────────────────────────────────
const List<Map<String, dynamic>> _alHaadiMenu = [
  {
    'category': 'Hamara Specials',
    'items': [
      {'name': 'Alfaham Tukda Rice (Half)', 'price': 450.0},
      {'name': 'Alfaham Tukda Rice (Full)', 'price': 800.0},
      {'name': 'Fish Tukda Rice', 'price': 800.0},
      {'name': 'Arabic Rice (Half)', 'price': 220.0},
      {'name': 'Arabic Rice (Full)', 'price': 320.0},
      {'name': 'Char Bag Rice (Half)', 'price': 220.0},
      {'name': 'Char Bag Rice (Full)', 'price': 320.0},
      {'name': 'Garden Rice (Half)', 'price': 220.0},
      {'name': 'Garden Rice (Full)', 'price': 320.0},
      {'name': 'Afghani Dum Rice (Half)', 'price': 270.0},
      {'name': 'Afghani Dum Rice (Full)', 'price': 370.0},
      {'name': 'Gulmarg Rice (Half)', 'price': 270.0},
      {'name': 'Gulmarg Rice (Full)', 'price': 370.0},
      {'name': 'Helmet Rice', 'price': 220.0},
      {'name': 'Tripple Rice', 'price': 320.0},
      {'name': 'Chicken Tikka Rice', 'price': 250.0},
      {'name': 'Popcorn Rice', 'price': 220.0},
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
    ],
  },
  {
    'category': 'Chinese Starters',
    'items': [
      {'name': 'Dry Manchurian', 'price': 120.0},
      {'name': 'Chicken Chilly (Half)', 'price': 170.0},
      {'name': 'Chicken Chilly (Full)', 'price': 270.0},
      {'name': 'Prawns Chilly (Half)', 'price': 220.0},
      {'name': 'Prawns Chilly (Full)', 'price': 370.0},
      {'name': 'Fish Chilly (Half)', 'price': 220.0},
      {'name': 'Fish Chilly (Full)', 'price': 370.0},
      {'name': 'Chicken 65 (Half)', 'price': 170.0},
      {'name': 'Chicken 65 (Full)', 'price': 270.0},
      {'name': 'Chicken Lolipop (Half)', 'price': 170.0},
      {'name': 'Chicken Lolipop (Full)', 'price': 270.0},
      {'name': 'Popcorn Chilly (Half)', 'price': 170.0},
      {'name': 'Popcorn Chilly (Full)', 'price': 270.0},
    ],
  },
  {
    'category': 'Tikka Khazana',
    'items': [
      {'name': 'Tandoori Tikka (Half)', 'price': 140.0},
      {'name': 'Tandoori Tikka (Full)', 'price': 220.0},
      {'name': 'Pahadi Tikka (Half)', 'price': 140.0},
      {'name': 'Pahadi Tikka (Full)', 'price': 220.0},
      {'name': 'Malai Tikka (Half)', 'price': 170.0},
      {'name': 'Malai Tikka (Full)', 'price': 270.0},
      {'name': 'Combo Tikka (Half)', 'price': 170.0},
      {'name': 'Combo Tikka (Full)', 'price': 270.0},
      {'name': 'Zafrani Tikka (Half)', 'price': 200.0},
      {'name': 'Zafrani Tikka (Full)', 'price': 360.0},
      {'name': 'Hydrabadi Tikka (Half)', 'price': 200.0},
      {'name': 'Hydrabadi Tikka (Full)', 'price': 360.0},
      {'name': 'Surti Tikka (Half)', 'price': 200.0},
      {'name': 'Surti Tikka (Full)', 'price': 360.0},
      {'name': 'Lemon Garlic Tikka (Half)', 'price': 200.0},
      {'name': 'Lemon Garlic Tikka (Full)', 'price': 360.0},
      {'name': 'Fish Tikka', 'price': 300.0},
    ],
  },
  {
    'category': 'Chicken Alfaham',
    'items': [
      {'name': 'Chicken Alfaham (Half)', 'price': 270.0},
      {'name': 'Chicken Alfaham (Full)', 'price': 500.0},
      {'name': 'Grill Chicken (Half)', 'price': 270.0},
      {'name': 'Grill Chicken (Full)', 'price': 500.0},
      {'name': 'Fish Alfaham', 'price': 450.0},
      {'name': 'Crackle Fish', 'price': 300.0},
      {'name': 'Zafrani Grill Chicken (Half)', 'price': 320.0},
      {'name': 'Zafrani Grill Chicken (Full)', 'price': 570.0},
      {'name': 'Peri Peri Alfaham (Half)', 'price': 320.0},
      {'name': 'Peri Peri Alfaham (Full)', 'price': 570.0},
      {'name': 'Honey Chilly Alfaham (Half)', 'price': 320.0},
      {'name': 'Honey Chilly Alfaham (Full)', 'price': 570.0},
      {'name': 'Classic Alfaham (Half)', 'price': 320.0},
      {'name': 'Classic Alfaham (Full)', 'price': 570.0},
      {'name': 'Peri Peri Grill Chicken (Half)', 'price': 320.0},
      {'name': 'Peri Peri Grill Chicken (Full)', 'price': 570.0},
    ],
  },
  {
    'category': 'Chicken Rice',
    'items': [
      {'name': 'Chicken Fried Rice (Half)', 'price': 110.0},
      {'name': 'Chicken Fried Rice (Full)', 'price': 170.0},
      {'name': 'Chicken Hakka Rice (Half)', 'price': 120.0},
      {'name': 'Chicken Hakka Rice (Full)', 'price': 190.0},
      {'name': 'Talmari Rice (Half)', 'price': 120.0},
      {'name': 'Talmari Rice (Full)', 'price': 190.0},
      {'name': 'Chicken Alfaham Masala Rice (Half)', 'price': 120.0},
      {'name': 'Chicken Alfaham Masala Rice (Full)', 'price': 190.0},
      {'name': 'Chicken Singapuri Rice (Half)', 'price': 120.0},
      {'name': 'Chicken Singapuri Rice (Full)', 'price': 190.0},
      {'name': 'Chicken Bombay Rice (Half)', 'price': 120.0},
      {'name': 'Chicken Bombay Rice (Full)', 'price': 190.0},
      {'name': 'Chicken Shezwan Rice (Half)', 'price': 120.0},
      {'name': 'Chicken Shezwan Rice (Full)', 'price': 190.0},
      {'name': 'Chicken Garlic Rice (Half)', 'price': 120.0},
      {'name': 'Chicken Garlic Rice (Full)', 'price': 190.0},
      {'name': 'Chicken Chilli Rice (Half)', 'price': 270.0},
      {'name': 'Chicken Chilli Rice (Full)', 'price': 370.0},
      {'name': 'Chicken Lolipop Rice (Half)', 'price': 270.0},
      {'name': 'Chicken Lolipop Rice (Full)', 'price': 370.0},
      {'name': 'Egg Fried Rice (Half)', 'price': 70.0},
      {'name': 'Egg Fried Rice (Full)', 'price': 120.0},
    ],
  },
  {
    'category': 'Chicken Noodles',
    'items': [
      {'name': 'Chicken Fried Noodles (Half)', 'price': 110.0},
      {'name': 'Chicken Fried Noodles (Full)', 'price': 170.0},
      {'name': 'Chicken Hakka Noodles (Half)', 'price': 120.0},
      {'name': 'Chicken Hakka Noodles (Full)', 'price': 190.0},
      {'name': 'Talmari Noodles (Half)', 'price': 120.0},
      {'name': 'Talmari Noodles (Full)', 'price': 190.0},
      {'name': 'Chicken Alfaham Masala Noodles (Half)', 'price': 120.0},
      {'name': 'Chicken Alfaham Masala Noodles (Full)', 'price': 190.0},
      {'name': 'Chicken Singapuri Noodles (Half)', 'price': 120.0},
      {'name': 'Chicken Singapuri Noodles (Full)', 'price': 190.0},
      {'name': 'Chicken Bombay Noodles (Half)', 'price': 120.0},
      {'name': 'Chicken Bombay Noodles (Full)', 'price': 190.0},
      {'name': 'Chicken Shezwan Noodles (Half)', 'price': 120.0},
      {'name': 'Chicken Shezwan Noodles (Full)', 'price': 190.0},
      {'name': 'Chicken Garlic Noodles (Half)', 'price': 120.0},
      {'name': 'Chicken Garlic Noodles (Full)', 'price': 190.0},
      {'name': 'Chicken Chilli Noodles (Half)', 'price': 270.0},
      {'name': 'Chicken Chilli Noodles (Full)', 'price': 370.0},
      {'name': 'Chicken Lolipop Noodles (Half)', 'price': 270.0},
      {'name': 'Chicken Lolipop Noodles (Full)', 'price': 370.0},
      {'name': 'Egg Fried Noodles (Half)', 'price': 70.0},
      {'name': 'Egg Fried Noodles (Full)', 'price': 120.0},
    ],
  },
  {
    'category': 'Veg Rice',
    'items': [
      {'name': 'Manchurian Fried Rice (Half)', 'price': 80.0},
      {'name': 'Manchurian Fried Rice (Full)', 'price': 140.0},
      {'name': 'Manchurian Singapuri Rice (Half)', 'price': 90.0},
      {'name': 'Manchurian Singapuri Rice (Full)', 'price': 160.0},
      {'name': 'Manchurian Bombay Rice (Half)', 'price': 90.0},
      {'name': 'Manchurian Bombay Rice (Full)', 'price': 160.0},
      {'name': 'Manchurian Shezwan Rice (Half)', 'price': 90.0},
      {'name': 'Manchurian Shezwan Rice (Full)', 'price': 160.0},
      {'name': 'Manchurian Garlic Rice (Half)', 'price': 90.0},
      {'name': 'Manchurian Garlic Rice (Full)', 'price': 160.0},
      {'name': 'Manchurian Talmari Rice (Half)', 'price': 90.0},
      {'name': 'Manchurian Talmari Rice (Full)', 'price': 160.0},
    ],
  },
  {
    'category': 'Veg Noodles',
    'items': [
      {'name': 'Manchurian Fried Noodle (Half)', 'price': 80.0},
      {'name': 'Manchurian Fried Noodle (Full)', 'price': 140.0},
      {'name': 'Manchurian Singapuri Noodle (Half)', 'price': 90.0},
      {'name': 'Manchurian Singapuri Noodle (Full)', 'price': 160.0},
      {'name': 'Manchurian Bombay Noodle (Half)', 'price': 90.0},
      {'name': 'Manchurian Bombay Noodle (Full)', 'price': 160.0},
      {'name': 'Manchurian Shezwan Noodle (Half)', 'price': 90.0},
      {'name': 'Manchurian Shezwan Noodle (Full)', 'price': 160.0},
      {'name': 'Manchurian Garlic Noodle (Half)', 'price': 90.0},
      {'name': 'Manchurian Garlic Noodle (Full)', 'price': 160.0},
      {'name': 'Manchurian Talmari Noodle (Half)', 'price': 90.0},
      {'name': 'Manchurian Talmari Noodle (Full)', 'price': 160.0},
      {'name': 'Hakka Noodle (Half)', 'price': 80.0},
      {'name': 'Hakka Noodle (Full)', 'price': 140.0},
    ],
  },
  {
    'category': 'Mix Bhel',
    'items': [
      {'name': 'Chicken Fried Bhel (Half)', 'price': 110.0},
      {'name': 'Chicken Fried Bhel (Full)', 'price': 170.0},
      {'name': 'Chicken Alfaham Masala Bhel (Half)', 'price': 120.0},
      {'name': 'Chicken Alfaham Masala Bhel (Full)', 'price': 190.0},
      {'name': 'Chicken Singapuri Bhel (Half)', 'price': 120.0},
      {'name': 'Chicken Singapuri Bhel (Full)', 'price': 190.0},
      {'name': 'Chicken Bombay Bhel (Half)', 'price': 120.0},
      {'name': 'Chicken Bombay Bhel (Full)', 'price': 190.0},
      {'name': 'Chicken Shezwan Bhel (Half)', 'price': 120.0},
      {'name': 'Chicken Shezwan Bhel (Full)', 'price': 190.0},
      {'name': 'Chicken Garlic Bhel (Half)', 'price': 120.0},
      {'name': 'Chicken Garlic Bhel (Full)', 'price': 190.0},
      {'name': 'Chicken Chilli Bhel (Half)', 'price': 270.0},
      {'name': 'Chicken Chilli Bhel (Full)', 'price': 370.0},
      {'name': 'Chicken Lolipop Bhel (Half)', 'price': 270.0},
      {'name': 'Chicken Lolipop Bhel (Full)', 'price': 370.0},
      {'name': 'Egg Fried Bhel (Half)', 'price': 70.0},
      {'name': 'Egg Fried Bhel (Full)', 'price': 120.0},
    ],
  },
  {
    'category': 'Burgers',
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
    'category': 'Shawarmas',
    'items': [
      {'name': 'Crispy Samoli (Bun)', 'price': 70.0},
      {'name': 'Crispy Lebnani (Chapati)', 'price': 80.0},
      {'name': 'Crispy Khaboos (Pita)', 'price': 90.0},
      {'name': 'Crispy Open Shawarma (450ml)', 'price': 190.0},
      {'name': 'Samoli (Bun)', 'price': 60.0},
      {'name': 'Lebnani (Chapati)', 'price': 70.0},
      {'name': 'Khaboos (Pita)', 'price': 80.0},
      {'name': 'Open Shawarma (450ml)', 'price': 190.0},
    ],
  },
  {
    'category': 'Fries',
    'items': [
      {'name': 'Salted Fries', 'price': 70.0},
      {'name': 'Peri Peri Fries', 'price': 80.0},
      {'name': 'Cheezy Fries', 'price': 90.0},
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

      // ── Step 2: Insert new categories + items ─────────────────────────────
      for (final categoryData in _alHaadiMenu) {
        final categoryName = categoryData['category'] as String;
        final items = categoryData['items'] as List<Map<String, dynamic>>;

        _log_('📂 Adding category: $categoryName...');

        // Add category doc
        final catRef = await FirestorePaths.scoped('menus').add({
          'name': categoryName,
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() => _categoriesAdded++);

        // Add each item as subcollection
        for (final item in items) {
          await FirestorePaths
              .scopedSubCollection('menus', catRef.id, 'items')
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
