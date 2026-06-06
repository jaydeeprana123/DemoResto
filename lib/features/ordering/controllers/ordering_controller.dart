import 'package:demo/features/transactions/repositories/transactions_repository.dart';
import 'package:get/get.dart';

class OrderingController extends GetxController {
  OrderingController(this._transactionsRepository);

  final TransactionsRepository _transactionsRepository;

  TransactionsRepository get transactionsRepository => _transactionsRepository;
}
