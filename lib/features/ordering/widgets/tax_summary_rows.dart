import 'package:smartKitchen/Styles/my_colors.dart';
import 'package:smartKitchen/Styles/my_font.dart';
import 'package:smartKitchen/core/utils/tax_calculator.dart';
import 'package:flutter/material.dart';

class TaxSummaryRows extends StatelessWidget {
  const TaxSummaryRows({
    super.key,
    required this.breakdown,
    this.spacing = 8,
  });

  final TaxBreakdown breakdown;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (!breakdown.hasTax) {
      return const SizedBox.shrink();
    }

    final rows = <Widget>[];

    if (breakdown.cgstPercent > 0 && breakdown.cgstAmount > 0) {
      rows.add(
        _row(
          'CGST (${TaxCalculator.formatPercent(breakdown.cgstPercent)}%)',
          breakdown.cgstAmount,
        ),
      );
      rows.add(SizedBox(height: spacing));
    } else if (breakdown.cgstAmount > 0 && breakdown.cgstPercent == 0) {
      rows.add(_row('Tax', breakdown.cgstAmount));
      rows.add(SizedBox(height: spacing));
    }

    if (breakdown.sgstPercent > 0 && breakdown.sgstAmount > 0) {
      rows.add(
        _row(
          'SGST (${TaxCalculator.formatPercent(breakdown.sgstPercent)}%)',
          breakdown.sgstAmount,
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _row(String label, int amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: secondary_text_color,
            fontFamily: fontMulishSemiBold,
          ),
        ),
        Text(
          '₹$amount',
          style: const TextStyle(
            fontSize: 14,
            color: text_color,
            fontFamily: fontMulishSemiBold,
          ),
        ),
      ],
    );
  }
}
