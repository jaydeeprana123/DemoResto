import 'dart:typed_data';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

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
