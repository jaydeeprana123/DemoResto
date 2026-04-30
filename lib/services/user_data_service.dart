import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:demo/models/user_data.dart';
import 'package:demo/services/ai_order_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UserDataService — Firestore CRUD for user history & preferences
//
// Firestore schema:
//   users/{uid}/
//     preferences    : Map   (spicyLevel, isParcel, noOnion, noGarlic)
//     lastOrders     : Array (max 5, newest first)
//     favoriteItems  : Array (top 20 by orderCount)
// ─────────────────────────────────────────────────────────────────────────────

class UserDataService {
  static final UserDataService _instance = UserDataService._internal();
  factory UserDataService() => _instance;
  UserDataService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  // ── Fetch all user data ──────────────────────────────────────────────────

  Future<UserData> getUserData() async {
    try {
      final doc = _userDoc;
      if (doc == null) return UserData.empty();

      final snapshot = await doc.get().timeout(const Duration(seconds: 8));
      if (!snapshot.exists) return UserData.empty();

      final data = snapshot.data()!;
      final prefs = UserPreferences.fromMap(
        data['preferences'] as Map<String, dynamic>? ?? {},
      );

      final rawOrders = data['lastOrders'] as List<dynamic>? ?? [];
      final lastOrders = rawOrders
          .map((e) => LastOrder.fromMap(e as Map<String, dynamic>))
          .toList();

      final rawFavs = data['favoriteItems'] as List<dynamic>? ?? [];
      final favoriteItems = rawFavs
          .map((e) => FavoriteItem.fromMap(e as Map<String, dynamic>))
          .toList();

      return UserData(
        preferences: prefs,
        lastOrders: lastOrders,
        favoriteItems: favoriteItems,
      );
    } catch (e) {
      debugPrint('[UserDataService] getUserData error: $e');
      return UserData.empty();
    }
  }

  // ── Save order to history ────────────────────────────────────────────────

  Future<void> saveLastOrder(List<OrderResult> results) async {
    try {
      final doc = _userDoc;
      if (doc == null || results.isEmpty) return;

      final newOrder = LastOrder(
        timestamp: DateTime.now(),
        items: results
            .map((r) => LastOrderItem(
                  name: r.item['name'].toString(),
                  quantity: r.quantity,
                  remarks: r.remarks,
                ))
            .toList(),
      );

      final snapshot = await doc.get().timeout(const Duration(seconds: 8));
      final currentData = snapshot.data() ?? {};
      final rawOrders = currentData['lastOrders'] as List<dynamic>? ?? [];

      // Prepend new order, keep max 5
      final updatedOrders = [newOrder.toMap(), ...rawOrders.take(4)];

      await doc.set(
        {'lastOrders': updatedOrders},
        SetOptions(merge: true),
      );

      // Update favorites (fire and forget — non-critical)
      _updateFavorites(results, currentData).ignore();
    } catch (e) {
      debugPrint('[UserDataService] saveLastOrder error: $e');
    }
  }

  // ── Update preferences ───────────────────────────────────────────────────

  Future<void> updatePreferences(UserPreferences prefs) async {
    try {
      final doc = _userDoc;
      if (doc == null) return;
      await doc.set(
        {'preferences': prefs.toMap()},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[UserDataService] updatePreferences error: $e');
    }
  }

  // ── Internal: rebuild favorites map ─────────────────────────────────────

  Future<void> _updateFavorites(
    List<OrderResult> results,
    Map<String, dynamic> currentData,
  ) async {
    final doc = _userDoc;
    if (doc == null) return;

    final rawFavs = currentData['favoriteItems'] as List<dynamic>? ?? [];
    final favMap = <String, int>{};

    for (final raw in rawFavs) {
      final f = FavoriteItem.fromMap(raw as Map<String, dynamic>);
      favMap[f.name] = f.orderCount;
    }
    for (final r in results) {
      final name = r.item['name'].toString();
      favMap[name] = (favMap[name] ?? 0) + r.quantity;
    }

    // Sort descending by count, keep top 20
    final sorted = favMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final updatedFavs = sorted
        .take(20)
        .map((e) => {'name': e.key, 'orderCount': e.value})
        .toList();

    await doc.set({'favoriteItems': updatedFavs}, SetOptions(merge: true));
  }
}
