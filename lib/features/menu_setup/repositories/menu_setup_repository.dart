import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartKitchen/core/firestore/firestore_paths.dart';
import 'package:smartKitchen/features/menu_setup/services/menu_revision.dart';

class MenuSetupRepository {
  Stream<QuerySnapshot<Map<String, dynamic>>> watchCategories() {
    return FirestorePaths.scoped('menus').snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>> addCategory(String name) async {
    final ref = await FirestorePaths.scoped('menus').add({'name': name});
    await MenuRevision.bumpRevision();
    return ref;
  }

  Future<void> deleteCategory(String categoryId) async {
    await FirestorePaths.scopedDoc('menus', categoryId).delete();
    await MenuRevision.bumpRevision();
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
  }) async {
    await FirestorePaths
        .scopedSubCollection('menus', categoryId, 'items')
        .add({'name': name, 'price': price, 'inStock': true});
    await MenuRevision.bumpRevision();
  }

  Future<void> updateItem({
    required String categoryId,
    required String itemId,
    required String name,
    required dynamic price,
  }) async {
    await FirestorePaths
        .scopedSubCollection('menus', categoryId, 'items')
        .doc(itemId)
        .update({'name': name, 'price': price});
    await MenuRevision.bumpRevision();
  }

  Future<void> deleteItem({
    required String categoryId,
    required String itemId,
  }) async {
    await FirestorePaths
        .scopedSubCollection('menus', categoryId, 'items')
        .doc(itemId)
        .delete();
    await MenuRevision.bumpRevision();
  }
}
