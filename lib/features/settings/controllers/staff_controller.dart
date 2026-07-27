import 'package:demo/core/models/staff_member.dart';
import 'package:demo/features/settings/repositories/staff_repository.dart';
import 'package:get/get.dart';

class StaffController extends GetxController {
  StaffController(this._repository);

  final StaffRepository _repository;

  final isLoading = false.obs;

  Stream<List<StaffMember>> watchStaff() => _repository.watchStaff();

  Stream<List<StaffMember>> watchRestaurantUsers() =>
      _repository.watchRestaurantUsers();

  Future<String?> setAllowMarkAsDelivered({
    required StaffMember member,
    required bool allow,
  }) async {
    try {
      await _repository.setAllowMarkAsDelivered(
        uid: member.uid,
        allow: allow,
      );
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

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

  Future<String?> sendPasswordResetEmail({required StaffMember staff}) async {
    isLoading.value = true;
    try {
      await _repository.sendPasswordResetEmail(staff: staff);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> deleteStaff({required StaffMember staff}) async {
    isLoading.value = true;
    try {
      await _repository.deleteStaff(staff: staff);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }
}
