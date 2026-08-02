import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

const exportXlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Opens a save dialog for a CSV file.
/// Returns the saved file path, or null if the user cancelled.
Future<String?> saveExportCsvWithDialog(
  Uint8List bytes,
  String fileName,
) async {
  const csvType = XTypeGroup(
    label: 'CSV',
    extensions: ['csv'],
    mimeTypes: ['text/csv'],
  );

  final location = await getSaveLocation(
    suggestedName: _safeFileName(fileName),
    acceptedTypeGroups: [csvType],
  );
  if (location == null) return null;

  final file = File(location.path);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// Opens a save dialog and writes the Excel bytes to the chosen path.
/// Returns the saved file path, or null if the user cancelled.
Future<String?> saveExportExcelWithDialog(
  Uint8List bytes,
  String fileName,
) async {
  const xlsxType = XTypeGroup(
    label: 'Excel',
    extensions: ['xlsx'],
    mimeTypes: [exportXlsxMime],
  );

  final location = await getSaveLocation(
    suggestedName: _safeFileName(fileName),
    acceptedTypeGroups: [xlsxType],
  );
  if (location == null) return null;

  final file = File(location.path);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String> writeExportExcelToDocuments(
  Uint8List bytes,
  String fileName,
) async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory(
    '${base.path}${Platform.pathSeparator}Smart Kitchen Exports',
  );
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final safeName = _safeFileName(fileName);
  final path = '${dir.path}${Platform.pathSeparator}$safeName';
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}

Future<void> openExportExcelFile(String path) async {
  if (Platform.isWindows) {
    await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        'Start-Process -FilePath ${_psQuote(path)}',
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

Future<String> writeExportExcelTempFile(
  Uint8List bytes,
  String fileName,
) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}${Platform.pathSeparator}${_safeFileName(fileName)}';
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}

Future<void> revealExportExcelInFolder(String path) async {
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

String _safeFileName(String fileName) {
  return fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
}

String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";
