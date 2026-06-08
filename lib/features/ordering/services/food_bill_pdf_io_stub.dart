import 'dart:typed_data';

Future<String> writeReceiptPdfFile(Uint8List bytes, String fileName) async {
  throw UnsupportedError('Receipt PDF file IO is unavailable on this platform.');
}

Future<void> openReceiptPdfFile(String path) async {}
