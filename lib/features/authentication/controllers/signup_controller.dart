import 'package:demo/features/authentication/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SignupController extends GetxController {
  SignupController(this._authRepository);

  final AuthRepository _authRepository;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final isLoading = false.obs;
  final selectedRole = 'Staff'.obs;
  final agreeTerms = false.obs;

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  String? validateSignup() {
    final name = nameController.text;
    final email = emailController.text;
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (name.trim().isEmpty) return 'Please enter your full name.';
    if (email.trim().isEmpty) return 'Please enter your email.';
    if (!email.contains('@')) return 'Please enter a valid email.';
    if (password.length < 6) return 'Password must be at least 6 characters.';
    if (password != confirmPassword) return 'Passwords do not match.';
    if (!agreeTerms.value) return 'Please agree to the terms to continue.';
    return null;
  }

  Future<String?> register() async {
    return 'Public signup is disabled. Contact Super Admin or Restaurant Admin.';
  }
}
