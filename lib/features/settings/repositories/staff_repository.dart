import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:demo/core/firebase/secondary_auth_service.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/core/models/staff_member.dart';
import 'package:demo/core/services/restaurant_session.dart';
import 'package:get/get.dart';

class StaffRepository {
  String? get _restaurantId =>
      Get.find<RestaurantSession>().profile.value?.restaurantId;

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
              .map((d) => StaffMember.fromFirestore(d.id, d.data()))
              .toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
        );
  }

  Future<void> updateStaffPassword({
    required StaffMember staff,
    required String newPassword,
  }) async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      throw Exception('No restaurant is linked to your admin account.');
    }

    final staffDoc = await FirestorePaths.user(staff.uid).get();
    if (!staffDoc.exists) throw Exception('Staff account not found.');

    final data = staffDoc.data()!;
    if (data['role'] != 'Staff' || data['restaurantId'] != restaurantId) {
      throw Exception('You can only update staff in your restaurant.');
    }

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('updateStaffPassword');
      await callable.call({
        'staffUid': staff.uid,
        'newPassword': newPassword,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to update password (${e.code}).');
    }
  }
}
