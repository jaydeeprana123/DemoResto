class SslErrorUtils {
  SslErrorUtils._();

  static bool isCertificateVerifyFailed(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('certificate_verify_failed') ||
        message.contains('unable to get local issuer certificate') ||
        message.contains('handshakeexception');
  }

  static String userMessage(Object error) {
    if (!isCertificateVerifyFailed(error)) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return 'Secure connection failed on this PC (SSL certificate trust issue). '
        'Restart the app after updating Windows, or run Windows Update to refresh '
        'root certificates. If this laptop is on office Wi‑Fi, try another network.';
  }
}
