import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartKitchen/Styles/my_font.dart';
import 'package:smartKitchen/features/activity_log/models/activity_log_entry.dart';
import 'package:smartKitchen/features/activity_log/repositories/activity_log_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({super.key});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  static const _navy = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);
  static final _dateTimeLabelFormat = DateFormat('dd-MM-yyyy hh:mm a');
  static final _listTimeFormat = DateFormat('dd MMM yyyy  hh:mm a');

  final _repository = ActivityLogRepository();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  String _searchQuery = '';

  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _setDefaultTodayRange();
    _scrollController.addListener(_onScroll);
    _applyFilter();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _setDefaultTodayRange() {
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
    _toDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    _fromController.text = _dateTimeLabelFormat.format(_fromDate!);
    _toController.text = _dateTimeLabelFormat.format(_toDate!);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 50 &&
        !_isLoading &&
        _hasMore) {
      _fetchPage();
    }
  }

  List<ActivityLogEntry> get _filteredEntries {
    final entries = ActivityLogRepository.mapDocs(_docs);
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries.where((entry) {
      return entry.action.toLowerCase().contains(q) ||
          entry.userName.toLowerCase().contains(q) ||
          (entry.tableName?.toLowerCase().contains(q) ?? false) ||
          (entry.details?.toLowerCase().contains(q) ?? false) ||
          entry.items.any(
            (item) =>
                (item['name']?.toString().toLowerCase() ?? '').contains(q),
          );
    }).toList();
  }

  Future<void> _applyFilter() async {
    setState(() {
      _docs.clear();
      _lastDoc = null;
      _hasMore = true;
    });
    await _fetchPage();
  }

  Future<void> _fetchPage() async {
    if (_isLoading || !_hasMore || _fromDate == null) return;

    setState(() => _isLoading = true);

    final now = DateTime.now();
    final from = _fromDate!;
    final to =
        _toDate ?? DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    try {
      final result = await _repository.fetchPage(
        from: from,
        to: to,
        startAfter: _lastDoc,
      );

      if (!mounted) return;
      setState(() {
        if (result.docs.isNotEmpty) {
          _docs.addAll(result.docs);
          _lastDoc = result.docs.last;
        }
        _hasMore = result.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load activity logs: $e')),
      );
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final base = isFrom ? (_fromDate ?? now) : (_toDate ?? _fromDate ?? now);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: isFrom ? DateTime(2023) : (_fromDate ?? DateTime(2023)),
      lastDate: now,
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (!mounted) return;

    final time = pickedTime ??
        (isFrom
            ? const TimeOfDay(hour: 0, minute: 0)
            : const TimeOfDay(hour: 23, minute: 59));

    final selected = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      time.hour,
      time.minute,
      isFrom ? 0 : 59,
      isFrom ? 0 : 999,
    );

    setState(() {
      if (isFrom) {
        _fromDate = selected;
        _fromController.text = _dateTimeLabelFormat.format(selected);
      } else {
        _toDate = selected;
        _toController.text = _dateTimeLabelFormat.format(selected);
      }
    });
  }

  Color _actionColor(String action) {
    if (action == ActivityLogActions.deleteTable) {
      return Colors.red.shade700;
    }
    if (action == ActivityLogActions.deleteMenuItems) {
      return Colors.deepOrange.shade600;
    }
    return _orange;
  }

  IconData _actionIcon(String action) {
    if (action == ActivityLogActions.deleteTable) {
      return Icons.table_restaurant_outlined;
    }
    if (action == ActivityLogActions.deleteMenuItems) {
      return Icons.restaurant_menu_rounded;
    }
    return Icons.delete_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filteredEntries;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Activity Log',
          style: TextStyle(
            fontFamily: fontMulishBold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: _navy,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _dateField(
                        label: 'From',
                        controller: _fromController,
                        onTap: () => _pickDate(isFrom: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dateField(
                        label: 'To',
                        controller: _toController,
                        onTap: () => _pickDate(isFrom: false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isLoading ? null : _applyFilter,
                      child: const Text(
                        'Go',
                        style: TextStyle(fontFamily: fontMulishSemiBold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: const TextStyle(
                    fontFamily: fontMulishRegular,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search action, user, table, item…',
                    hintStyle: TextStyle(
                      fontFamily: fontMulishRegular,
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.12),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty && _isLoading
                ? const Center(child: CircularProgressIndicator())
                : entries.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No activity logs found'
                              : 'No logs match "$_searchQuery"',
                          style: TextStyle(
                            fontFamily: fontMulishRegular,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                        itemCount: entries.length + (_hasMore || _isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= entries.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          return _logCard(entries[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _dateField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      style: const TextStyle(
        fontFamily: fontMulishSemiBold,
        fontSize: 12,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: fontMulishRegular,
          fontSize: 11,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _logCard(ActivityLogEntry entry) {
    final color = _actionColor(entry.action);
    final summary = entry.summaryLine;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_actionIcon(entry.action), size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.action,
                  style: const TextStyle(
                    fontFamily: fontMulishBold,
                    fontSize: 14,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'By: ${entry.userName}',
                  style: TextStyle(
                    fontFamily: fontMulishSemiBold,
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    style: TextStyle(
                      fontFamily: fontMulishRegular,
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                if (entry.items.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: entry.items.take(6).map((item) {
                      final name = item['name']?.toString() ?? '-';
                      final qty = item['qty'] ?? 1;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          '${qty}x $name',
                          style: TextStyle(
                            fontFamily: fontMulishSemiBold,
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (entry.items.length > 6)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${entry.items.length - 6} more',
                        style: TextStyle(
                          fontFamily: fontMulishRegular,
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 6),
                Text(
                  entry.createdAt != null
                      ? _listTimeFormat.format(entry.createdAt!)
                      : '-',
                  style: TextStyle(
                    fontFamily: fontMulishRegular,
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
