import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Data layer for Firebase authentication and user profile documents.
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

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Login screen legacy register path (Staff role, no display name).
  Future<void> createStaffUserDocument(User user) {
    return FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'email': user.email,
      'role': 'Staff',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Sign-up screen user document with name and selected role.
  Future<void> createUserDocument({
    required User user,
    required String name,
    required String role,
  }) {
    return FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': name,
      'email': user.email,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
