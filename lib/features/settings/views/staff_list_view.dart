import 'package:demo/core/models/staff_member.dart';
import 'package:demo/features/settings/controllers/staff_controller.dart';
import 'package:demo/features/settings/views/create_staff_view.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

const _navy = Color(0xFF1A3A5C);
const _orange = Color(0xFFf57c35);

class StaffListView extends StatelessWidget {
  const StaffListView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StaffController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text('Staff', style: MyFont.bold(18, color: Colors.white)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        onPressed: () => Get.to(() => const CreateStaffView()),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Staff'),
      ),
      body: StreamBuilder<List<StaffMember>>(
        stream: controller.watchStaff(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _orange),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: MyFont.regular(14, color: Colors.red.shade700),
                ),
              ),
            );
          }

          final staff = snapshot.data ?? [];
          if (staff.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.groups_outlined,
                        size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No staff yet',
                      style: MyFont.bold(18, color: _navy),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap "Add Staff" to create login accounts for your team.',
                      textAlign: TextAlign.center,
                      style: MyFont.regular(14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: staff.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final member = staff[index];
              return _StaffCard(
                member: member,
                onChangePassword: () => _showPasswordResetDialog(
                  context,
                  controller,
                  member,
                ),
                onDelete: () => _showDeleteStaffDialog(
                  context,
                  controller,
                  member,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showPasswordResetDialog(
    BuildContext context,
    StaffController controller,
    StaffMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset password?', style: MyFont.bold(16, color: _navy)),
        content: Text(
          'Send a password reset link to ${member.email}?\n\n'
          '${member.name} will receive an email and can set a new password.',
          style: MyFont.regular(14, color: Colors.grey.shade800),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send email'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final error = await controller.sendPasswordResetEmail(staff: member);
    if (!context.mounted) return;

    if (error != null) {
      _snack(context, error);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Password reset email sent to ${member.email}.'),
      ),
    );
  }

  Future<void> _showDeleteStaffDialog(
    BuildContext context,
    StaffController controller,
    StaffMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete staff?', style: MyFont.bold(16, color: _navy)),
        content: Text(
          'Remove ${member.name} from your team?\n\n'
          'They will lose access to the app immediately. '
          'Their login email is not deleted from Firebase, but they cannot sign in.',
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

    final error = await controller.deleteStaff(staff: member);
    if (!context.mounted) return;

    if (error != null) {
      _snack(context, error);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${member.name} has been removed.')),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.member,
    required this.onChangePassword,
    required this.onDelete,
  });

  final StaffMember member;
  final VoidCallback onChangePassword;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _orange.withValues(alpha: 0.15),
              child: Text(
                member.name.isNotEmpty ? member.name[0].toUpperCase() : 'S',
                style: MyFont.bold(16, color: _orange),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: MyFont.semiBold(15, color: _navy),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.email_outlined,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          member.email,
                          style: MyFont.regular(13, color: Colors.grey.shade700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Send password reset email',
              onPressed: onChangePassword,
              icon: const Icon(Icons.mail_outline_rounded, color: _navy),
            ),
            IconButton(
              tooltip: 'Delete staff',
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
