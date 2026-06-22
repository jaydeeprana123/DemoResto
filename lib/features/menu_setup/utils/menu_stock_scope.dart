import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/core/services/restaurant_session.dart';
import 'package:get/get.dart';

/// Restaurant key stored on menu item docs for collection-group stock queries.
class MenuStockScope {
  MenuStockScope._();

  static String restaurantIdForItems() {
    final session = Get.find<RestaurantSession>();
    if (session.useLegacyCollections) {
      return '${FirestorePaths.legacyRestaurantId}_legacy';
    }
    return session.scopedRestaurantId;
  }
}
