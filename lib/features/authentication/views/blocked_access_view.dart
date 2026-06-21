import 'package:demo/core/repositories/user_repository.dart';
import 'package:demo/core/widgets/logout_confirmation_dialog.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

const _navy = Color(0xFF1A3A5C);

class BlockedAccessView extends StatelessWidget {
  const BlockedAccessView({
    required this.message,
    this.restaurantName,
    super.key,
  });

  final String message;
  final String? restaurantName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 72, color: Colors.red.shade400),
                const SizedBox(height: 24),
                Text(
                  'Access Restricted',
                  style: MyFont.bold(22, color: _navy),
                  textAlign: TextAlign.center,
                ),
                if (restaurantName != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    restaurantName!,
                    style: MyFont.semiBold(16, color: Colors.grey.shade700),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  message,
                  style: MyFont.regular(15, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (await confirmLogout()) {
                      await Get.find<UserRepository>().signOut();
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
