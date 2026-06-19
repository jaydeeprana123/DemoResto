import 'package:demo/features/settings/controllers/settings_controller.dart';
import 'package:demo/features/settings/views/settings_section_pages.dart';
import 'package:demo/features/settings/views/settings_ui.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsController _settings;

  @override
  void initState() {
    super.initState();
    _settings = Get.find<SettingsController>();
    _settings.loadUserRole();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SettingsColors.background,
      appBar: AppBar(
        backgroundColor: SettingsColors.navy,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 16,
            fontFamily: fontMulishBold,
            color: Colors.white,
          ),
        ),
      ),
      body: Obx(() {
        if (_settings.isLoadingRole.value) {
          return const Center(
            child: CircularProgressIndicator(color: SettingsColors.orange),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SettingsGroupedSection(
              children: [
                SettingsHubRow(
                  icon: Icons.business_center_outlined,
                  title: 'Business',
                  subtitle: 'Dashboard, transactions, expenses & export',
                  onTap: () => Get.to(() => const SettingsBusinessSectionPage()),
                ),
                SettingsHubRow(
                  icon: Icons.restaurant_outlined,
                  title: 'Restaurant setup',
                  subtitle: 'Tables, menu, staff, Zomato & stock',
                  onTap: () =>
                      Get.to(() => const SettingsRestaurantSectionPage()),
                ),
                SettingsHubRow(
                  icon: Icons.receipt_long_outlined,
                  title: 'Billing',
                  subtitle: 'GST, printer & receipt options',
                  onTap: () => Get.to(() => const SettingsBillingSectionPage()),
                ),
                SettingsHubRow(
                  icon: Icons.navigation_outlined,
                  title: 'Navigation',
                  subtitle: 'App tab layout',
                  onTap: () =>
                      Get.to(() => const SettingsNavigationSectionPage()),
                ),
                SettingsHubRow(
                  icon: Icons.soup_kitchen_outlined,
                  title: 'Kitchen',
                  subtitle: 'Kitchen display & alerts',
                  onTap: () => Get.to(() => const SettingsKitchenSectionPage()),
                ),
                SettingsHubRow(
                  icon: Icons.person_outline_rounded,
                  title: 'Account',
                  subtitle: 'Profile & sign out',
                  onTap: () => Get.to(() => const SettingsAccountSectionPage()),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}
