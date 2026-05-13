import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/Screens/BottomNavigation/bottom_navigation_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SignupController extends GetxController with GetSingleTickerProviderStateMixin {
  // ── Text Controllers for user input ──
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  // ── Observables (Reactive variables) ──
  // These update the UI instantly when changed inside Obx()
  var loading = false.obs;
  var obscurePass = true.obs;
  var obscureConfirm = true.obs;
  var agreeTerms = false.obs;
  var selectedRole = 'Staff'.obs;
  
  final List<String> roles = ['Admin', 'Staff'];

  // ── Animations ──
  late AnimationController animCtrl;
  late Animation<double> fadeAnim;
  late Animation<Offset> slideAnim;

  /// Runs automatically when the controller is created.
  /// Sets up the fade and slide animations for the signup form.
  @override
  void onInit() {
    super.onInit();
    animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    fadeAnim = CurvedAnimation(parent: animCtrl, curve: Curves.easeOut);
    slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animCtrl, curve: Curves.easeOut));

    animCtrl.forward();
  }

  /// Runs when the controller is destroyed (page is closed).
  /// Clears out memory to prevent app slowdowns.
  @override
  void onClose() {
    animCtrl.dispose();
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
    super.onClose();
  }

  /// Toggles whether the password is shown as dots or readable text.
  void toggleObscurePass() {
    obscurePass.value = !obscurePass.value;
  }

  /// Toggles whether the confirm password is shown as dots or readable text.
  void toggleObscureConfirm() {
    obscureConfirm.value = !obscureConfirm.value;
  }

  /// Toggles the "I agree to Terms" checkbox.
  void toggleTerms() {
    agreeTerms.value = !agreeTerms.value;
  }

  /// Selects the user's role (Admin or Staff).
  void selectRole(String role) {
    selectedRole.value = role;
  }

  /// Checks if all input fields are filled correctly before signing up.
  /// Returns an error message if something is wrong, or null if everything is okay.
  String? validateForm() {
    if (nameCtrl.text.trim().isEmpty) return 'Please enter your full name.';
    if (emailCtrl.text.trim().isEmpty) return 'Please enter your email.';
    if (!emailCtrl.text.contains('@')) return 'Please enter a valid email.';
    if (passCtrl.text.length < 6) return 'Password must be at least 6 characters.';
    if (passCtrl.text != confirmCtrl.text) return 'Passwords do not match.';
    if (!agreeTerms.value) return 'Please agree to the terms to continue.';
    return null;
  }

  /// Attempts to create a new user account in Firebase.
  /// Shows loading spinner, validates inputs, and saves user data in Firestore.
  Future<void> register() async {
    final errorMsg = validateForm();
    if (errorMsg != null) {
      Get.snackbar('Oops!', errorMsg, snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    // Show loading spinner
    loading.value = true;
    
    try {
      // 1. Create account in Firebase Auth
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );
      
      final user = cred.user;
      if (user != null) {
        // 2. Save user details in Firestore Database
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': nameCtrl.text.trim(),
          'email': user.email,
          'role': selectedRole.value,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      // 3. Move to the Dashboard
      Get.offAll(() => const BottomNavigationView());
      
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Signup failed', e.message ?? 'Unknown error', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      // Hide loading spinner
      loading.value = false;
    }
  }
}
