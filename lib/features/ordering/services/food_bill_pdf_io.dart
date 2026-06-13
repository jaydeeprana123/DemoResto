import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<String> writeReceiptPdfFile(Uint8List bytes, String fileName) async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}${Platform.pathSeparator}Flavor Flow Receipts');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final safeName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  final path = '${dir.path}${Platform.pathSeparator}$safeName';
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}

Future<void> openReceiptPdfFile(String path) async {
  if (Platform.isWindows) {
    // Use PowerShell Start-Process so the app returns to dashboard while PDF opens.
    await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        'Start-Process -FilePath ${ _psQuote(path) }',
      ],
      runInShell: true,
    );
    return;
  }
  if (Platform.isMacOS) {
    await Process.run('open', [path]);
    return;
  }
  if (Platform.isLinux) {
    await Process.run('xdg-open', [path]);
  }
}

/// Opens a WhatsApp chat for [phone] (digits with country code, e.g. 919876543210).
/// Uses the native WhatsApp app on desktop so the number is not routed via browser wa.me.
Future<bool> openWhatsAppChat(String phone, {String? text}) async {
  final textQuery =
      text != null && text.isNotEmpty ? '&text=${Uri.encodeComponent(text)}' : '';
  final deepLink = 'whatsapp://send?phone=$phone$textQuery';

  if (Platform.isWindows) {
    final psQuote = deepLink.replaceAll("'", "''");
    final deepLinkResult = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        "Start-Process '$psQuote'",
      ],
      runInShell: true,
    );
    if (deepLinkResult.exitCode == 0) return true;

    final webUrl = 'https://api.whatsapp.com/send?phone=$phone$textQuery';
    final webQuote = webUrl.replaceAll("'", "''");
    final webResult = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        "Start-Process '$webQuote'",
      ],
      runInShell: true,
    );
    return webResult.exitCode == 0;
  }

  if (Platform.isMacOS) {
    final result = await Process.run('open', [deepLink]);
    if (result.exitCode == 0) return true;
    final webUri = Uri.parse(
      'https://api.whatsapp.com/send?phone=$phone$textQuery',
    );
    return launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  if (Platform.isLinux) {
    final result = await Process.run('xdg-open', [deepLink]);
    if (result.exitCode == 0) return true;
    final webUri = Uri.parse(
      'https://api.whatsapp.com/send?phone=$phone$textQuery',
    );
    return launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  final mobileUri = Uri.parse(
    text != null && text.isNotEmpty
        ? 'https://wa.me/$phone?text=${Uri.encodeComponent(text)}'
        : 'https://wa.me/$phone',
  );
  return launchUrl(mobileUri, mode: LaunchMode.externalApplication);
}

Future<void> revealReceiptPdfInFolder(String path) async {
  if (Platform.isWindows) {
    await Process.run(
      'explorer',
      ['/select,', path.replaceAll('/', '\\')],
      runInShell: true,
    );
    return;
  }
  if (Platform.isMacOS) {
    await Process.run('open', ['-R', path]);
    return;
  }
  if (Platform.isLinux) {
    await Process.run('xdg-open', [File(path).parent.path]);
  }
}

String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";
