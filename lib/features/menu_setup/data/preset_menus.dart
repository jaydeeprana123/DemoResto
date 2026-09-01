/// Preset restaurant menus that can be imported via Menu Seeder.
library;

class PresetMenu {
  const PresetMenu({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.categories,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> categories;

  int get categoryCount => categories.length;

  int get itemCount => categories.fold<int>(
    0,
    (sum, category) => sum + ((category['items'] as List?)?.length ?? 0),
  );
}

const List<PresetMenu> kPresetMenus = [
  PresetMenu(
    id: 'al_haadi',
    title: 'Al-Haadi Menu',
    subtitle: 'Al-Haadi Restaurant, Diwalipura',
    categories: _alHaadiMenu,
  ),
  PresetMenu(
    id: 'arabian_grill',
    title: 'Arabian Grill Menu',
    subtitle: 'Arabian Grill full menu',
    categories: _arabianGrillMenu,
  ),

  PresetMenu(
    id: 'tawaazo',
    title: 'Tawaazo Restaurant Menu',
    subtitle: 'Tawaazo Restaurant full menu',
    categories: _tawaazoMenu,
  ),
];

PresetMenu? presetMenuById(String id) {
  for (final menu in kPresetMenus) {
    if (menu.id == id) return menu;
  }
  return null;
}

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
      {'name': 'Pyazi Tikka', 'halfPrice': 200.0, 'fullPrice': 360.0},
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
      {
        'name': 'Peri Peri Grill Chicken',
        'halfPrice': 320.0,
        'fullPrice': 570.0,
      },
      {'name': 'Afghani Grill Chicken', 'halfPrice': 320.0, 'fullPrice': 570.0},
      {'name': 'Smoky Grill', 'halfPrice': 300.0, 'fullPrice': 550.0},
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
      {
        'name': 'Chicken Alfaham Masala Rice',
        'halfPrice': 120.0,
        'fullPrice': 190.0,
      },
      {
        'name': 'Chicken Singapuri Rice',
        'halfPrice': 120.0,
        'fullPrice': 190.0,
      },
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
      {
        'name': 'Chicken Alfaham Masala Noodles',
        'halfPrice': 120.0,
        'fullPrice': 190.0,
      },
      {
        'name': 'Chicken Singapuri Noodles',
        'halfPrice': 120.0,
        'fullPrice': 190.0,
      },
      {
        'name': 'Chicken Bombay Noodles',
        'halfPrice': 120.0,
        'fullPrice': 190.0,
      },
      {
        'name': 'Chicken Shezwan Noodles',
        'halfPrice': 120.0,
        'fullPrice': 190.0,
      },
      {
        'name': 'Chicken Garlic Noodles',
        'halfPrice': 120.0,
        'fullPrice': 190.0,
      },
      {
        'name': 'Chicken Chilli Noodles',
        'halfPrice': 270.0,
        'fullPrice': 370.0,
      },
      {
        'name': 'Chicken Lolipop Noodles',
        'halfPrice': 270.0,
        'fullPrice': 370.0,
      },
      {'name': 'Egg Fried Noodles', 'halfPrice': 70.0, 'fullPrice': 120.0},
    ],
  },
  {
    'category': 'Veg Rice',
    'items': [
      {'name': 'Manchurian Fried Rice', 'halfPrice': 80.0, 'fullPrice': 140.0},
      {
        'name': 'Manchurian Singapuri Rice',
        'halfPrice': 90.0,
        'fullPrice': 160.0,
      },
      {'name': 'Manchurian Bombay Rice', 'halfPrice': 90.0, 'fullPrice': 160.0},
      {
        'name': 'Manchurian Shezwan Rice',
        'halfPrice': 90.0,
        'fullPrice': 160.0,
      },
      {'name': 'Manchurian Garlic Rice', 'halfPrice': 90.0, 'fullPrice': 160.0},
      {
        'name': 'Manchurian Talmari Rice',
        'halfPrice': 90.0,
        'fullPrice': 160.0,
      },
    ],
  },
  {
    'category': 'Veg Noodles',
    'items': [
      {
        'name': 'Manchurian Fried Noodle',
        'halfPrice': 80.0,
        'fullPrice': 140.0,
      },
      {
        'name': 'Manchurian Singapuri Noodle',
        'halfPrice': 90.0,
        'fullPrice': 160.0,
      },
      {
        'name': 'Manchurian Bombay Noodle',
        'halfPrice': 90.0,
        'fullPrice': 160.0,
      },
      {
        'name': 'Manchurian Shezwan Noodle',
        'halfPrice': 90.0,
        'fullPrice': 160.0,
      },
      {
        'name': 'Manchurian Garlic Noodle',
        'halfPrice': 90.0,
        'fullPrice': 160.0,
      },
      {
        'name': 'Manchurian Talmari Noodle',
        'halfPrice': 90.0,
        'fullPrice': 160.0,
      },
      {'name': 'Hakka Noodle', 'halfPrice': 80.0, 'fullPrice': 140.0},
    ],
  },
  {
    'category': 'Mix Bhel',
    'items': [
      {'name': 'Chicken Fried Bhel', 'halfPrice': 110.0, 'fullPrice': 170.0},
      {
        'name': 'Chicken Alfaham Masala Bhel',
        'halfPrice': 120.0,
        'fullPrice': 190.0,
      },
      {
        'name': 'Chicken Singapuri Bhel',
        'halfPrice': 120.0,
        'fullPrice': 190.0,
      },
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
      {'name': 'Blue Berry', 'price': 10.0},
      {'name': 'Kashmiri Soda', 'price': 20.0},
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
      {'name': 'Rainbow Mocktail', 'price': 70.0},
      {'name': 'Pineapple Mocktail', 'price': 50.0},
      {'name': 'Guava Mocktail', 'price': 50.0},
      {'name': 'Black Current', 'price': 50.0},
      {'name': 'Peach Mocktail', 'price': 50.0},
      {'name': 'Cherry Mocktail', 'price': 50.0},
      {'name': 'Mango Mocktail', 'price': 50.0},
      {'name': 'Patiala Mocktail', 'price': 70.0},
      {'name': 'Kashmiri Jeera Mocktail', 'price': 50.0},
      {'name': 'Jamun Mocktail', 'price': 50.0},
      {'name': 'Cool Mint Mocktail', 'price': 50.0},
      {'name': 'Citrus Punch Mocktail', 'price': 50.0},
      {'name': 'Litchi Mocktail', 'price': 50.0},
      {'name': 'Strawberry Mocktail', 'price': 50.0},
      {'name': 'Blue Curacao Mocktail', 'price': 50.0},
      {'name': 'Kiwi Mocktail', 'price': 50.0},
    ],
  },
  {
    'category': 'Extras',
    'items': [
      {'name': 'Small Water Bottle', 'price': 10.0},
      {'name': 'Big Water Bottle', 'price': 20.0},
      {'name': 'Mayonnaise', 'price': 10.0},
      {'name': 'Extra Chicken', 'price': 20.0},
      {'name': 'Extra Cheese', 'price': 20.0},
      {'name': 'Without Cabbage', 'price': 10.0},
    ],
  },
  {
    'category': 'Cold Drinks',
    'items': [
      {'name': 'Sosyo', 'price': 20.0},
    ],
  },
];

