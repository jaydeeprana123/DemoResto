import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firebase/secondary_auth_service.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/core/models/staff_member.dart';
import 'package:demo/core/services/restaurant_session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

/// Staff management without Cloud Functions (works on Firebase Spark / no card).
class StaffRepository {
  String? get _restaurantId =>
      Get.find<RestaurantSession>().profile.value?.restaurantId;

  String? get _adminUid => Get.find<RestaurantSession>().profile.value?.uid;

  Future<void> createStaff({
    required String name,
    required String email,
    required String password,
  }) async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      throw Exception('No restaurant is linked to your admin account.');
    }

    final uid = await SecondaryAuthService.createUser(
      email: email,
      password: password,
    );

    await FirestorePaths.user(uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'role': 'Staff',
      'restaurantId': restaurantId,
      'active': true,
      'allowMarkAsDelivered': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<StaffMember>> watchStaff() {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      return Stream.value(const []);
    }

    return FirestorePaths.users()
        .where('restaurantId', isEqualTo: restaurantId)
        .where('role', isEqualTo: 'Staff')
        .snapshots()
        .map(
          (snap) => snap.docs
              .where((d) => d.data()['active'] != false)
              .map((d) => StaffMember.fromFirestore(d.id, d.data()))
              .toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
        );
  }

  /// Active Admin + Staff users for per-user permission toggles.
  Stream<List<StaffMember>> watchRestaurantUsers() {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      return Stream.value(const []);
    }

    return FirestorePaths.users()
        .where('restaurantId', isEqualTo: restaurantId)
        .snapshots()
        .map(
          (snap) => snap.docs
              .where((d) {
                final data = d.data();
                if (data['active'] == false) return false;
                final role = data['role']?.toString();
                return role == 'Admin' || role == 'Staff';
              })
              .map((d) => StaffMember.fromFirestore(d.id, d.data()))
              .toList()
            ..sort((a, b) {
              final roleCmp = a.role.compareTo(b.role);
              if (roleCmp != 0) return roleCmp;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            }),
        );
  }

  /// Persists [allowMarkAsDelivered] on the user doc and updates the in-memory
  /// session profile when the current user is edited.
  Future<void> setAllowMarkAsDelivered({
    required String uid,
    required bool allow,
  }) async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      throw Exception('No restaurant is linked to your admin account.');
    }

    final userDoc = await FirestorePaths.user(uid).get();
    if (!userDoc.exists) throw Exception('User account not found.');

    final data = userDoc.data()!;
    if (data['restaurantId'] != restaurantId) {
      throw Exception('You can only manage users in your restaurant.');
    }
    final role = data['role']?.toString();
    if (role != 'Admin' && role != 'Staff') {
      throw Exception('Only Admin and Staff permissions can be changed.');
    }
    if (data['active'] == false) {
      throw Exception('This account is deactivated.');
    }

    await FirestorePaths.user(uid).set(
      {
        'allowMarkAsDelivered': allow,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final session = Get.find<RestaurantSession>();
    final current = session.profile.value;
    if (current != null && current.uid == uid) {
      session.profile.value = current.copyWith(allowMarkAsDelivered: allow);
    }
  }

  /// Sends a password-reset email to the staff member (no Cloud Functions needed).
  Future<void> sendPasswordResetEmail({required StaffMember staff}) async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      throw Exception('No restaurant is linked to your admin account.');
    }

    final staffDoc = await FirestorePaths.user(staff.uid).get();
    if (!staffDoc.exists) throw Exception('Staff account not found.');

    final data = staffDoc.data()!;
    if (data['role'] != 'Staff' || data['restaurantId'] != restaurantId) {
      throw Exception('You can only manage staff in your restaurant.');
    }
    if (data['active'] == false) {
      throw Exception('This staff account is deactivated.');
    }

    final email = staff.email.trim();
    if (email.isEmpty) throw Exception('Staff email is missing.');

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Failed to send reset email (${e.code}).');
    }
  }

  /// Deactivates staff in Firestore so they cannot use the app (no Auth delete).
  Future<void> deleteStaff({required StaffMember staff}) async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      throw Exception('No restaurant is linked to your admin account.');
    }

    if (staff.uid == _adminUid) {
      throw Exception('You cannot remove your own account here.');
    }

    final staffDoc = await FirestorePaths.user(staff.uid).get();
    if (!staffDoc.exists) throw Exception('Staff account not found.');

    final data = staffDoc.data()!;
    if (data['role'] != 'Staff' || data['restaurantId'] != restaurantId) {
      throw Exception('You can only delete staff in your restaurant.');
    }

    await FirestorePaths.user(staff.uid).update({
      'active': false,
      'deactivatedAt': FieldValue.serverTimestamp(),
      if (_adminUid != null) 'deactivatedBy': _adminUid,
    });
  }
}
