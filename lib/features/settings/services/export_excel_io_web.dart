import 'dart:typed_data';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

const exportXlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

Future<String?> saveExportExcelWithDialog(
  Uint8List bytes,
  String fileName,
) async {
  final safeName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  final blob = html.Blob([bytes], exportXlsxMime);
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

Future<String> writeExportExcelToDocuments(
  Uint8List bytes,
  String fileName,
) =>
    saveExportExcelWithDialog(bytes, fileName).then(
      (name) => name ?? fileName,
    );

Future<String> writeExportExcelTempFile(
  Uint8List bytes,
  String fileName,
) async =>
    saveExportExcelWithDialog(bytes, fileName).then(
      (name) => name ?? fileName,
    );

Future<void> openExportExcelFile(String path) async {}

Future<void> revealExportExcelInFolder(String path) async {}
