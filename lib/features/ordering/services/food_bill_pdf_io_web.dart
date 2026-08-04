import 'dart:typed_data';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:url_launcher/url_launcher.dart';

bool get _isWindowsBrowser {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return ua.contains('windows');
}

Future<String> writeReceiptPdfFile(Uint8List bytes, String fileName) async {
  final safeName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..style.display = 'none'
    ..download = safeName;

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return safeName;
}

Future<void> openReceiptPdfFile(String path) async {}

/// Opens WhatsApp Desktop via the registered whatsapp:// protocol.
Future<bool> openWhatsAppChat(String phone, {String? text}) async {
  final textQuery =
      text != null && text.isNotEmpty ? '&text=${Uri.encodeComponent(text)}' : '';
  final deepLink = 'whatsapp://send?phone=$phone$textQuery';
  final deepUri = Uri.parse(deepLink);

  try {
    if (await canLaunchUrl(deepUri)) {
      final launched = await launchUrl(
        deepUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;
    }
  } catch (_) {}

  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = deepLink
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();

  await Future<void>.delayed(const Duration(milliseconds: 300));
  return true;
}

Future<bool> _launchCustomProtocol(String link) async {
  try {
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) return true;
    }
  } catch (_) {}

  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = link
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  return true;
}

/// Uses the installed Smart Kitchen desktop app (smartkitchen://) to select the
/// downloaded PDF in Explorer. Retries while the browser finishes downloading.
Future<bool> _revealViaSmartKitchenDesktop(String fileName) async {
  final encodedName = Uri.encodeComponent(fileName);
  final link = 'smartkitchen://reveal-pdf?name=$encodedName';
  return _launchCustomProtocol(link);
}

/// Uses the installed Smart Kitchen desktop app (smartkitchen://) to select the
/// downloaded PDF in Explorer. Retries while the browser finishes downloading.
Future<bool> printPdfToNamedPrinterWindows({
  required String pdfPath,
  required String printerName,
}) async =>
    false;

Future<void> revealReceiptPdfInFolder(String fileName) async {
  if (!_isWindowsBrowser) return;

  const retryDelaysMs = [500, 1500, 3000];
  for (final delayMs in retryDelaysMs) {
    await Future<void>.delayed(Duration(milliseconds: delayMs));
    await _revealViaSmartKitchenDesktop(fileName);
  }
}
