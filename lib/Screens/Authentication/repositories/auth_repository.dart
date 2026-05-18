import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// AuthRepository
/// 
/// Part of the GetX Repository Pattern.
/// This class acts as the single source of truth for all authentication and user-profile
/// database operations. It interacts directly with Firebase Authentication and Cloud Firestore.
/// By separating the data access logic here, the controller is kept clean and focusing
/// purely on UI state and orchestration.
class AuthRepository {
  // Initialize instances for Firebase Auth and Cloud Firestore.
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Sign in a user with email and password via Firebase Auth.
  /// Returns the [UserCredential] on success.
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('An unexpected authentication error occurred during sign in: $e');
    }
  }

  /// Register a new user account with email and password via Firebase Auth.
  /// Returns the [UserCredential] on success.
  Future<UserCredential> signUpWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('An unexpected authentication error occurred during sign up: $e');
    }
  }

  /// Create or update a user profile document in Firestore inside the 'users' collection.
  /// This stores metadata such as name, email, account role, and timestamp.
  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String role,
    String? name,
  }) async {
    try {
      final Map<String, dynamic> userData = {
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Only add full name if it's provided (used in signup).
      if (name != null && name.trim().isNotEmpty) {
        userData['name'] = name.trim();
      }

      await _db.collection('users').doc(uid).set(userData, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to write user profile to Firestore: $e');
    }
  }

  /// Sign out the current user session from Firebase Auth.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out user: $e');
    }
  }
}
