import 'package:demo/core/utils/platform_utils.dart';
import 'package:demo/features/menu_setup/menu_setup.dart';
import 'package:demo/features/settings/controllers/settings_controller.dart';
import 'package:demo/features/settings/services/print_settings.dart';
import 'package:demo/features/settings/views/AdminDashboardPage.dart';
import 'package:demo/features/settings/views/ExpensesPage.dart';
import 'package:demo/features/settings/views/staff_list_view.dart';
import 'package:demo/features/settings/views/ExportPage.dart';
import 'package:demo/features/tables/tables.dart';
import 'package:demo/features/transactions/transactions.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _navy = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);

  late final SettingsController _settings;
  late final TextEditingController _cgstController;
  late final TextEditingController _sgstController;

  @override
  void initState() {
    super.initState();
    _settings = Get.find<SettingsController>();
    _cgstController = TextEditingController();
    _sgstController = TextEditingController();
    _settings.loadUserRole();
    _settings.loadKitchenSettings();
    _settings.loadPrintSettings();
    _loadTaxFields();
  }

  Future<void> _loadTaxFields() async {
    await _settings.loadTaxSettings();
    if (!mounted) return;
    _cgstController.text = _formatTaxField(_settings.cgstPercentage.value);
    _sgstController.text = _formatTaxField(_settings.sgstPercentage.value);
    setState(() {});
  }

  String _formatTaxField(double value) {
    if (value == 0) return '0';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }

  Future<void> _saveTaxSettings() async {
    final cgst = double.tryParse(_cgstController.text.trim()) ?? 0;
    final sgst = double.tryParse(_sgstController.text.trim()) ?? 0;

    if (cgst < 0 || sgst < 0 || cgst > 100 || sgst > 100) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid tax percentages between 0 and 100.')),
      );
      return;
    }

    final ok = await _settings.saveTaxSettings(cgst: cgst, sgst: sgst);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'GST settings saved.' : 'Could not save GST settings.'),
        backgroundColor: ok ? const Color(0xFF2E7D32) : Colors.red.shade700,
      ),
    );
  }

  @override
  void dispose() {
    _cgstController.dispose();
    _sgstController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    await _settings.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 16,
            fontFamily: fontMulishBold,
            color: Colors.white,
          ),
        ),
      ),
      body: Obx(() {
        if (_settings.isLoadingRole.value) {
          return const Center(child: CircularProgressIndicator(color: _orange));
        }

        final isAdmin = _settings.isAdmin;

        return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Business',
                  style: TextStyle(
                    fontFamily: fontMulishSemiBold,
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                if (isAdmin)
                  _SettingsTile(
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    subtitle: 'Sales, expenses & reserved tables overview',
                    onTap: () => Get.to(() => const AdminDashboardPage()),
                  ),
                if (isAdmin)
                  _SettingsTile(
                    icon: Icons.receipt_long_rounded,
                    title: 'Transactions',
                    subtitle: 'View sales and payment history',
                    onTap: () => Get.to(() => const TransactionsPage()),
                  ),
                _SettingsTile(
                  icon: Icons.payments_outlined,
                  title: 'Expenses',
                  subtitle: 'Track and add business expenses',
                  onTap: () => Get.to(() => const ExpensesPage()),
                ),
                if (isAdmin)
                  _SettingsTile(
                    icon: Icons.file_download_outlined,
                    title: 'Export',
                    subtitle: 'Download transactions & expenses to Excel',
                    onTap: () => Get.to(() => ExportPage(isAdmin: true)),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'Restaurant setup',
                  style: TextStyle(
                    fontFamily: fontMulishSemiBold,
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.table_restaurant_rounded,
                  title: 'Tables',
                  subtitle: 'Add or manage dining tables',
                  onTap: () => Get.to(() => AddTablePage()),
                ),
                if (isAdmin)
                  _SettingsTile(
                    icon: Icons.menu_book_rounded,
                    title: 'Menu',
                    subtitle: 'Categories and menu items',
                    onTap: () => Get.to(() => AddCategoryPage()),
                  ),
                if (isAdmin)
                  _SettingsTile(
                    icon: Icons.group_add_rounded,
                    title: 'Staff',
                    subtitle: 'Add staff, send password reset & remove access',
                    onTap: () => Get.to(() => const StaffListView()),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'Billing',
                  style: TextStyle(
                    fontFamily: fontMulishSemiBold,
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                if (isAdmin)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: _orange.withOpacity(0.12),
                                child: const Icon(
                                  Icons.percent_rounded,
                                  color: _orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CGST & SGST',
                                      style: TextStyle(
                                        fontFamily: fontMulishSemiBold,
                                        fontSize: 15,
                                        color: _navy,
                                      ),
                                    ),
                                    Text(
                                      'Applied on final billing (0 = hidden)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _cgstController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'CGST %',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _sgstController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'SGST %',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Obx(
                              () => FilledButton(
                                onPressed: _settings.isSavingTaxSettings.value
                                    ? null
                                    : _saveTaxSettings,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _orange,
                                ),
                                child: _settings.isSavingTaxSettings.value
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Save GST'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    secondary: CircleAvatar(
                      backgroundColor: _orange.withOpacity(0.12),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: _orange),
                    ),
                    title: const Text(
                      'Print PDF bill',
                      style: TextStyle(
                        fontFamily: fontMulishSemiBold,
                        fontSize: 15,
                        color: _navy,
                      ),
                    ),
                    subtitle: Text(
                      isDesktopPlatform
                          ? 'Opens the bill PDF in your default viewer after billing'
                          : 'Print POS receipt on Confirm & Billing',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    value: _settings.printPdfEnabled.value,
                    activeColor: _orange,
                    onChanged: (value) async {
                      if (value == null) return;
                      await _settings.setPrintPdfEnabled(value);
                    },
                  ),
                ),
                if (_settings.printPdfEnabled.value)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: _orange.withOpacity(0.12),
                        child: const Icon(Icons.print_rounded, color: _orange),
                      ),
                      title: const Text(
                        'POS Printer',
                        style: TextStyle(
                          fontFamily: fontMulishSemiBold,
                          fontSize: 15,
                          color: _navy,
                        ),
                      ),
                      subtitle: Text(
                        _settings.printerType.value.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      trailing: DropdownButton<PosPrinterType>(
                        value: _settings.printerType.value,
                        underline: const SizedBox.shrink(),
                        items: PosPrinterType.values
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type.label,
                                  style: const TextStyle(
                                    fontFamily: fontMulishSemiBold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) async {
                          if (value == null) return;
                          await _settings.setPrinterType(value);
                        },
                      ),
                    ),
                  ),
                if (_settings.printPdfEnabled.value)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      secondary: CircleAvatar(
                        backgroundColor: _orange.withOpacity(0.12),
                        child: const Icon(Icons.image_outlined, color: _orange),
                      ),
                      title: const Text(
                        'Logos on bill PDF',
                        style: TextStyle(
                          fontFamily: fontMulishSemiBold,
                          fontSize: 15,
                          color: _navy,
                        ),
                      ),
                      subtitle: Text(
                        'Off is faster — text-only bill header and footer',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      value: _settings.billPdfIncludeLogos.value,
                      activeColor: _orange,
                      onChanged: (value) async {
                        if (value == null) return;
                        await _settings.setBillPdfIncludeLogos(value);
                      },
                    ),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'Kitchen',
                  style: TextStyle(
                    fontFamily: fontMulishSemiBold,
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    secondary: CircleAvatar(
                      backgroundColor: _orange.withOpacity(0.12),
                      child: const Icon(Icons.soup_kitchen_rounded, color: _orange),
                    ),
                    title: const Text(
                      'Show all table orders',
                      style: TextStyle(
                        fontFamily: fontMulishSemiBold,
                        fontSize: 15,
                        color: _navy,
                      ),
                    ),
                    subtitle: Text(
                      'Group items by table with time for each round',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    value: _settings.kitchenShowTableAllOrders.value,
                    activeColor: _orange,
                    onChanged: (value) async {
                      if (value == null) return;
                      await _settings.setKitchenShowTableAllOrders(value);
                    },
                  ),
                ),
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    secondary: CircleAvatar(
                      backgroundColor: _orange.withOpacity(0.12),
                      child: const Icon(Icons.check_circle_outline, color: _orange),
                    ),
                    title: const Text(
                      'Show Serve Orders screen',
                      style: TextStyle(
                        fontFamily: fontMulishSemiBold,
                        fontSize: 15,
                        color: _navy,
                      ),
                    ),
                    subtitle: Text(
                      'When off, hide Served Orders tab and combine all items in All Orders',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    value: _settings.kitchenShowServeOrderScreen.value,
                    activeColor: _orange,
                    onChanged: (value) async {
                      if (value == null) return;
                      await _settings.setKitchenShowServeOrderScreen(value);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Account',
                  style: TextStyle(
                    fontFamily: fontMulishSemiBold,
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  subtitle: 'Log out of your account',
                  iconColor: Colors.red.shade400,
                  onTap: _signOut,
                ),
              ],
            );
      }),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  static const _navy = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: (iconColor ?? _orange).withOpacity(0.12),
          child: Icon(icon, color: iconColor ?? _orange),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: fontMulishSemiBold,
            fontSize: 15,
            color: _navy,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      ),
    );
  }
}
