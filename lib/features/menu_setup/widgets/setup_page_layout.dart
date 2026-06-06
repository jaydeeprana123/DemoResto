import 'package:flutter/material.dart';

import 'package:demo/Styles/my_font.dart';

class SetupPageColors {
  static const navy = Color(0xFF1A3A5C);
  static const navyDk = Color(0xFF0D2137);
  static const orange = Color(0xFFf57c35);
  static const green = Color(0xFF4CAF50);
  static const bg = Color(0xFFF5F6FA);
}

class SetupPageLayout extends StatefulWidget {
  const SetupPageLayout({
    super.key,
    required this.appBarTitle,
    required this.panelTitle,
    required this.panelSubtitle,
    required this.panelIllustration,
    required this.child,
    this.wideTitle,
    this.wideSubtitle,
    this.appBarActions,
  });

  final String appBarTitle;
  final String panelTitle;
  final String panelSubtitle;
  final Widget panelIllustration;
  final String? wideTitle;
  final String? wideSubtitle;
  final List<Widget>? appBarActions;
  final Widget child;

  @override
  State<SetupPageLayout> createState() => _SetupPageLayoutState();
}

class _SetupPageLayoutState extends State<SetupPageLayout>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: SetupPageColors.bg,
      appBar: AppBar(
        backgroundColor: SetupPageColors.navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.appBarTitle,
          style: const TextStyle(
            fontSize: 16,
            fontFamily: fontMulishBold,
            color: Colors.white,
          ),
        ),
        actions: widget.appBarActions,
      ),
      body: isWide ? _wideLayout() : _narrowLayout(),
    );
  }

  Widget _wideLayout() {
    return Row(
      children: [
        Expanded(flex: 5, child: _sidePanel()),
        Expanded(flex: 6, child: _contentPanel()),
      ],
    );
  }

  Widget _narrowLayout() {
    return _contentPanel();
  }

  Widget _sidePanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SetupPageColors.navy, SetupPageColors.navyDk],
        ),
      ),
      child: Stack(
        children: [
          ...SetupPageStyle.decorCircles(),
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Center(child: widget.panelIllustration),
                const Spacer(),
                Text(
                  widget.panelTitle,
                  style: const TextStyle(
                    fontSize: 28,
                    fontFamily: fontMulishBold,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.panelSubtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: fontMulishRegular,
                    color: Colors.white70,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: List.generate(
                    3,
                    (i) => SetupPageStyle.dot(active: i == 0),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contentPanel() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (MediaQuery.of(context).size.width > 700 &&
                  widget.wideTitle != null) ...[
                Text(
                  widget.wideTitle!,
                  style: const TextStyle(
                    fontSize: 24,
                    fontFamily: fontMulishBold,
                    color: SetupPageColors.navy,
                  ),
                ),
                const SizedBox(height: 6),
                if (widget.wideSubtitle != null)
                  Text(
                    widget.wideSubtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: fontMulishRegular,
                      color: Colors.grey.shade600,
                    ),
                  ),
                const SizedBox(height: 24),
              ],
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
}

class SetupPageStyle {
  static Widget label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontFamily: fontMulishSemiBold,
      color: SetupPageColors.navy,
    ),
  );

  static InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.grey.shade400,
        fontSize: 13,
        fontFamily: fontMulishRegular,
      ),
      prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SetupPageColors.orange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
    );
  }

  static Widget primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontFamily: fontMulishSemiBold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: SetupPageColors.orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: SetupPageColors.orange.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 4,
          shadowColor: SetupPageColors.orange.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  static Widget outlineButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: SetupPageColors.orange, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          foregroundColor: SetupPageColors.orange,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontFamily: fontMulishSemiBold,
            color: SetupPageColors.orange,
          ),
        ),
      ),
    );
  }

  static Widget sectionDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontFamily: fontMulishRegular,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  static Widget listCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: SetupPageColors.navy.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  static Widget leadingIcon({
    required IconData icon,
    Color? color,
  }) {
    final c = color ?? SetupPageColors.orange;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: c, size: 22),
    );
  }

  static Widget emptyState({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontFamily: fontMulishSemiBold,
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                fontFamily: fontMulishRegular,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Future<bool?> confirmDelete(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(fontFamily: fontMulishSemiBold, fontSize: 18),
        ),
        content: Text(
          message,
          style: const TextStyle(fontFamily: fontMulishRegular, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: fontMulishSemiBold,
                color: Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: fontMulishSemiBold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget panelIllustration({
    required IconData centerIcon,
    required IconData rightIcon,
    double size = 120,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi, color: SetupPageColors.orange, size: size * 0.2),
              SizedBox(height: size * 0.04),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(centerIcon, color: Colors.white, size: size * 0.26),
                  SizedBox(width: size * 0.05),
                  Container(
                    width: size * 0.18,
                    height: size * 0.18,
                    decoration: const BoxDecoration(
                      color: SetupPageColors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: size * 0.12,
                    ),
                  ),
                  SizedBox(width: size * 0.05),
                  Icon(
                    rightIcon,
                    color: SetupPageColors.green,
                    size: size * 0.26,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static List<Widget> decorCircles() {
    return [
      _circle(
        top: -30,
        right: -30,
        size: 140,
        color: Colors.white.withValues(alpha: 0.04),
      ),
      _circle(
        top: 80,
        left: -20,
        size: 80,
        color: SetupPageColors.orange.withValues(alpha: 0.12),
      ),
      _circle(
        bottom: 60,
        right: 20,
        size: 60,
        color: SetupPageColors.green.withValues(alpha: 0.12),
      ),
      _circle(
        bottom: -20,
        left: 40,
        size: 100,
        color: Colors.white.withValues(alpha: 0.04),
      ),
    ];
  }

  static Widget dot({required bool active}) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    margin: const EdgeInsets.only(right: 6),
    width: active ? 24 : 8,
    height: 8,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      color: active ? SetupPageColors.orange : Colors.white38,
    ),
  );

  static Widget _circle({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required Color color,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
