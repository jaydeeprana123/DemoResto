import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/core/services/restaurant_session.dart';
import 'package:get/get.dart';

/// Reads/writes the Staff edit/delete time limit (in minutes) on the
/// restaurant document. `0` means Staff have no time restriction.
class StaffPermissionSettingsService {
  const StaffPermissionSettingsService._();

  static RestaurantSession get _session => Get.find<RestaurantSession>();

  static Future<int> loadEditDeleteLimitMinutes() async {
    final restaurant = _session.activeRestaurant.value;
    if (restaurant != null) {
      return restaurant.staffEditDeleteLimitMinutes;
    }

    final restaurantId = _session.scopedRestaurantId;
    if (restaurantId.isEmpty) return 0;

    final doc = await FirestorePaths.restaurant(restaurantId).get();
    if (!doc.exists) return 0;
    return (doc.data()?['staffEditDeleteLimitMinutes'] as num?)?.toInt() ?? 0;
  }

  static Future<void> saveEditDeleteLimitMinutes(int minutes) async {
    final restaurantId = _session.scopedRestaurantId;
    if (restaurantId.isEmpty) {
      throw StateError('No restaurant linked to save permission settings.');
    }

    final value = minutes < 0 ? 0 : minutes;

    await FirestorePaths.restaurant(restaurantId).set(
      {
        'staffEditDeleteLimitMinutes': value,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final current = _session.activeRestaurant.value;
    if (current != null) {
      _session.activeRestaurant.value = current.copyWith(
        staffEditDeleteLimitMinutes: value,
      );
    } else {
      await _session.reloadRestaurant();
    }
  }
}
