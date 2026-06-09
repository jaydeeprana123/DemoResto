import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

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

String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";
