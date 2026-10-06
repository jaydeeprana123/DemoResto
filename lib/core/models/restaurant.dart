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
    this.logoUrl,
    this.qrCodeUrl,
    this.mobile1,
    this.mobile2,
    this.mobile3,
    this.createdAt,
    this.cgstPercentage = 0,
    this.sgstPercentage = 0,
    this.staffEditDeleteLimitMinutes = 0,
  });

  final String id;
  final String name;
  final RestaurantStatus status;
  final DateTime subscriptionStart;
  final DateTime subscriptionEnd;
  final String? adminEmail;
  final String? address;
  final String? logoUrl;
  final String? qrCodeUrl;
  final String? mobile1;
  final String? mobile2;
  final String? mobile3;
  final DateTime? createdAt;
  final double cgstPercentage;
  final double sgstPercentage;

  /// Minutes a Staff user is allowed to edit/delete the latest order after it
  /// was placed. `0` means no time restriction (Staff can always modify).
  /// Admins are never restricted by this value.
  final int staffEditDeleteLimitMinutes;

  bool get isAccessible => status == RestaurantStatus.active;

  int get daysUntilExpiry {
    final diff = subscriptionEnd.difference(DateTime.now());
    return diff.inDays;
  }

  bool get isExpiringSoon =>
      status == RestaurantStatus.active && daysUntilExpiry <= 7;

  /// Non-empty mobile numbers joined for display (e.g. "9876543210, 9123456789").
  String get mobileNumbersLine => [mobile1, mobile2, mobile3]
      .whereType<String>()
      .map((m) => m.trim())
      .where((m) => m.isNotEmpty)
      .join(', ');

  factory Restaurant.fromFirestore(String id, Map<String, dynamic> data) {
    return Restaurant(
      id: id,
      name: data['name']?.toString() ?? 'Restaurant',
      status: _parseStatus(data['status']),
      subscriptionStart: _toDate(data['subscriptionStart']),
      subscriptionEnd: _toDate(data['subscriptionEnd']),
      adminEmail: data['adminEmail']?.toString(),
      address: data['address']?.toString(),
      logoUrl: data['logoUrl']?.toString(),
      qrCodeUrl: data['qrCodeUrl']?.toString(),
      mobile1: data['mobile1']?.toString(),
      mobile2: data['mobile2']?.toString(),
      mobile3: data['mobile3']?.toString(),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      cgstPercentage: (data['cgstPercentage'] as num?)?.toDouble() ?? 0,
      sgstPercentage: (data['sgstPercentage'] as num?)?.toDouble() ?? 0,
      staffEditDeleteLimitMinutes:
          (data['staffEditDeleteLimitMinutes'] as num?)?.toInt() ?? 0,
    );
  }

  Restaurant copyWith({
    String? name,
    RestaurantStatus? status,
    DateTime? subscriptionStart,
    DateTime? subscriptionEnd,
    String? adminEmail,
    String? address,
    String? logoUrl,
    String? qrCodeUrl,
    String? mobile1,
    String? mobile2,
    String? mobile3,
    DateTime? createdAt,
    double? cgstPercentage,
    double? sgstPercentage,
    int? staffEditDeleteLimitMinutes,
  }) {
    return Restaurant(
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
      subscriptionStart: subscriptionStart ?? this.subscriptionStart,
      subscriptionEnd: subscriptionEnd ?? this.subscriptionEnd,
      adminEmail: adminEmail ?? this.adminEmail,
      address: address ?? this.address,
      logoUrl: logoUrl ?? this.logoUrl,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      mobile1: mobile1 ?? this.mobile1,
      mobile2: mobile2 ?? this.mobile2,
      mobile3: mobile3 ?? this.mobile3,
      createdAt: createdAt ?? this.createdAt,
      cgstPercentage: cgstPercentage ?? this.cgstPercentage,
      sgstPercentage: sgstPercentage ?? this.sgstPercentage,
      staffEditDeleteLimitMinutes:
          staffEditDeleteLimitMinutes ?? this.staffEditDeleteLimitMinutes,
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
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (qrCodeUrl != null) 'qrCodeUrl': qrCodeUrl,
      if (mobile1 != null) 'mobile1': mobile1,
      if (mobile2 != null) 'mobile2': mobile2,
      if (mobile3 != null) 'mobile3': mobile3,
      'cgstPercentage': cgstPercentage,
      'sgstPercentage': sgstPercentage,
      'staffEditDeleteLimitMinutes': staffEditDeleteLimitMinutes,
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
