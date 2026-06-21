import 'package:demo/features/menu_setup/menu_setup.dart';
import 'package:demo/features/settings/controllers/settings_controller.dart';
import 'package:demo/features/settings/services/print_settings.dart';
import 'package:demo/features/settings/views/AdminDashboardPage.dart';
import 'package:demo/features/settings/views/ExpensesPage.dart';
import 'package:demo/features/settings/views/ExportPage.dart';
import 'package:demo/features/settings/views/bill_customer_contacts_page.dart';
import 'package:demo/features/settings/views/profile_view.dart';
import 'package:demo/features/settings/views/settings_ui.dart';
import 'package:demo/features/settings/views/staff_list_view.dart';
import 'package:demo/features/settings/views/stock_management_page.dart';
import 'package:demo/features/shell/services/app_tab_settings.dart';
import 'package:demo/features/tables/tables.dart';
import 'package:demo/features/transactions/transactions.dart';
import 'package:demo/features/zomato/views/imagekit_settings_page.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsBusinessSectionPage extends StatelessWidget {
  const SettingsBusinessSectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsController>();
    return Obx(() {
      final isAdmin = settings.isAdmin;
      return SettingsSectionScaffold(
        title: 'Business',
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SettingsGroupedSection(
              children: [
                if (isAdmin)
                  SettingsNavRow(
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    subtitle: 'Sales, expenses & reserved tables overview',
                    onTap: () => Get.to(() => const AdminDashboardPage()),
                  ),
                if (isAdmin)
                  SettingsNavRow(
                    icon: Icons.receipt_long_rounded,
                    title: 'Transactions',
                    subtitle: 'View sales and payment history',
                    onTap: () => Get.to(() => const TransactionsPage()),
                  ),
                SettingsNavRow(
                  icon: Icons.payments_outlined,
                  title: 'Expenses',
                  subtitle: 'Track and add business expenses',
                  onTap: () => Get.to(() => const ExpensesPage()),
                ),
                if (isAdmin)
                  SettingsNavRow(
                    icon: Icons.file_download_outlined,
                    title: 'Export',
                    subtitle: 'Download transactions & expenses to Excel',
                    onTap: () => Get.to(() => ExportPage(isAdmin: true)),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class SettingsRestaurantSectionPage extends StatelessWidget {
  const SettingsRestaurantSectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsController>();
    return Obx(() {
      final isAdmin = settings.isAdmin;
      return SettingsSectionScaffold(
        title: 'Restaurant setup',
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SettingsGroupedSection(
              children: [
                SettingsNavRow(
                  icon: Icons.table_restaurant_rounded,
                  title: 'Tables',
                  subtitle: 'Add or manage dining tables',
                  onTap: () => Get.to(() => AddTablePage()),
                ),
                if (isAdmin)
                  SettingsNavRow(
                    icon: Icons.menu_book_rounded,
                    title: 'Menu',
                    subtitle: 'Categories and menu items',
                    onTap: () => Get.to(() => AddCategoryPage()),
                  ),
                if (isAdmin)
                  SettingsNavRow(
                    icon: Icons.group_add_rounded,
                    title: 'Staff',
                    subtitle: 'Add staff, send password reset & remove access',
                    onTap: () => Get.to(() => const StaffListView()),
                  ),
                if (isAdmin)
                  SettingsNavRow(
                    icon: Icons.lock_clock_rounded,
                    title: 'Permissions',
                    subtitle: 'Time limit for staff to edit or delete orders',
                    onTap: () =>
                        Get.to(() => const SettingsPermissionsSectionPage()),
                  ),
                if (isAdmin)
                  SettingsNavRow(
                    icon: Icons.delivery_dining_rounded,
                    title: 'Zomato / ImageKit',
                    subtitle:
                        'ImageKit keys for Zomato orders and WhatsApp bills',
                    onTap: () => Get.to(() => const ImageKitSettingsPage()),
                  ),
                SettingsNavRow(
                  icon: Icons.inventory_2_outlined,
                  title: 'Stock Management',
                  subtitle: 'Mark menu items in stock or out of stock',
                  onTap: () => Get.to(() => const StockManagementPage()),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class SettingsPermissionsSectionPage extends StatefulWidget {
  const SettingsPermissionsSectionPage({super.key});

  @override
  State<SettingsPermissionsSectionPage> createState() =>
      _SettingsPermissionsSectionPageState();
}

class _SettingsPermissionsSectionPageState
    extends State<SettingsPermissionsSectionPage> {
  late final SettingsController _settings;
  late final TextEditingController _limitController;

  @override
  void initState() {
    super.initState();
    _settings = Get.find<SettingsController>();
    _limitController = TextEditingController();
    _loadFields();
  }

  Future<void> _loadFields() async {
    await _settings.loadStaffPermissionSettings();
    if (!mounted) return;
    _limitController.text =
        _settings.staffEditDeleteLimitMinutes.value.toString();
    setState(() {});
  }

  Future<void> _save() async {
    final minutes = int.tryParse(_limitController.text.trim());
    if (minutes == null || minutes < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid number of minutes (0 or more).'),
        ),
      );
      return;
    }

    final ok = await _settings.saveStaffEditDeleteLimit(minutes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Permission settings saved.' : 'Could not save permissions.',
        ),
        backgroundColor: ok ? const Color(0xFF2E7D32) : Colors.red.shade700,
      ),
    );
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSectionScaffold(
      title: 'Permissions',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsGroupedSection(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              SettingsColors.orange.withValues(alpha: 0.12),
                          child: const Icon(
                            Icons.lock_clock_rounded,
                            color: SettingsColors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Staff edit/delete time limit',
                                style: TextStyle(
                                  fontFamily: fontMulishSemiBold,
                                  fontSize: 15,
                                  color: SettingsColors.navy,
                                ),
                              ),
                              Text(
                                'Minutes staff can edit/delete the latest order '
                                'after it is placed (0 = no limit). Admins are '
                                'never restricted.',
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
                    TextField(
                      controller: _limitController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Time limit (minutes)',
                        hintText: 'e.g. 10',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Obx(
                        () => FilledButton(
                          onPressed: _settings.isSavingPermissions.value
                              ? null
                              : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: SettingsColors.orange,
                          ),
                          child: _settings.isSavingPermissions.value
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SettingsBillingSectionPage extends StatefulWidget {
  const SettingsBillingSectionPage({super.key});

  @override
  State<SettingsBillingSectionPage> createState() =>
      _SettingsBillingSectionPageState();
}

class _SettingsBillingSectionPageState extends State<SettingsBillingSectionPage> {
  late final SettingsController _settings;
  late final TextEditingController _cgstController;
  late final TextEditingController _sgstController;

  @override
  void initState() {
    super.initState();
    _settings = Get.find<SettingsController>();
    _cgstController = TextEditingController();
    _sgstController = TextEditingController();
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
        const SnackBar(
          content: Text('Enter valid tax percentages between 0 and 100.'),
        ),
      );
      return;
    }

    final ok = await _settings.saveTaxSettings(cgst: cgst, sgst: sgst);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'GST settings saved.' : 'Could not save GST settings.',
        ),
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

  Widget _buildGstSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    SettingsColors.orange.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.percent_rounded,
                  color: SettingsColors.orange,
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
                        color: SettingsColors.navy,
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
                  keyboardType: const TextInputType.numberWithOptions(
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
                  keyboardType: const TextInputType.numberWithOptions(
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
                  backgroundColor: SettingsColors.orange,
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
    );
  }

  Widget _buildPrinterSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: SettingsColors.orange.withValues(alpha: 0.12),
              child: const Icon(Icons.print_rounded, color: SettingsColors.orange),
            ),
            title: const Text(
              'Receipt printer',
              style: TextStyle(
                fontFamily: fontMulishSemiBold,
                fontSize: 15,
                color: SettingsColors.navy,
              ),
            ),
            subtitle: Text(
              'Paper width for billing receipts (USB thermal)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          ...PosPrinterType.values.map((type) {
            return RadioListTile<PosPrinterType>(
              value: type,
              groupValue: _settings.printerType.value,
              activeColor: SettingsColors.orange,
              title: Text(
                type.label,
                style: const TextStyle(
                  fontFamily: fontMulishSemiBold,
                  fontSize: 14,
                  color: SettingsColors.navy,
                ),
              ),
              subtitle: Text(
                type.subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              onChanged: (value) async {
                if (value == null) return;
                await _settings.setPrinterType(value);
              },
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isAdmin = _settings.isAdmin;
      return SettingsSectionScaffold(
        title: 'Billing',
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SettingsGroupedSection(
              children: [
                if (isAdmin) _buildGstSection(),
                _buildPrinterSection(),
                SettingsSwitchRow(
                  icon: Icons.image_outlined,
                  title: 'Logos on bill PDF',
                  subtitle:
                      'Show restaurant and Flavor Flow logos on printed receipts',
                  value: _settings.billPdfIncludeLogos.value,
                  onChanged: (value) async {
                    if (value == null) return;
                    await _settings.setBillPdfIncludeLogos(value);
                  },
                ),
                SettingsSwitchRow(
                  icon: Icons.print_outlined,
                  title: 'Auto-print after billing',
                  subtitle:
                      'Print receipt automatically when billing completes (without choosing Print in dialog)',
                  value: _settings.printPdfEnabled.value,
                  onChanged: (value) async {
                    if (value == null) return;
                    await _settings.setPrintPdfEnabled(value);
                  },
                ),
                SettingsNavRow(
                  icon: Icons.contacts_outlined,
                  title: 'WhatsApp bill customers',
                  subtitle: 'Names and mobile numbers saved from billing',
                  onTap: () => Get.to(() => const BillCustomerContactsPage()),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class SettingsNavigationSectionPage extends StatefulWidget {
  const SettingsNavigationSectionPage({super.key});

  @override
  State<SettingsNavigationSectionPage> createState() =>
      _SettingsNavigationSectionPageState();
}

class _SettingsNavigationSectionPageState
    extends State<SettingsNavigationSectionPage> {
  late final SettingsController _settings;

  @override
  void initState() {
    super.initState();
    _settings = Get.find<SettingsController>();
    _settings.loadAppTabSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SettingsSectionScaffold(
        title: 'Navigation',
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SettingsGroupedSection(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Column(
                    children: AppTabMode.values.map((mode) {
                      return RadioListTile<AppTabMode>(
                        value: mode,
                        groupValue: _settings.appTabMode.value,
                        activeColor: SettingsColors.orange,
                        title: Text(
                          mode.label,
                          style: const TextStyle(
                            fontFamily: fontMulishSemiBold,
                            fontSize: 15,
                            color: SettingsColors.navy,
                          ),
                        ),
                        subtitle: Text(
                          mode.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        onChanged: (value) async {
                          if (value == null) return;
                          await _settings.setAppTabMode(value);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsKitchenSectionPage extends StatefulWidget {
  const SettingsKitchenSectionPage({super.key});

  @override
  State<SettingsKitchenSectionPage> createState() =>
      _SettingsKitchenSectionPageState();
}

class _SettingsKitchenSectionPageState extends State<SettingsKitchenSectionPage> {
  late final SettingsController _settings;

  @override
  void initState() {
    super.initState();
    _settings = Get.find<SettingsController>();
    _settings.loadKitchenSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SettingsSectionScaffold(
        title: 'Kitchen',
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SettingsGroupedSection(
              children: [
                SettingsSwitchRow(
                  icon: Icons.soup_kitchen_rounded,
                  title: 'Show all table orders',
                  subtitle: 'Group items by table with time for each round',
                  value: _settings.kitchenShowTableAllOrders.value,
                  onChanged: (value) async {
                    if (value == null) return;
                    await _settings.setKitchenShowTableAllOrders(value);
                  },
                ),
                SettingsSwitchRow(
                  icon: Icons.view_list_rounded,
                  title: 'Enable Kitchen Preparation View',
                  subtitle:
                      'Group kitchen orders by item with qty × table lines',
                  value: _settings.kitchenPreparationViewEnabled.value,
                  onChanged: (value) async {
                    if (value == null) return;
                    await _settings.setKitchenPreparationViewEnabled(value);
                  },
                ),
                SettingsSwitchRow(
                  icon: Icons.check_circle_outline,
                  title: 'Show Serve Orders screen',
                  subtitle:
                      'When off, hide Served Orders tab and combine all items in All Orders',
                  value: _settings.kitchenShowServeOrderScreen.value,
                  onChanged: (value) async {
                    if (value == null) return;
                    await _settings.setKitchenShowServeOrderScreen(value);
                  },
                ),
                SettingsSwitchRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Enable Order Ringtone in Background',
                  subtitle:
                      'When on, new-order bells play while the screen is locked. Android will ask to allow notifications and disable battery optimization for reliable alerts.',
                  value: _settings.kitchenBackgroundOrderRingtoneEnabled.value,
                  onChanged: (value) async {
                    if (value == null) return;
                    await _settings.setKitchenBackgroundOrderRingtoneEnabled(
                      value,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsAccountSectionPage extends StatelessWidget {
  const SettingsAccountSectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsController>();
    return Obx(() {
      final isAdmin = settings.isAdmin;
      return SettingsSectionScaffold(
        title: 'Account',
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SettingsGroupedSection(
              children: [
                SettingsNavRow(
                  icon: Icons.person_outline_rounded,
                  title: 'My Profile',
                  subtitle: isAdmin
                      ? 'View account details and change password'
                      : 'View your name and email',
                  onTap: () => Get.to(() => const ProfileView()),
                ),
                SettingsNavRow(
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  subtitle: 'Log out of your account',
                  iconColor: Colors.red.shade400,
                  onTap: settings.signOut,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
