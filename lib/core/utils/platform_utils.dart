import 'dart:ui';

import 'package:flutter/foundation.dart';

bool get isDesktopPlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

/// Wide menu + side cart layout (desktop web and desktop apps only).
bool useWideMenuLayoutFor(Size size) {
  if (isDesktopPlatform) return true;
  if (kIsWeb) return size.shortestSide >= 600;
  return false;
}

/// Prefer [useWideMenuLayoutFor] when [BuildContext] / [Size] is available.
bool get useWideMenuLayout => isDesktopPlatform;

/// Dashboard Ctrl+V Zomato screenshot paste (web and desktop only).
bool get supportsZomatoClipboardPaste => kIsWeb || isDesktopPlatform;
