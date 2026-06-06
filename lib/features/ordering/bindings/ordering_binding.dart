import 'package:demo/features/ordering/controllers/ordering_controller.dart';
import 'package:demo/features/transactions/repositories/transactions_repository.dart';
import 'package:get/get.dart';

class OrderingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<OrderingController>(
      () => OrderingController(Get.find<TransactionsRepository>()),
      fenix: true,
    );
  }
}
