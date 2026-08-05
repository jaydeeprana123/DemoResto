import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartKitchen/core/services/restaurant_session.dart';
import 'package:get/get.dart';

/// Resolves Firestore paths under `restaurants/{id}/…` with legacy root fallback.
class FirestorePaths {
  static const legacyRestaurantId = 'default';

  static RestaurantSession get _session => Get.find<RestaurantSession>();

  static CollectionReference<Map<String, dynamic>> restaurants() {
    return FirebaseFirestore.instance.collection('restaurants');
  }

  static DocumentReference<Map<String, dynamic>> restaurant(String id) {
    return restaurants().doc(id);
  }

  static CollectionReference<Map<String, dynamic>> scoped(String name) {
    if (_session.useLegacyCollections) {
      return legacy(name);
    }
    return FirebaseFirestore.instance
        .collection('restaurants')
        .doc(_session.scopedRestaurantId)
        .collection(name);
  }

  static DocumentReference<Map<String, dynamic>> scopedDoc(
    String collection,
    String docId,
  ) {
    return scoped(collection).doc(docId);
  }

  static CollectionReference<Map<String, dynamic>> scopedSubCollection(
    String parentCollection,
    String parentDocId,
    String subCollection,
  ) {
    if (_session.useLegacyCollections) {
      return legacy(parentCollection)
          .doc(parentDocId)
          .collection(subCollection);
    }
    return FirebaseFirestore.instance
        .collection('restaurants')
        .doc(_session.scopedRestaurantId)
        .collection(parentCollection)
        .doc(parentDocId)
        .collection(subCollection);
  }

  static CollectionReference<Map<String, dynamic>> legacy(String name) {
    return FirebaseFirestore.instance.collection(name);
  }

  static CollectionReference<Map<String, dynamic>> users() {
    return FirebaseFirestore.instance.collection('users');
  }

  static DocumentReference<Map<String, dynamic>> user(String uid) {
    return users().doc(uid);
  }
}
