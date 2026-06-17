import 'package:demo/Styles/my_font.dart';
import 'package:demo/features/kitchen/services/kitchen_cross_table_pending_index.dart';
import 'package:demo/features/tables/repositories/table_item_served.dart';
import 'package:flutter/material.dart';

const _navy = Color(0xFF1A3A5C);
const _orange = Color(0xFFf57c35);

class KitchenCrossTablePendingSheet {
  KitchenCrossTablePendingSheet._();

  static Future<void> show(
    BuildContext context, {
    required KitchenCrossTablePendingSummary summary,
    required String Function(DateTime) formatRelativeTime,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _KitchenCrossTablePendingSheetBody(
        summary: summary,
        formatRelativeTime: formatRelativeTime,
      ),
    );
  }
}

class _KitchenCrossTablePendingSheetBody extends StatefulWidget {
  const _KitchenCrossTablePendingSheetBody({
    required this.summary,
    required this.formatRelativeTime,
  });

  final KitchenCrossTablePendingSummary summary;
  final String Function(DateTime) formatRelativeTime;

  @override
  State<_KitchenCrossTablePendingSheetBody> createState() =>
      _KitchenCrossTablePendingSheetBodyState();
}

class _KitchenCrossTablePendingSheetBodyState
    extends State<_KitchenCrossTablePendingSheetBody> {
  late List<KitchenCrossTablePendingEntry> _entries;
  final Set<int> _selectedIndices = {};
  bool _selectionMode = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _entries = List<KitchenCrossTablePendingEntry>.from(widget.summary.entries);
  }

  int get _totalQty => _entries.fold<int>(0, (sum, entry) => sum + entry.qty);

  int get _selectedQty {
    var total = 0;
    for (final index in _selectedIndices) {
      total += _entries[index].qty;
    }
    return total;
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIndices.clear();
    });
  }

  void _onRowTap(int index) {
    setState(() {
      if (!_selectionMode) {
        _selectionMode = true;
        _selectedIndices
          ..clear()
          ..add(index);
        return;
      }

      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  Future<void> _serveSelected() async {
    if (_selectedIndices.isEmpty || _submitting) return;

    final keys = <TableItemKey>[];
    for (final index in _selectedIndices) {
      keys.addAll(_entries[index].itemKeys);
    }
    if (keys.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final updated = await TableItemServed.markItemsServed(keys);
      if (!mounted) return;

      if (updated) {
        setState(() {
          final sorted = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
          for (final index in sorted) {
            _entries.removeAt(index);
          }
          _selectionMode = false;
          _selectedIndices.clear();
        });
        if (_entries.isEmpty) {
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not mark items as served. Please try again.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    final selectedCount = _selectedIndices.length;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
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
                  const SizedBox(height: 14),
                  Text(
                    widget.summary.itemName,
                    style: MyFont.bold(18, color: _navy),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectionMode
                        ? 'Tap rows to select, then mark as served'
                        : 'Unserved quantity across orders',
                    style: MyFont.regular(13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (_selectionMode) const SizedBox(width: 28),
                    Expanded(
                      child: Text(
                        'Qty × Table',
                        style: MyFont.semiBold(
                          12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Text(
                      'Time',
                      style: MyFont.semiBold(
                        12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _entries.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  final remarks = entry.remarksText;
                  final isSelected = _selectedIndices.contains(index);

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _submitting ? null : () => _onRowTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.green.withValues(alpha: 0.08)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectionMode) ...[
                            Padding(
                              padding: const EdgeInsets.only(right: 6, top: 1),
                              child: Icon(
                                isSelected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                size: 20,
                                color: isSelected
                                    ? Colors.green.shade600
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 28,
                                      child: Text(
                                        '${entry.qty}',
                                        style:
                                            MyFont.bold(15, color: _orange),
                                      ),
                                    ),
                                    Text(
                                      '×',
                                      style: MyFont.regular(
                                        14,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        entry.tableName,
                                        style:
                                            MyFont.semiBold(14, color: _navy),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _formatTimeLabel(
                                        widget.formatRelativeTime(
                                          entry.orderTime,
                                        ),
                                      ),
                                      style: MyFont.regular(
                                        12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (remarks != null) ...[
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 36),
                                    child: Text(
                                      '* $remarks',
                                      style: MyFont.regular(
                                        12,
                                        color: Colors.red.shade400,
                                      ).copyWith(fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_selectionMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  children: [
                    const Spacer(),
                    _actionIcon(
                      icon: Icons.close,
                      tooltip: 'Cancel',
                      color: Colors.grey.shade700,
                      onPressed: _submitting ? null : _cancelSelection,
                    ),
                    const SizedBox(width: 12),
                    _actionIcon(
                      icon: Icons.check_circle_outline,
                      tooltip: selectedCount > 0
                          ? 'Serve ($selectedCount)'
                          : 'Serve',
                      color: Colors.green.shade600,
                      onPressed: selectedCount == 0 || _submitting
                          ? null
                          : _serveSelected,
                      showSpinner: _submitting,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, _selectionMode ? 8 : 8, 20, 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _orange.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectionMode && selectedCount > 0
                          ? 'Selected pending'
                          : 'Total pending',
                      style: MyFont.semiBold(15, color: _navy),
                    ),
                    const Spacer(),
                    Text(
                      _selectionMode && selectedCount > 0
                          ? '$_selectedQty'
                          : '$_totalQty',
                      style: MyFont.bold(18, color: _orange),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback? onPressed,
    bool showSpinner = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: 40,
            height: 40,
            child: showSpinner
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Icon(
                    icon,
                    color: onPressed == null
                        ? color.withValues(alpha: 0.4)
                        : color,
                  ),
          ),
        ),
      ),
    );
  }

  static String _formatTimeLabel(String relative) {
    final lower = relative.toLowerCase();
    if (lower == 'just now') return 'Just now';
    if (lower.endsWith(' ago')) {
      return lower[0].toUpperCase() + lower.substring(1);
    }
    return relative;
  }
}

class KitchenCrossTablePendingBadge extends StatefulWidget {
  const KitchenCrossTablePendingBadge({
    required this.totalQty,
    required this.onTap,
    super.key,
  });

  final int totalQty;
  final VoidCallback onTap;

  @override
  State<KitchenCrossTablePendingBadge> createState() =>
      _KitchenCrossTablePendingBadgeState();
}

class _KitchenCrossTablePendingBadgeState extends State<KitchenCrossTablePendingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Pending on ${widget.totalQty} tables — tap to view',
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(
          scale: _pulseScale,
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _orange,
                  Color.lerp(_orange, Colors.red.shade700, 0.35)!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _orange.withValues(alpha: 0.55),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${widget.totalQty}',
              style: MyFont.bold(13, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
