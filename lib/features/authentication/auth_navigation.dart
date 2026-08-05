import 'package:smartKitchen/features/authentication/views/auth_gate_view.dart';
import 'package:smartKitchen/features/authentication/views/login_screen_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Replaces the GetX stack with the post-login shell after Firebase auth succeeds.
void openAuthenticatedApp() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  Get.offAll(() => AuthGateView(key: ValueKey(user.uid)));
}

/// Replaces the GetX stack with the login screen after sign-out.
///
/// Required because [openAuthenticatedApp] makes the dashboard the GetX root;
/// popping routes alone does not return to login.
void openLoginPage() {
  Get.offAll(() => const LoginPage(key: ValueKey('login')));
}
