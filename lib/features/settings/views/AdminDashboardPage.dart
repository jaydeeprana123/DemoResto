import 'package:demo/features/settings/repositories/admin_dashboard_repository.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  static const _navy = Color(0xFF1A3A5C);
  static const _navyDk = Color(0xFF0D2137);
  static const _orange = Color(0xFFf57c35);
  static const _bg = Color(0xFFF0F2F5);
  static const _green = Color(0xFF2E7D32);
  static const _greenLight = Color(0xFFE8F5E9);

  static final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  Future<AdminDashboardData>? _dataFuture;
  DateTime? _lastLoaded;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _dataFuture = Get.find<AdminDashboardRepository>().load();
      _lastLoaded = null;
    });
    _dataFuture?.then((_) {
      if (mounted) setState(() => _lastLoaded = DateTime.now());
    });
  }

  String get _updatedLabel {
    if (_lastLoaded == null) return 'Updating…';
    return 'Updated ${DateFormat('hh:mm a').format(_lastLoaded!)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: _navy,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 17,
                fontFamily: fontMulishBold,
                color: Colors.white,
              ),
            ),
            Text(
              'Business overview',
              style: TextStyle(
                fontSize: 11,
                fontFamily: fontMulishRegular,
                color: Colors.white60,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<AdminDashboardData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _orange),
            );
          }

          if (snapshot.hasError) {
            return _buildError(snapshot.error.toString());
          }

          final data = snapshot.data!;
          final netMonth = data.transactionsThisMonth.amount -
              data.expensesThisMonth.amount;

          return RefreshIndicator(
            color: _orange,
            onRefresh: () async {
              final future = Get.find<AdminDashboardRepository>().load();
              setState(() {
                _dataFuture = future;
                _lastLoaded = null;
              });
              await future;
              if (mounted) setState(() => _lastLoaded = DateTime.now());
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 520;
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _buildStatusChip(_updatedLabel),
                    const SizedBox(height: 12),
                    _buildTablesHero(data, wide: wide),
                    const SizedBox(height: 14),
                    _buildNetBanner(netMonth),
                    const SizedBox(height: 14),
                    _buildMetricsSection(
                      title: 'Transactions',
                      subtitle: 'Sales & billing',
                      icon: Icons.trending_up_rounded,
                      headerColor: _green,
                      headerBg: _greenLight,
                      summaries: [
                        _PeriodData('All time', data.transactionsAllTime),
                        _PeriodData('This week', data.transactionsThisWeek),
                        _PeriodData('This month', data.transactionsThisMonth),
                      ],
                      amountColor: _navy,
                      wide: wide,
                    ),
                    const SizedBox(height: 14),
                    _buildMetricsSection(
                      title: 'Expenses',
                      subtitle: 'Business spending',
                      icon: Icons.trending_down_rounded,
                      headerColor: Colors.red.shade700,
                      headerBg: const Color(0xFFFFEBEE),
                      summaries: [
                        _PeriodData('All time', data.expensesAllTime),
                        _PeriodData('This week', data.expensesThisWeek),
                        _PeriodData('This month', data.expensesThisMonth),
                      ],
                      amountColor: Colors.red.shade700,
                      wide: wide,
                      isExpense: true,
                    ),
                    const SizedBox(height: 8),
                    _buildFootnote(),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_outlined,
                  size: 40, color: Colors.red.shade400),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load dashboard',
              style: TextStyle(
                fontFamily: fontMulishBold,
                fontSize: 16,
                color: _navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontFamily: fontMulishRegular,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: _green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontFamily: fontMulishSemiBold,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTablesHero(AdminDashboardData data, {required bool wide}) {
    final available = (data.totalTables - data.reservedTables).clamp(0, 999);
    final occupancy = data.totalTables > 0
        ? data.reservedTables / data.totalTables
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, _navyDk],
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: wide
            ? Row(
                children: [
                  Expanded(child: _tablesHeroLeft(data, available)),
                  const SizedBox(width: 20),
                  _tablesHeroRing(occupancy, available, data.totalTables),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _tablesHeroLeft(data, available),
                  const SizedBox(height: 16),
                  _tablesHeroRing(occupancy, available, data.totalTables),
                ],
              ),
      ),
    );
  }

  Widget _tablesHeroLeft(AdminDashboardData data, int available) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 10,
              fontFamily: fontMulishBold,
              color: Colors.white,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Tables reserved',
          style: TextStyle(
            fontFamily: fontMulishSemiBold,
            fontSize: 15,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${data.reservedTables}',
          style: const TextStyle(
            fontFamily: fontMulishBold,
            fontSize: 48,
            color: Colors.white,
            height: 1,
          ),
        ),
        Text(
          'active orders on ${data.totalTables} tables',
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white54,
            fontFamily: fontMulishRegular,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$available tables available now',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.45),
            fontFamily: fontMulishRegular,
          ),
        ),
      ],
    );
  }

  Widget _tablesHeroRing(double occupancy, int available, int total) {
    final pct = (occupancy * 100).round();
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: CircularProgressIndicator(
              value: total > 0 ? occupancy : 0,
              strokeWidth: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              color: _orange,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$pct%',
                style: const TextStyle(
                  fontFamily: fontMulishBold,
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
              Text(
                'in use',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNetBanner(double netMonth) {
    final positive = netMonth >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: positive
              ? _green.withValues(alpha: 0.35)
              : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: positive ? _greenLight : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              positive
                  ? Icons.account_balance_wallet_outlined
                  : Icons.warning_amber_rounded,
              color: positive ? _green : Colors.red.shade700,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Net this month',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: fontMulishSemiBold,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Transactions − expenses',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontFamily: fontMulishRegular,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _currency.format(netMonth),
            style: TextStyle(
              fontFamily: fontMulishBold,
              fontSize: 20,
              color: positive ? _green : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color headerColor,
    required Color headerBg,
    required List<_PeriodData> summaries,
    required Color amountColor,
    required bool wide,
    bool isExpense = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: headerColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: fontMulishBold,
                          fontSize: 16,
                          color: headerColor,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: headerColor.withValues(alpha: 0.7),
                          fontFamily: fontMulishRegular,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: wide
                ? Row(
                    children: summaries
                        .map(
                          (p) => Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: _periodTile(
                                p,
                                amountColor: amountColor,
                                isExpense: isExpense,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  )
                : Column(
                    children: summaries
                        .map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _periodTile(
                              p,
                              amountColor: amountColor,
                              isExpense: isExpense,
                              horizontal: true,
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _periodTile(
    _PeriodData period, {
    required Color amountColor,
    required bool isExpense,
    bool horizontal = false,
  }) {
    final countLabel =
        '${period.summary.count} ${isExpense ? 'expense' : 'order'}${period.summary.count == 1 ? '' : 's'}';

    if (horizontal) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    period.label,
                    style: const TextStyle(
                      fontFamily: fontMulishSemiBold,
                      fontSize: 14,
                      color: _navy,
                    ),
                  ),
                  Text(
                    countLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontFamily: fontMulishRegular,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _currency.format(period.summary.amount),
              style: TextStyle(
                fontFamily: fontMulishBold,
                fontSize: 17,
                color: amountColor,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            period.label,
            style: TextStyle(
              fontFamily: fontMulishSemiBold,
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currency.format(period.summary.amount),
            style: TextStyle(
              fontFamily: fontMulishBold,
              fontSize: 18,
              color: amountColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            countLabel,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
              fontFamily: fontMulishRegular,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFootnote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Reserved tables have active orders on the floor plan. '
              'Week starts Monday; month is calendar month to today.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: Colors.grey.shade600,
                fontFamily: fontMulishRegular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodData {
  final String label;
  final PeriodSummary summary;

  const _PeriodData(this.label, this.summary);
}
