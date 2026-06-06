import 'package:cloud_firestore/cloud_firestore.dart';

class MenuSetupRepository {
  Stream<QuerySnapshot<Map<String, dynamic>>> watchCategories() {
    return FirebaseFirestore.instance.collection('menus').snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>> addCategory(String name) {
    return FirebaseFirestore.instance.collection('menus').add({'name': name});
  }

  Future<void> deleteCategory(String categoryId) {
    return FirebaseFirestore.instance.collection('menus').doc(categoryId).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchItems(String categoryId) {
    return FirebaseFirestore.instance
        .collection('menus')
        .doc(categoryId)
        .collection('items')
        .snapshots();
  }

  Future<void> addItem({
    required String categoryId,
    required String name,
    required dynamic price,
  }) {
    return FirebaseFirestore.instance
        .collection('menus')
        .doc(categoryId)
        .collection('items')
        .add({'name': name, 'price': price});
  }

  Future<void> updateItem({
    required String categoryId,
    required String itemId,
    required String name,
    required dynamic price,
  }) {
    return FirebaseFirestore.instance
        .collection('menus')
        .doc(categoryId)
        .collection('items')
        .doc(itemId)
        .update({'name': name, 'price': price});
  }

  Future<void> deleteItem({
    required String categoryId,
    required String itemId,
  }) {
    return FirebaseFirestore.instance
        .collection('menus')
        .doc(categoryId)
        .collection('items')
        .doc(itemId)
        .delete();
  }
}
