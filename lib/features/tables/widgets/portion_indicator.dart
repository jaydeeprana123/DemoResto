import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:smartKitchen/Styles/my_font.dart';

/// Portion size detected from an item name (e.g. "Noodles (Half)").
enum PortionType { half, full }

/// Matches a "half" / "full" token together with any surrounding brackets
/// (e.g. "(Half)"), case-insensitive. Word boundaries avoid partial matches
/// inside longer words. Group 1 holds the bare keyword for type detection.
final RegExp _portionPattern = RegExp(
  r'\(?\s*\b(half|full)\b\s*\)?',
  caseSensitive: false,
);

PortionType? _portionTypeFor(String word) {
  switch (word.toLowerCase()) {
    case 'half':
      return PortionType.half;
    case 'full':
      return PortionType.full;
  }
  return null;
}

/// Dark red used to emphasize the "Half"/"Full" token and its plate icon.
const Color kPortionHighlightColor = Color(0xFFFF0000);

/// Builds the item-name widget, bolding any "Half"/"Full" token in dark red
/// and rendering a matching plate icon right next to it. Falls back to a plain
/// [Text] when the name has no portion keyword.
Widget buildPortionAwareName(
  String name, {
  required TextStyle style,
  Color highlightColor = kPortionHighlightColor,
}) {
  final matches = _portionPattern.allMatches(name).toList();
  if (matches.isEmpty) {
    return Text(name, style: style);
  }

  final highlightStyle = style.copyWith(
    fontFamily: fontMulishBold,
    fontWeight: FontWeight.w800,
    // color: highlightColor,
  );

  final plateColor = style.color??Colors.black;
  // final plateColor = highlightColor;
  final iconSize = (style.fontSize ?? 14) + 2;

  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final match in matches) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: name.substring(cursor, match.start)));
    }

    // Full match keeps the surrounding brackets; group 1 is the keyword.
    final highlighted = name.substring(match.start, match.end);
    final keyword = match.group(1) ?? '';
    final type = _portionTypeFor(keyword) ?? PortionType.full;
    spans.add(TextSpan(text: highlighted, style: highlightStyle));
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: PortionPlateIcon(
            type: type,
            size: iconSize,
            color: plateColor,
          ),
        ),
      ),
    );
    cursor = match.end;
  }
  if (cursor < name.length) {
    spans.add(TextSpan(text: name.substring(cursor)));
  }

  return Text.rich(TextSpan(style: style, children: spans));
}

/// A small plate icon: an outlined plate rim filled fully for a full portion
/// or only on the left half for a half portion.
class PortionPlateIcon extends StatelessWidget {
  const PortionPlateIcon({
    super.key,
    required this.type,
    this.size = 16,
    this.color = const Color(0xFFf57c35),
  });

  final PortionType type;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _PortionPlatePainter(type: type, color: color),
      ),
    );
  }
}

class _PortionPlatePainter extends CustomPainter {
  _PortionPlatePainter({required this.type, required this.color});

  final PortionType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rimRadius = size.width / 2;
    final foodRadius = rimRadius * 0.62;
    final foodRect = Rect.fromCircle(center: center, radius: foodRadius);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (type == PortionType.full) {
      canvas.drawCircle(center, foodRadius, fillPaint);
    } else {
      // Left half of the plate represents a half portion.
      canvas.drawArc(foodRect, math.pi / 2, math.pi, true, fillPaint);
    }

    final rimPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, size.width * 0.09);
    canvas.drawCircle(center, rimRadius - rimPaint.strokeWidth / 2, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _PortionPlatePainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
