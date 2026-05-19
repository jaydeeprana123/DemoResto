import 'package:cloud_firestore/cloud_firestore.dart';

/// CatalogManagementRepository
/// 
/// Part of the GetX Repository Pattern.
/// Abstracts Firestore read/write operations for categories and menu items.
class CatalogManagementRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of categories from menus collection ordered by createdAt.
  Stream<QuerySnapshot<Map<String, dynamic>>> getCategoriesStream() {
    return _firestore
        .collection('menus')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Stream of items within a category collection ordered by createdAt.
  Stream<QuerySnapshot<Map<String, dynamic>>> getMenuItemsStream(String categoryId) {
    return _firestore
        .collection('menus')
        .doc(categoryId)
        .collection('items')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Adds a new category to Firestore.
  Future<void> addCategory(String name) async {
    await _firestore.collection('menus').add({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a category from Firestore.
  Future<void> deleteCategory(String categoryId) async {
    await _firestore.collection('menus').doc(categoryId).delete();
  }

  /// Adds a new menu item to a category in Firestore.
  Future<void> addMenuItem({
    required String categoryId,
    required String name,
    required double price,
  }) async {
    await _firestore
        .collection('menus')
        .doc(categoryId)
        .collection('items')
        .add({
          'name': name,
          'price': price,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /// Deletes a menu item from a category in Firestore.
  Future<void> deleteMenuItem({
    required String categoryId,
    required String itemId,
  }) async {
    await _firestore
        .collection('menus')
        .doc(categoryId)
        .collection('items')
        .doc(itemId)
        .delete();
  }
}
