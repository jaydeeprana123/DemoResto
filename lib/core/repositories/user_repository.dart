import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/core/models/user_profile.dart';
import 'package:demo/core/services/restaurant_session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class UserRepository {
  User? get currentUser => FirebaseAuth.instance.currentUser;

  Stream<User?> authStateChanges() =>
      FirebaseAuth.instance.authStateChanges();

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await FirestorePaths.user(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(uid, doc.data()!);
  }

  Future<String?> getUserRole(String uid) async {
    final profile = await getUserProfile(uid);
    return profile?.role;
  }

  Future<void> signOut() async {
    if (Get.isRegistered<RestaurantSession>()) {
      Get.find<RestaurantSession>().clear();
    }
    await FirebaseAuth.instance.signOut();
  }
}
