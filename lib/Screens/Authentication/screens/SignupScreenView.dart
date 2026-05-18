import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:demo/Screens/Authentication/screens/LoginScreenView.dart';
import 'package:demo/Screens/Authentication/controllers/auth_controller.dart';
import 'package:demo/Styles/my_font.dart';

// Brand colors matching the Flavor Flow identity
const _navy   = Color(0xFF1A3A5C);
const _navyDk = Color(0xFF0D2137);
const _orange = Color(0xFFf57c35); // primary color
const _green  = Color(0xFF4CAF50);

/// SignupScreenView
/// 
/// A beautifully responsive sign-up screen.
/// Implemented using the GetX Repository Pattern.
/// It delegates business operations and state storage to [AuthController].
class SignupScreenView extends StatefulWidget {
  const SignupScreenView({super.key});

  @override
  State<SignupScreenView> createState() => _SignupScreenViewState();
}

class _SignupScreenViewState extends State<SignupScreenView> with SingleTickerProviderStateMixin {
  // Access the AuthController (using Get.find since it was put in LoginPage, or fallback to Get.put)
  final AuthController _authCtrl = Get.isRegistered<AuthController>()
      ? Get.find<AuthController>()
      : Get.put(AuthController());

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    // UI Entrance animations
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: isWide ? _wideLayout() : _narrowLayout(),
    );
  }

  // ─────────────────────────── Wide Layout (Web / Desktop) ────────────────────────
  Widget _wideLayout() {
    return Row(
      children: [
        // Left panel featuring the interactive PageView illustration and slides
        Expanded(flex: 5, child: _leftPanel()),
        // Right panel rendering the registration form
        Expanded(flex: 6, child: _formPanel()),
      ],
    );
  }

  // ─────────────────────────── Narrow Layout (Mobile Devices) ───────────────────────
  Widget _narrowLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Top banner
          _topBanner(),
          // Form
          _formPanel(),
        ],
      ),
    );
  }

  // ─────────────────────────── Interactive Left Panel (PageView) ────────────────────────────
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
          // Ambient decorative circles
          ..._decorCircles(),
          
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                
                // Proper PageView container to support sliding features (synchronized state)
                Expanded(
                  flex: 14,
                  child: PageView(
                    controller: _authCtrl.pageController,
                    onPageChanged: _authCtrl.onPageChanged,
                    children: [
                      // Slide 1: General Smart Management
                      _pageSlide(
                        title: 'Smart Restaurant\nManagement',
                        subtitle: 'Manage orders, tables, kitchen & billing all from one powerful unified dashboard.',
                        illustration: _illustration(size: 140),
                      ),
                      // Slide 2: Real-time Kitchen Synchronization
                      _pageSlide(
                        title: 'Real-Time Kitchen\nCoordination',
                        subtitle: 'Instantly synchronize orders between tables and the kitchen queue for swift preparation.',
                        illustration: _featureIllustration(Icons.soup_kitchen_outlined, size: 140),
                      ),
                      // Slide 3: Voice-assisted AI features
                      _pageSlide(
                        title: 'Voice-Based AI\nOrdering',
                        subtitle: 'Supercharge order capture and table mapping with our advanced voice-to-order engine.',
                        illustration: _featureIllustration(Icons.mic_none_rounded, size: 140),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Interactive Dot Indicators
                Obx(() => Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: List.generate(
                    _authCtrl.totalPages, 
                    (i) => _dot(i == _authCtrl.pageViewIndex.value, index: i),
                  ),
                )),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Helper widget to build a specific PageView slide
  Widget _pageSlide({
    required String title,
    required String subtitle,
    required Widget illustration,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: illustration),
        const SizedBox(height: 48),
        Text(
          title,
          style: TextStyle(
            fontSize: 28,
            fontFamily: fontMulishBold,
            color: Colors.white,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            fontFamily: fontMulishRegular,
            color: Colors.white70,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────── Top Banner (Mobile Compact Layout) ──────────────────────
  Widget _topBanner() {
    return Container(
      width: double.infinity,
      height: 200,
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
                _illustration(size: 72),
                const SizedBox(height: 12),
                Text(
                  'Create Your Account',
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

  // ─────────────────────────── Form Panel (Reactive) ─────────────────────────────────
  Widget _formPanel() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Heading
                  Text(
                    'Create Account ✨',
                    style: TextStyle(
                      fontSize: 24,
                      fontFamily: fontMulishBold,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fill in your details to get started',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: fontMulishRegular,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Full Name
                  _label('Full Name'),
                  const SizedBox(height: 8),
                  _inputField(
                    controller: _authCtrl.nameCtrl,
                    hint: 'John Doe',
                    icon: Icons.person_outline_rounded,
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 16),

                  // Email
                  _label('Email Address'),
                  const SizedBox(height: 8),
                  _inputField(
                    controller: _authCtrl.emailCtrl,
                    hint: 'your@email.com',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // Password (Obx dynamic obscure toggling)
                  _label('Password'),
                  const SizedBox(height: 8),
                  Obx(() => _inputField(
                    controller: _authCtrl.passCtrl,
                    hint: 'Min. 6 characters',
                    icon: Icons.lock_outline_rounded,
                    obscure: _authCtrl.obscurePass.value,
                    suffix: IconButton(
                      icon: Icon(
                        _authCtrl.obscurePass.value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: Colors.grey.shade500,
                      ),
                      onPressed: () => _authCtrl.obscurePass.toggle(),
                    ),
                  )),
                  const SizedBox(height: 16),

                  // Confirm Password (Obx dynamic obscure toggling)
                  _label('Confirm Password'),
                  const SizedBox(height: 8),
                  Obx(() => _inputField(
                    controller: _authCtrl.confirmPassCtrl,
                    hint: 'Re-enter password',
                    icon: Icons.lock_outline_rounded,
                    obscure: _authCtrl.obscureConfirmPass.value,
                    suffix: IconButton(
                      icon: Icon(
                        _authCtrl.obscureConfirmPass.value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: Colors.grey.shade500,
                      ),
                      onPressed: () => _authCtrl.obscureConfirmPass.toggle(),
                    ),
                  )),
                  const SizedBox(height: 16),

                  // Role Selector
                  _label('Account Role'),
                  const SizedBox(height: 8),
                  _roleSelector(),
                  const SizedBox(height: 20),

                  // Agree to terms Checkbox
                  _termsRow(),
                  const SizedBox(height: 24),

                  // Create Account Action Button
                  Obx(() => _authCtrl.isLoading.value
                      ? const Center(
                          child: CircularProgressIndicator(color: _orange))
                      : _primaryButton(
                          label: 'Create Account',
                          icon: Icons.person_add_alt_1_rounded,
                          onTap: _authCtrl.registerUser,
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

                  // Redirect to Login
                  _outlineButton(
                    label: 'Already have an account? Sign In',
                    onTap: () => Get.off(() => const LoginPage()),
                  ),
                  const SizedBox(height: 28),

                  // Footer Copyright
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

  // ─────────────────────────── Role Selector Pills (Reactive) ───────────────────────────
  Widget _roleSelector() {
    return Row(
      children: _authCtrl.roles.map((role) {
        return Obx(() {
          final selected = _authCtrl.selectedRole.value == role;
          final isAdmin  = role == 'Admin';
          final selColor = isAdmin ? _navy : _orange;
          return Expanded(
            child: GestureDetector(
              onTap: () => _authCtrl.selectedRole.value = role,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(right: isAdmin ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? selColor : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? selColor : Colors.grey.shade200,
                      width: 1.5,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: selColor.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isAdmin
                            ? Icons.admin_panel_settings_outlined
                            : Icons.badge_outlined,
                        size: 18,
                        color: selected ? Colors.white : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        role,
                        style: TextStyle(
                          fontFamily: fontMulishSemiBold,
                          fontSize: 14,
                          color: selected ? Colors.white : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      }).toList(),
    );
  }

  // ─────────────────────────── Agree to terms Row (Reactive) ───────────────────────────
  Widget _termsRow() {
    return Obx(() => GestureDetector(
      onTap: () => _authCtrl.agreeTerms.toggle(),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: _authCtrl.agreeTerms.value ? _orange : Colors.grey.shade400,
                  width: 1.5,
                ),
                color: _authCtrl.agreeTerms.value ? _orange : Colors.transparent,
              ),
              child: _authCtrl.agreeTerms.value
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  text: 'I agree to the ',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontFamily: fontMulishRegular,
                  ),
                  children: [
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(
                        color: _orange,
                        fontFamily: fontMulishSemiBold,
                        fontSize: 13,
                      ),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: _orange,
                        fontFamily: fontMulishSemiBold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  // ─────────────────────────── Feature Illustration Generator ────────────────────────
  Widget _featureIllustration(IconData icon, {double size = 140}) {
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
          Icon(
            icon,
            color: Colors.white,
            size: size * 0.45,
          ),
          Positioned(
            bottom: size * 0.12,
            right: size * 0.12,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: _orange,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: Colors.white,
                size: size * 0.15,
              ),
            ),
          )
        ],
      ),
    );
  }

  // ─────────────────────────── General Illustration ──────────────────────
  Widget _illustration({double size = 140}) {
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

  // ─────────────────────────── Decorative Ambient Circles ────────────────────────────────
  List<Widget> _decorCircles() => [
        _circle(top: -30, right: -30, size: 140,
            color: Colors.white.withOpacity(0.04)),
        _circle(top: 80, left: -20, size: 80,
            color: _orange.withOpacity(0.12)),
        _circle(bottom: 60, right: 20, size: 60,
            color: _green.withOpacity(0.12)),
        _circle(bottom: -20, left: 40, size: 100,
            color: Colors.white.withOpacity(0.04)),
      ];

  Widget _circle({
    double? top, double? bottom, double? left, double? right,
    required double size, required Color color,
  }) =>
      Positioned(
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

  // Clickable interactive dot indicators
  Widget _dot(bool active, {required int index}) => GestureDetector(
        onTap: () => _authCtrl.animateToPage(index),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(right: 6),
            width: active ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: active ? _orange : Colors.white38,
            ),
          ),
        ),
      );

  // ─────────────────────────── Shared Form Widgets ─────────────────────────────────
  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontFamily: fontMulishBold,
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
  }) =>
      TextField(
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

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label,
              style: TextStyle(
                  fontSize: 15, fontFamily: fontMulishSemiBold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 4,
            shadowColor: _orange.withOpacity(0.4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Widget _outlineButton({
    required String label,
    required VoidCallback onTap,
  }) =>
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: _orange, width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            foregroundColor: _orange,
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontFamily: fontMulishSemiBold,
                  color: _orange)),
        ),
      );
}
