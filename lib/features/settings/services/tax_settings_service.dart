import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/core/services/restaurant_session.dart';
import 'package:get/get.dart';

class TaxSettings {
  const TaxSettings({
    this.cgstPercentage = 0,
    this.sgstPercentage = 0,
  });

  final double cgstPercentage;
  final double sgstPercentage;
}

class TaxSettingsService {
  const TaxSettingsService._();

  static RestaurantSession get _session => Get.find<RestaurantSession>();

  static Future<TaxSettings> load() async {
    final restaurant = _session.activeRestaurant.value;
    if (restaurant != null) {
      return TaxSettings(
        cgstPercentage: restaurant.cgstPercentage,
        sgstPercentage: restaurant.sgstPercentage,
      );
    }

    final restaurantId = _session.scopedRestaurantId;
    if (restaurantId.isEmpty) {
      return const TaxSettings();
    }

    final doc = await FirestorePaths.restaurant(restaurantId).get();
    if (!doc.exists) {
      return const TaxSettings();
    }

    return _fromMap(doc.data() ?? {});
  }

  static TaxSettings _fromMap(Map<String, dynamic> data) {
    return TaxSettings(
      cgstPercentage: (data['cgstPercentage'] as num?)?.toDouble() ?? 0,
      sgstPercentage: (data['sgstPercentage'] as num?)?.toDouble() ?? 0,
    );
  }

  static Future<void> save({
    required double cgstPercentage,
    required double sgstPercentage,
  }) async {
    final restaurantId = _session.scopedRestaurantId;
    if (restaurantId.isEmpty) {
      throw StateError('No restaurant linked to save tax settings.');
    }

    await FirestorePaths.restaurant(restaurantId).set(
      {
        'cgstPercentage': cgstPercentage,
        'sgstPercentage': sgstPercentage,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final current = _session.activeRestaurant.value;
    if (current != null) {
      _session.activeRestaurant.value = current.copyWith(
        cgstPercentage: cgstPercentage,
        sgstPercentage: sgstPercentage,
      );
    } else {
      await _session.reloadRestaurant();
    }
  }
}
