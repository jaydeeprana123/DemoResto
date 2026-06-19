import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';

class SettingsColors {
  SettingsColors._();

  static const navy = Color(0xFF1A3A5C);
  static const orange = Color(0xFFf57c35);
  static const background = Color(0xFFF5F6FA);
}

class SettingsSectionScaffold extends StatelessWidget {
  const SettingsSectionScaffold({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SettingsColors.background,
      appBar: AppBar(
        backgroundColor: SettingsColors.navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontFamily: fontMulishBold,
            color: Colors.white,
          ),
        ),
      ),
      body: body,
    );
  }
}

class SettingsGroupedSection extends StatelessWidget {
  const SettingsGroupedSection({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: Colors.grey.shade200,
          ),
        );
      }
      items.add(children[i]);
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      ),
    );
  }
}

class SettingsHubRow extends StatelessWidget {
  const SettingsHubRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: SettingsColors.orange.withValues(alpha: 0.12),
        child: Icon(icon, color: SettingsColors.orange),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: fontMulishSemiBold,
          fontSize: 15,
          color: SettingsColors.navy,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
    );
  }
}

class SettingsNavRow extends StatelessWidget {
  const SettingsNavRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? SettingsColors.orange;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: accent.withValues(alpha: 0.12),
        child: Icon(icon, color: accent),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: fontMulishSemiBold,
          fontSize: 15,
          color: SettingsColors.navy,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
    );
  }
}

class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: CircleAvatar(
        backgroundColor: SettingsColors.orange.withValues(alpha: 0.12),
        child: Icon(icon, color: SettingsColors.orange),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: fontMulishSemiBold,
          fontSize: 15,
          color: SettingsColors.navy,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      value: value,
      activeColor: SettingsColors.orange,
      onChanged: onChanged,
    );
  }
}
