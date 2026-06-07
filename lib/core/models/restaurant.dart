import 'package:cloud_firestore/cloud_firestore.dart';

enum RestaurantStatus { active, expired, deactivated }

extension RestaurantStatusLabel on RestaurantStatus {
  String get label => switch (this) {
        RestaurantStatus.active => 'Active',
        RestaurantStatus.expired => 'Expired',
        RestaurantStatus.deactivated => 'Deactivated',
      };
}

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.status,
    required this.subscriptionStart,
    required this.subscriptionEnd,
    this.adminEmail,
    this.address,
    this.createdAt,
    this.cgstPercentage = 0,
    this.sgstPercentage = 0,
  });

  final String id;
  final String name;
  final RestaurantStatus status;
  final DateTime subscriptionStart;
  final DateTime subscriptionEnd;
  final String? adminEmail;
  final String? address;
  final DateTime? createdAt;
  final double cgstPercentage;
  final double sgstPercentage;

  bool get isAccessible => status == RestaurantStatus.active;

  int get daysUntilExpiry {
    final diff = subscriptionEnd.difference(DateTime.now());
    return diff.inDays;
  }

  bool get isExpiringSoon =>
      status == RestaurantStatus.active && daysUntilExpiry <= 7;

  factory Restaurant.fromFirestore(String id, Map<String, dynamic> data) {
    return Restaurant(
      id: id,
      name: data['name']?.toString() ?? 'Restaurant',
      status: _parseStatus(data['status']),
      subscriptionStart: _toDate(data['subscriptionStart']),
      subscriptionEnd: _toDate(data['subscriptionEnd']),
      adminEmail: data['adminEmail']?.toString(),
      address: data['address']?.toString(),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      cgstPercentage: (data['cgstPercentage'] as num?)?.toDouble() ?? 0,
      sgstPercentage: (data['sgstPercentage'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'status': status.name,
      'subscriptionStart': Timestamp.fromDate(subscriptionStart),
      'subscriptionEnd': Timestamp.fromDate(subscriptionEnd),
      if (adminEmail != null) 'adminEmail': adminEmail,
      if (address != null) 'address': address,
      'cgstPercentage': cgstPercentage,
      'sgstPercentage': sgstPercentage,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static RestaurantStatus _parseStatus(dynamic raw) {
    final value = raw?.toString() ?? 'active';
    return RestaurantStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RestaurantStatus.active,
    );
  }

  static DateTime _toDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.now();
  }
}
