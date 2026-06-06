import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firebase/secondary_auth_service.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/core/models/restaurant.dart';

class SuperAdminRepository {
  Stream<List<Restaurant>> watchRestaurants() {
    return FirestorePaths.restaurants()
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Restaurant.fromFirestore(d.id, d.data()))
              .toList(),
        );
  }

  Future<String> createRestaurant({
    required String name,
    String? address,
    required int subscriptionYears,
  }) async {
    final now = DateTime.now();
    final end = DateTime(
      now.year + subscriptionYears,
      now.month,
      now.day,
      23,
      59,
      59,
    );

    final doc = await FirestorePaths.restaurants().add({
      'name': name.trim(),
      if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
      'status': RestaurantStatus.active.name,
      'subscriptionStart': Timestamp.fromDate(now),
      'subscriptionEnd': Timestamp.fromDate(end),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> setRestaurantStatus({
    required String restaurantId,
    required RestaurantStatus status,
  }) {
    return FirestorePaths.restaurant(restaurantId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> extendSubscription({
    required String restaurantId,
    required int additionalYears,
  }) async {
    final doc = await FirestorePaths.restaurant(restaurantId).get();
    if (!doc.exists) throw Exception('Restaurant not found.');

    final data = doc.data()!;
    final currentEnd = Restaurant.fromFirestore(restaurantId, data).subscriptionEnd;
    final base = currentEnd.isAfter(DateTime.now()) ? currentEnd : DateTime.now();
    final newEnd = DateTime(
      base.year + additionalYears,
      base.month,
      base.day,
      23,
      59,
      59,
    );

    await FirestorePaths.restaurant(restaurantId).update({
      'subscriptionEnd': Timestamp.fromDate(newEnd),
      'status': RestaurantStatus.active.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createRestaurantAdmin({
    required String email,
    required String password,
    required String name,
    required String restaurantId,
  }) async {
    final uid = await SecondaryAuthService.createUser(
      email: email,
      password: password,
    );

    await FirestorePaths.user(uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'role': 'Admin',
      'restaurantId': restaurantId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirestorePaths.restaurant(restaurantId).update({
      'adminEmail': email.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }


}
