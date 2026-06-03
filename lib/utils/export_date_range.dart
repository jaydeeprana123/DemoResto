/// Normalized start/end-of-day range for Firestore export queries.
class ExportDateRange {
  final DateTime from;
  final DateTime to;

  const ExportDateRange({required this.from, required this.to});

  String get label {
    final fromStr =
        '${from.day.toString().padLeft(2, '0')}-${from.month.toString().padLeft(2, '0')}-${from.year}';
    final toStr =
        '${to.day.toString().padLeft(2, '0')}-${to.month.toString().padLeft(2, '0')}-${to.year}';
    return '$fromStr to $toStr';
  }
}

ExportDateRange buildExportDateRange({
  required DateTime fromDate,
  DateTime? toDate,
}) {
  final now = DateTime.now();
  final effectiveFrom = DateTime(
    fromDate.year,
    fromDate.month,
    fromDate.day,
    0,
    0,
    0,
  );
  final effectiveTo = (toDate != null)
      ? DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59, 999)
      : DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  return ExportDateRange(from: effectiveFrom, to: effectiveTo);
}
