import 'package:demo/core/models/restaurant.dart';
import 'package:demo/core/models/user_profile.dart';
import 'package:demo/features/super_admin/controllers/super_admin_controller.dart';
import 'package:demo/features/super_admin/views/create_restaurant_admin_view.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

const _navy = Color(0xFF1A3A5C);
const _orange = Color(0xFFf57c35);

class RestaurantAdminsView extends StatelessWidget {
  const RestaurantAdminsView({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SuperAdminController>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text(
          'Admins – ${restaurant.name}',
          style: MyFont.bold(16, color: Colors.white),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        onPressed: () => Get.to(
          () => CreateRestaurantAdminView(restaurant: restaurant),
        ),
        icon: const Icon(Icons.person_add),
        label: const Text('Create Admin'),
      ),
      body: Obx(() {
        final admins = controller.adminsForRestaurant(restaurant.id);
        if (admins.isEmpty) {
          return Center(
            child: Text(
              'No admin accounts for this restaurant yet.',
              textAlign: TextAlign.center,
              style: MyFont.regular(16, color: Colors.grey.shade600),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: admins.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _AdminDetailCard(admin: admins[index]);
          },
        );
      }),
    );
  }
}

class _AdminDetailCard extends StatelessWidget {
  const _AdminDetailCard({required this.admin});

  final UserProfile admin;

  String get _displayName {
    final name = admin.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    return admin.email;
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _navy.withValues(alpha: 0.12),
                  child: Icon(Icons.person, color: _navy.withValues(alpha: 0.85)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName,
                        style: MyFont.bold(17, color: _navy),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        admin.email,
                        style: MyFont.regular(14, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (admin.active ? Colors.green : Colors.red)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    admin.active ? 'Active' : 'Inactive',
                    style: MyFont.semiBold(
                      12,
                      color: admin.active ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.badge_outlined,
              label: 'Role',
              value: admin.role,
            ),
            if (admin.createdAt != null) ...[
              const SizedBox(height: 6),
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Created',
                value: dateFmt.format(admin.createdAt!),
              ),
            ],
            const SizedBox(height: 6),
            _DetailRow(
              icon: Icons.fingerprint_outlined,
              label: 'User ID',
              value: admin.uid,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: MyFont.regular(13, color: Colors.grey.shade700),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: MyFont.semiBold(13, color: Colors.grey.shade800),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
