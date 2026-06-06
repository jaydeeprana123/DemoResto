class StaffMember {
  const StaffMember({
    required this.uid,
    required this.name,
    required this.email,
  });

  final String uid;
  final String name;
  final String email;

  factory StaffMember.fromFirestore(String uid, Map<String, dynamic> data) {
    return StaffMember(
      uid: uid,
      name: data['name']?.toString().trim().isNotEmpty == true
          ? data['name'].toString().trim()
          : 'Staff',
      email: data['email']?.toString() ?? '',
    );
  }
}
