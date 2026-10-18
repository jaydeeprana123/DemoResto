import 'package:smartKitchen/core/models/restaurant.dart';
import 'package:smartKitchen/core/models/user_profile.dart';
import 'package:smartKitchen/features/super_admin/controllers/super_admin_controller.dart';
import 'package:smartKitchen/features/super_admin/models/admin_assignment.dart';
import 'package:smartKitchen/features/super_admin/widgets/restaurant_admin_assign_section.dart';
import 'package:smartKitchen/features/super_admin/widgets/restaurant_profile_fields.dart';
import 'package:smartKitchen/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CreateRestaurantAdminView extends StatefulWidget {
  const CreateRestaurantAdminView({required this.restaurant, super.key});

  final Restaurant restaurant;

  @override
  State<CreateRestaurantAdminView> createState() =>
      _CreateRestaurantAdminViewState();
}

class _CreateRestaurantAdminViewState extends State<CreateRestaurantAdminView> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  AdminAssignmentMode _mode = AdminAssignmentMode.createNew;
  UserProfile? _selectedAdmin;
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = Get.find<SuperAdminController>();
    final existingAdmins =
        controller.adminsAvailableToAssign(widget.restaurant.id);
    final admin = AdminAssignmentInput(
      mode: _mode,
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      existingAdmin: _selectedAdmin,
      requiredAssignment: true,
      existingAdminCount: existingAdmins.length,
    );
    final validationError = admin.validate();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    final String? error;
    if (admin.mode == AdminAssignmentMode.assignExisting) {
      error = await controller.assignExistingAdmin(
        admin: _selectedAdmin!,
        restaurantId: widget.restaurant.id,
      );
    } else {
      error = await controller.createRestaurantAdmin(
        restaurantId: widget.restaurant.id,
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
    }
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    final restaurantName = widget.restaurant.name;
    final assignedName = _selectedAdmin == null
        ? _nameCtrl.text.trim()
        : ((_selectedAdmin!.name?.trim().isNotEmpty ?? false)
            ? _selectedAdmin!.name!.trim()
            : _selectedAdmin!.email);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          admin.mode == AdminAssignmentMode.assignExisting
              ? '$assignedName can now manage $restaurantName with the same login.'
              : 'Restaurant admin created successfully.',
        ),
      ),
    );
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SuperAdminController>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: superAdminNavy,
        foregroundColor: Colors.white,
        title: Text(
          'Assign Admin – ${widget.restaurant.name}',
          style: MyFont.bold(16, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(() {
              final existingAdmins =
                  controller.adminsAvailableToAssign(widget.restaurant.id);
              return RestaurantAdminAssignSection(
                mode: _mode,
                onModeChanged: (mode) => setState(() => _mode = mode),
                nameController: _nameCtrl,
                emailController: _emailCtrl,
                passwordController: _passwordCtrl,
                obscurePassword: _obscure,
                onTogglePassword: () => setState(() => _obscure = !_obscure),
                existingAdmins: existingAdmins,
                selectedAdmin: _selectedAdmin,
                onAdminSelected: (admin) =>
                    setState(() => _selectedAdmin = admin),
                restaurantNamesFor: controller.restaurantNamesFor,
                requiredAssignment: true,
              );
            }),
            const SizedBox(height: 24),
            superAdminSubmitButton(
              controller: controller,
              label: _mode == AdminAssignmentMode.assignExisting
                  ? 'Assign Existing Admin'
                  : 'Create Restaurant Admin',
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
