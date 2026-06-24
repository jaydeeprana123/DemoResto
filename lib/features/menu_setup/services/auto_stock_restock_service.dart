import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/services/restaurant_session.dart';
import 'package:demo/features/menu_setup/services/menu_revision.dart';
import 'package:demo/features/menu_setup/utils/menu_stock_scope.dart';
import 'package:demo/features/menu_setup/utils/menu_stock_utils.dart';
import 'package:get/get.dart';

/// Client-side auto restock using a targeted collection-group query (Option A).
class AutoStockRestockService {
  bool _processing = false;

  /// Returns how many item docs were restocked.
  Future<int> processDueAutoRestocks() async {
    if (_processing) return 0;
    if (!Get.isRegistered<RestaurantSession>()) return 0;

    _processing = true;
    try {
      final restaurantId = MenuStockScope.restaurantIdForItems();
      final now = Timestamp.now();

      final snap = await FirebaseFirestore.instance
          .collectionGroup('items')
          .where('restaurantId', isEqualTo: restaurantId)
          .where('stockMode', isEqualTo: MenuStockUtils.modeAuto)
          .where('inStock', isEqualTo: false)
          .where('nextStockTime', isLessThanOrEqualTo: now)
          .get();

      if (snap.docs.isEmpty) return 0;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          'inStock': true,
          'stockMode': MenuStockUtils.modeManual,
          'nextStockTime': FieldValue.delete(),
        });
      }
      MenuRevision.bumpRevision(batch: batch);
      await batch.commit();
      return snap.docs.length;
    } catch (_) {
      return 0;
    } finally {
      _processing = false;
    }
  }
}
