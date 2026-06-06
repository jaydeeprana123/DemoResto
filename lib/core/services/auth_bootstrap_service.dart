import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/constants/auth_constants.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthBootstrapService {
  /// Creates Super Admin profile for the configured email on first login.
  static Future<bool> tryBootstrapSuperAdmin(User user) async {
    final email = user.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return false;
    if (email != AuthConstants.superAdminEmail.toLowerCase()) return false;

    await FirestorePaths.user(user.uid).set({
      'email': user.email,
      'name': 'Super Admin',
      'role': 'SuperAdmin',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return true;
  }
}
