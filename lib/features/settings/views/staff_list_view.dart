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
                onChangePassword: () => _showChangePasswordDialog(
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

  Future<void> _showChangePasswordDialog(
    BuildContext context,
    StaffController controller,
    StaffMember member,
  ) async {
    final newPasswordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var obscureNew = true;
    var obscureConfirm = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Change password', style: MyFont.bold(16, color: _navy)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      member.name,
                      style: MyFont.semiBold(15, color: _navy),
                    ),
                    Text(
                      member.email,
                      style: MyFont.regular(13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newPasswordCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New password *',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setDialogState(
                            () => obscureNew = !obscureNew,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm new password *',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () => setDialogState(
                            () => obscureConfirm = !obscureConfirm,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                Obx(
                  () => FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _orange),
                    onPressed: controller.isLoading.value
                        ? null
                        : () async {
                            final newPass = newPasswordCtrl.text;
                            final confirm = confirmCtrl.text;
                            if (newPass.length < 6) {
                              _snack(ctx, 'Password must be at least 6 characters.');
                              return;
                            }
                            if (newPass != confirm) {
                              _snack(ctx, 'Passwords do not match.');
                              return;
                            }

                            final error = await controller.updateStaffPassword(
                              staff: member,
                              newPassword: newPass,
                            );
                            if (!ctx.mounted) return;
                            if (error != null) {
                              _snack(ctx, error);
                              return;
                            }
                            Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Password updated for ${member.name}.',
                                  ),
                                ),
                              );
                            }
                          },
                    child: controller.isLoading.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Update'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    newPasswordCtrl.dispose();
    confirmCtrl.dispose();
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.member,
    required this.onChangePassword,
  });

  final StaffMember member;
  final VoidCallback onChangePassword;

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
              tooltip: 'Change password',
              onPressed: onChangePassword,
              icon: const Icon(Icons.lock_reset_rounded, color: _navy),
            ),
          ],
        ),
      ),
    );
  }
}
