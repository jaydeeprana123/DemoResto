import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/core/models/menu_stock_entry.dart';
import 'package:demo/features/menu_setup/utils/menu_sort_utils.dart';
import 'package:demo/features/menu_setup/utils/menu_stock_utils.dart';
import 'package:demo/features/ordering/utils/menu_item_variants.dart';

class StockRepository {
  List<MenuStockEntry> _buildStockEntries(
    String categoryId,
    String categoryName,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final docById = {
      for (final doc in docs) doc.id: doc,
    };

    final rawItems = sortMenuDocs(docs).map((doc) {
      final data = doc.data();
      return {
        ...data,
        'categoryId': categoryId,
        'itemId': doc.id,
        'category': categoryName,
        'categorySortOrder': (data['sortOrder'] as num?)?.toInt() ??
            (data['categorySortOrder'] as num?)?.toInt() ??
            9999,
        'itemSortOrder': (data['sortOrder'] as num?)?.toInt() ?? 9999,
        'inStock': MenuStockUtils.isInStock(data),
      };
    }).toList();

    final normalized = MenuItemVariants.normalizeCategoryItems(
      rawItems,
      categoryName,
    );

    return normalized.map((item) {
      final targetKeys = _firestoreTargetKeys(item);
      var inStock = true;
      for (final key in targetKeys) {
        final parts = key.split('|');
        if (parts.length != 2) continue;
        final doc = docById[parts[1]];
        if (doc != null && !MenuStockUtils.isInStock(doc.data())) {
          inStock = false;
          break;
        }
      }

      return MenuStockEntry(
        categoryId: categoryId,
        categoryName: categoryName,
        name: MenuItemVariants.displayName(item),
        inStock: inStock,
        firestoreTargetKeys: targetKeys,
        hasVariants: MenuItemVariants.hasVariants(item),
      );
    }).toList();
  }

  List<String> _firestoreTargetKeys(Map<String, dynamic> item) {
    final keys = <String>{};
    if (MenuItemVariants.hasVariants(item)) {
      for (final variant in MenuItemVariants.variantsOf(item)) {
        final catId =
            variant['categoryId']?.toString() ?? item['categoryId']?.toString();
        final itemId = variant['itemId']?.toString();
        if (catId != null && itemId != null) {
          keys.add('$catId|$itemId');
        }
      }
    }

    if (keys.isEmpty) {
      final catId = item['categoryId']?.toString();
      final itemId = item['itemId']?.toString();
      if (catId != null && itemId != null) {
        keys.add('$catId|$itemId');
      }
    }
    return keys.toList()..sort();
  }

  Stream<List<MenuStockEntry>> watchMenuStock() {
    return FirestorePaths.scoped('menus').snapshots().asyncExpand((catSnap) {
      return _mergeItemSnapshots(sortMenuDocs(catSnap.docs));
    });
  }

  Stream<List<MenuStockEntry>> _mergeItemSnapshots(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> categories,
  ) {
    if (categories.isEmpty) {
      return Stream.value(const []);
    }

    late StreamController<List<MenuStockEntry>> controller;
    final latestByCategory = <String, List<MenuStockEntry>>{};
    final subscriptions = <StreamSubscription<dynamic>>[];

    void emitMerged() {
      if (controller.isClosed) return;
      final merged = latestByCategory.values.expand((e) => e).toList()
        ..sort((a, b) {
          final cat = a.categoryName.toLowerCase().compareTo(
            b.categoryName.toLowerCase(),
          );
          if (cat != 0) return cat;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      controller.add(merged);
    }

    controller = StreamController<List<MenuStockEntry>>(
      onListen: () {
        for (final catDoc in categories) {
          final categoryId = catDoc.id;
          final categoryName = catDoc.data()['name']?.toString() ?? 'Menu';
          final sub = FirestorePaths
              .scopedSubCollection('menus', categoryId, 'items')
              .snapshots()
              .listen((itemSnap) {
            latestByCategory[categoryId] = _buildStockEntries(
              categoryId,
              categoryName,
              sortMenuDocs(itemSnap.docs),
            );
            emitMerged();
          });
          subscriptions.add(sub);
        }
      },
      onCancel: () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
      },
    );

    return controller.stream;
  }

  Future<void> setStockStatus({
    required Iterable<MenuStockEntry> items,
    required bool inStock,
  }) async {
    await setStockByKeys(
      items.map((e) => e.key),
      inStock: inStock,
    );
  }

  Future<void> setStockByKeys(
    Iterable<String> keys, {
    required bool inStock,
  }) async {
    final firestoreKeys = <String>{};
    for (final key in keys) {
      if (key.contains('~')) {
        firestoreKeys.addAll(key.split('~'));
      } else {
        firestoreKeys.add(key);
      }
    }
    if (firestoreKeys.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final firestoreKey in firestoreKeys) {
      final parts = firestoreKey.split('|');
      if (parts.length != 2) continue;
      batch.update(
        FirestorePaths.scopedSubCollection('menus', parts[0], 'items')
            .doc(parts[1]),
        {'inStock': inStock},
      );
    }
    await batch.commit();
  }
}
