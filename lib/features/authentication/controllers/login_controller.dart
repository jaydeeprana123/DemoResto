import 'package:demo/features/authentication/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginController extends GetxController {
  LoginController(this._authRepository);

  final AuthRepository _authRepository;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final isLoading = false.obs;

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  Future<String?> login() async {
    final email = emailController.text;
    final password = passwordController.text;

    if (email.trim().isEmpty || password.trim().isEmpty) {
      return 'Please enter email and password.';
    }

    isLoading.value = true;
    try {
      await _authRepository.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Login failed';
    } finally {
      isLoading.value = false;
    }
  }

  /// Preserves the unused login-screen register helper for parity.
  Future<String?> register() async {
    final email = emailController.text;
    final password = passwordController.text;

    isLoading.value = true;
    try {
      final cred = await _authRepository.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final user = cred.user;
      if (user != null) {
        await _authRepository.createStaffUserDocument(user);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Signup failed';
    } finally {
      isLoading.value = false;
    }
  }
}
