import 'package:demo/features/tables/repositories/tables_repository.dart';
import 'package:get/get.dart';

class TablesController extends GetxController {
  TablesController(this._tablesRepository);

  final TablesRepository _tablesRepository;

  TablesRepository get repository => _tablesRepository;
}
