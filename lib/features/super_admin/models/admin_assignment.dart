import 'package:smartKitchen/core/models/user_profile.dart';

enum AdminAssignmentMode { createNew, assignExisting }

/// Choice made on the create/edit restaurant forms.
class AdminAssignmentInput {
  const AdminAssignmentInput({
    required this.mode,
    this.name = '',
    this.email = '',
    this.password = '',
    this.existingAdmin,
    this.requiredAssignment = false,
    this.existingAdminCount = 0,
  });

  final AdminAssignmentMode mode;
  final String name;
  final String email;
  final String password;
  final UserProfile? existingAdmin;

  /// When false, a blank "create new" form or an empty selection is skipped.
  final bool requiredAssignment;
  final int existingAdminCount;

  bool get _createStarted =>
      name.trim().isNotEmpty || email.trim().isNotEmpty || password.isNotEmpty;

  /// True when Save/Create should write an admin assignment.
  bool get shouldApply {
    if (mode == AdminAssignmentMode.assignExisting) {
      return existingAdmin != null;
    }
    return requiredAssignment || _createStarted;
  }

  String? validate() {
    if (mode == AdminAssignmentMode.assignExisting) {
      if (!shouldApply && !requiredAssignment) return null;
      if (existingAdminCount == 0) {
        return 'No other active admins are available. Create a new admin instead.';
      }
      if (existingAdmin == null) return 'Select an existing admin.';
      return null;
    }

    if (!shouldApply) return null;
    if (name.trim().isEmpty) return 'Admin name is required.';
    if (email.trim().isEmpty) return 'Admin email is required.';
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }
}
