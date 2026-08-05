import 'package:smartKitchen/core/models/restaurant.dart';
import 'package:smartKitchen/features/super_admin/controllers/super_admin_controller.dart';
import 'package:smartKitchen/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

const _navy = Color(0xFF1A3A5C);
const _orange = Color(0xFFf57c35);

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
    final error = await controller.createRestaurantAdmin(
      restaurantId: widget.restaurant.id,
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restaurant admin created successfully.')),
    );
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SuperAdminController>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text(
          'Create Admin – ${widget.restaurant.name}',
          style: MyFont.bold(16, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Admin Name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password *',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Obx(
              () => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: controller.isLoading.value ? null : _submit,
                child: controller.isLoading.value
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Restaurant Admin'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