const List<Map<String, dynamic>> _arabianGrillMenu = [
  {
    'category': 'Papad',
    'items': [
      {'name': 'Roasted Papad', 'price': 20.0},
      {'name': 'Fried Papad', 'price': 30.0},
      {'name': 'Masala Papad', 'price': 50.0},
    ],
  },
  {
    'category': 'French Fries',
    'items': [
      {'name': 'French Fries', 'price': 80.0},
      {'name': 'Mayo Fries', 'price': 90.0},
      {'name': 'Peri Peri Fries', 'price': 90.0},
      {'name': 'Cheesy Fries', 'price': 110.0},
      {'name': 'Crispy Platter', 'price': 280.0},
    ],
  },
  {
    'category': 'Chicken Shawarma',
    'items': [
      {'name': 'Special Grilled Shawarma', 'price': 170.0},
      {'name': 'Only Chicken Samoli', 'price': 80.0},
      {'name': 'Only Chicken Shawarma', 'price': 140.0},
      {
        'name': 'Container Shawarma',
        'variants': [
          {'label': 'S', 'price': 180.0},
          {'label': 'M', 'price': 200.0},
          {'label': 'L', 'price': 220.0},
        ],
      },
      {'name': 'Plate Shawarma', 'price': 180.0},
      {'name': 'Samoli Shawarma', 'price': 60.0},
      {'name': 'Shawarma Khaboos', 'price': 80.0},
      {'name': 'Cheese Shawarma Khaboos', 'price': 110.0},
      {'name': 'Lebnani Shawarma', 'price': 80.0},
      {'name': 'Tortilla Shawarma', 'price': 170.0},
      {'name': 'Tikka Roll', 'price': 180.0},
      {'name': 'Paratha Shawarma', 'price': 170.0},
      {'name': 'Crispy Khaboos Shawarma', 'price': 100.0},
      {'name': 'Crispy Samoli Shawarma', 'price': 80.0},
    ],
  },
  {
    'category': 'Chicken Tikka',
    'items': [
      {'name': 'Chicken Angara Tikka', 'price': 200.0},
      {'name': 'Chicken Hariyali Tikka', 'price': 200.0},
      {'name': 'Chicken Malai Tikka', 'price': 230.0},
      {'name': 'Chicken Tigada Tikka (Mixed)', 'price': 650.0},
      {'name': 'Chicken Jaituni Tikka', 'price': 250.0},
      {'name': 'Chicken Golden Tikka', 'price': 250.0},
      {'name': 'Chicken Akbari Tikka', 'price': 270.0},
      {'name': 'Chicken Sikandri Tikka', 'price': 250.0},
      {'name': 'Chicken Matka Tikka', 'price': 300.0},
      {'name': 'Chicken Barra Tikka', 'price': 280.0},
    ],
  },
  {
    'category': 'Chicken Seekh Kabab',
    'items': [
      {
        'name': 'Chicken Seekh Kabab',
        'variants': [
          {'label': '4 pcs', 'price': 120.0},
          {'label': '8 pcs', 'price': 220.0},
        ],
      },
      {
        'name': 'Mughlai Seekh Kabab',
        'variants': [
          {'label': '4 pcs', 'price': 170.0},
          {'label': '8 pcs', 'price': 300.0},
        ],
      },
      {
        'name': 'Malai Seekh Kabab',
        'variants': [
          {'label': '4 pcs', 'price': 150.0},
          {'label': '8 pcs', 'price': 280.0},
        ],
      },
      {
        'name': 'Mutton Seekh Kabab',
        'variants': [
          {'label': '4 pcs', 'price': 170.0},
          {'label': '8 pcs', 'price': 300.0},
        ],
      },
    ],
  },
  {
    'category': 'Chicken Tandoori (Sigdi)',
    'items': [
      {'name': 'Grilled Chicken', 'halfPrice': 280.0, 'fullPrice': 500.0},
      {
        'name': 'Zaafraani Grill Chicken',
        'halfPrice': 400.0,
        'fullPrice': 700.0,
      },
      {
        'name': 'Chicken Al Faham',
        'variants': [
          {'label': '1 pc', 'price': 170.0},
          {'label': 'Half', 'price': 280.0},
          {'label': 'Full', 'price': 500.0},
        ],
      },
      {'name': 'Mughlai Al Faham', 'halfPrice': 380.0, 'fullPrice': 700.0},
      {'name': 'Chicken Afghani', 'halfPrice': 320.0, 'fullPrice': 570.0},
      {'name': 'Pathani Tandoori', 'halfPrice': 320.0, 'fullPrice': 570.0},
      {'name': 'Golden Cream Tandoori', 'halfPrice': 340.0, 'fullPrice': 640.0},
      {'name': 'Barra Tandoori', 'halfPrice': 340.0, 'fullPrice': 640.0},
      {'name': 'Sizzling Tandoori', 'halfPrice': 340.0, 'fullPrice': 640.0},
      {'name': 'Matla Tandoori', 'halfPrice': 380.0, 'fullPrice': 700.0},
      {'name': 'Schezwan Tandoori', 'halfPrice': 340.0, 'fullPrice': 640.0},
      {
        'name': 'Chicken Grilled Strips',
        'variants': [
          {'label': '6 pcs', 'price': 220.0},
          {'label': '12 pcs', 'price': 400.0},
        ],
      },
    ],
  },
  {
    'category': 'Chicken Leg & Breast (1 pc)',
    'items': [
      {'name': 'Chicken Al Faham', 'price': 170.0},
      {'name': 'Chicken Winter Leg', 'price': 200.0},
      {'name': 'Chicken Pathani Leg', 'price': 220.0},
      {'name': 'Chicken Golden Creamy Leg', 'price': 220.0},
      {'name': 'Chicken Sezwan Leg', 'price': 220.0},
    ],
  },
  {
    'category': 'Fish & Prawns',
    'items': [
      {'name': 'Fish Tikka Dry', 'price': 340.0},
      {'name': 'Prawns Tikka Dry', 'price': 320.0},
      {
        'name': 'Crackle Fish',
        'variants': [
          {'label': '4 pcs', 'price': 200.0},
          {'label': '8 pcs', 'price': 380.0},
        ],
      },
      {'name': 'Lemon Fish Fry', 'price': 340.0},
      {'name': 'Moghlai Fish Fry', 'price': 400.0},
      {'name': 'Fish Fry', 'price': 340.0},
      {'name': 'Prawns Fry', 'price': 350.0},
      {'name': 'Gravy Prawns', 'price': 400.0},
      {'name': 'Prawns Butter Garlic', 'price': 450.0},
      {'name': 'Fish Butter Garlic', 'price': 450.0},
      {'name': 'Fish Chilly Dry', 'price': 450.0},
      {'name': 'Prawns Chilly Dry', 'price': 450.0},
    ],
  },
  {
    'category': 'Fried Chicken Feast',
    'items': [
      {
        'name': 'Crispy Fried Chicken',
        'variants': [
          {'label': '3 pcs', 'price': 270.0},
          {'label': '6 pcs', 'price': 500.0},
        ],
      },

      {'name': 'Chicken Popcorn (10 pcs)', 'price': 200.0},
      {
        'name': 'Fried Strips',
        'variants': [
          {'label': '6 pcs', 'price': 200.0},
          {'label': '12 pcs', 'price': 380.0},
        ],
      },
    ],
  },
  {
    'category': 'Mughlai Gravy - Chicken',
    'items': [
      {'name': 'Chicken Masala', 'halfPrice': 220.0, 'fullPrice': 430.0},
      {
        'name': 'Butter Chicken Boneless',
        'halfPrice': 220.0,
        'fullPrice': 430.0,
      },
      {
        'name': 'Butter Chicken With Bone',
        'halfPrice': 200.0,
        'fullPrice': 380.0,
      },
      {'name': 'Murgh Musallam', 'halfPrice': 400.0, 'fullPrice': 680.0},
      {'name': 'Murgh Bhuna', 'halfPrice': 400.0, 'fullPrice': 680.0},
      {'name': 'Methi Chicken', 'halfPrice': 220.0, 'fullPrice': 430.0},
      {'name': 'Chicken Tikka Masala', 'halfPrice': 220.0, 'fullPrice': 430.0},
      {
        'name': 'Chicken Afghani Masala',
        'halfPrice': 220.0,
        'fullPrice': 430.0,
      },
      {'name': 'Chicken Haandi', 'halfPrice': 220.0, 'fullPrice': 430.0},
      {'name': 'Kashmiri Chicken', 'halfPrice': 220.0, 'fullPrice': 430.0},
      {
        'name': 'Tandoori Chicken Masala',
        'halfPrice': 400.0,
        'fullPrice': 680.0,
      },
      {
        'name': 'Special Arbian Chicken Masala',
        'halfPrice': 280.0,
        'fullPrice': 530.0,
      },
    ],
  },
  {
    'category': 'Mughlai Gravy - Veg',
    'items': [
      {'name': 'Paneer Butter Masala', 'halfPrice': 220.0, 'fullPrice': 430.0},
      {'name': 'Paneer Tikka Masala', 'halfPrice': 220.0, 'fullPrice': 430.0},
      {'name': 'Paneer Tawa Masala', 'halfPrice': 220.0, 'fullPrice': 430.0},
    ],
  },
  {
    'category': 'Rice (Mughlai)',
    'items': [
      {'name': 'Plain Rice', 'price': 70.0},
      {'name': 'Jeera Rice', 'price': 80.0},
    ],
  },
  {
    'category': 'Chinese Starters - Chicken',
    'items': [
      {'name': 'Chicken Chilly', 'halfPrice': 180.0, 'fullPrice': 340.0},
      {'name': 'Dragon Chilly', 'halfPrice': 180.0, 'fullPrice': 340.0},
      {'name': 'Chilly Sweet And Sour', 'halfPrice': 180.0, 'fullPrice': 340.0},
      {'name': 'Chicken Crispy', 'halfPrice': 180.0, 'fullPrice': 340.0},
      {'name': 'Paper Chicken', 'halfPrice': 180.0, 'fullPrice': 340.0},
      {'name': 'Mayo Paper Chicken', 'halfPrice': 220.0, 'fullPrice': 400.0},
      {'name': 'Chicken 65', 'halfPrice': 180.0, 'fullPrice': 340.0},
      {'name': 'Lollypop Fry', 'halfPrice': 180.0, 'fullPrice': 340.0},
      {'name': 'Lollypop Masala', 'halfPrice': 200.0, 'fullPrice': 380.0},
      {'name': 'Italian Lollypop', 'halfPrice': 200.0, 'fullPrice': 380.0},
      {'name': 'Oyster Chicken', 'halfPrice': 200.0, 'fullPrice': 380.0},
      {'name': 'Chicken Chopsuey', 'price': 250.0},
      {'name': 'Mughlai Chicken', 'halfPrice': 200.0, 'fullPrice': 380.0},
    ],
  },
  {
    'category': 'Chinese Starters - Veg',
    'items': [
      {'name': 'Dry Manchurian', 'halfPrice': 100.0, 'fullPrice': 170.0},
      {'name': 'Paneer Chilly', 'halfPrice': 200.0, 'fullPrice': 380.0},
      {'name': 'Paneer Tikka', 'price': 220.0},
      {'name': 'Bombay Bhel Crispy', 'halfPrice': 120.0, 'fullPrice': 200.0},
    ],
  },
  {
    'category': 'Chinese Rice - Chicken',
    'items': [
      {'name': 'Chicken Fried Rice', 'halfPrice': 120.0, 'fullPrice': 180.0},
      {'name': 'Chicken Schezwan Rice', 'halfPrice': 130.0, 'fullPrice': 200.0},
      {'name': 'Chicken Triple Rice', 'price': 300.0},
      {'name': 'Chicken 3 Triple Rice', 'price': 350.0},
      {'name': 'Chicken Lemon Rice', 'halfPrice': 130.0, 'fullPrice': 200.0},
      {'name': 'Chicken Korean Rice', 'halfPrice': 130.0, 'fullPrice': 200.0},
      {
        'name': 'Chicken Singapore Rice',
        'halfPrice': 130.0,
        'fullPrice': 200.0,
      },
      {
        'name': 'Chicken Mongolian Rice',
        'halfPrice': 130.0,
        'fullPrice': 200.0,
      },
      {'name': 'Chicken Soya Stick Rice', 'price': 290.0},
      {'name': 'Chicken Chopper Rice', 'price': 290.0},
      {'name': 'Chicken Chilly Rice', 'price': 290.0},
      {'name': 'Chicken Crispy Rice', 'price': 290.0},
      {'name': 'Chicken Chipotle Rice', 'price': 320.0},
      {'name': 'Chicken Hot Spot Rice', 'price': 400.0},
      {'name': 'Chicken 1000 Rice', 'price': 400.0},
      {'name': 'Chicken Khabsa Rice', 'price': 375.0},
    ],
  },

  {
    'category': 'Chinese Noodles - Chicken',
    'items': [
      {'name': 'Chicken Fried Noodles', 'halfPrice': 120.0, 'fullPrice': 180.0},
      {
        'name': 'Chicken Schezwan Noodles',
        'halfPrice': 130.0,
        'fullPrice': 200.0,
      },
      {'name': 'Chicken Triple Noodles', 'price': 300.0},
      {'name': 'Chicken 3 Triple Noodles', 'price': 350.0},
      {'name': 'Chicken Lemon Noodles', 'halfPrice': 130.0, 'fullPrice': 200.0},
      {
        'name': 'Chicken Korean Noodles',
        'halfPrice': 130.0,
        'fullPrice': 200.0,
      },
      {
        'name': 'Chicken Singapore Noodles',
        'halfPrice': 130.0,
        'fullPrice': 200.0,
      },
      {
        'name': 'Chicken Mongolian Noodles',
        'halfPrice': 130.0,
        'fullPrice': 200.0,
      },
      {'name': 'Chicken Soya Stick Noodles', 'price': 290.0},
      {'name': 'Chicken Chopper Noodles', 'price': 290.0},
      {'name': 'Chicken Chilly Noodles', 'price': 290.0},
      {'name': 'Chicken Crispy Noodles', 'price': 290.0},
      {'name': 'Chicken Chipotle Noodles', 'price': 320.0},
      {'name': 'Chicken Khabsa Noodles', 'price': 375.0},
    ],
  },

  {
    'category': 'Chinese Rice - Veg',
    'items': [
      {'name': 'Manchurian Fried Rice', 'halfPrice': 100.0, 'fullPrice': 170.0},
      {'name': 'Paneer Rice', 'halfPrice': 120.0, 'fullPrice': 200.0},
      {'name': 'Arabian Plain Rice', 'price': 70.0},
      {'name': 'Jeera Rice', 'price': 80.0},
    ],
  },

  {
    'category': 'Chinese Noodles - Veg',
    'items': [
      {
        'name': 'Manchurian Fried Noodles',
        'halfPrice': 100.0,
        'fullPrice': 170.0,
      },

      {'name': 'Arabian Plain Noodles', 'price': 70.0},
    ],
  },

  {
    'category': 'Special Aap Ke Liye',
    'items': [
      {'name': 'Pineapple Chilly', 'price': 600.0},
      {'name': 'Al Faham Rice', 'halfPrice': 460.0, 'fullPrice': 800.0},
      {'name': 'Mughlai Al Faham Rice', 'halfPrice': 570.0, 'fullPrice': 920.0},
      {'name': 'Shawai Rice', 'halfPrice': 460.0, 'fullPrice': 800.0},
      {'name': 'Zaafraani Shawai Rice', 'halfPrice': 570.0, 'fullPrice': 920.0},
      {'name': 'Sultaani Tikka Rice', 'price': 440.0},
      {'name': 'Tikka Rito Rice', 'price': 420.0},
    ],
  },
  {
    'category': 'Grill Special Thaals',
    'items': [
      {
        'name': 'Thaal for 2 Person',
        'price': 699.0,
        'includes':
            'Chicken Al Faham H + Shawarma Platter + Chicken Tikka + Chicken Lemon Rice + Salad',
      },
      {
        'name': 'Thaal for 4 Person',
        'price': 1399.0,
        'includes':
            'Afghani Chicken H + Chicken Chilly H + Chicken Tikka + Crispy Platter + Chicken Fried Rice + Crackle Fish H + Butter Chicken H + Chapatti Roti 4 + Cold Drink 1L',
      },
      {
        'name': 'Thaal for 6 Person',
        'price': 2299.0,
        'includes':
            'Grilled Chicken H + Sizzling Tandoori H + Reshmi Malai Tikka + Chicken Chilly H + Chicken 65 H + Chicken Singapore Rice + Chicken Lemon Rice + Crackle Fish 6 Pcs + Tandoor Jhinga 12 Pcs + Butter Chicken H + Chicken Haandi H + Chapatti Roti 6 + Cold Drink 1',
      },
    ],
  },
  {
    'category': 'Thaal Extras',
    'items': [
      {'name': 'Mayonnaise', 'price': 15.0},
      {'name': 'Roti/Chapati', 'price': 15.0},
      {'name': 'Butter Roti', 'price': 20.0},
      {'name': 'Paratha', 'price': 20.0},
      {'name': 'Lachha Paratha', 'price': 30.0},
      {'name': 'Khaboos', 'price': 15.0},
    ],
  },
  {
    'category': 'Best & More Combos',
    'items': [
      {
        'name': 'Crispy Snacks',
        'price': 320.0,
        'includes':
            'Crispy Chicken (1pc) + Al-Faham (1pc) + Soft Drink (250ml)',
      },
      {
        'name': 'Dinner Delite',
        'price': 630.0,
        'includes':
            'Crispy Chicken (3pc) + Al-Faham (Half) + Fries + Soft Drink (250ml)',
      },
      {
        'name': 'Mixed Pack',
        'price': 890.0,
        'includes':
            'Crispy Chicken (4pc) + Grill Chicken (Half) + Shawarma Khaboos (2) + Fries + Soft Drink (500ml)',
      },
      {
        'name': 'Family Special',
        'price': 1700.0,
        'includes':
            'Crispy Chicken (8pc) + Grill Chicken (Half) + Al Faham Chicken (Half) + Shawarma Khaboos (4) + Fries + Soft Drink (500ml)',
      },
      {
        'name': 'All In One Combo',
        'price': 1950.0,
        'includes':
            'Shawarma Khaboos (4p) + Chicken Grill (H) + Chicken Al Faham (H) + Fish Tikka + Chicken Strips (6pc) + Chicken Popcorn (10p) + Crispy Chicken (4pc) + Soft Drink (1 Ltr)',
      },
    ],
  },
  {
    'category': 'Value Combos',
    'items': [
      {
        'name': 'Combo 1',
        'price': 230.0,
        'includes':
            'Fish Popcorn (6pc) + Samoli Shawarma (2) + Soft Drink (250ml)',
      },
      {
        'name': 'Combo 2',
        'price': 320.0,
        'includes':
            'Grilled Strips (6pcs) + Samoli Shawarma (2) + Soft Drink (250ml)',
      },
      {
        'name': 'Combo 3',
        'price': 430.0,
        'includes':
            'Fish Tikka Grilled (6pcs) + Samoli Shawarma (2) + Soft Drink (250ml)',
      },
      {
        'name': 'Combo 4',
        'price': 520.0,
        'includes':
            'Chicken Tikka (6pcs) + Samoli/Khaboos Shawarma + 1pc Al Faham + Soft Drink (500ml)',
      },
    ],
  },
  {
    'category': 'Shahi Biryani',
    'items': [
      {'name': 'Shahi Chicken Biryani', 'price': 200.0},
      {'name': 'Tikka Biryani', 'price': 350.0},
      {'name': 'Sheek Biryani', 'price': 350.0},
    ],
  },

  {
    'category': 'Veg & Nonveg Soup',
    'items': [
      {'name': 'Chicken Lemon Coriander Soup', 'price': 120.0},
      {'name': 'Chicken Manchow Soup', 'price': 120.0},
      {'name': 'Chicken Dragon Soup', 'price': 130.0},
      {'name': 'Chicken Clear Soup', 'price': 120.0},
      {'name': 'Chicken Hot & Sour Soup', 'price': 120.0},
      {'name': 'Grill Special Soup', 'price': 150.0},
      {'name': 'Royal Chicken Soup', 'price': 140.0},
    ],
  },

  {
    'category': 'Cold Drinks',
    'items': [
      {
        'name': 'Water Bottle',
        'variants': [
          {'label': 'S', 'price': 10.0},
          {'label': 'L', 'price': 20.0},
        ],
      },

      {
        'name': 'Campa',
        'variants': [
          {'label': 'S', 'price': 10.0},
          {'label': 'M', 'price': 20.0},
          {'label': 'L', 'price': 40.0},
        ],
      },
    ],
  },
];

