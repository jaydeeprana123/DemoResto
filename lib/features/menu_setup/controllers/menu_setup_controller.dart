import 'package:demo/features/menu_setup/repositories/menu_setup_repository.dart';
import 'package:get/get.dart';

class MenuSetupController extends GetxController {
  MenuSetupController(this._menuSetupRepository);

  final MenuSetupRepository _menuSetupRepository;

  MenuSetupRepository get repository => _menuSetupRepository;
}
