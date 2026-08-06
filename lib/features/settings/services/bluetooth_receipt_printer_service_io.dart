import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:smartKitchen/features/ordering/services/food_bill_pdf_service.dart';
import 'package:smartKitchen/features/settings/services/esc_pos_receipt_builder.dart';
import 'package:smartKitchen/features/settings/services/print_settings.dart';

class BluetoothPrinterDevice {
  const BluetoothPrinterDevice({
    required this.name,
    required this.macAddress,
  });

  final String name;
  final String macAddress;
}

class BluetoothReceiptPrinterService {
  BluetoothReceiptPrinterService._();

  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static Future<bool> ensurePermissions() async {
    if (!isSupported) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      await PrintBluetoothThermal.isPermissionBluetoothGranted;
    }

    return PrintBluetoothThermal.bluetoothEnabled;
  }

  static Future<List<BluetoothPrinterDevice>> listPairedPrinters() async {
    if (!isSupported) return const [];
    if (!await ensurePermissions()) return const [];

    final devices = await PrintBluetoothThermal.pairedBluetooths;
    return devices
        .map(
          (device) => BluetoothPrinterDevice(
            name: device.name,
            macAddress: device.macAdress,
          ),
        )
        .where((device) => device.macAddress.trim().isNotEmpty)
        .toList();
  }

  static Future<bool> connect({String? macAddress}) async {
    if (!isSupported) return false;

    final targetMac = (macAddress ?? PrintSettings.bluetoothMacAddress)?.trim();
    if (targetMac == null || targetMac.isEmpty) return false;
    if (!await ensurePermissions()) return false;

    if (await PrintBluetoothThermal.connectionStatus) {
      return true;
    }

    return PrintBluetoothThermal.connect(macPrinterAddress: targetMac);
  }

  static Future<bool> isConnected() async {
    if (!isSupported) return false;
    return PrintBluetoothThermal.connectionStatus;
  }

  static Future<bool> printReceipt(
    FoodBillPdfData data, {
    PosPrinterType printerType = PosPrinterType.narrow58,
  }) async {
    if (!isSupported) return false;

    final connected = await connect();
    if (!connected) return false;

    final bytes = await EscPosReceiptBuilder.buildReceiptBytes(
      data,
      printerType: printerType,
    );
    return PrintBluetoothThermal.writeBytes(bytes);
  }

  static Future<bool> printTestReceipt({
    PosPrinterType printerType = PosPrinterType.narrow58,
  }) async {
    if (!isSupported) return false;

    final connected = await connect();
    if (!connected) return false;

    final bytes = await EscPosReceiptBuilder.buildTestReceiptBytes(
      printerType: printerType,
    );
    return PrintBluetoothThermal.writeBytes(bytes);
  }

  static Future<void> disconnect() async {
    if (!isSupported) return;
    if (await PrintBluetoothThermal.connectionStatus) {
      await PrintBluetoothThermal.disconnect;
    }
  }
}
