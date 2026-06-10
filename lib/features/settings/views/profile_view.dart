import 'package:demo/features/settings/controllers/profile_controller.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

const _navy = Color(0xFF1A3A5C);
const _orange = Color(0xFFf57c35);

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword(ProfileController controller) async {
    final error = await controller.changePassword(
      currentPassword: _currentPasswordCtrl.text,
      newPassword: _newPasswordCtrl.text,
      confirmPassword: _confirmPasswordCtrl.text,
    );
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    _currentPasswordCtrl.clear();
    _newPasswordCtrl.clear();
    _confirmPasswordCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password updated successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ProfileController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text('My Profile', style: MyFont.bold(18, color: Colors.white)),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: _orange),
          );
        }

        final role = controller.profile.value?.role ?? 'Staff';
        final isAdmin = controller.isAdmin;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: _orange.withValues(alpha: 0.15),
                      child: Text(
                        controller.displayName.isNotEmpty
                            ? controller.displayName[0].toUpperCase()
                            : 'U',
                        style: MyFont.bold(28, color: _orange),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      controller.displayName,
                      style: MyFont.bold(20, color: _navy),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isAdmin
                            ? _navy.withValues(alpha: 0.1)
                            : _orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        role,
                        style: MyFont.semiBold(
                          12,
                          color: isAdmin ? _navy : _orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.person_outline, color: Colors.grey.shade600),
                    title: Text('Name', style: MyFont.regular(13, color: Colors.grey.shade600)),
                    subtitle: Text(
                      controller.displayName,
                      style: MyFont.semiBold(15, color: _navy),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.email_outlined, color: Colors.grey.shade600),
                    title: Text('Email', style: MyFont.regular(13, color: Colors.grey.shade600)),
                    subtitle: Text(
                      controller.displayEmail,
                      style: MyFont.semiBold(15, color: _navy),
                    ),
                  ),
                ],
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 24),
              Text(
                'Change password',
                style: MyFont.semiBold(13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _currentPasswordCtrl,
                        obscureText: _obscureCurrent,
                        decoration: InputDecoration(
                          labelText: 'Current password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureCurrent
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscureCurrent = !_obscureCurrent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _newPasswordCtrl,
                        obscureText: _obscureNew,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNew
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscureNew = !_obscureNew),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmPasswordCtrl,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm new password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(
                        () => FilledButton(
                          onPressed: controller.isChangingPassword.value
                              ? null
                              : () => _changePassword(controller),
                          style: FilledButton.styleFrom(
                            backgroundColor: _navy,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: controller.isChangingPassword.value
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Update password'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Text(
                'Contact your restaurant admin if you need to reset your password.',
                style: MyFont.regular(13, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      }),
    );
  }
}
