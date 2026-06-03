import 'package:cloud_firestore/cloud_firestore.dart';

class PeriodSummary {
  final double amount;
  final int count;

  const PeriodSummary({required this.amount, required this.count});
}

class AdminDashboardData {
  final int reservedTables;
  final int totalTables;
  final PeriodSummary transactionsAllTime;
  final PeriodSummary transactionsThisWeek;
  final PeriodSummary transactionsThisMonth;
  final PeriodSummary expensesAllTime;
  final PeriodSummary expensesThisWeek;
  final PeriodSummary expensesThisMonth;

  const AdminDashboardData({
    required this.reservedTables,
    required this.totalTables,
    required this.transactionsAllTime,
    required this.transactionsThisWeek,
    required this.transactionsThisMonth,
    required this.expensesAllTime,
    required this.expensesThisWeek,
    required this.expensesThisMonth,
  });
}

class AdminDashboardService {
  static DateTime _startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 0, 0, 0);

  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  /// Monday as the first day of the week.
  static DateTime _startOfWeek(DateTime now) {
    final today = _startOfDay(now);
    return today.subtract(Duration(days: now.weekday - 1));
  }

  static DateTime _startOfMonth(DateTime now) =>
      DateTime(now.year, now.month, 1, 0, 0, 0);

  static Future<AdminDashboardData> load() async {
    final now = DateTime.now();
    final weekStart = _startOfWeek(now);
    final monthStart = _startOfMonth(now);
    final endNow = _endOfDay(now);

    final results = await Future.wait([
      _countReservedTables(),
      _summarizeTransactions(null, null),
      _summarizeTransactions(weekStart, endNow),
      _summarizeTransactions(monthStart, endNow),
      _summarizeExpenses(null, null),
      _summarizeExpenses(weekStart, endNow),
      _summarizeExpenses(monthStart, endNow),
    ]);

    final tableCounts = results[0] as ({int reserved, int total});

    return AdminDashboardData(
      reservedTables: tableCounts.reserved,
      totalTables: tableCounts.total,
      transactionsAllTime: results[1] as PeriodSummary,
      transactionsThisWeek: results[2] as PeriodSummary,
      transactionsThisMonth: results[3] as PeriodSummary,
      expensesAllTime: results[4] as PeriodSummary,
      expensesThisWeek: results[5] as PeriodSummary,
      expensesThisMonth: results[6] as PeriodSummary,
    );
  }

  static Future<({int reserved, int total})> _countReservedTables() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('tables').get();

    var reserved = 0;
    for (final doc in snapshot.docs) {
      final items = doc.data()['items'] as List<dynamic>?;
      if (items != null && items.isNotEmpty) {
        reserved++;
      }
    }
    return (reserved: reserved, total: snapshot.docs.length);
  }

  static Future<PeriodSummary> _summarizeTransactions(
    DateTime? from,
    DateTime? to,
  ) async {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('transactions');

    if (from != null && to != null) {
      query = query
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(from),
          )
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
          .orderBy('createdAt', descending: false);
    }

    final snapshot = await query.get();
    var amount = 0.0;
    for (final doc in snapshot.docs) {
      amount += (doc.data()['total'] as num?)?.toDouble() ?? 0;
    }
    return PeriodSummary(amount: amount, count: snapshot.docs.length);
  }

  static Future<PeriodSummary> _summarizeExpenses(
    DateTime? from,
    DateTime? to,
  ) async {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('expenses');

    if (from != null && to != null) {
      query = query
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(from),
          )
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
          .orderBy('createdAt', descending: false);
    }

    final snapshot = await query.get();
    var amount = 0.0;
    for (final doc in snapshot.docs) {
      amount += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
    }
    return PeriodSummary(amount: amount, count: snapshot.docs.length);
  }
}
