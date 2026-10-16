import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartKitchen/core/services/restaurant_session.dart';
import 'package:smartKitchen/Styles/my_font.dart';

/// Shown on the dashboard when the signed-in admin manages more than one restaurant.
class RestaurantSwitcher extends StatelessWidget {
  const RestaurantSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.find<RestaurantSession>();

    return Obx(() {
      final currentId = session.scopedRestaurantId;
      final currentName = _nameFor(session, currentId);
      final restaurants = session.assignedRestaurants;

      return PopupMenuButton<String>(
        tooltip: 'Switch restaurant',
        enabled: !session.isSwitchingRestaurant.value,
        onSelected: _switch,
        itemBuilder: (context) {
          return [
            for (final restaurant in restaurants)
              PopupMenuItem<String>(
                value: restaurant.id,
                child: Row(
                  children: [
                    Icon(
                      restaurant.id == currentId
                          ? Icons.check_circle
                          : Icons.storefront_outlined,
                      size: 18,
                      color: restaurant.id == currentId
                          ? const Color(0xFFf57c35)
                          : const Color(0xFF1A3A5C),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        restaurant.name,
                        style: MyFont.semiBold(14, color: const Color(0xFF1A3A5C)),
                      ),
                    ),
                  ],
                ),
              ),
          ];
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                currentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: fontMulishSemiBold,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
          ],
        ),
      );
    });
  }

  String _nameFor(RestaurantSession session, String restaurantId) {
    for (final restaurant in session.assignedRestaurants) {
      if (restaurant.id == restaurantId && restaurant.name.trim().isNotEmpty) {
        return restaurant.name.trim();
      }
    }
    final active = session.activeRestaurant.value;
    if (active != null && active.id == restaurantId && active.name.trim().isNotEmpty) {
      return active.name.trim();
    }
    return 'Switch restaurant';
  }

  Future<void> _switch(String restaurantId) async {
    final error = await Get.find<RestaurantSession>().switchRestaurant(
      restaurantId,
    );
    if (error == null) return;
    Get.snackbar(
      'Restaurant',
      error,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade700,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
    );
  }
}
