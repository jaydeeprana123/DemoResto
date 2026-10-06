import 'dart:typed_data';

import 'package:smartKitchen/core/models/restaurant.dart';
import 'package:smartKitchen/features/ordering/widgets/whatsapp_share_phone_dialog.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;

/// Cached restaurant header data for receipt PDFs (logo, address, phones).
class RestaurantPrintProfileService extends GetxService {
  String _name = '';
  String? _address;
  String? _mobile1;
  String? _mobile2;
  String? _mobile3;
  String? _logoUrl;
  String? _loadedLogoUrl;
  Uint8List? _logoBytes;
  pw.MemoryImage? _cachedLogo;
  String? _qrCodeUrl;
  String? _loadedQrCodeUrl;
  Uint8List? _qrCodeBytes;
  pw.MemoryImage? _cachedQrCode;

  String get name => _name;
  String? get address => _address;
  String? get mobile1 => _mobile1;
  String? get mobile2 => _mobile2;
  String? get mobile3 => _mobile3;
  String? get logoUrl => _logoUrl;
  Uint8List? get logoBytes => _logoBytes;
  pw.MemoryImage? get logoImage => _cachedLogo;
  String? get qrCodeUrl => _qrCodeUrl;
  Uint8List? get qrCodeBytes => _qrCodeBytes;
  pw.MemoryImage? get qrCodeImage => _cachedQrCode;

  String? get displayMobile1 {
    final value = _mobile1?.trim();
    if (value == null || value.isEmpty) return null;
    return WhatsAppSharePhoneDialog.formatForDisplay(value);
  }

  String? get displayMobile2 {
    final value = _mobile2?.trim();
    if (value == null || value.isEmpty) return null;
    return WhatsAppSharePhoneDialog.formatForDisplay(value);
  }

  String? get displayMobile3 {
    final value = _mobile3?.trim();
    if (value == null || value.isEmpty) return null;
    return WhatsAppSharePhoneDialog.formatForDisplay(value);
  }

  /// Formatted mobile numbers for receipt headers, comma-separated on one line.
  String get displayMobilesLine {
    final phones = [
      displayMobile1,
      displayMobile2,
      displayMobile3,
    ].whereType<String>().where((phone) => phone.isNotEmpty).toList();
    return phones.join(', ');
  }

  Future<void> loadFromRestaurant(Restaurant restaurant) async {
    _name = restaurant.name;
    _address = restaurant.address;
    _mobile1 = restaurant.mobile1;
    _mobile2 = restaurant.mobile2;
    _mobile3 = restaurant.mobile3;
    _logoUrl = restaurant.logoUrl;
    _qrCodeUrl = restaurant.qrCodeUrl;

    if (_logoUrl != _loadedLogoUrl) {
      _cachedLogo = null;
      _logoBytes = null;
      _loadedLogoUrl = null;
    }
    if (_qrCodeUrl != _loadedQrCodeUrl) {
      _cachedQrCode = null;
      _qrCodeBytes = null;
      _loadedQrCodeUrl = null;
    }

    await ensureLogoReady();
    await ensureQrCodeReady();
  }

  Future<void> ensureLogoReady() async {
    final url = _logoUrl?.trim();
    if (url == null || url.isEmpty) return;
    if (_cachedLogo != null && _loadedLogoUrl == url) return;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) return;
      _logoBytes = Uint8List.fromList(bytes);
      _cachedLogo = pw.MemoryImage(_logoBytes!);
      _loadedLogoUrl = url;
    } catch (_) {
      // Receipt falls back to restaurant name when logo cannot be loaded.
    }
  }

  Future<void> ensureQrCodeReady() async {
    final url = _qrCodeUrl?.trim();
    if (url == null || url.isEmpty) return;
    if (_cachedQrCode != null && _loadedQrCodeUrl == url) return;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) return;
      _qrCodeBytes = Uint8List.fromList(bytes);
      _cachedQrCode = pw.MemoryImage(_qrCodeBytes!);
      _loadedQrCodeUrl = url;
    } catch (_) {
      // Physical bills print without a QR when the image cannot be loaded.
    }
  }

  void clear() {
    _name = '';
    _address = null;
    _mobile1 = null;
    _mobile2 = null;
    _mobile3 = null;
    _logoUrl = null;
    _loadedLogoUrl = null;
    _logoBytes = null;
    _cachedLogo = null;
    _qrCodeUrl = null;
    _loadedQrCodeUrl = null;
    _qrCodeBytes = null;
    _cachedQrCode = null;
  }
}
