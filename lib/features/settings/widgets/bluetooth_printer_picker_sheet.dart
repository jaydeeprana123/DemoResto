import 'package:smartKitchen/Styles/my_font.dart';
import 'package:smartKitchen/features/settings/services/bluetooth_receipt_printer_service.dart';
import 'package:smartKitchen/features/settings/services/print_settings.dart';
import 'package:flutter/material.dart';

const _navy = Color(0xFF1A3A5C);

class BluetoothPrinterPickerSheet extends StatefulWidget {
  const BluetoothPrinterPickerSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final selected = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const BluetoothPrinterPickerSheet(),
    );
    return selected == true;
  }

  @override
  State<BluetoothPrinterPickerSheet> createState() =>
      _BluetoothPrinterPickerSheetState();
}

class _BluetoothPrinterPickerSheetState extends State<BluetoothPrinterPickerSheet> {
  bool _loading = true;
  String? _error;
  List<BluetoothPrinterDevice> _devices = const [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final granted = await BluetoothReceiptPrinterService.ensurePermissions();
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error =
              'Turn on Bluetooth and allow Bluetooth permission, then pair your printer in phone settings.';
        });
        return;
      }

      final devices = await BluetoothReceiptPrinterService.listPairedPrinters();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _devices = devices;
        if (devices.isEmpty) {
          _error =
              'No paired printers found. Pair your PeriPeri printer in Bluetooth settings first.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load Bluetooth printers: $e';
      });
    }
  }

  Future<void> _selectPrinter(BluetoothPrinterDevice device) async {
    await PrintSettings.setBluetoothPrinter(
      name: device.name,
      macAddress: device.macAddress,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final savedMac = PrintSettings.bluetoothMacAddress;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Bluetooth printer',
              style: TextStyle(
                fontFamily: fontMulishBold,
                fontSize: 18,
                color: _navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pair your printer in phone Bluetooth settings, then choose it here.',
              style: TextStyle(
                fontFamily: fontMulishRegular,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontFamily: fontMulishRegular,
                    fontSize: 14,
                    color: Colors.red,
                  ),
                ),
              )
            else
              ..._devices.map((device) {
                final isSelected = device.macAddress == savedMac;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.print_rounded,
                    color: isSelected ? _navy : Colors.grey.shade600,
                  ),
                  title: Text(
                    device.name,
                    style: TextStyle(
                      fontFamily: fontMulishSemiBold,
                      color: isSelected ? _navy : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    device.macAddress,
                    style: TextStyle(
                      fontFamily: fontMulishRegular,
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: _navy)
                      : null,
                  onTap: () => _selectPrinter(device),
                );
              }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loading ? null : _loadDevices,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'Refresh list',
                style: TextStyle(fontFamily: fontMulishSemiBold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
