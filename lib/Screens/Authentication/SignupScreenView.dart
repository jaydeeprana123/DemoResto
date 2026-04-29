import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/Screens/Authentication/LoginScreenView.dart';
import 'package:demo/Screens/BottomNavigation/bottom_navigation_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../Styles/my_font.dart';

// ── Brand colours (same as LoginScreenView) ───────────────────────────────
const _navy   = Color(0xFF1A3A5C);
const _navyDk = Color(0xFF0D2137);
const _orange = Color(0xFFf57c35);
const _green  = Color(0xFF4CAF50);

class SignupScreenView extends StatefulWidget {
  const SignupScreenView({super.key});
  @override
  State<SignupScreenView> createState() => _SignupScreenViewState();
}

class _SignupScreenViewState extends State<SignupScreenView>
    with SingleTickerProviderStateMixin {
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _selectedRole = 'Staff';
  final List<String> _roles = ['Admin', 'Staff'];
  bool _loading        = false;
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _agreeTerms     = false;

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
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────────────────
  String? _validate() {
    if (_nameCtrl.text.trim().isEmpty) return 'Please enter your full name.';
    if (_emailCtrl.text.trim().isEmpty) return 'Please enter your email.';
    if (!_emailCtrl.text.contains('@')) return 'Please enter a valid email.';
    if (_passCtrl.text.length < 6)
      return 'Password must be at least 6 characters.';
    if (_passCtrl.text != _confirmCtrl.text) return 'Passwords do not match.';
    if (!_agreeTerms) return 'Please agree to the terms to continue.';
    return null;
  }

  Future<void> _register() async {
    final err = _validate();
    if (err != null) { _snack(err); return; }

    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      final user = cred.user;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'name': _nameCtrl.text.trim(),
          'email': user.email,
          'role': _selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BottomNavigationView()),
      );
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Signup failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: isWide ? _wideLayout() : _narrowLayout(),
    );
  }

  Widget _wideLayout() => Row(
        children: [
          Expanded(flex: 5, child: _leftPanel()),
          Expanded(flex: 6, child: _formPanel()),
        ],
      );

  Widget _narrowLayout() => SingleChildScrollView(
        child: Column(
          children: [_topBanner(), _formPanel()],
        ),
      );

  // ── Left panel (navy) ─────────────────────────────────────────────────
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Center(child: _illustration()),
                const Spacer(),
                Text(
                  'Join Flavor Flow\nToday',
                  style: TextStyle(
                    fontSize: 28,
                    fontFamily: fontMulishBold,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Set up your restaurant in minutes.\n'
                  'Manage orders, staff, tables & billing\n'
                  'all from one smart dashboard.',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: fontMulishRegular,
                    color: Colors.white70,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                // Feature bullets
                ...[
                  ('Real-time kitchen orders', Icons.kitchen_outlined),
                  ('Smart table management', Icons.table_restaurant_outlined),
                  ('Voice-based ordering', Icons.mic_outlined),
                ].map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(f.$2, color: _orange, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            f.$1,
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: fontMulishSemiBold,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 20),
                Row(children: List.generate(3, (i) => _dot(i == 1))),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBanner() => Container(
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

  // ── Form panel (white) ────────────────────────────────────────────────
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
                  // Logo
                  // Center(child: _logoWidget()),
                  // const SizedBox(height: 24),

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
                    controller: _nameCtrl,
                    hint: 'John Doe',
                    icon: Icons.person_outline_rounded,
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 16),

                  // Email
                  _label('Email Address'),
                  const SizedBox(height: 8),
                  _inputField(
                    controller: _emailCtrl,
                    hint: 'your@email.com',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // Password
                  _label('Password'),
                  const SizedBox(height: 8),
                  _inputField(
                    controller: _passCtrl,
                    hint: 'Min. 6 characters',
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
                  const SizedBox(height: 16),

                  // Confirm Password
                  _label('Confirm Password'),
                  const SizedBox(height: 8),
                  _inputField(
                    controller: _confirmCtrl,
                    hint: 'Re-enter password',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscureConfirm,
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: Colors.grey.shade500,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Role selector
                  _label('Account Role'),
                  const SizedBox(height: 8),
                  _roleSelector(),
                  const SizedBox(height: 20),

                  // Agree to terms
                  _termsRow(),
                  const SizedBox(height: 24),

                  // Create Account button
                  _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: _orange))
                      : _primaryButton(
                          label: 'Create Account',
                          icon: Icons.person_add_alt_1_rounded,
                          onTap: _register,
                        ),
                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontFamily: fontMulishRegular)),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Back to login
                  _outlineButton(
                    label: 'Already have an account? Sign In',
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    ),
                  ),
                  const SizedBox(height: 28),

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

  // ── Role selector pills ───────────────────────────────────────────────
  Widget _roleSelector() {
    return Row(
      children: _roles.map((role) {
        final selected = _selectedRole == role;
        final isAdmin  = role == 'Admin';
        final selColor = isAdmin ? _navy : _orange;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedRole = role),
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
        );
      }).toList(),
    );
  }

  // ── Agree-to-terms row ────────────────────────────────────────────────
  Widget _termsRow() {
    return GestureDetector(
      onTap: () => setState(() => _agreeTerms = !_agreeTerms),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20, height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: _agreeTerms ? _orange : Colors.grey.shade400,
                width: 1.5,
              ),
              color: _agreeTerms ? _orange : Colors.transparent,
            ),
            child: _agreeTerms
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
                  TextSpan(text: ' and '),
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
    );
  }

  // ── Logo widget ───────────────────────────────────────────────────────
  Widget _logoWidget() {
    return Container(
      width: 80, height: 80,
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
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.restaurant, size: 40, color: _orange),
        ),
      ),
    );
  }

  // ── Illustration ──────────────────────────────────────────────────────
  Widget _illustration({double size = 140}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.15), width: 1.5),
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
                    width: size * 0.18, height: size * 0.18,
                    decoration: BoxDecoration(
                        color: _orange, shape: BoxShape.circle),
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

  // ── Decorative circles ────────────────────────────────────────────────
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
        top: top, bottom: bottom, left: left, right: right,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      );

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

  // ── Shared form widgets ───────────────────────────────────────────────
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
