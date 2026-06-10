import 'package:demo/core/models/user_profile.dart';
import 'package:demo/core/repositories/user_repository.dart';
import 'package:demo/core/services/restaurant_session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class ProfileController extends GetxController {
  ProfileController(this._userRepository);

  final UserRepository _userRepository;

  final isLoading = true.obs;
  final isChangingPassword = false.obs;
  final profile = Rxn<UserProfile>();

  bool get isAdmin => profile.value?.isAdmin ?? false;

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile() async {
    isLoading.value = true;
    try {
      if (Get.isRegistered<RestaurantSession>()) {
        final sessionProfile = Get.find<RestaurantSession>().profile.value;
        if (sessionProfile != null) {
          profile.value = sessionProfile;
          return;
        }
      }

      final user = _userRepository.currentUser;
      if (user == null) {
        profile.value = null;
        return;
      }

      profile.value = await _userRepository.getUserProfile(user.uid);
    } finally {
      isLoading.value = false;
    }
  }

  String get displayName {
    final p = profile.value;
    if (p?.name != null && p!.name!.trim().isNotEmpty) {
      return p.name!.trim();
    }
    final authName = _userRepository.currentUser?.displayName?.trim();
    if (authName != null && authName.isNotEmpty) return authName;
    final email = displayEmail;
    if (email.contains('@')) return email.split('@').first;
    return 'User';
  }

  String get displayEmail {
    final p = profile.value;
    if (p?.email.isNotEmpty == true) return p!.email;
    return _userRepository.currentUser?.email ?? '';
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (!isAdmin) {
      return 'Only restaurant admin can change password here.';
    }

    if (currentPassword.isEmpty) return 'Enter your current password.';
    if (newPassword.length < 6) {
      return 'New password must be at least 6 characters.';
    }
    if (newPassword != confirmPassword) {
      return 'New passwords do not match.';
    }
    if (newPassword == currentPassword) {
      return 'New password must be different from the current password.';
    }

    isChangingPassword.value = true;
    try {
      await _userRepository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'Current password is incorrect.';
        case 'weak-password':
          return 'New password is too weak.';
        default:
          return e.message ?? 'Could not update password (${e.code}).';
      }
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      isChangingPassword.value = false;
    }
  }
}
