import 'package:demo/features/menu_setup/utils/auto_stock_schedule.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum StockOutMode { manual, auto }

class StockOutModeResult {
  const StockOutModeResult.manual() : mode = StockOutMode.manual, nextStockTime = null;

  const StockOutModeResult.auto(this.nextStockTime) : mode = StockOutMode.auto;

  final StockOutMode mode;
  final DateTime? nextStockTime;
}

class StockOutModeSheet extends StatefulWidget {
  const StockOutModeSheet({super.key});

  static Future<StockOutModeResult?> show(BuildContext context) {
    return showModalBottomSheet<StockOutModeResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const StockOutModeSheet(),
    );
  }

  @override
  State<StockOutModeSheet> createState() => _StockOutModeSheetState();
}

class _StockOutModeSheetState extends State<StockOutModeSheet> {
  static const _navy = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);

  late DateTime _nextStockTime;

  @override
  void initState() {
    super.initState();
    _nextStockTime = AutoStockSchedule.defaultNextRestockLocal();
  }

  String _formatDateTime(DateTime value) {
    return DateFormat('EEE, d MMM · h:mm a').format(value);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _nextStockTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_nextStockTime),
    );
    if (time == null || !mounted) return;

    setState(() {
      _nextStockTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Stock Out mode',
              style: MyFont.bold(18, color: _navy),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose how selected items return to Stock In.',
              style: MyFont.regular(13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            _ModeTile(
              icon: Icons.pan_tool_alt_outlined,
              title: 'Manual Stock Out',
              subtitle: 'Stays out until you mark Stock In',
              onTap: () => Navigator.pop(
                context,
                const StockOutModeResult.manual(),
              ),
            ),
            const SizedBox(height: 10),
            _ModeTile(
              icon: Icons.schedule_rounded,
              title: 'Automatic Stock Out',
              subtitle: 'Returns in stock automatically at a set time',
              onTap: () => Navigator.pop(
                context,
                StockOutModeResult.auto(_nextStockTime),
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, color: _orange, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto restock time',
                              style: MyFont.semiBold(13, color: _navy),
                            ),
                            Text(
                              _formatDateTime(_nextStockTime),
                              style: MyFont.regular(12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.edit_calendar, color: Colors.grey.shade500, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Default: next day at 3:00 PM. Tap the schedule row to change before confirming Auto.',
              style: MyFont.regular(11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFf57c35)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: MyFont.semiBold(15, color: const Color(0xFF1A3A5C))),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: MyFont.regular(12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
