import 'package:demo/core/models/restaurant.dart';
import 'package:demo/features/super_admin/controllers/super_admin_controller.dart';
import 'package:demo/features/super_admin/views/create_restaurant_admin_view.dart';
import 'package:demo/features/super_admin/views/create_restaurant_view.dart';
import 'package:demo/features/super_admin/views/edit_restaurant_view.dart';
import 'package:demo/features/super_admin/views/restaurant_admins_view.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

const _navy = Color(0xFF1A3A5C);
const _orange = Color(0xFFf57c35);

class SuperAdminHomeView extends StatelessWidget {
  const SuperAdminHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SuperAdminController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text('Super Admin', style: MyFont.bold(18, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: controller.signOut,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        onPressed: () => Get.to(() => const CreateRestaurantView()),
        icon: const Icon(Icons.add_business),
        label: const Text('Add Restaurant'),
      ),
      body: Obx(() {
        if (controller.restaurants.isEmpty) {
          return Center(
            child: Text(
              'No restaurants yet.\nTap "Add Restaurant" to create one.',
              textAlign: TextAlign.center,
              style: MyFont.regular(16, color: Colors.grey.shade600),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.restaurants.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final restaurant = controller.restaurants[index];
            return _RestaurantCard(restaurant: restaurant);
          },
        );
      }),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.restaurant});

  final Restaurant restaurant;

  Color _statusColor(RestaurantStatus status) => switch (status) {
        RestaurantStatus.active => Colors.green,
        RestaurantStatus.expired => Colors.orange,
        RestaurantStatus.deactivated => Colors.red,
      };

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SuperAdminController>();
    final dateFmt = DateFormat('dd MMM yyyy');

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
                Expanded(
                  child: Text(
                    restaurant.name,
                    style: MyFont.bold(18, color: _navy),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(restaurant.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    restaurant.status.label,
                    style: MyFont.semiBold(
                      12,
                      color: _statusColor(restaurant.status),
                    ),
                  ),
                ),
              ],
            ),
            if (restaurant.address != null && restaurant.address!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                restaurant.address!,
                style: MyFont.regular(14, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Subscription: ${dateFmt.format(restaurant.subscriptionStart)} – ${dateFmt.format(restaurant.subscriptionEnd)}',
              style: MyFont.regular(13, color: Colors.grey.shade700),
            ),
            if (restaurant.mobile1 != null && restaurant.mobile1!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Mobile: ${restaurant.mobile1}'
                '${restaurant.mobile2 != null && restaurant.mobile2!.isNotEmpty ? ', ${restaurant.mobile2}' : ''}',
                style: MyFont.regular(13, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 4),
            Obx(
              () => Text(
                'Admins: ${controller.adminSummaryForRestaurant(restaurant.id)}',
                style: MyFont.regular(13, color: Colors.grey.shade700),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Get.to(
                    () => EditRestaurantView(restaurant: restaurant),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Get.to(
                    () => RestaurantAdminsView(restaurant: restaurant),
                  ),
                  icon: const Icon(Icons.people_outline, size: 18),
                  label: const Text('View Admins'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Get.to(
                    () => CreateRestaurantAdminView(restaurant: restaurant),
                  ),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Create Admin'),
                ),
                if (restaurant.status != RestaurantStatus.active)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => controller.activateRestaurant(restaurant.id),
                    child: const Text('Activate'),
                  ),
                if (restaurant.status == RestaurantStatus.active)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => _confirmDeactivate(context, controller),
                    child: const Text('Deactivate'),
                  ),
                OutlinedButton(
                  onPressed: () => _extendSubscription(context, controller),
                  child: const Text('Extend 1 Year'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeactivate(
    BuildContext context,
    SuperAdminController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Restaurant?'),
        content: Text(
          '${restaurant.name} admins and staff will lose access immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deactivateRestaurant(restaurant.id);
    }
  }

  Future<void> _extendSubscription(
    BuildContext context,
    SuperAdminController controller,
  ) async {
    final error = await controller.extendSubscription(
      restaurantId: restaurant.id,
      years: 1,
    );
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription extended by 1 year.')),
      );
    }
  }
}
