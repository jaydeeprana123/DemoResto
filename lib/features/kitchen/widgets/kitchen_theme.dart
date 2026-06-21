import 'package:flutter/material.dart';

/// KDS-inspired palette shared across kitchen screens.
abstract final class KitchenTheme {
  // Reference palette: red = Zomato, yellow/green/blue rotate for other orders.
  static const bg = Color(0xFF1E272E);
  static const surface = Color(0xFF242D34);
  static const surfaceElevated = Color(0xFF2C3E50);
  static const surfaceBorder = Color(0xFF3D4F61);

  static const cardBody = Color(0xFFFFFFFF);

  static const zomatoRed = Color(0xFFE84C3D);
  static const kdsYellow = Color(0xFFF4C430);
  static const kdsGreen = Color(0xFF4CAF50);
  static const kdsBlue = Color(0xFF3498DB);

  static const orange = Color(0xFFf57c35);

  /// Non-Zomato header colors — red is never included here.
  static const orderHeaderPalette = [kdsYellow, kdsGreen, kdsBlue];

  static const accent = kdsBlue;
  static const accentMuted = Color(0xFF94A3B8);
  static const textOnDark = Color(0xFFFFFFFF);
  static const textOnDarkMuted = Color(0xB3FFFFFF);
  static const textOnLight = Color(0xFF212121);

  static const delayedBarBg = Color(0xFFFFF9E6);
  static const delayedBarBlink = Color(0xFFFFF3C4);
  static const delayedText = Color(0xFFB8860B);
  static const delayedIcon = kdsYellow;

  static const servedGreen = kdsGreen;

  static const filterBannerBg = Color(0xFF3D3520);
  static const filterBannerIcon = kdsYellow;
  static const filterBannerText = Color(0xFFFCD34D);

  static const sheetBg = Color(0xFF2A3441);
  static const sheetHeaderBg = Color(0xFF323F4E);

  /// Stable pseudo-random header color per order/item key.
  /// Red is reserved for Zomato; delayed orders use yellow (process).
  static Color headerForOrderKey(
    String key, {
    required bool isZomato,
    bool isDelayed = false,
  }) {
    if (isZomato) return zomatoRed;
    if (isDelayed) return kdsYellow;
    final index = key.hashCode.abs() % orderHeaderPalette.length;
    return orderHeaderPalette[index];
  }

  /// Kitchen order card header: table = blue, take-away = green, Zomato = red.
  static Color headerForOrderTable(
    String tableName, {
    required bool isZomato,
    bool isDelayed = false,
  }) {
    if (isZomato) return zomatoRed;
    if (isDelayed) return kdsYellow;
    if (tableName.contains('Table')) return kdsBlue;
    return kdsGreen;
  }

  static bool isYellowHeader(Color headerColor) => headerColor == kdsYellow;

  /// Yellow headers use dark text for readability.
  static Color headerTitleColor(Color headerColor) =>
      isYellowHeader(headerColor) ? textOnLight : textOnDark;

  static List<BoxShadow> cardShadows({
    Color? accentColor,
    bool emphasize = false,
    bool compact = false,
  }) {
    if (compact) return [];
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.38),
        blurRadius: 14,
        offset: const Offset(0, 5),
      ),
      if (emphasize && accentColor != null)
        BoxShadow(
          color: accentColor.withValues(alpha: 0.32),
          blurRadius: 16,
          offset: const Offset(0, 2),
        ),
    ];
  }
}
