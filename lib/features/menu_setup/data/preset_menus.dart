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
      {'name': 'Peri Peri Grill Chicken', 'halfPrice': 320.0, 'fullPrice': 570.0},
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
      {'name': 'Salted French Fries', 'price': 80.0},
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
      {'name': 'Zaafraani Grill Chicken', 'halfPrice': 400.0, 'fullPrice': 700.0},
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
      {'name': 'Crispy Fried Chicken (3 pcs)', 'price': 270.0},
      {'name': 'Crispy Fried Chicken (6 pcs)', 'price': 500.0},
      {'name': 'Chicken Popcorn (10 pcs)', 'price': 200.0},
      {'name': 'Fried Strips (6 pcs)', 'price': 200.0},
      {'name': 'Fried Strips (12 pcs)', 'price': 380.0},
    ],
  },
  {
    'category': 'Mughlai Gravy - Chicken',
    'items': [
      {'name': 'Chicken Masala', 'halfPrice': 220.0, 'fullPrice': 430.0},
      {'name': 'Butter Chicken Boneless', 'halfPrice': 220.0, 'fullPrice': 430.0},
      {'name': 'Butter Chicken With Bone', 'halfPrice': 200.0, 'fullPrice': 380.0},
      {'name': 'Murgh Musallam', 'halfPrice': 400.0, 'fullPrice': 680.0},
      {'name': 'Murgh Bhuna', 'halfPrice': 400.0, 'fullPrice': 680.0},
      {'name': 'Methi Chicken', 'halfPrice': 220.0, 'fullPrice': 430.0},
      {'name': 'Chicken Tikka Masala', 'halfPrice': 220.0, 'fullPrice': 430.0},
      {'name': 'Chicken Afghani Masala', 'halfPrice': 220.0, 'fullPrice': 430.0},
      {'name': 'Chicken Haandi', 'halfPrice': 220.0, 'fullPrice': 430.0},
      {'name': 'Kashmiri Chicken', 'halfPrice': 220.0, 'fullPrice': 430.0},
      {'name': 'Tandoori Chicken Masala', 'halfPrice': 400.0, 'fullPrice': 680.0},
      {'name': 'Special Arbian Chicken Masala', 'halfPrice': 280.0, 'fullPrice': 530.0},
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
    'category': 'Chinese Rice & Noodles - Chicken',
    'items': [
      {'name': 'Chicken Fried Rice & Noodles', 'halfPrice': 120.0, 'fullPrice': 180.0},
      {'name': 'Chicken Schezwan Rice & Noodles', 'halfPrice': 130.0, 'fullPrice': 200.0},
      {'name': 'Chicken Triple Rice & Noodles', 'price': 300.0},
      {'name': 'Chicken 3 Triple Rice & Noodles', 'price': 350.0},
      {'name': 'Chicken Lemon Rice & Noodles', 'halfPrice': 130.0, 'fullPrice': 200.0},
      {'name': 'Chicken Korean Rice & Noodles', 'halfPrice': 130.0, 'fullPrice': 200.0},
      {'name': 'Chicken Singapore Rice & Noodles', 'halfPrice': 130.0, 'fullPrice': 200.0},
      {'name': 'Chicken Mongolian Rice & Noodles', 'halfPrice': 130.0, 'fullPrice': 200.0},
      {'name': 'Chicken Soya Stick Rice & Noodles', 'price': 290.0},
      {'name': 'Chicken Chopper Rice & Noodles', 'price': 290.0},
      {'name': 'Chicken Chilly Rice & Noodles', 'price': 290.0},
      {'name': 'Chicken Crispy Rice & Noodles', 'price': 290.0},
      {'name': 'Chicken Chipotle Rice & Noodles', 'price': 320.0},
      {'name': 'Chicken Hot Spot Rice & Noodles', 'price': 400.0},
      {'name': 'Chicken 1000 Rice & Noodles', 'price': 400.0},
      {'name': 'Chicken Khabsa Rice & Noodles', 'price': 375.0},
    ],
  },
  {
    'category': 'Chinese Rice & Noodles - Veg',
    'items': [
      {'name': 'Manchurian Fried Rice & Noodles', 'halfPrice': 100.0, 'fullPrice': 170.0},
      {'name': 'Paneer Rice & Noodles', 'halfPrice': 120.0, 'fullPrice': 200.0},
      {'name': 'Arabian Plain Rice & Noodles', 'price': 70.0},
      {'name': 'Jeera Rice & Noodles', 'price': 80.0},
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
        'includes': 'Crispy Chicken (1pc) + Al-Faham (1pc) + Soft Drink (250ml)',
      },
      {
        'name': 'Dinner Delite',
        'price': 630.0,
        'includes': 'Crispy Chicken (3pc) + Al-Faham (Half) + Fries + Soft Drink (250ml)',
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
        'includes': 'Fish Popcorn (6pc) + Samoli Shawarma (2) + Soft Drink (250ml)',
      },
      {
        'name': 'Combo 2',
        'price': 320.0,
        'includes': 'Grilled Strips (6pcs) + Samoli Shawarma (2) + Soft Drink (250ml)',
      },
      {
        'name': 'Combo 3',
        'price': 430.0,
        'includes': 'Fish Tikka Grilled (6pcs) + Samoli Shawarma (2) + Soft Drink (250ml)',
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
];
