import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.role,
    this.name,
    this.restaurantId,
    this.active = true,
    this.createdAt,
  });

  final String uid;
  final String email;
  final String role;
  final String? name;
  final String? restaurantId;
  final bool active;
  final DateTime? createdAt;

  bool get isSuperAdmin => role == 'SuperAdmin';
  bool get isAdmin => role == 'Admin';
  bool get isStaff => role == 'Staff';
  bool get isRestaurantUser => isAdmin || isStaff;

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      email: data['email']?.toString() ?? '',
      role: data['role']?.toString() ?? 'Staff',
      name: data['name']?.toString(),
      restaurantId: data['restaurantId']?.toString(),
      active: data['active'] != false,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}
