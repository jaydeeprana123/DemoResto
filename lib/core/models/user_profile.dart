import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.role,
    this.name,
    this.restaurantId,
    this.restaurantRoles = const {},
    this.active = true,
    this.allowMarkAsDelivered = false,
    this.createdAt,
  });

  final String uid;
  final String email;
  final String role;
  final String? name;
  final String? restaurantId;

  /// Restaurant id → role (`Admin` or `Staff`).
  /// Existing accounts keep working through [restaurantId] and [role] alone.
  final Map<String, String> restaurantRoles;
  final bool active;
  /// When true, this user may mark paid orders as delivered/served.
  /// Defaults to false for all users.
  final bool allowMarkAsDelivered;
  final DateTime? createdAt;

  bool get isSuperAdmin => role == 'SuperAdmin';
  bool get isAdmin => role == 'Admin';
  bool get isStaff => role == 'Staff';
  bool get isRestaurantUser => isAdmin || isStaff;

  /// Primary restaurant first, then any extra ids in [restaurantRoles].
  List<String> get assignedRestaurantIds {
    final ids = <String>[];
    final primary = restaurantId?.trim() ?? '';
    if (primary.isNotEmpty) ids.add(primary);
    for (final id in restaurantRoles.keys) {
      final trimmed = id.trim();
      if (trimmed.isEmpty || ids.contains(trimmed)) continue;
      ids.add(trimmed);
    }
    return ids;
  }

  bool get hasMultipleRestaurants => assignedRestaurantIds.length > 1;

  bool managesRestaurant(String restaurantId) {
    return assignedRestaurantIds.contains(restaurantId);
  }

  String roleForRestaurant(String restaurantId) {
    final mapped = restaurantRoles[restaurantId];
    if (mapped != null && mapped.isNotEmpty) return mapped;
    if (this.restaurantId == restaurantId) return role;
    return '';
  }

  UserProfile copyWith({
    String? uid,
    String? email,
    String? role,
    String? name,
    String? restaurantId,
    Map<String, String>? restaurantRoles,
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
      restaurantRoles: restaurantRoles ?? this.restaurantRoles,
      active: active ?? this.active,
      allowMarkAsDelivered: allowMarkAsDelivered ?? this.allowMarkAsDelivered,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static Map<String, String> parseRestaurantRoles(dynamic raw) {
    if (raw is! Map) return const {};
    final roles = <String, String>{};
    raw.forEach((key, value) {
      final id = key.toString().trim();
      final role = value?.toString().trim() ?? '';
      if (id.isEmpty || role.isEmpty) return;
      roles[id] = role;
    });
    return roles;
  }

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      email: data['email']?.toString() ?? '',
      role: data['role']?.toString() ?? 'Staff',
      name: data['name']?.toString(),
      restaurantId: data['restaurantId']?.toString(),
      restaurantRoles: parseRestaurantRoles(data['restaurantRoles']),
      active: data['active'] != false,
      allowMarkAsDelivered: data['allowMarkAsDelivered'] == true,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}
