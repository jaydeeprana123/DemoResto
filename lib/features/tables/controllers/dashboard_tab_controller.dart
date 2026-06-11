import 'package:get/get.dart';

class DashboardTabController extends GetxController {
  final externalTabRequest = Rxn<String>();

  void requestTab(String tab) => externalTabRequest.value = tab;

  void clearRequest() => externalTabRequest.value = null;
}
