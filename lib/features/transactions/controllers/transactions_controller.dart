import 'package:demo/features/transactions/repositories/transactions_repository.dart';
import 'package:get/get.dart';

class TransactionsController extends GetxController {
  TransactionsController(this._transactionsRepository);

  final TransactionsRepository _transactionsRepository;

  TransactionsRepository get repository => _transactionsRepository;
}
