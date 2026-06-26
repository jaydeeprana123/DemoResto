import 'dart:typed_data';

import 'package:demo/core/models/restaurant.dart';
import 'package:demo/features/ordering/widgets/whatsapp_share_phone_dialog.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;

/// Cached restaurant header data for receipt PDFs (logo, address, phones).
class RestaurantPrintProfileService extends GetxService {
  String _name = '';
  String? _address;
  String? _mobile1;
  String? _mobile2;
  String? _logoUrl;
  String? _loadedLogoUrl;
  pw.MemoryImage? _cachedLogo;

  String get name => _name;
  String? get address => _address;
  String? get mobile1 => _mobile1;
  String? get mobile2 => _mobile2;
  String? get logoUrl => _logoUrl;
  pw.MemoryImage? get logoImage => _cachedLogo;

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

  Future<void> loadFromRestaurant(Restaurant restaurant) async {
    _name = restaurant.name;
    _address = restaurant.address;
    _mobile1 = restaurant.mobile1;
    _mobile2 = restaurant.mobile2;
    _logoUrl = restaurant.logoUrl;

    if (_logoUrl != _loadedLogoUrl) {
      _cachedLogo = null;
      _loadedLogoUrl = null;
    }

    await ensureLogoReady();
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
      _cachedLogo = pw.MemoryImage(Uint8List.fromList(bytes));
      _loadedLogoUrl = url;
    } catch (_) {
      // Receipt falls back to restaurant name when logo cannot be loaded.
    }
  }

  void clear() {
    _name = '';
    _address = null;
    _mobile1 = null;
    _mobile2 = null;
    _logoUrl = null;
    _loadedLogoUrl = null;
    _cachedLogo = null;
  }
}
