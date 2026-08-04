import 'package:demo/Styles/my_font.dart';
import 'package:demo/features/authentication/auth_navigation.dart';
import 'package:demo/features/authentication/controllers/login_controller.dart';
import 'package:demo/features/authentication/services/device_session_settings.dart';
import 'package:demo/features/authentication/services/login_remember_me_settings.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Brand colours extracted from the Smart Kitchen logo
const _navy = Color(0xFF1A3A5C);
const _navyDk = Color(0xFF0D2137);
const _orange = Color(0xFFf57c35); // matches existing primary_color
const _green = Color(0xFF4CAF50);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late final LoginController _loginController;
  bool _obscurePass = true;
  bool _rememberMe = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _loginController = Get.find<LoginController>();
    _loadRememberedCredentials();
    _showPendingSessionMessage();
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

  Future<void> _loadRememberedCredentials() async {
    final saved = await LoginRememberMeSettings.load();
    if (!mounted) return;

    setState(() {
      _rememberMe = saved.rememberMe;
      if (saved.rememberMe) {
        _loginController.emailController.text = saved.email ?? '';
      } else {
        _loginController.emailController.clear();
        _loginController.passwordController.clear();
      }
    });
  }

  Future<void> _showPendingSessionMessage() async {
    final message = await DeviceSessionSettings.takePendingLoginMessage();
    if (message == null || message.isEmpty || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
    });
  }

  Future<void> _persistRememberMeChoice() {
    return LoginRememberMeSettings.save(
      rememberMe: _rememberMe,
      email: _loginController.emailController.text,
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final error = await _loginController.login();
    if (error != null) {
      _snack(error);
      return;
    }
    await _persistRememberMeChoice();
    openAuthenticatedApp();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: isWide ? _wideLayout() : _narrowLayout(),
    );
  }

  // ─────────────────────────── Wide / Tablet layout ────────────────────────
  Widget _wideLayout() {
    return Row(
      children: [
        // Left panel — navy illustration
        Expanded(flex: 5, child: _leftPanel()),
        // Right panel — form
        Expanded(flex: 6, child: _formPanel(scrollable: true)),
      ],
    );
  }

  // ─────────────────────────── Narrow / Phone layout ───────────────────────
  Widget _narrowLayout() {
    return Column(
      children: [
        _topBanner(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: _formPanel(scrollable: false),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────── Left / Top panel ────────────────────────────
  Widget _leftPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, _navyDk],
        ),
      ),
      child: Stack(
        children: [
          ..._decorCircles(),
          Center(child: _brandHeader(compact: false)),
        ],
      ),
    );
  }

  Widget _topBanner() {
    return Container(
      width: double.infinity,
      height: 210,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, _navyDk],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          ..._decorCircles(),
          Center(child: _brandHeader(compact: true)),
        ],
      ),
    );
  }

  Widget _brandHeader({required bool compact}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 24 : 6, vertical: 6),
      child: _logoWidget(height: compact ? 150 : 230),
    );
  }

  // ─────────────────────────── Form panel ─────────────────────────────────
  Widget _formPanel({bool scrollable = true}) {
    final form = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo + brand
            // Center(child: _logoWidget()),
            // const SizedBox(height: 28),

            // Welcome text
            Text(
              'Welcome Back 👋',
              style: TextStyle(
                fontSize: 24,
                fontFamily: fontMulishBold,
                color: _navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to your restaurant dashboard',
              style: TextStyle(
                fontSize: 13,
                fontFamily: fontMulishRegular,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),

            // Email field
            _label('Email Address'),
            const SizedBox(height: 8),
            _inputField(
              controller: _loginController.emailController,
              hint: 'your@email.com',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),

            // Password field
            _label('Password'),
            const SizedBox(height: 8),
            _inputField(
              controller: _loginController.passwordController,
              hint: '••••••••',
              icon: Icons.lock_outline_rounded,
              obscure: _obscurePass,
              suffix: IconButton(
                icon: Icon(
                  _obscurePass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: Colors.grey.shade500,
                ),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              ),
            ),
            const SizedBox(height: 14),

            // Remember me + Forgot
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: _rememberMe ? _orange : Colors.grey.shade400,
                            width: 1.5,
                          ),
                          color: _rememberMe ? _orange : Colors.transparent,
                        ),
                        child: _rememberMe
                            ? const Icon(
                                Icons.check,
                                size: 13,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Remember me',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: fontMulishRegular,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _snack('Reset email sent (if exists).'),
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: fontMulishSemiBold,
                      color: _orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Sign In button
            Obx(
              () => _loginController.isLoading.value
                  ? const Center(
                      child: CircularProgressIndicator(color: _orange),
                    )
                  : _primaryButton(
                      label: 'Sign In',
                      icon: Icons.login_rounded,
                      onTap: _login,
                    ),
            ),
            const SizedBox(height: 16),

            // Divider
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Restaurant staff and admins are created by Super Admin '
                'or Restaurant Admin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontFamily: fontMulishRegular,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Footer
            Center(
              child: Text(
                'Smart Kitchen © ${DateTime.now().year}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  fontFamily: fontMulishRegular,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Center(
          child: scrollable
              ? SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: form,
                )
              : form,
        ),
      ),
    );
  }

  // ─────────────────────────── Logo widget ────────────────────────────────
  Widget _logoWidget({double height = 200}) {
    return Image.asset(
      'assets/images/logo.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.restaurant, size: height * 0.4, color: _orange),
    );
  }

  // ─────────────────────────── Decorative circles ─────────────────────────
  List<Widget> _decorCircles() {
    return [
      _circle(
        top: -30,
        right: -30,
        size: 140,
        color: Colors.white.withOpacity(0.04),
      ),
      _circle(top: 80, left: -20, size: 80, color: _orange.withOpacity(0.12)),
      _circle(bottom: 60, right: 20, size: 60, color: _green.withOpacity(0.12)),
      _circle(
        bottom: -20,
        left: 40,
        size: 100,
        color: Colors.white.withOpacity(0.04),
      ),
    ];
  }

  Widget _circle({
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

  // ─────────────────────────── Form helpers ────────────────────────────────
  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      fontFamily: fontMulishSemiBold,
      color: _navy,
    ),
  );

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: 14,
        fontFamily: fontMulishRegular,
        color: _navy,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 13,
          fontFamily: fontMulishRegular,
        ),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
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
          borderSide: const BorderSide(color: _orange, width: 1.5),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: TextStyle(fontSize: 15, fontFamily: fontMulishSemiBold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 4,
          shadowColor: _orange.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
