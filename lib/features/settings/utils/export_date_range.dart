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
  // Honor the exact date & time the user selected; only fall back to
  // end-of-today when no upper bound was provided.
  final effectiveTo =
      toDate ?? DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  return ExportDateRange(from: fromDate, to: effectiveTo);
}