const List<Map<String, dynamic>> _tawaazoMenu = [
  {
    'category': 'Tandoori',
    'items': [
      {'name': 'Chicken Tandoori', 'halfPrice': 240.0, 'fullPrice': 440.0},
      {
        'name': 'Double Masala Tandoori',
        'halfPrice': 260.0,
        'fullPrice': 470.0,
      },
      {
        'name': 'Chicken Pathani Tandoori',
        'halfPrice': 280.0,
        'fullPrice': 500.0,
      },
      {
        'name': 'Chicken Schezwan Tandoori',
        'halfPrice': 330.0,
        'fullPrice': 550.0,
      },
      {
        'name': 'Chicken Arabian Tandoori',
        'halfPrice': 330.0,
        'fullPrice': 550.0,
      },
      {
        'name': 'Chicken Zafrani Tandoori',
        'halfPrice': 330.0,
        'fullPrice': 550.0,
      },
      {
        'name': 'Chicken Peri-Peri Tandoori',
        'halfPrice': 380.0,
        'fullPrice': 600.0,
      },
      {
        'name': 'Chicken Malai Tandoori',
        'halfPrice': 380.0,
        'fullPrice': 600.0,
      },
      {
        'name': 'Chicken Sizzling Tandoori',
        'halfPrice': 380.0,
        'fullPrice': 600.0,
      },
      {'name': 'Chicken Barra Tandoori', 'price': 650.0},
      {'name': 'Zaika Tandoori', 'halfPrice': 400.0, 'fullPrice': 700.0},
    ],
  },

  {
    'category': 'Leg',
    'items': [
      {'name': 'Chicken Tandoori Leg', 'price': 140.0},
      {'name': 'Chicken Pathani Leg', 'price': 150.0},
      {'name': 'Double Masala Leg', 'price': 150.0},
      {'name': 'Chicken Schezwan Leg', 'price': 170.0},
      {'name': 'Chicken Arabian Leg', 'price': 170.0},
      {'name': 'Chicken Winter Leg', 'price': 170.0},
      {'name': 'Chicken Irani Leg', 'price': 170.0},
      {'name': 'Chicken Zafrani Leg', 'price': 170.0},
      {'name': 'Chicken Peri Peri Leg', 'price': 190.0},
      {'name': 'Chicken Shikari Leg', 'price': 190.0},
      {'name': 'Chicken Mari Maska Leg', 'price': 190.0},
      {'name': 'Chicken Shahi Sp. Leg', 'price': 190.0},
      {'name': 'Tawaazo Sp. Leg', 'price': 200.0},
    ],
  },

  {
    'category': 'Tikka',
    'items': [
      {'name': 'Chicken Seek Kebab', 'price': 100.0},
      {'name': 'Mutton Seek Kebab (BEEF)', 'price': 100.0},
      {'name': 'Malai Seek Kebab', 'price': 150.0},
      {'name': 'Chicken Tikka', 'price': 220.0},
      {'name': 'Pathani Tikka', 'price': 240.0},
      {'name': 'Pahadi Tikka', 'price': 240.0},
      {'name': 'Hyderabadi Tikka', 'price': 240.0},
      {'name': 'Achari Tikka', 'price': 260.0},
      {'name': 'Cheese Burst Tikka', 'price': 260.0},
      {'name': 'Malai Tikka', 'price': 260.0},
      {'name': 'Makhmali Gulabi Tikka', 'price': 260.0},
      {'name': 'Peri-Peri Tikka', 'price': 260.0},
      {'name': 'Fire Tikka', 'price': 280.0},
      {'name': 'Irani Tikka', 'price': 280.0},
      {'name': 'Sizzler Tikka', 'price': 300.0},
      {'name': 'Pineapple Tikka', 'price': 350.0},
      {'name': 'Fish Tikka', 'price': 350.0},
      {'name': 'Fish Angara Tikka', 'price': 380.0},
      {'name': 'Lazawab Tikka', 'price': 400.0},
      {'name': 'Passa Tikka', 'price': 400.0},
      {'name': 'Mutton Tikka', 'price': 70.0},
      {
        'name': 'Chicken Dana',
        'variants': [
          {'label': '250 gm', 'price': 100.0},
          {'label': '500 gm', 'price': 200.0},
          {'label': '750 gm', 'price': 300.0},
          {'label': '1 kg', 'price': 70.0},
        ],
      },
    ],
  },

  {
    'category': 'Mutton Special',
    'items': [
      {'name': 'Mutton Burra (Check Availability)', 'price': 700.0},
      {'name': 'Sukha Mutton (Check Availability)', 'price': 750.0},
      {'name': 'Saudi Mutton (Check Availability)', 'price': 750.0},
      {'name': 'Pathani Mutton (Check Availability)', 'price': 850.0},
    ],
  },

  {
    'category': 'Tawa Mutton',
    'items': [
      {'name': 'Bheja Masala', 'price': 270.0},
      {'name': 'Surti Bheja', 'price': 270.0},
      {'name': 'Kali Mari Bheja', 'price': 270.0},
      {'name': 'Mutton Bhuna', 'price': 350.0},
      {'name': 'Mutton Chap', 'price': 350.0},
      {'name': 'Gurda & Kaleji', 'price': 380.0},
      {'name': 'Bombay Chap', 'price': 380.0},
      {'name': 'Bombay Bhuna', 'price': 380.0},
      {'name': 'Darbari', 'price': 380.0},
      {'name': 'Mutton D', 'price': 400.0},
    ],
  },

  {
    'category': 'Tawa Chicken',
    'items': [
      {'name': 'Tawa Dum Biryani', 'price': 160.0},
      {'name': 'Tawa Chicken', 'price': 240.0},
      {'name': 'Amrin Chicken', 'price': 300.0},
      {'name': 'Chicken Hongkong', 'price': 350.0},
      {'name': 'Luckhnawi Chicken', 'price': 350.0},
      {'name': 'Chicken Tikka Masala (Boneless)', 'price': 280.0},
      {'name': 'Golden Chicken (Boneless)', 'price': 280.0},
      {'name': 'Lahori Chicken (Boneless)', 'price': 300.0},
      {'name': 'Daimond Chicken (Boneless)', 'price': 330.0},
      {'name': 'Chicken Titanic (Boneless)', 'price': 350.0},
      {'name': 'Methi Malai Chicken (Boneless)', 'price': 350.0},
      {'name': 'Chicken Sitara (Boneless)', 'price': 370.0},
      {'name': 'Chicken Karishma (Boneless)', 'price': 400.0},
    ],
  },

  {
    'category': 'Tawa Sea Food',
    'items': [
      {'name': 'Fish Fry', 'price': 240.0},
      {'name': 'Fish Masala', 'price': 240.0},
      {'name': 'Boneless Fish', 'price': 270.0},
      {'name': 'Crackle Fish', 'price': 350.0},
      {'name': 'Prawns Fry', 'price': 380.0},
      {'name': 'Prawns Masala', 'price': 380.0},
      {'name': 'Tandoori Prawns', 'price': 380.0},
    ],
  },

  {
    'category': 'Tawa Khichdi',
    'items': [
      {'name': 'Masala Khichdi', 'price': 120.0},
      {'name': 'Bhuna Khichdi', 'halfPrice': 160.0, 'fullPrice': 250.0},
      {'name': 'Gurda Khichdi', 'price': 280.0},
      {'name': 'Prawns Khichdi', 'price': 300.0},
      {'name': 'Bheja Khichdi', 'price': 300.0},
    ],
  },

  {
    'category': 'Mughlai',
    'items': [
      {'name': 'Chicken Masala', 'halfPrice': 170.0, 'fullPrice': 270.0},
      {'name': 'Chicken Pathani', 'halfPrice': 200.0, 'fullPrice': 300.0},
      {'name': 'Chicken Kadhai', 'halfPrice': 200.0, 'fullPrice': 300.0},
      {'name': 'Chicken Handi', 'halfPrice': 200.0, 'fullPrice': 300.0},
      {'name': 'Chicken Tufani', 'halfPrice': 230.0, 'fullPrice': 330.0},
      {'name': 'Phudina Chicken', 'halfPrice': 230.0, 'fullPrice': 330.0},
      {'name': 'Chicken Mughlai', 'halfPrice': 230.0, 'fullPrice': 330.0},
      {'name': 'Chicken Angara', 'halfPrice': 230.0, 'fullPrice': 330.0},
      {
        'name': 'Chicken Khaibar (Boneless)',
        'halfPrice': 230.0,
        'fullPrice': 330.0,
      },
      {
        'name': 'Chicken Chatpata (Boneless)',
        'halfPrice': 230.0,
        'fullPrice': 330.0,
      },
      {
        'name': 'Nawabi Chicken (Boneless)',
        'halfPrice': 250.0,
        'fullPrice': 350.0,
      },
      {
        'name': 'Butter Chicken (Boneless)',
        'halfPrice': 250.0,
        'fullPrice': 350.0,
      },
      {
        'name': 'Chicken Patiala (Boneless)',
        'halfPrice': 250.0,
        'fullPrice': 350.0,
      },
      {
        'name': 'Chicken Afghani (Boneless)',
        'halfPrice': 250.0,
        'fullPrice': 350.0,
      },
      {'name': 'Cheese Tandoori Masala (Boneless)', 'price': 380.0},
      {'name': 'Chicken Rashida (Boneless)', 'price': 400.0},
      {'name': 'Rose Garden Chicken (Boneless)', 'price': 400.0},
      {'name': 'Mumtaz Chicken (Boneless)', 'price': 450.0},
      {'name': 'Tawaazo Special Chicken (Boneless)', 'price': 500.0},
      {'name': 'Mutton Handi', 'price': 400.0},
      {'name': 'Mutton Kadhai', 'price': 400.0},
      {'name': 'Laal Maas', 'price': 450.0},
      {'name': 'Arabian Mutton', 'price': 450.0},
      {'name': 'Mutton Rogan Josh', 'price': 480.0},
      {'name': 'Tawazo Special Mutton', 'price': 550.0},
    ],
  },

  {
    'category': 'Chinese Soup',
    'items': [
      {'name': 'Chicken Manchow Soup', 'price': 120.0},
      {'name': 'Chicken Hot & Sour Soup', 'price': 130.0},
      {'name': 'Chicken Lemon Corriender Soup', 'price': 140.0},
      {'name': 'Chicken Garlic Soup', 'price': 150.0},
      {'name': 'Tawazo Special Soup', 'price': 160.0},
    ],
  },

  {
    'category': 'Chinese Starter',
    'items': [
      {'name': 'Lolipop Dry/Fry', 'halfPrice': 160.0, 'fullPrice': 260.0},
      {'name': 'Chicken Manchurian', 'halfPrice': 170.0, 'fullPrice': 280.0},
      {'name': 'Chicken Chilli', 'halfPrice': 170.0, 'fullPrice': 280.0},
      {'name': 'Chicken Interian', 'price': 300.0},
      {'name': 'Lal Badshah Dry', 'price': 300.0},
      {'name': 'Dargon Chilli', 'price': 300.0},
      {'name': 'Chicken Crispy', 'price': 300.0},
      {'name': 'Paris Crispy', 'price': 300.0},
      {'name': 'Chatpata Lolipop', 'price': 320.0},
      {'name': 'Bombay Lolipop', 'price': 320.0},
      {'name': 'Chicken Hongkong Lolipop', 'price': 320.0},
      {'name': 'Pepper Chilli', 'price': 340.0},
      {'name': 'Malai Chilli', 'price': 340.0},
      {'name': 'Hungama Chilli', 'price': 350.0},
      {'name': 'Chicken Butter Garlic Dry', 'price': 350.0},
      {'name': 'Shanghai Chicken', 'price': 360.0},
      {'name': 'Mangolian Chicken', 'price': 360.0},
      {'name': 'Fish Chilli', 'price': 360.0},
      {'name': 'Fish Kurkure', 'price': 360.0},
      {'name': 'Prawns Chilli', 'price': 370.0},
      {'name': 'Makkah Fish', 'price': 380.0},
      {'name': 'Butter Garlic Fish', 'price': 400.0},
      {'name': 'Butter Garlic Prawns', 'price': 400.0},
      {'name': 'Pineapple Chilli', 'price': 450.0},
    ],
  },

  {
    'category': 'Chicken Chinese Noodles',
    'items': [
      {'name': 'Hakka Noodles', 'halfPrice': 130.0, 'fullPrice': 180.0},
      {'name': 'Schezwan Noodles', 'halfPrice': 140.0, 'fullPrice': 200.0},
      {'name': 'Singapuri Noodles', 'halfPrice': 150.0, 'fullPrice': 200.0},
      {'name': 'Manchurian Noodles', 'halfPrice': 160.0, 'fullPrice': 220.0},
      {'name': 'Chilli Garlic Noodles', 'halfPrice': 160.0, 'fullPrice': 220.0},
      {'name': 'Hongkong Noodles', 'price': 240.0},
      {'name': 'Hungama Noodles', 'price': 240.0},
      {'name': 'Hyderabadi Noodles', 'price': 250.0},
    ],
  },

  {
    'category': 'Chicken Chinese Rice',
    'items': [
      {'name': 'Fried Rice', 'halfPrice': 130.0, 'fullPrice': 180.0},
      {'name': 'Schezwan Rice', 'halfPrice': 140.0, 'fullPrice': 200.0},
      {'name': 'Singapuri Rice', 'halfPrice': 150.0, 'fullPrice': 200.0},
      {'name': 'Chinese Bhel', 'halfPrice': 160.0, 'fullPrice': 200.0},
      {'name': 'Chilli Garlic Rice', 'halfPrice': 160.0, 'fullPrice': 220.0},
      {'name': 'Manchurian Rice', 'price': 220.0},
      {'name': 'Hungama Rice', 'price': 240.0},
      {'name': 'Hongkong Rice', 'price': 240.0},
      {'name': 'Bombay Bhel', 'price': 250.0},
      {'name': 'Hyderbadi Rice', 'price': 250.0},
    ],
  },

  {
    'category': 'Chicken Special Rice',
    'items': [
      {'name': 'Pack In Rice', 'price': 350.0},
      {'name': 'Trafic Jam Rice', 'price': 350.0},
      {'name': 'Hakka Wakka Rice', 'price': 380.0},
      {'name': 'Khabsa Rice', 'price': 380.0},
      {'name': 'Garden Rice', 'price': 400.0},
      {'name': 'Pizza Rice', 'price': 400.0},
      {'name': 'Box Rice', 'price': 400.0},
      {'name': 'Chicken Ching Rice', 'price': 400.0},
      {'name': 'Tawaazo Sp. Rice', 'price': 450.0},
      {'name': 'Family Rice (3 to 4 Person)', 'price': 450.0},
    ],
  },

  {
    'category': 'Veg Soup',
    'items': [
      {'name': 'Veg Manchow Soup', 'price': 100.0},
      {'name': 'Veg Hot & Sour Soup', 'price': 100.0},
      {'name': 'Veg Garlic Soup', 'price': 120.0},
      {'name': 'Veg Lemon Corriender Soup', 'price': 120.0},
    ],
  },

  {
    'category': 'Veg Starter',
    'items': [
      {'name': 'Veg Manchurian Dry', 'price': 160.0},
      {'name': 'Veg Schezwan Dry', 'price': 180.0},
      {'name': 'Veg Chilli Dry', 'price': 240.0},
      {'name': 'Veg Garlic Dry', 'price': 260.0},
    ],
  },

  {
    'category': 'Veg Noodles',
    'items': [
      {'name': 'Veg Hakka Noodles', 'halfPrice': 100.0, 'fullPrice': 150.0},
      {'name': 'Veg Schezwan Noodles', 'halfPrice': 110.0, 'fullPrice': 160.0},
      {'name': 'Veg Singapuri Noodles', 'halfPrice': 120.0, 'fullPrice': 170.0},
      {'name': 'Veg Hongkong Noodles', 'halfPrice': 130.0, 'fullPrice': 180.0},
    ],
  },

  {
    'category': 'Veg Rice',
    'items': [
      {'name': 'Steam Rice', 'price': 80.0},
      {'name': 'Jeera Rice', 'price': 100.0},
      {'name': 'Veg Fried Rice', 'halfPrice': 100.0, 'fullPrice': 150.0},
      {'name': 'Veg Schezwan Rice', 'halfPrice': 110.0, 'fullPrice': 160.0},
      {'name': 'Veg Singapuri Rice', 'halfPrice': 120.0, 'fullPrice': 170.0},
      {
        'name': 'Veg Butter Garlic Rice',
        'halfPrice': 130.0,
        'fullPrice': 180.0,
      },
      {'name': 'Veg Triple Rice', 'price': 240.0},
    ],
  },

  {
    'category': 'Veg Gravy',
    'items': [
      {'name': 'Veg Manchurian Gravy', 'price': 150.0},
      {'name': 'Veg Chilli Gravy', 'price': 250.0},
    ],
  },

  {
    'category': 'Meifoon, Noodles & Chopsuey',
    'items': [
      {'name': 'American Chopsuey', 'price': 280.0},
      {'name': 'Hu-Nan Chopsuey', 'price': 300.0},
    ],
  },

  {
    'category': 'Roti / Naan',
    'items': [
      {
        'name': 'Chapati Roti',
        'variants': [
          {'label': 'Plain', 'price': 10.0},
          {'label': 'Butter', 'price': 15.0},
        ],
      },
      {
        'name': 'Tandoori Roti',
        'variants': [
          {'label': 'Plain', 'price': 20.0},
          {'label': 'Butter', 'price': 25.0},
        ],
      },
      {
        'name': 'Rumali Roti (Check Availability)',
        'variants': [
          {'label': 'Plain', 'price': 40.0},
          {'label': 'Butter', 'price': 50.0},
        ],
      },
      {'name': 'Butter Naan', 'price': 50.0},
      {
        'name': 'Garlic Naan',
        'variants': [
          {'label': 'Plain', 'price': 50.0},
          {'label': 'Butter', 'price': 60.0},
        ],
      },
      {
        'name': 'Lachha Paratha',
        'variants': [
          {'label': 'Plain', 'price': 50.0},
          {'label': 'Butter', 'price': 60.0},
        ],
      },
      {
        'name': 'Cheese Naan',
        'variants': [
          {'label': 'Plain', 'price': 60.0},
          {'label': 'Butter', 'price': 70.0},
        ],
      },
    ],
  },

  {
    'category': 'Extras',
    'items': [
      {'name': 'Rosted Papad', 'price': 20.0},
      {'name': 'Fry Papad', 'price': 20.0},
      {'name': 'Masala Papad', 'price': 30.0},
      {'name': 'Raita (Check Availability)', 'price': 50.0},
      {'name': 'Water Bottle', 'price': 20.0},

      {
        'name': 'Soft Drink',
        'variants': [
          {'label': 'Small', 'price': 10.0},
          {'label': 'Large', 'price': 20.0},
        ],
      },

      {'name': 'Butter Milk', 'price': 30.0},
    ],
  },
];
