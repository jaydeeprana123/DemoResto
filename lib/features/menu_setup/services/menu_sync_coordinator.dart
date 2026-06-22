import 'package:demo/features/menu_setup/services/menu_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Starts menu revision checks and the Firestore meta listener for Phase 2 sync.
class MenuSyncCoordinator extends GetxService with WidgetsBindingObserver {
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    if (Get.isRegistered<MenuCacheService>()) {
      Get.find<MenuCacheService>().stopAutoSync();
    }
    super.onClose();
  }

  Future<void> start() async {
    if (!Get.isRegistered<MenuCacheService>()) return;
    await Get.find<MenuCacheService>().startAutoSync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!Get.isRegistered<MenuCacheService>()) return;
    final cache = Get.find<MenuCacheService>();

    switch (state) {
      case AppLifecycleState.resumed:
        cache.resumeAutoSync();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        cache.pauseAutoSync();
      case AppLifecycleState.detached:
        cache.stopAutoSync();
    }
  }
}
