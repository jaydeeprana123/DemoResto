import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UserPreferences
// ─────────────────────────────────────────────────────────────────────────────

class UserPreferences {
  /// 'none' | 'less' | 'medium' | 'extra'
  final String spicyLevel;
  final bool isParcel;
  final bool noOnion;
  final bool noGarlic;

  const UserPreferences({
    this.spicyLevel = 'medium',
    this.isParcel = false,
    this.noOnion = false,
    this.noGarlic = false,
  });

  factory UserPreferences.fromMap(Map<String, dynamic> map) => UserPreferences(
        spicyLevel: map['spicyLevel'] as String? ?? 'medium',
        isParcel: map['isParcel'] as bool? ?? false,
        noOnion: map['noOnion'] as bool? ?? false,
        noGarlic: map['noGarlic'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'spicyLevel': spicyLevel,
        'isParcel': isParcel,
        'noOnion': noOnion,
        'noGarlic': noGarlic,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// LastOrderItem
// ─────────────────────────────────────────────────────────────────────────────

class LastOrderItem {
  final String name;
  final int quantity;
  final String remarks;

  const LastOrderItem({
    required this.name,
    required this.quantity,
    this.remarks = '',
  });

  factory LastOrderItem.fromMap(Map<String, dynamic> map) => LastOrderItem(
        name: map['name'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
        remarks: map['remarks'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'quantity': quantity,
        'remarks': remarks,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// LastOrder
// ─────────────────────────────────────────────────────────────────────────────

class LastOrder {
  final DateTime timestamp;
  final List<LastOrderItem> items;

  const LastOrder({required this.timestamp, required this.items});

  factory LastOrder.fromMap(Map<String, dynamic> map) {
    final ts = map['timestamp'];
    final dt = ts is Timestamp ? ts.toDate() : DateTime.now();
    final rawItems = map['items'] as List<dynamic>? ?? [];
    return LastOrder(
      timestamp: dt,
      items: rawItems
          .map((e) => LastOrderItem.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'timestamp': Timestamp.fromDate(timestamp),
        'items': items.map((i) => i.toMap()).toList(),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// FavoriteItem
// ─────────────────────────────────────────────────────────────────────────────

class FavoriteItem {
  final String name;
  final int orderCount;

  const FavoriteItem({required this.name, required this.orderCount});

  factory FavoriteItem.fromMap(Map<String, dynamic> map) => FavoriteItem(
        name: map['name'] as String? ?? '',
        orderCount: (map['orderCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'orderCount': orderCount,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// UserData
// ─────────────────────────────────────────────────────────────────────────────

class UserData {
  final UserPreferences preferences;
  final List<LastOrder> lastOrders;
  final List<FavoriteItem> favoriteItems;

  const UserData({
    required this.preferences,
    required this.lastOrders,
    required this.favoriteItems,
  });

  factory UserData.empty() => const UserData(
        preferences: UserPreferences(),
        lastOrders: [],
        favoriteItems: [],
      );
}
