import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartKitchen/core/firebase/secondary_auth_service.dart';
import 'package:smartKitchen/core/firestore/firestore_paths.dart';
import 'package:smartKitchen/core/models/restaurant.dart';
import 'package:smartKitchen/core/models/user_profile.dart';

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
    String? qrCodeUrl,
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
      if (qrCodeUrl != null && qrCodeUrl.trim().isNotEmpty)
        'qrCodeUrl': qrCodeUrl.trim(),
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
    String? qrCodeUrl,
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

    final trimmedQr = qrCodeUrl?.trim();
    if (trimmedQr != null && trimmedQr.isNotEmpty) {
      updates['qrCodeUrl'] = trimmedQr;
    } else {
      updates['qrCodeUrl'] = FieldValue.delete();
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

  /// Returns the user with this email, if one already exists.
  Future<UserProfile?> findUserByEmail(String email) async {
    final trimmed = email.trim();
    final normalized = trimmed.toLowerCase();
    if (normalized.isEmpty) return null;

    final candidates = <String>{trimmed, normalized};
    for (final value in candidates) {
      final snap = await FirestorePaths.users()
          .where('email', isEqualTo: value)
          .limit(5)
          .get();
      for (final doc in snap.docs) {
        final profile = UserProfile.fromFirestore(doc.id, doc.data());
        if (profile.email.trim().toLowerCase() == normalized) {
          return profile;
        }
      }
    }
    return null;
  }

  /// Creates a new Firebase Auth login and admin profile for [restaurantId].
  /// An email that already exists must be assigned with [assignAdminToRestaurant].
  Future<void> createRestaurantAdmin({
    required String email,
    required String password,
    required String name,
    required String restaurantId,
  }) async {
    final existing = await findUserByEmail(email);
    if (existing != null) {
      if (!existing.isAdmin) {
        throw Exception(
          'This email is already used by a ${existing.role} account.',
        );
      }
      throw Exception(
        'This email already has an admin login. Choose Assign Existing Admin so they keep the same password.',
      );
    }

    final String uid;
    try {
      uid = await SecondaryAuthService.createUser(
        email: email,
        password: password,
      );
    } on Exception catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('already in use') ||
          message.contains('email-already-in-use')) {
        throw Exception(
          'This email is already registered. Assign that admin from the restaurant admins list so they keep the same login.',
        );
      }
      rethrow;
    }

    await FirestorePaths.user(uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'role': 'Admin',
      'restaurantId': restaurantId,
      'restaurantRoles': {restaurantId: 'Admin'},
      'active': true,
      'allowMarkAsDelivered': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _rememberAdminEmailIfEmpty(
      restaurantId: restaurantId,
      email: email.trim(),
    );
  }

  /// Adds [restaurantId] to an existing admin without changing their login.
  /// [restaurantId] and [role] stay as the primary assignment.
  Future<void> assignAdminToRestaurant({
    required UserProfile admin,
    required String restaurantId,
  }) async {
    if (admin.uid.isEmpty) {
      throw Exception('Admin account id is missing.');
    }
    if (restaurantId.trim().isEmpty) {
      throw Exception('Restaurant is missing.');
    }

    final adminDoc = await FirestorePaths.user(admin.uid).get();
    if (!adminDoc.exists) throw Exception('Admin account not found.');

    final data = adminDoc.data()!;
    if (data['role']?.toString() != 'Admin') {
      throw Exception('Only restaurant Admin accounts can be assigned.');
    }
    if (data['active'] == false) {
      throw Exception('This admin account is deactivated.');
    }

    final profile = UserProfile.fromFirestore(admin.uid, data);
    if (profile.managesRestaurant(restaurantId)) {
      throw Exception('This admin is already assigned to this restaurant.');
    }

    final roles = Map<String, String>.from(profile.restaurantRoles);
    final primary = profile.restaurantId?.trim() ?? '';
    if (primary.isNotEmpty) {
      roles.putIfAbsent(primary, () => 'Admin');
    }
    roles[restaurantId] = 'Admin';

    final updates = <String, dynamic>{
      'restaurantRoles': roles,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (primary.isEmpty) {
      updates['restaurantId'] = restaurantId;
    }

    await FirestorePaths.user(admin.uid).update(updates);
    await _rememberAdminEmailIfEmpty(
      restaurantId: restaurantId,
      email: (data['email']?.toString() ?? admin.email).trim(),
    );
  }

  /// Records the first admin email on the restaurant. Later admins are not
  /// written over it, and the admin's own login is left unchanged.
  Future<void> _rememberAdminEmailIfEmpty({
    required String restaurantId,
    required String email,
  }) async {
    if (email.isEmpty) return;
    final restaurantDoc = await FirestorePaths.restaurant(restaurantId).get();
    final current = restaurantDoc.data()?['adminEmail']?.toString().trim() ?? '';
    if (current.isNotEmpty) return;
    await FirestorePaths.restaurant(restaurantId).update({
      'adminEmail': email,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes access to one restaurant.
  /// The account is deactivated only when this was their last restaurant.
  /// Firebase Auth login is not deleted (same pattern as Staff delete).
  Future<void> deleteRestaurantAdmin({
    required UserProfile admin,
    required String restaurantId,
  }) async {
    if (admin.uid.isEmpty) {
      throw Exception('Admin account id is missing.');
    }

    final adminDoc = await FirestorePaths.user(admin.uid).get();
    if (!adminDoc.exists) throw Exception('Admin account not found.');

    final data = adminDoc.data()!;
    if (data['role']?.toString() != 'Admin') {
      throw Exception('Only restaurant Admin accounts can be deleted here.');
    }
    final profile = UserProfile.fromFirestore(admin.uid, data);
    if (!profile.managesRestaurant(restaurantId)) {
      throw Exception('This admin does not belong to the selected restaurant.');
    }
    if (data['active'] == false) {
      throw Exception('This admin account is already deactivated.');
    }

    final remaining = Map<String, String>.from(profile.restaurantRoles);
    final primary = profile.restaurantId?.trim() ?? '';
    if (primary.isNotEmpty) {
      remaining.putIfAbsent(primary, () => 'Admin');
    }
    remaining.remove(restaurantId);

    if (remaining.isEmpty) {
      await FirestorePaths.user(admin.uid).update({
        'restaurantRoles': <String, String>{},
        'active': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
        'deactivatedByRole': 'SuperAdmin',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final updates = <String, dynamic>{
        'restaurantRoles': remaining,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (primary == restaurantId) {
        updates['restaurantId'] = remaining.keys.first;
      }
      await FirestorePaths.user(admin.uid).update(updates);
    }

    final restaurantDoc = await FirestorePaths.restaurant(restaurantId).get();
    final restaurantEmail = restaurantDoc.data()?['adminEmail']?.toString().trim();
    final adminEmail = (data['email']?.toString() ?? admin.email).trim();
    if (restaurantEmail != null &&
        restaurantEmail.isNotEmpty &&
        restaurantEmail.toLowerCase() == adminEmail.toLowerCase()) {
      await FirestorePaths.restaurant(restaurantId).update({
        'adminEmail': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
