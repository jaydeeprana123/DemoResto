import 'package:demo/features/shell/shell.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/features/authentication/controllers/login_controller.dart';
import 'package:demo/features/authentication/views/signup_screen_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Brand colours extracted from the Flavor Flow logo
const _navy   = Color(0xFF1A3A5C);
const _navyDk = Color(0xFF0D2137);
const _orange = Color(0xFFf57c35);  // matches existing primary_color
const _green  = Color(0xFF4CAF50);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _AboutInfoPage {
  final String title;
  final String body;
  final IconData icon;

  const _AboutInfoPage({
    required this.title,
    required this.body,
    required this.icon,
  });
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _infoPageCtrl = PageController();
  late final LoginController _loginController;
  bool _obscurePass   = true;
  bool _rememberMe    = false;
  int _infoPageIndex  = 0;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const _aboutPages = [
    _AboutInfoPage(
      title: 'Flavor Flow',
      icon: Icons.restaurant_menu_rounded,
      body:
          'Flavor Flow is a restaurant management app built for busy kitchens '
          'and front-of-house teams. Run dine-in tables, take-away orders, '
          'kitchen display, billing, and expenses from one place.',
    ),
    _AboutInfoPage(
      title: 'Orders & Tables',
      icon: Icons.table_restaurant_rounded,
      body:
          'Drag-and-drop table layout, queue take-away orders, send items to '
          'the kitchen, edit rounds, and bill from the menu or cart. Paid '
          'orders stay visible until served or delivered.',
    ),
    _AboutInfoPage(
      title: 'Kitchen & Insights',
      icon: Icons.soup_kitchen_rounded,
      body:
          'Kitchen view with category filters and optional grouped table '
          'orders. Track transactions, manage settings, and keep service '
          'moving with real-time Firestore sync across devices.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loginController = Get.find<LoginController>();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _infoPageCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final error = await _loginController.login();
    if (error != null) {
      _snack(error);
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const BottomNavigationView()),
    );
  }

  Future<void> _register() async {
    final error = await _loginController.register();
    if (error != null) {
      _snack(error);
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const BottomNavigationView()),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 100),
                Center(child: _restaurantIllustration()),
                const SizedBox(height: 24),
                Expanded(child: _aboutPageView(compact: false)),
                const SizedBox(height: 16),
                _aboutPageDots(),
                const SizedBox(height: 8),
                Text(
                  'Swipe or tap dots to explore',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: fontMulishRegular,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBanner() {
    return Container(
      width: double.infinity,
      height: 300,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              children: [
                _restaurantIllustration(size: 72),
                const SizedBox(height: 12),
                Expanded(child: _aboutPageView(compact: true)),
                const SizedBox(height: 10),
                _aboutPageDots(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ScrollBehavior get _pageScrollBehavior => ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      );

  Widget _aboutPageView({required bool compact}) {
    return ScrollConfiguration(
      behavior: _pageScrollBehavior,
      child: PageView.builder(
        controller: _infoPageCtrl,
        physics: const PageScrollPhysics(),
        onPageChanged: (index) => setState(() => _infoPageIndex = index),
        itemCount: _aboutPages.length,
        itemBuilder: (context, index) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: _aboutInfoPageContent(
                    _aboutPages[index],
                    compact: compact,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _aboutInfoPageContent(_AboutInfoPage page, {required bool compact}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(page.icon, color: _orange, size: compact ? 22 : 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  page.title,
                  style: TextStyle(
                    fontSize: compact ? 18 : 26,
                    fontFamily: fontMulishBold,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            page.body,
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              fontFamily: fontMulishRegular,
              color: Colors.white70,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _aboutPages.length,
        (i) => GestureDetector(
          onTap: () => _infoPageCtrl.animateToPage(
            i,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          ),
          child: _dot(i == _infoPageIndex),
        ),
      ),
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
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Remember me + Forgot
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setState(() => _rememberMe = !_rememberMe),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: _rememberMe
                                      ? _orange
                                      : Colors.grey.shade400,
                                  width: 1.5,
                                ),
                                color: _rememberMe
                                    ? _orange
                                    : Colors.transparent,
                              ),
                              child: _rememberMe
                                  ? const Icon(Icons.check,
                                      size: 13, color: Colors.white)
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
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or',
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
                  const SizedBox(height: 16),

                  // Sign Up button
                  _outlineButton(
                    label: "Don't have an account? Sign Up",
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SignupScreenView()),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Footer
                  Center(
                    child: Text(
                      'Flavor Flow © ${DateTime.now().year}',
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
  Widget _logoWidget() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.restaurant,
            size: 40,
            color: _orange,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Restaurant illustration ────────────────────
  Widget _restaurantIllustration({double size = 140}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1.5,
              ),
            ),
          ),
          // Icon group
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi, color: _orange, size: size * 0.22),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant, color: Colors.white, size: size * 0.28),
                  SizedBox(width: size * 0.05),
                  Container(
                    width: size * 0.18,
                    height: size * 0.18,
                    decoration: BoxDecoration(
                      color: _orange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.play_arrow,
                        color: Colors.white, size: size * 0.13),
                  ),
                  SizedBox(width: size * 0.05),
                  Icon(Icons.trending_up, color: _green, size: size * 0.28),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Decorative circles ─────────────────────────
  List<Widget> _decorCircles() {
    return [
      _circle(top: -30, right: -30, size: 140,
          color: Colors.white.withOpacity(0.04)),
      _circle(top: 80, left: -20, size: 80,
          color: _orange.withOpacity(0.12)),
      _circle(bottom: 60, right: 20, size: 60,
          color: _green.withOpacity(0.12)),
      _circle(bottom: -20, left: 40, size: 100,
          color: Colors.white.withOpacity(0.04)),
    ];
  }

  Widget _circle({
    double? top, double? bottom, double? left, double? right,
    required double size, required Color color,
  }) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }

  Widget _dot(bool active) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: active ? 24 : 8,
        height: 8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: active ? _orange : Colors.white38,
        ),
      );

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
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          style: TextStyle(
            fontSize: 15,
            fontFamily: fontMulishSemiBold,
          ),
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

  Widget _outlineButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: _orange, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          foregroundColor: _orange,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontFamily: fontMulishSemiBold,
            color: _orange,
          ),
        ),
      ),
    );
  }
}
