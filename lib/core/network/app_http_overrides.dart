import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// On some Windows laptops the system root CA store is incomplete, which causes
/// `CERTIFICATE_VERIFY_FAILED` for ImageKit, Gemini, and other HTTPS calls.
/// We augment Dart's trust store with bundled public root certificates.
class AppHttpOverrides extends HttpOverrides {
  AppHttpOverrides(this._securityContext);

  final SecurityContext _securityContext;

  static const _bundledCertAssets = [
    'assets/certs/isrg-root-x1.pem',
    'assets/certs/amazon-root-ca-1.pem',
    'assets/certs/digicert-global-root-g2.pem',
  ];

  static Future<void> installIfNeeded() async {
    if (kIsWeb || !Platform.isWindows) return;
    if (HttpOverrides.current is AppHttpOverrides) return;

    final context = SecurityContext(withTrustedRoots: true);
    for (final assetPath in _bundledCertAssets) {
      try {
        final data = await rootBundle.load(assetPath);
        context.setTrustedCertificatesBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      } catch (e) {
        debugPrint('[AppHttpOverrides] Could not load $assetPath: $e');
      }
    }

    HttpOverrides.global = AppHttpOverrides(context);
    debugPrint('[AppHttpOverrides] Installed bundled root certificates.');
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(_securityContext);
  }
}
