import 'package:demo/core/repositories/user_repository.dart';
import 'package:demo/features/shell/services/app_tab_settings.dart';
import 'package:get/get.dart';

enum ShellTab { dashboard, kitchen, settings }

class ShellController extends GetxController {
  ShellController(this._userRepository);

  final UserRepository _userRepository;

  final currentIndex = 0.obs;
  final userRole = Rxn<String>();
  final appTabMode = AppTabMode.dashboardAndKitchen.obs;

  @override
  void onInit() {
    super.onInit();
    loadAppTabMode();
  }

  List<ShellTab> get visibleTabs {
    switch (appTabMode.value) {
      case AppTabMode.dashboardOnly:
        return const [ShellTab.dashboard, ShellTab.settings];
      case AppTabMode.kitchenOnly:
        return const [ShellTab.kitchen, ShellTab.settings];
      case AppTabMode.dashboardAndKitchen:
        return const [
          ShellTab.dashboard,
          ShellTab.kitchen,
          ShellTab.settings,
        ];
    }
  }

  ShellTab get currentTab {
    final tabs = visibleTabs;
    final index = currentIndex.value;
    if (index < 0 || index >= tabs.length) return tabs.first;
    return tabs[index];
  }

  int get stackIndex => switch (currentTab) {
        ShellTab.dashboard => 0,
        ShellTab.kitchen => 1,
        ShellTab.settings => 2,
      };

  bool get isKitchenTabActive => currentTab == ShellTab.kitchen;

  void changeTab(int index) {
    if (index < 0 || index >= visibleTabs.length) return;
    currentIndex.value = index;
  }

  Future<void> loadAppTabMode() async {
    appTabMode.value = await AppTabSettings.getMode();
    _syncCurrentIndexToVisibleTabs();
  }

  void syncAppTabMode(AppTabMode mode) {
    final previousTab = currentTab;
    appTabMode.value = mode;
    _syncCurrentIndexToVisibleTabs(preferredTab: previousTab);
  }

  void _syncCurrentIndexToVisibleTabs({ShellTab? preferredTab}) {
    final tabs = visibleTabs;
    if (tabs.isEmpty) return;

    final target = preferredTab ?? currentTab;
    final nextIndex = tabs.indexOf(target);
    currentIndex.value = nextIndex >= 0 ? nextIndex : 0;
  }

  Future<void> loadUserRole() async {
    final user = _userRepository.currentUser;
    if (user == null) return;
    userRole.value = await _userRepository.getUserRole(user.uid);
  }
}
