import 'package:flutter/foundation.dart';

bool get isDesktopPlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

/// Wide menu + side cart layout (web and desktop).
bool get useWideMenuLayout => kIsWeb || isDesktopPlatform;

/// Dashboard Ctrl+V Zomato screenshot paste (web and desktop only).
bool get supportsZomatoClipboardPaste => kIsWeb || isDesktopPlatform;
