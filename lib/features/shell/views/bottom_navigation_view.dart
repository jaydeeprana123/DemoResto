import 'package:demo/Styles/my_font.dart';
import 'package:demo/features/kitchen/kitchen.dart';
import 'package:demo/features/settings/settings.dart';
import 'package:demo/features/shell/controllers/shell_controller.dart';
import 'package:demo/features/tables/tables.dart';
import 'package:demo/features/zomato/services/zomato_share_intent_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BottomNavigationView extends StatefulWidget {
  const BottomNavigationView({Key? key}) : super(key: key);

  @override
  State<BottomNavigationView> createState() => _BottomNavigationViewState();
}

class _BottomNavigationViewState extends State<BottomNavigationView> {
  late final ShellController _shell;

  @override
  void initState() {
    super.initState();
    _shell = Get.find<ShellController>();
    _shell.loadUserRole();
    if (Get.isRegistered<ZomatoShareIntentService>()) {
      Get.find<ZomatoShareIntentService>().markUiReady();
    }
  }

  @override
  void dispose() {
    if (Get.isRegistered<ZomatoShareIntentService>()) {
      Get.find<ZomatoShareIntentService>().markUiNotReady();
    }
    super.dispose();
  }

  static const _navy = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);

  BottomNavigationBarItem _navItem(ShellTab tab) {
    return switch (tab) {
      ShellTab.dashboard => const BottomNavigationBarItem(
          icon: Icon(Icons.grid_view_rounded, size: 24),
          activeIcon: Icon(Icons.grid_view_rounded, size: 26),
          label: 'Dashboard',
        ),
      ShellTab.kitchen => const BottomNavigationBarItem(
          icon: Icon(Icons.soup_kitchen_rounded, size: 24),
          activeIcon: Icon(Icons.soup_kitchen_rounded, size: 26),
          label: 'Kitchen',
        ),
      ShellTab.settings => const BottomNavigationBarItem(
          icon: Icon(Icons.settings_rounded, size: 24),
          activeIcon: Icon(Icons.settings_rounded, size: 26),
          label: 'Settings',
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: Obx(() {
          return IndexedStack(
            index: _shell.stackIndex,
            children: [
              const DragListBetweenTables(),
              KitchenOrdersListView(
                isTabActive: _shell.isKitchenTabActive,
              ),
              const SettingsPage(),
            ],
          );
        }),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: _navy,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Obx(() {
            final tabs = _shell.visibleTabs;
            return BottomNavigationBar(
              backgroundColor: _navy,
              selectedItemColor: _orange,
              unselectedItemColor: Colors.white54,
              selectedLabelStyle: const TextStyle(
                fontFamily: fontMulishSemiBold,
                fontSize: 11,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: fontMulishSemiBold,
                fontSize: 11,
              ),
              currentIndex: _shell.currentIndex.value.clamp(0, tabs.length - 1),
              showSelectedLabels: true,
              showUnselectedLabels: true,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              items: tabs.map(_navItem).toList(),
              onTap: _shell.changeTab,
            );
          }),
        ),
      ),
    );
  }
}
