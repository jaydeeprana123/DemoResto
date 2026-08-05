import 'package:smartKitchen/core/services/restaurant_session.dart';
import 'package:get/get.dart';

/// Whether the logged-in user may open "Mark as Delivered?" / served dialogs.
///
/// Default is OFF for every user. Admins are not exempt — the flag must be
/// enabled on that user's Firestore profile and is loaded with the session.
class MarkAsDeliveredPermission {
  const MarkAsDeliveredPermission._();

  static bool get canMarkAsDelivered {
    if (!Get.isRegistered<RestaurantSession>()) return false;
    return Get.find<RestaurantSession>().profile.value?.allowMarkAsDelivered ??
        false;
  }
}
