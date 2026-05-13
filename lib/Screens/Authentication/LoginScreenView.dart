import 'package:demo/Screens/Authentication/SignupScreenView.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Styles/my_font.dart';
import 'LoginController.dart';

// Brand colours extracted from the Flavor Flow logo
const _navy   = Color(0xFF1A3A5C);
const _navyDk = Color(0xFF0D2137);
const _orange = Color(0xFFf57c35);  // matches existing primary_color
const _green  = Color(0xFF4CAF50);

// Since we moved all state to LoginController, this widget is now a StatelessWidget!
// This makes the UI code much lighter and faster.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Dependency Injection in GetX: 
    // Get.put() initializes the controller and makes it available globally.
    final controller = Get.put(LoginController());

    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: isWide ? _wideLayout(controller) : _narrowLayout(controller),
    );
  }

  // ─────────────────────────── Wide / Tablet layout ────────────────────────
  /// Builds the layout optimized for wide screens (tablets and desktops).
  /// Splits the screen into a left decorative panel and a right login form panel.
  Widget _wideLayout(LoginController controller) {
    return Row(
      children: [
        // Left panel — navy illustration
        Expanded(flex: 5, child: _leftPanel()),
        // Right panel — form
        Expanded(flex: 6, child: _formPanel(controller)),
      ],
    );
  }

  // ─────────────────────────── Narrow / Phone layout ───────────────────────
  /// Builds the layout optimized for narrow screens (mobile phones).
  /// Stacks a top decorative banner above the login form panel.
  Widget _narrowLayout(LoginController controller) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Top banner (compact version of left panel)
          _topBanner(),
          // Form
          _formPanel(controller),
        ],
      ),
    );
  }

  // ─────────────────────────── Left / Top panel ────────────────────────────
  /// Creates the large decorative left panel used in the wide layout.
  /// Features a gradient background, decorative circles, and an illustration.
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
          // Decorative circles
          ..._decorCircles(),
          // Content
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                // Big illustration icon cluster
                Center(
                  child: _restaurantIllustration(),
                ),
                const Spacer(),
                // Tag line
                const Text(
                  'Smart Restaurant\nManagement',
                  style: TextStyle(
                    fontSize: 28,
                    fontFamily: fontMulishBold,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Manage orders, tables, kitchen & billing\n'
                  'all from one powerful dashboard.',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: fontMulishRegular,
                    color: Colors.white70,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 40),
                // Dot indicators
                Row(
                  children: List.generate(3, (i) => _dot(i == 0)),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Creates the compact decorative top banner used in the narrow layout.
  Widget _topBanner() {
    return Container(
      width: double.infinity,
      height: 220,
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
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _restaurantIllustration(size: 80),
                const SizedBox(height: 12),
                const Text(
                  'Smart Restaurant Management',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: fontMulishBold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Form panel ─────────────────────────────────
  /// Builds the main login form containing the email, password, and action buttons.
  /// Uses [FadeTransition] and [SlideTransition] to animate into view on load.
  Widget _formPanel(LoginController controller) {
    return FadeTransition(
      opacity: controller.fadeAnim,
      child: SlideTransition(
        position: controller.slideAnim,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
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
                    controller: controller.emailCtrl,
                    hint: 'your@email.com',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 18),

                  // Password field
                  _label('Password'),
                  const SizedBox(height: 8),
                  // Obx() listens to observable variables inside it (like controller.obscurePass.value)
                  // When the value changes, ONLY this widget rebuilds, not the whole page!
                  Obx(() => _inputField(
                        controller: controller.passCtrl,
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        obscure: controller.obscurePass.value,
                        suffix: IconButton(
                          icon: Icon(
                            controller.obscurePass.value
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: Colors.grey.shade500,
                          ),
                          onPressed: controller.toggleObscure,
                        ),
                      )),
                  const SizedBox(height: 14),

                  // Remember me + Forgot
                  Row(
                    children: [
                      GestureDetector(
                        onTap: controller.toggleRememberMe,
                        child: Row(
                          children: [
                            Obx(() => AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: controller.rememberMe.value
                                          ? _orange
                                          : Colors.grey.shade400,
                                      width: 1.5,
                                    ),
                                    color: controller.rememberMe.value
                                        ? _orange
                                        : Colors.transparent,
                                  ),
                                  child: controller.rememberMe.value
                                      ? const Icon(Icons.check,
                                          size: 13, color: Colors.white)
                                      : null,
                                )),
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
                        onTap: controller.showResetPasswordMsg,
                        child: const Text(
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
                  // Another Obx() wrapper perfectly scoped just around the loading state.
                  Obx(() => controller.loading.value
                      ? const Center(
                          child: CircularProgressIndicator(color: _orange))
                      : _primaryButton(
                          label: 'Sign In',
                          icon: Icons.login_rounded,
                          onTap: controller.login,
                        )),
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
                    onTap: () => Get.off(() => SignupScreenView()),
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
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Logo widget ────────────────────────────────
  /// Builds a circular container wrapping the application logo image.
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
  /// Builds a custom illustration utilizing Material icons inside a circular layout
  /// to visually represent restaurant management.
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
                    decoration: const BoxDecoration(
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
  /// Generates a list of floating decorative circles used in the background panels.
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

  /// Helper method to create a single positioned decorative circle.
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

  /// Creates a small dot used as a decorative indicator in the left panel.
  Widget _dot(bool active) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(right: 6),
        width: active ? 24 : 8,
        height: 8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: active ? _orange : Colors.white38,
        ),
      );

  // ─────────────────────────── Form helpers ────────────────────────────────
  /// Helper method to create a styled label text widget for form fields.
  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontFamily: fontMulishSemiBold,
          color: _navy,
        ),
      );

  /// Helper method to build a styled [TextField] with standardized borders,
  /// padding, and icons.
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
      style: const TextStyle(
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

  /// Helper method to build the primary filled action button (e.g., 'Sign In').
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
          style: const TextStyle(
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

  /// Helper method to build an outlined action button (e.g., 'Sign Up').
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
          style: const TextStyle(
            fontSize: 14,
            fontFamily: fontMulishSemiBold,
            color: _orange,
          ),
        ),
      ),
    );
  }
}
