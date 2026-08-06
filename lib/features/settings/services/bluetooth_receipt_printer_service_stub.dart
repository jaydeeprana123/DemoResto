import 'package:smartKitchen/features/ordering/services/food_bill_pdf_service.dart';
import 'package:smartKitchen/features/settings/services/print_settings.dart';

class BluetoothPrinterDevice {
  const BluetoothPrinterDevice({
    required this.name,
    required this.macAddress,
  });

  final String name;
  final String macAddress;
}

/// No-op stub for web and desktop platforms.
class BluetoothReceiptPrinterService {
  BluetoothReceiptPrinterService._();

  static bool get isSupported => false;

  static Future<bool> ensurePermissions() async => false;

  static Future<List<BluetoothPrinterDevice>> listPairedPrinters() async =>
      const [];

  static Future<bool> connect({String? macAddress}) async => false;

  static Future<bool> isConnected() async => false;

  static Future<bool> printReceipt(
    FoodBillPdfData data, {
    PosPrinterType printerType = PosPrinterType.narrow58,
  }) async =>
      false;

  static Future<bool> printTestReceipt({
    PosPrinterType printerType = PosPrinterType.narrow58,
  }) async =>
      false;

  static Future<void> disconnect() async {}
}
