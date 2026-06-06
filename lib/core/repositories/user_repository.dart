import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRepository {
  User? get currentUser => FirebaseAuth.instance.currentUser;

  Stream<User?> authStateChanges() =>
      FirebaseAuth.instance.authStateChanges();

  Future<String?> getUserRole(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data()?['role'] as String?;
  }

  Future<void> signOut() => FirebaseAuth.instance.signOut();
}
