class TaxBreakdown {
  const TaxBreakdown({
    required this.cgstPercent,
    required this.sgstPercent,
    required this.cgstAmount,
    required this.sgstAmount,
  });

  final double cgstPercent;
  final double sgstPercent;
  final int cgstAmount;
  final int sgstAmount;

  int get totalTax => cgstAmount + sgstAmount;

  bool get hasTax => totalTax > 0;
}

class TaxCalculator {
  const TaxCalculator._();

  static TaxBreakdown calculate(
    num subtotal, {
    double cgstPercent = 0,
    double sgstPercent = 0,
  }) {
    final base = subtotal.toDouble();
    return TaxBreakdown(
      cgstPercent: cgstPercent,
      sgstPercent: sgstPercent,
      cgstAmount: (base * cgstPercent / 100).round(),
      sgstAmount: (base * sgstPercent / 100).round(),
    );
  }

  static String formatPercent(double value) {
    if (value == 0) return '0';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  static TaxBreakdown fromTransaction(
    Map<String, dynamic> transaction, {
    double defaultCgstPercent = 0,
    double defaultSgstPercent = 0,
  }) {
    final subtotal = (transaction['subtotal'] as num?)?.toDouble() ?? 0;
    final cgstPercent =
        (transaction['cgstPercentage'] as num?)?.toDouble() ?? defaultCgstPercent;
    final sgstPercent =
        (transaction['sgstPercentage'] as num?)?.toDouble() ?? defaultSgstPercent;

    final storedCgst = transaction['cgstAmount'];
    final storedSgst = transaction['sgstAmount'];
    if (storedCgst != null || storedSgst != null) {
      return TaxBreakdown(
        cgstPercent: cgstPercent,
        sgstPercent: sgstPercent,
        cgstAmount: (storedCgst as num?)?.round() ?? 0,
        sgstAmount: (storedSgst as num?)?.round() ?? 0,
      );
    }

    final tax = (transaction['tax'] as num?)?.round() ?? 0;
    if (tax > 0 && cgstPercent == 0 && sgstPercent == 0) {
      return TaxBreakdown(
        cgstPercent: 0,
        sgstPercent: 0,
        cgstAmount: tax,
        sgstAmount: 0,
      );
    }

    return calculate(
      subtotal,
      cgstPercent: cgstPercent,
      sgstPercent: sgstPercent,
    );
  }
}
