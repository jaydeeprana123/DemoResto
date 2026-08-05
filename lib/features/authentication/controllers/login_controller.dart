import 'package:smartKitchen/features/authentication/repositories/auth_repository.dart';
import 'package:smartKitchen/features/authentication/services/device_session_service.dart';
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
}
