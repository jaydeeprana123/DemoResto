import 'dart:typed_data';

import 'package:demo/core/models/restaurant.dart';
import 'package:demo/features/super_admin/controllers/super_admin_controller.dart';
import 'package:demo/features/super_admin/widgets/restaurant_profile_fields.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class EditRestaurantView extends StatefulWidget {
  const EditRestaurantView({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  State<EditRestaurantView> createState() => _EditRestaurantViewState();
}

class _EditRestaurantViewState extends State<EditRestaurantView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _mobile1Ctrl;
  late final TextEditingController _mobile2Ctrl;
  late final TextEditingController _mobile3Ctrl;

  Uint8List? _logoBytes;
  bool _removeLogo = false;
  late DateTime _subscriptionEnd;

  @override
  void initState() {
    super.initState();
    final restaurant = widget.restaurant;
    _nameCtrl = TextEditingController(text: restaurant.name);
    _addressCtrl = TextEditingController(text: restaurant.address ?? '');
    _mobile1Ctrl = TextEditingController(text: restaurant.mobile1 ?? '');
    _mobile2Ctrl = TextEditingController(text: restaurant.mobile2 ?? '');
    _mobile3Ctrl = TextEditingController(text: restaurant.mobile3 ?? '');
    _subscriptionEnd = restaurant.subscriptionEnd;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _mobile1Ctrl.dispose();
    _mobile2Ctrl.dispose();
    _mobile3Ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickSubscriptionEnd() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _subscriptionEnd,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_subscriptionEnd),
    );
    if (time == null || !mounted) return;

    setState(() {
      _subscriptionEnd = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final controller = Get.find<SuperAdminController>();
    final error = await controller.updateRestaurant(
      restaurant: widget.restaurant,
      name: _nameCtrl.text,
      address: _addressCtrl.text,
      mobile1: _mobile1Ctrl.text,
      mobile2: _mobile2Ctrl.text,
      mobile3: _mobile3Ctrl.text,
      logoBytes: _logoBytes,
      removeLogo: _removeLogo,
      subscriptionEnd: _subscriptionEnd,
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restaurant updated successfully.')),
    );
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SuperAdminController>();
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: superAdminNavy,
        foregroundColor: Colors.white,
        title: Text('Edit Restaurant', style: MyFont.bold(18, color: Colors.white)),
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
                existingLogoUrl:
                    _removeLogo ? null : widget.restaurant.logoUrl,
                onPicked: (bytes) => setState(() {
                  _logoBytes = bytes;
                  _removeLogo = false;
                }),
                onClear: () => setState(() {
                  _logoBytes = null;
                  _removeLogo = true;
                }),
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
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Subscription Expiry',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateFmt.format(_subscriptionEnd),
                        style: MyFont.regular(14),
                      ),
                    ),
                    TextButton(
                      onPressed: _pickSubscriptionEnd,
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              superAdminSubmitButton(
                controller: controller,
                label: 'Save Changes',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
