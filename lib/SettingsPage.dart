import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'TransactionsPage.dart';
import 'ExpensePage.dart';
import 'Styles/my_font.dart';
import 'Styles/my_colors.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showPrintDialog = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showPrintDialog = prefs.getBool('show_print_dialog') ?? true;
    });
  }

  Future<void> _updatePrintDialog(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_print_dialog', value);
    setState(() {
      _showPrintDialog = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color navy = Color(0xFF1A3A5C);
    const Color orange = Color(0xFFf57c35);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          "Settings",
          style: TextStyle(
            fontFamily: fontMulishBold,
            color: navy,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingItem(
            icon: Icons.account_balance_wallet_outlined,
            title: "Income",
            subtitle: "View transaction history and revenue",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TransactionsPage()),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            icon: Icons.outbound_outlined,
            title: "Expense",
            subtitle: "Manage and track business expenses",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpensePage()),
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SwitchListTile(
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.print_outlined, color: orange, size: 22),
              ),
              title: const Text(
                "Show print dialog",
                style: TextStyle(
                  fontFamily: fontMulishBold,
                  fontSize: 15,
                  color: navy,
                ),
              ),
              subtitle: Text(
                "Ask to print receipt after billing",
                style: TextStyle(
                  fontFamily: fontMulishRegular,
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              activeColor: orange,
              value: _showPrintDialog,
              onChanged: _updatePrintDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    const Color navy = Color(0xFF1A3A5C);
    const Color orange = Color(0xFFf57c35);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: navy.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: navy, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: fontMulishBold,
            fontSize: 15,
            color: navy,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontFamily: fontMulishRegular,
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        onTap: onTap,
      ),
    );
  }
}
