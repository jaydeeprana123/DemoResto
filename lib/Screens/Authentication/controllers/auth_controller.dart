import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:demo/Screens/Authentication/repositories/auth_repository.dart';
import 'package:demo/Screens/BottomNavigation/bottom_navigation_view.dart';

/// AuthController
/// 
/// Part of the GetX Repository Pattern.
/// This controller handles all UI states, form validations, text field controllers,
/// PageView navigation, and orchestrates actions by calling the [AuthRepository].
/// Observables are marked with `.obs` so that the UI can automatically rebuild using [Obx].
class AuthController extends GetxController {
  // Inject/instantiate the repository.
  final AuthRepository _authRepo = AuthRepository();

  // ── Text Controllers ───────────────────────────────────────────────────────
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();

  // ── Reactive UI States (.obs) ──────────────────────────────────────────────
  final isLoading = false.obs;
  final obscurePass = true.obs;
  final obscureConfirmPass = true.obs;
  final rememberMe = false.obs;
  final agreeTerms = false.obs;
  final selectedRole = 'Staff'.obs; // Default role
  
  // Available user roles
  final List<String> roles = ['Admin', 'Staff'];

  // ── PageView Controller and Sliding Logic ──────────────────────────────────
  late PageController pageController;
  final pageViewIndex = 0.obs;
  Timer? _pageTimer;
  final int totalPages = 3;

  @override
  void onInit() {
    super.onInit();
    pageController = PageController(initialPage: 0);
    _startAutoSlide();
  }

  @override
  void onClose() {
    _pageTimer?.cancel();
    pageController.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    nameCtrl.dispose();
    confirmPassCtrl.dispose();
    super.onClose();
  }

  /// Automatically changes the page in the left banner/panel PageView every 4 seconds.
  void _startAutoSlide() {
    _pageTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (pageController.hasClients) {
        int nextPage = pageViewIndex.value + 1;
        if (nextPage >= totalPages) {
          nextPage = 0;
        }
        animateToPage(nextPage);
      }
    });
  }

  /// Interactive navigation to a specific slide from dot indicators or gesture.
  void animateToPage(int page) {
    pageViewIndex.value = page;
    pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  /// Track manual swipe/scroll on the PageView.
  void onPageChanged(int index) {
    pageViewIndex.value = index;
  }

  // ── Business Actions & Methods ─────────────────────────────────────────────

  /// Helper to trigger feedback Snackbars in a highly robust way.
  /// Uses ScaffoldMessenger which is 100% immune to "No Overlay widget found" crashes.
  void showSnackbar(String title, String message, {bool isError = true}) {
    final context = Get.context;
    if (context != null) {
      // Instantly dismiss any active snackbars so new feedback is immediate
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          backgroundColor: isError ? const Color(0xFFE57373) : const Color(0xFF81C784),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      // Graceful console fallback in case view context is not yet fully mounted
      debugPrint('[AuthController] Snackbar: [$title] - $message');
    }
  }

  /// Log in a user.
  /// Calls the Repository to authenticate and then handles routing.
  Future<void> loginUser() async {
    final email = emailCtrl.text.trim();
    final password = passCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showSnackbar('Validation Error', 'Please enter your email and password.');
      return;
    }

    isLoading.value = true;
    try {
      // Direct data query delegating to Repository
      await _authRepo.signInWithEmailAndPassword(email, password);
      
      // Clear inputs upon success
      emailCtrl.clear();
      passCtrl.clear();

      // GetX smooth routing to dashboard
      Get.offAll(() => const BottomNavigationView());
    } catch (e) {
      showSnackbar('Login Failed', e.toString().replaceAll('Exception: ', ''));
    } finally {
      isLoading.value = false;
    }
  }

  /// Register/Sign up a new user.
  /// Validates all parameters, registers user with Firebase Auth, and creates their profile doc in Firestore.
  Future<void> registerUser() async {
    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final password = passCtrl.text.trim();
    final confirmPass = confirmPassCtrl.text.trim();

    // Custom extracted validation method
    final validationError = _validateRegistration(name, email, password, confirmPass);
    if (validationError != null) {
      showSnackbar('Validation Error', validationError);
      return;
    }

    isLoading.value = true;
    try {
      // 1. Create auth account in Firebase Auth
      final credential = await _authRepo.signUpWithEmailAndPassword(email, password);
      final user = credential.user;

      if (user != null) {
        // 2. Create the corresponding profile record in Firestore users collection
        await _authRepo.createUserProfile(
          uid: user.uid,
          email: email,
          role: selectedRole.value,
          name: name,
        );
      }

      // Clear input fields
      nameCtrl.clear();
      emailCtrl.clear();
      passCtrl.clear();
      confirmPassCtrl.clear();
      agreeTerms.value = false;

      // Navigate to the main application
      Get.offAll(() => const BottomNavigationView());
    } catch (e) {
      showSnackbar('Registration Failed', e.toString().replaceAll('Exception: ', ''));
    } finally {
      isLoading.value = false;
    }
  }

  /// Form Validation logic extracted to keep code clean and readable.
  String? _validateRegistration(String name, String email, String password, String confirmPass) {
    if (name.isEmpty) {
      return 'Please enter your full name.';
    }
    if (email.isEmpty) {
      return 'Please enter your email.';
    }
    if (!GetUtils.isEmail(email)) {
      return 'Please enter a valid email address.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    if (password != confirmPass) {
      return 'Passwords do not match.';
    }
    if (!agreeTerms.value) {
      return 'You must agree to the Terms of Service and Privacy Policy.';
    }
    return null;
  }
}
