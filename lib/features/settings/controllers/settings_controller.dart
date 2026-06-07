import 'package:demo/core/repositories/user_repository.dart';
import 'package:demo/features/kitchen/services/kitchen_settings.dart';
import 'package:demo/features/settings/services/print_settings.dart';
import 'package:demo/features/settings/services/tax_settings_service.dart';
import 'package:get/get.dart';

class SettingsController extends GetxController {
  SettingsController(this._userRepository);

  final UserRepository _userRepository;

  final userRole = Rxn<String>();
  final isLoadingRole = true.obs;
  final kitchenShowTableAllOrders = false.obs;
  final kitchenShowServeOrderScreen = true.obs;
  final printPdfEnabled = false.obs;
  final printerType = PosPrinterType.tvs80.obs;
  final cgstPercentage = 0.0.obs;
  final sgstPercentage = 0.0.obs;
  final isSavingTaxSettings = false.obs;

  Future<void> loadUserRole() async {
    isLoadingRole.value = true;
    final user = _userRepository.currentUser;
    if (user == null) {
      userRole.value = null;
      isLoadingRole.value = false;
      return;
    }
    userRole.value = await _userRepository.getUserRole(user.uid);
    isLoadingRole.value = false;
  }

  Future<void> loadKitchenSettings() async {
    kitchenShowTableAllOrders.value =
        await KitchenSettings.getShowTableAllOrders();
    kitchenShowServeOrderScreen.value =
        await KitchenSettings.getShowServeOrderScreen();
  }

  Future<void> setKitchenShowTableAllOrders(bool value) async {
    await KitchenSettings.setShowTableAllOrders(value);
    kitchenShowTableAllOrders.value = value;
  }

  Future<void> setKitchenShowServeOrderScreen(bool value) async {
    await KitchenSettings.setShowServeOrderScreen(value);
    kitchenShowServeOrderScreen.value = value;
  }

  Future<void> loadPrintSettings() async {
    printPdfEnabled.value = await PrintSettings.getPrintPdfEnabled();
    printerType.value = await PrintSettings.getPrinterType();
  }

  Future<void> setPrintPdfEnabled(bool value) async {
    await PrintSettings.setPrintPdfEnabled(value);
    printPdfEnabled.value = value;
  }

  Future<void> setPrinterType(PosPrinterType value) async {
    await PrintSettings.setPrinterType(value);
    printerType.value = value;
  }

  Future<void> loadTaxSettings() async {
    final settings = await TaxSettingsService.load();
    cgstPercentage.value = settings.cgstPercentage;
    sgstPercentage.value = settings.sgstPercentage;
  }

  Future<bool> saveTaxSettings({
    required double cgst,
    required double sgst,
  }) async {
    if (cgst < 0 || sgst < 0 || cgst > 100 || sgst > 100) {
      return false;
    }

    isSavingTaxSettings.value = true;
    try {
      await TaxSettingsService.save(
        cgstPercentage: cgst,
        sgstPercentage: sgst,
      );
      cgstPercentage.value = cgst;
      sgstPercentage.value = sgst;
      return true;
    } finally {
      isSavingTaxSettings.value = false;
    }
  }

  Future<void> signOut() => _userRepository.signOut();

  bool get isAdmin => userRole.value == 'Admin';
}
