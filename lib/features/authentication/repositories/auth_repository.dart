import 'package:firebase_auth/firebase_auth.dart';

/// Data layer for Firebase authentication (sign-in only).
///
/// New Staff/Admin accounts are provisioned by Admin/SuperAdmin flows via
/// [SecondaryAuthService], not through this repository.
class AuthRepository {
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
}
