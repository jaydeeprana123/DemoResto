import 'package:demo/core/constants/auth_constants.dart';
import 'package:demo/features/authentication/repositories/auth_repository.dart';
import 'package:demo/features/authentication/services/device_session_service.dart';
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
      final credential = await _authRepository.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final uid = credential.user?.uid;
      if (uid == null || uid.isEmpty) {
        return 'Login failed';
      }
      await Get.find<DeviceSessionService>().claimNewSession(uid);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Login failed';
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  /// First-time setup: only the designated Super Admin can create an account.
  Future<String?> createSuperAdminAccount() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      return 'Please enter email and password.';
    }
    if (email.toLowerCase() != AuthConstants.superAdminEmail.toLowerCase()) {
      return 'First-time setup is only for the Super Admin email.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    isLoading.value = true;
    try {
      final credential = await _authRepository.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid == null || uid.isEmpty) {
        return 'Account setup failed';
      }
      await Get.find<DeviceSessionService>().claimNewSession(uid);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Account setup failed';
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }
}
