import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/Screens/BottomNavigation/bottom_navigation_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginController extends GetxController with GetSingleTickerProviderStateMixin {
  // 1. Text Controllers for user input
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  // 2. Reactive State Variables (Observables)
  // By adding '.obs', these variables become reactive.
  // When their value changes, any widget wrapped in Obx() will automatically rebuild.
  var loading = false.obs;
  var obscurePass = true.obs;
  var rememberMe = false.obs;

  // 3. Animation Controllers
  // GetSingleTickerProviderStateMixin replaces the standard SingleTickerProviderStateMixin 
  // used in StatefulWidgets, allowing us to handle animations completely inside the controller.
  late AnimationController animCtrl;
  late Animation<double> fadeAnim;
  late Animation<Offset> slideAnim;

  /// Initializes the controller.
  /// Sets up the animation controller and defines the fade and slide animations
  /// that are used when the login screen first loads.
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

  /// Disposes of the animation and text controllers to free up memory
  /// when the login screen is removed from the widget tree.
  @override
  void onClose() {
    animCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    super.onClose();
  }

  // Helper methods to update state
  // Notice we don't need setState() anymore. We just update the .value of the observable.
  /// Toggles the visibility state of the password text field.
  void toggleObscure() {
    obscurePass.value = !obscurePass.value;
  }

  /// Toggles the "Remember me" checkbox state.
  void toggleRememberMe() {
    rememberMe.value = !rememberMe.value;
  }

  /// Handles the login process.
  /// Validates the input fields, displays a loading spinner, and attempts to
  /// sign in the user via Firebase Authentication. On success, navigates to
  /// the main dashboard. On failure, displays an error snackbar.
  Future<void> login() async {
    if (emailCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
      // Get.snackbar allows us to show beautiful alerts without needing BuildContext!
      Get.snackbar(
        'Error',
        'Please enter email and password.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }
    
    // Set loading to true (triggers UI to show spinner)
    loading.value = true;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );
      
      // Get.offAll() clears the entire navigation stack and navigates to the new page.
      // This is exactly like Navigator.pushAndRemoveUntil, but much simpler!
      Get.offAll(() => const BottomNavigationView());
    } on FirebaseAuthException catch (e) {
      Get.snackbar(
        'Login failed',
        e.message ?? 'Unknown error',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      // Set loading to false (triggers UI to hide spinner)
      loading.value = false;
    }
  }

  /// Displays a snackbar message notifying the user that a password reset
  /// email has been sent (mock functionality for UI purposes).
  void showResetPasswordMsg() {
    Get.snackbar(
      'Info',
      'Reset email sent (if exists).',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.blueAccent,
      colorText: Colors.white,
    );
  }
}
