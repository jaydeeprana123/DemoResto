import 'package:smartKitchen/core/models/user_profile.dart';
import 'package:smartKitchen/features/super_admin/models/admin_assignment.dart';
import 'package:smartKitchen/features/super_admin/widgets/restaurant_profile_fields.dart';
import 'package:smartKitchen/Styles/my_font.dart';
import 'package:flutter/material.dart';

class RestaurantAdminAssignSection extends StatelessWidget {
  const RestaurantAdminAssignSection({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.existingAdmins,
    required this.selectedAdmin,
    required this.onAdminSelected,
    required this.restaurantNamesFor,
    this.requiredAssignment = false,
  });

  final AdminAssignmentMode mode;
  final ValueChanged<AdminAssignmentMode> onModeChanged;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final List<UserProfile> existingAdmins;
  final UserProfile? selectedAdmin;
  final ValueChanged<UserProfile> onAdminSelected;
  final String Function(UserProfile admin) restaurantNamesFor;
  final bool requiredAssignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Assign Admin', style: MyFont.bold(16, color: superAdminNavy)),
        const SizedBox(height: 4),
        Text(
          requiredAssignment
              ? 'Create a new login, or give this restaurant to an admin who already manages another one.'
              : 'Optional. Add an admin now, or leave the new-admin fields blank to only save restaurant details.',
          style: MyFont.regular(13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        RadioGroup<AdminAssignmentMode>(
          groupValue: mode,
          onChanged: (value) {
            if (value != null) onModeChanged(value);
          },
          child: Column(
            children: [
              RadioListTile<AdminAssignmentMode>(
                contentPadding: EdgeInsets.zero,
                value: AdminAssignmentMode.createNew,
                activeColor: superAdminOrange,
                title: Text(
                  'Create New Admin',
                  style: MyFont.semiBold(15, color: superAdminNavy),
                ),
                subtitle: Text(
                  'Name, email, and password. Creates a new Firebase login.',
                  style: MyFont.regular(12, color: Colors.grey.shade700),
                ),
              ),
              RadioListTile<AdminAssignmentMode>(
                contentPadding: EdgeInsets.zero,
                value: AdminAssignmentMode.assignExisting,
                activeColor: superAdminOrange,
                title: Text(
                  'Assign Existing Admin',
                  style: MyFont.semiBold(15, color: superAdminNavy),
                ),
                subtitle: Text(
                  'Same login and password. No new account is created.',
                  style: MyFont.regular(12, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (mode == AdminAssignmentMode.createNew) ...[
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Admin Name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password *',
              helperText: 'At least 6 characters. Used only for a new login.',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: onTogglePassword,
              ),
            ),
          ),
        ] else
          _ExistingAdminList(
            admins: existingAdmins,
            selectedAdmin: selectedAdmin,
            onAdminSelected: onAdminSelected,
            restaurantNamesFor: restaurantNamesFor,
          ),
      ],
    );
  }
}

class _ExistingAdminList extends StatelessWidget {
  const _ExistingAdminList({
    required this.admins,
    required this.selectedAdmin,
    required this.onAdminSelected,
    required this.restaurantNamesFor,
  });

  final List<UserProfile> admins;
  final UserProfile? selectedAdmin;
  final ValueChanged<UserProfile> onAdminSelected;
  final String Function(UserProfile admin) restaurantNamesFor;

  @override
  Widget build(BuildContext context) {
    if (admins.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          'No other active admins yet. Create a new admin instead.',
          style: MyFont.regular(14, color: Colors.grey.shade700),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: RadioGroup<String>(
        groupValue: selectedAdmin?.uid,
        onChanged: (uid) {
          if (uid == null) return;
          for (final admin in admins) {
            if (admin.uid == uid) {
              onAdminSelected(admin);
              return;
            }
          }
        },
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: admins.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final admin = admins[index];
            final name = (admin.name?.trim().isNotEmpty ?? false)
                ? admin.name!.trim()
                : admin.email;
            final restaurants = restaurantNamesFor(admin);
            return RadioListTile<String>(
              value: admin.uid,
              activeColor: superAdminOrange,
              title: Text(name, style: MyFont.semiBold(14, color: superAdminNavy)),
              subtitle: Text(
                restaurants.isEmpty
                    ? admin.email
                    : '${admin.email}\n$restaurants',
                style: MyFont.regular(12, color: Colors.grey.shade700),
              ),
            );
          },
        ),
      ),
    );
  }
}
