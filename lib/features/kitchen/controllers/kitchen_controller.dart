import 'package:demo/features/tables/repositories/tables_repository.dart';
import 'package:get/get.dart';

class KitchenController extends GetxController {
  KitchenController(this._tablesRepository);

  final TablesRepository _tablesRepository;

  TablesRepository get tablesRepository => _tablesRepository;
}
