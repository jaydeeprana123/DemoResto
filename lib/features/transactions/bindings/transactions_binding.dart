import 'package:smartKitchen/features/transactions/controllers/transactions_controller.dart';
import 'package:smartKitchen/features/transactions/repositories/transactions_repository.dart';
import 'package:get/get.dart';

class TransactionsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TransactionsRepository>(
      () => TransactionsRepository(),
      fenix: true,
    );
    Get.lazyPut<TransactionsController>(
      () => TransactionsController(Get.find<TransactionsRepository>()),
      fenix: true,
    );
  }
}
