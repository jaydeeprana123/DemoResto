import 'dart:typed_data';

import 'package:demo/core/utils/platform_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:pasteboard/pasteboard.dart';

class ZomatoClipboardPasteService {
  ZomatoClipboardPasteService._();

  static bool get isSupported => supportsZomatoClipboardPaste;

  static Future<Uint8List?> readImageBytes() async {
    if (!isSupported) return null;
    try {
      return await Pasteboard.image;
    } catch (e) {
      debugPrint('[ZomatoClipboardPasteService] read failed: $e');
      return null;
    }
  }
}
