import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.role,
    this.name,
    this.restaurantId,
    this.active = true,
    this.allowMarkAsDelivered = false,
    this.createdAt,
  });

  final String uid;
  final String email;
  final String role;
  final String? name;
  final String? restaurantId;
  final bool active;
  /// When true, this user may mark paid orders as delivered/served.
  /// Defaults to false for all users.
  final bool allowMarkAsDelivered;
  final DateTime? createdAt;

  bool get isSuperAdmin => role == 'SuperAdmin';
  bool get isAdmin => role == 'Admin';
  bool get isStaff => role == 'Staff';
  bool get isRestaurantUser => isAdmin || isStaff;

  UserProfile copyWith({
    String? uid,
    String? email,
    String? role,
    String? name,
    String? restaurantId,
    bool? active,
    bool? allowMarkAsDelivered,
    DateTime? createdAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      name: name ?? this.name,
      restaurantId: restaurantId ?? this.restaurantId,
      active: active ?? this.active,
      allowMarkAsDelivered: allowMarkAsDelivered ?? this.allowMarkAsDelivered,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      email: data['email']?.toString() ?? '',
      role: data['role']?.toString() ?? 'Staff',
      name: data['name']?.toString(),
      restaurantId: data['restaurantId']?.toString(),
      active: data['active'] != false,
      allowMarkAsDelivered: data['allowMarkAsDelivered'] == true,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}
