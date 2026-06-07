import 'package:demo/core/models/staff_member.dart';
import 'package:demo/features/settings/repositories/staff_repository.dart';
import 'package:get/get.dart';

class StaffController extends GetxController {
  StaffController(this._repository);

  final StaffRepository _repository;

  final isLoading = false.obs;

  Stream<List<StaffMember>> watchStaff() => _repository.watchStaff();

  Future<String?> createStaff({
    required String name,
    required String email,
    required String password,
  }) async {
    if (name.trim().isEmpty) return 'Staff name is required.';
    if (email.trim().isEmpty) return 'Email is required.';
    if (password.length < 6) return 'Password must be at least 6 characters.';

    isLoading.value = true;
    try {
      await _repository.createStaff(
        name: name,
        email: email,
        password: password,
      );
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> updateStaffPassword({
    required StaffMember staff,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      return 'New password must be at least 6 characters.';
    }

    isLoading.value = true;
    try {
      await _repository.updateStaffPassword(
        staff: staff,
        newPassword: newPassword,
      );
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }
}
