import 'package:demo/features/settings/repositories/admin_dashboard_repository.dart';
import 'package:get/get.dart';

class AdminDashboardController extends GetxController {
  AdminDashboardController(this._adminDashboardRepository);

  final AdminDashboardRepository _adminDashboardRepository;

  final isLoading = true.obs;
  final dashboardData = Rxn<AdminDashboardData>();

  Future<void> load() async {
    isLoading.value = true;
    try {
      dashboardData.value = await _adminDashboardRepository.load();
    } finally {
      isLoading.value = false;
    }
  }
}
