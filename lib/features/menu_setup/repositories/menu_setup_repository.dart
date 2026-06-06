import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';

class MenuSetupRepository {
  Stream<QuerySnapshot<Map<String, dynamic>>> watchCategories() {
    return FirestorePaths.scoped('menus').snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>> addCategory(String name) {
    return FirestorePaths.scoped('menus').add({'name': name});
  }

  Future<void> deleteCategory(String categoryId) {
    return FirestorePaths.scopedDoc('menus', categoryId).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchItems(String categoryId) {
    return FirestorePaths
        .scopedSubCollection('menus', categoryId, 'items')
        .snapshots();
  }

  Future<void> addItem({
    required String categoryId,
    required String name,
    required dynamic price,
  }) {
    return FirestorePaths
        .scopedSubCollection('menus', categoryId, 'items')
        .add({'name': name, 'price': price});
  }

  Future<void> updateItem({
    required String categoryId,
    required String itemId,
    required String name,
    required dynamic price,
  }) {
    return FirestorePaths
        .scopedSubCollection('menus', categoryId, 'items')
        .doc(itemId)
        .update({'name': name, 'price': price});
  }

  Future<void> deleteItem({
    required String categoryId,
    required String itemId,
  }) {
    return FirestorePaths
        .scopedSubCollection('menus', categoryId, 'items')
        .doc(itemId)
        .delete();
  }
}
