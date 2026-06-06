import 'package:demo/features/super_admin/controllers/super_admin_controller.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

const _navy = Color(0xFF1A3A5C);
const _orange = Color(0xFFf57c35);

class CreateRestaurantView extends StatefulWidget {
  const CreateRestaurantView({super.key});

  @override
  State<CreateRestaurantView> createState() => _CreateRestaurantViewState();
}

class _CreateRestaurantViewState extends State<CreateRestaurantView> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  int _subscriptionYears = 1;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = Get.find<SuperAdminController>();
    final error = await controller.createRestaurant(
      name: _nameCtrl.text,
      address: _addressCtrl.text,
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
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text('Create Restaurant', style: MyFont.bold(18, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Restaurant Name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
                border: OutlineInputBorder(),
              ),
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
                    : const Text('Create Restaurant'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
