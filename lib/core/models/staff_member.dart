class StaffMember {
  const StaffMember({
    required this.uid,
    required this.name,
    required this.email,
    this.role = 'Staff',
    this.allowMarkAsDelivered = false,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final bool allowMarkAsDelivered;

  bool get isAdmin => role == 'Admin';
  bool get isStaff => role == 'Staff';

  factory StaffMember.fromFirestore(String uid, Map<String, dynamic> data) {
    return StaffMember(
      uid: uid,
      name: data['name']?.toString().trim().isNotEmpty == true
          ? data['name'].toString().trim()
          : 'Staff',
      email: data['email']?.toString() ?? '',
      role: data['role']?.toString() ?? 'Staff',
      allowMarkAsDelivered: data['allowMarkAsDelivered'] == true,
    );
  }
}
