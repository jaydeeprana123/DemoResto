import 'package:demo/features/settings/repositories/expenses_repository.dart';
import 'package:get/get.dart';

class ExpensesController extends GetxController {
  ExpensesController(this._expensesRepository);

  final ExpensesRepository _expensesRepository;

  ExpensesRepository get repository => _expensesRepository;
}
