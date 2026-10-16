import 'package:smartKitchen/core/models/restaurant.dart';
import 'package:smartKitchen/core/models/user_profile.dart';
import 'package:smartKitchen/features/super_admin/controllers/super_admin_controller.dart';
import 'package:smartKitchen/features/super_admin/views/create_restaurant_admin_view.dart';
import 'package:smartKitchen/Styles/my_font.dart';
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'assign-existing-admin',
            backgroundColor: Colors.white,
            foregroundColor: _navy,
            onPressed: () => _showAssignExistingDialog(context, controller),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Assign existing'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'create-restaurant-admin',
            backgroundColor: _orange,
            foregroundColor: Colors.white,
            onPressed: () => Get.to(
              () => CreateRestaurantAdminView(restaurant: restaurant),
            ),
            icon: const Icon(Icons.person_add),
            label: const Text('Create Admin'),
          ),
        ],
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
          itemCount: admins.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _AdminDetailCard(
              admin: admins[index],
              restaurantsLabel: controller.restaurantNamesFor(admins[index]),
              onDelete: admins[index].active
                  ? () => _showDeleteAdminDialog(
                        context,
                        controller,
                        restaurant,
                        admins[index],
                      )
                  : null,
            );
          },
        );
      }),
    );
  }

  Future<void> _showAssignExistingDialog(
    BuildContext context,
    SuperAdminController controller,
  ) async {
    final candidates = controller.adminsAvailableToAssign(restaurant.id);
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other active admins are available to assign.'),
        ),
      );
      return;
    }

    final selected = await showDialog<UserProfile>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Assign existing admin',
          style: MyFont.bold(16, color: _navy),
        ),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: candidates.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final admin = candidates[index];
              final name = (admin.name?.trim().isNotEmpty ?? false)
                  ? admin.name!.trim()
                  : admin.email;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(name, style: MyFont.semiBold(15, color: _navy)),
                subtitle: Text(
                  admin.email,
                  style: MyFont.regular(13, color: Colors.grey.shade700),
                ),
                onTap: () => Navigator.pop(ctx, admin),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected == null || !context.mounted) return;

    final error = await controller.assignExistingAdmin(
      admin: selected,
      restaurantId: restaurant.id,
    );
    if (!context.mounted) return;

    final displayName = (selected.name?.trim().isNotEmpty ?? false)
        ? selected.name!.trim()
        : selected.email;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? '$displayName can now manage ${restaurant.name}.',
        ),
        backgroundColor: error == null ? null : Colors.red.shade700,
      ),
    );
  }

  Future<void> _showDeleteAdminDialog(
    BuildContext context,
    SuperAdminController controller,
    Restaurant restaurant,
    UserProfile admin,
  ) async {
    final displayName = (admin.name?.trim().isNotEmpty ?? false)
        ? admin.name!.trim()
        : admin.email;

    final keepsOtherRestaurants = admin.assignedRestaurantIds.length > 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          keepsOtherRestaurants ? 'Remove from restaurant?' : 'Delete admin?',
          style: MyFont.bold(16, color: _navy),
        ),
        content: Text(
          keepsOtherRestaurants
              ? 'Remove $displayName from ${restaurant.name}?\n\n'
                  'They will keep the same login and still manage their other restaurants.'
              : 'Remove $displayName from ${restaurant.name}?\n\n'
                  'They will lose access to the app immediately. '
                  'Their login email is not deleted from Firebase Auth, '
                  'but they cannot sign in while deactivated.',
          style: MyFont.regular(14, color: Colors.grey.shade800),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final error = await controller.deleteRestaurantAdmin(
      admin: admin,
      restaurantId: restaurant.id,
    );
    if (!context.mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red.shade700),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$displayName has been removed.')),
    );
  }
}

class _AdminDetailCard extends StatelessWidget {
  const _AdminDetailCard({
    required this.admin,
    required this.restaurantsLabel,
    this.onDelete,
  });

  final UserProfile admin;
  final String restaurantsLabel;
  final VoidCallback? onDelete;

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
                if (onDelete != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Delete admin',
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.badge_outlined,
              label: 'Role',
              value: admin.role,
            ),
            if (restaurantsLabel.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              _DetailRow(
                icon: Icons.storefront_outlined,
                label: 'Restaurants',
                value: restaurantsLabel,
              ),
            ],
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
