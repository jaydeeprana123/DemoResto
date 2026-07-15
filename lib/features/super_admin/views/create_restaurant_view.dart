import 'dart:typed_data';

import 'package:demo/features/super_admin/controllers/super_admin_controller.dart';
import 'package:demo/features/super_admin/widgets/restaurant_profile_fields.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CreateRestaurantView extends StatefulWidget {
  const CreateRestaurantView({super.key});

  @override
  State<CreateRestaurantView> createState() => _CreateRestaurantViewState();
}

class _CreateRestaurantViewState extends State<CreateRestaurantView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _mobile1Ctrl = TextEditingController();
  final _mobile2Ctrl = TextEditingController();
  final _mobile3Ctrl = TextEditingController();
  int _subscriptionYears = 1;
  Uint8List? _logoBytes;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _mobile1Ctrl.dispose();
    _mobile2Ctrl.dispose();
    _mobile3Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final controller = Get.find<SuperAdminController>();
    final error = await controller.createRestaurant(
      name: _nameCtrl.text,
      address: _addressCtrl.text,
      mobile1: _mobile1Ctrl.text,
      mobile2: _mobile2Ctrl.text,
      mobile3: _mobile3Ctrl.text,
      logoBytes: _logoBytes,
      subscriptionYears: _subscriptionYears,
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restaurant created successfully.')),
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
        title: Text('Create Restaurant', style: MyFont.bold(18, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RestaurantLogoPicker(
                logoBytes: _logoBytes,
                existingLogoUrl: null,
                onPicked: (bytes) => setState(() => _logoBytes = bytes),
                onClear: () => setState(() => _logoBytes = null),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Restaurant Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Restaurant name is required.'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              RestaurantMobileFields(
                mobile1Controller: _mobile1Ctrl,
                mobile2Controller: _mobile2Ctrl,
                mobile3Controller: _mobile3Ctrl,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _subscriptionYears,
                decoration: const InputDecoration(
                  labelText: 'Subscription Duration',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 Year')),
                  DropdownMenuItem(value: 2, child: Text('2 Years')),
                  DropdownMenuItem(value: 3, child: Text('3 Years')),
                ],
                onChanged: (v) => setState(() => _subscriptionYears = v ?? 1),
              ),
              const SizedBox(height: 24),
              superAdminSubmitButton(
                controller: controller,
                label: 'Create Restaurant',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
