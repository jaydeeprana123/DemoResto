import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firebase/secondary_auth_service.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/core/models/restaurant.dart';
import 'package:demo/core/models/user_profile.dart';

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
    required String mobile1,
    String? mobile2,
    String? mobile3,
    String? logoUrl,
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
      'mobile1': mobile1.trim(),
      if (mobile2 != null && mobile2.trim().isNotEmpty) 'mobile2': mobile2.trim(),
      if (mobile3 != null && mobile3.trim().isNotEmpty) 'mobile3': mobile3.trim(),
      if (logoUrl != null && logoUrl.trim().isNotEmpty) 'logoUrl': logoUrl.trim(),
      'status': RestaurantStatus.active.name,
      'subscriptionStart': Timestamp.fromDate(now),
      'subscriptionEnd': Timestamp.fromDate(end),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateRestaurantProfile({
    required String restaurantId,
    required String name,
    String? address,
    required String mobile1,
    String? mobile2,
    String? mobile3,
    String? logoUrl,
  }) {
    final updates = <String, dynamic>{
      'name': name.trim(),
      'mobile1': mobile1.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final trimmedAddress = address?.trim();
    if (trimmedAddress != null && trimmedAddress.isNotEmpty) {
      updates['address'] = trimmedAddress;
    } else {
      updates['address'] = FieldValue.delete();
    }

    final trimmedMobile2 = mobile2?.trim();
    if (trimmedMobile2 != null && trimmedMobile2.isNotEmpty) {
      updates['mobile2'] = trimmedMobile2;
    } else {
      updates['mobile2'] = FieldValue.delete();
    }

    final trimmedMobile3 = mobile3?.trim();
    if (trimmedMobile3 != null && trimmedMobile3.isNotEmpty) {
      updates['mobile3'] = trimmedMobile3;
    } else {
      updates['mobile3'] = FieldValue.delete();
    }

    final trimmedLogo = logoUrl?.trim();
    if (trimmedLogo != null && trimmedLogo.isNotEmpty) {
      updates['logoUrl'] = trimmedLogo;
    } else {
      updates['logoUrl'] = FieldValue.delete();
    }

    return FirestorePaths.restaurant(restaurantId).update(updates);
  }

  Future<void> updateSubscriptionEnd({
    required String restaurantId,
    required DateTime subscriptionEnd,
  }) {
    return FirestorePaths.restaurant(restaurantId).update({
      'subscriptionEnd': Timestamp.fromDate(subscriptionEnd),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

  Stream<List<UserProfile>> watchRestaurantAdmins() {
    return FirestorePaths.users()
        .where('role', isEqualTo: 'Admin')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => UserProfile.fromFirestore(d.id, d.data()))
              .toList()
            ..sort(_compareAdmins),
        );
  }

  static int _compareAdmins(UserProfile a, UserProfile b) {
    final aCreated = a.createdAt;
    final bCreated = b.createdAt;
    if (aCreated != null && bCreated != null) {
      return bCreated.compareTo(aCreated);
    }
    final aName = (a.name ?? a.email).toLowerCase();
    final bName = (b.name ?? b.email).toLowerCase();
    return aName.compareTo(bName);
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
