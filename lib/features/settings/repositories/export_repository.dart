import 'package:demo/features/settings/services/export_excel_service.dart';
import 'package:demo/features/settings/utils/export_date_range.dart';

class ExportRepository {
  Future<String> exportTransactions(ExportDateRange range) {
    return ExportExcelService.exportTransactions(range);
  }

  Future<String> exportExpenses(ExportDateRange range) {
    return ExportExcelService.exportExpenses(range);
  }
}
