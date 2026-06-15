import 'package:demo/Styles/my_font.dart';
import 'package:demo/features/kitchen/services/kitchen_preparation_view_index.dart';
import 'package:demo/features/tables/repositories/table_item_served.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

const _navy = Color(0xFF1A3A5C);
const _orange = Color(0xFFf57c35);
const _tileBorder = Color(0xFFE5E7EB);

class KitchenPreparationOrdersList extends StatefulWidget {
  const KitchenPreparationOrdersList({
    super.key,
    required this.groups,
    required this.scrollController,
    required this.formatRelativeTime,
    required this.minuteTick,
    required this.crossAxisCount,
    this.mainAxisSpacing = 10,
    this.crossAxisSpacing = 10,
    this.padding = const EdgeInsets.all(12),
    this.layoutIsGrid = true,
    this.servedTabActive = false,
  });

  final List<KitchenPreparationItemGroup> groups;
  final ScrollController scrollController;
  final String Function(DateTime) formatRelativeTime;
  final ValueListenable<int> minuteTick;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsets padding;
  final bool layoutIsGrid;
  final bool servedTabActive;

  @override
  State<KitchenPreparationOrdersList> createState() =>
      _KitchenPreparationOrdersListState();
}

class _KitchenPreparationOrdersListState
    extends State<KitchenPreparationOrdersList> {
  final Set<String> _selectedLineKeys = {};
  bool _selectionMode = false;
  bool _submitting = false;

  String _lineKey(KitchenPreparationTableLine line) {
    return line.itemKeys.map((key) => key.id).join('|');
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedLineKeys.clear();
    });
  }

  void _onLineTap(KitchenPreparationTableLine line) {
    if (line.isServed || _submitting) return;
    final key = _lineKey(line);
    setState(() {
      if (!_selectionMode) {
        _selectionMode = true;
        _selectedLineKeys
          ..clear()
          ..add(key);
        return;
      }

      if (_selectedLineKeys.contains(key)) {
        _selectedLineKeys.remove(key);
        if (_selectedLineKeys.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedLineKeys.add(key);
      }
    });
  }

  Future<void> _serveSelected() async {
    if (_selectedLineKeys.isEmpty || _submitting) return;

    final keys = <TableItemKey>[];
    for (final group in widget.groups) {
      for (final line in group.lines) {
        if (_selectedLineKeys.contains(_lineKey(line))) {
          keys.addAll(line.itemKeys);
        }
      }
    }
    if (keys.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final updated = await TableItemServed.markItemsServed(keys);
      if (!mounted) return;

      if (updated) {
        setState(() {
          _selectionMode = false;
          _selectedLineKeys.clear();
        });
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
    return Column(
      children: [
        Expanded(
          child: widget.layoutIsGrid
              ? _buildGridView()
              : _buildListView(),
        ),
        if (_selectionMode && !widget.servedTabActive) _buildSelectionBar(),
      ],
    );
  }

  Widget _buildItemBlock(KitchenPreparationItemGroup group, {required bool bordered}) {
    return _PreparationItemBlock(
      group: group,
      bordered: bordered,
      selectionMode: _selectionMode,
      selectedLineKeys: _selectedLineKeys,
      lineKey: _lineKey,
      formatRelativeTime: widget.formatRelativeTime,
      minuteTick: widget.minuteTick,
      onLineTap: _onLineTap,
      submitting: _submitting,
    );
  }

  Widget _buildGridView() {
    return MasonryGridView.count(
      controller: widget.scrollController,
      restorationId: 'kitchen_preparation_orders_grid',
      cacheExtent: 3000,
      physics: const AlwaysScrollableScrollPhysics(),
      crossAxisCount: widget.crossAxisCount,
      mainAxisSpacing: widget.mainAxisSpacing,
      crossAxisSpacing: widget.crossAxisSpacing,
      padding: widget.padding,
      itemCount: widget.groups.length,
      itemBuilder: (context, index) =>
          _buildItemBlock(widget.groups[index], bordered: true),
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      controller: widget.scrollController,
      restorationId: 'kitchen_preparation_orders_list',
      cacheExtent: 3000,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: widget.padding,
      itemCount: widget.groups.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Divider(height: 1, color: Colors.grey.shade300),
      ),
      itemBuilder: (context, index) =>
          _buildItemBlock(widget.groups[index], bordered: false),
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedLineKeys.length} selected',
            style: MyFont.semiBold(13, color: _navy),
          ),
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
            tooltip: _selectedLineKeys.isEmpty
                ? 'Serve'
                : 'Serve (${_selectedLineKeys.length})',
            color: Colors.green.shade600,
            onPressed: _selectedLineKeys.isEmpty || _submitting
                ? null
                : _serveSelected,
            showSpinner: _submitting,
          ),
        ],
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
}

/// Item group block for grid (bordered) or list (flat) layout.
class _PreparationItemBlock extends StatelessWidget {
  const _PreparationItemBlock({
    required this.group,
    required this.bordered,
    required this.selectionMode,
    required this.selectedLineKeys,
    required this.lineKey,
    required this.formatRelativeTime,
    required this.minuteTick,
    required this.onLineTap,
    required this.submitting,
  });

  final KitchenPreparationItemGroup group;
  final bool bordered;
  final bool selectionMode;
  final Set<String> selectedLineKeys;
  final String Function(KitchenPreparationTableLine line) lineKey;
  final String Function(DateTime) formatRelativeTime;
  final ValueListenable<int> minuteTick;
  final ValueChanged<KitchenPreparationTableLine> onLineTap;
  final bool submitting;

  Widget _buildItemHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: _navy,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              group.itemName,
              style: MyFont.semiBold(14, color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(${group.totalQty})',
            style: MyFont.bold(14, color: _orange),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = group.lines.map(
      (line) => _PreparationTableLineRow(
        line: line,
        selectionMode: selectionMode,
        isSelected: selectedLineKeys.contains(lineKey(line)),
        formatRelativeTime: formatRelativeTime,
        minuteTick: minuteTick,
        onTap: submitting || line.isServed ? null : () => onLineTap(line),
      ),
    );

    if (!bordered) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildItemHeader(),
          const SizedBox(height: 10),
          ...lines,
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _tileBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildItemHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: lines.toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreparationTableLineRow extends StatelessWidget {
  const _PreparationTableLineRow({
    required this.line,
    required this.selectionMode,
    required this.isSelected,
    required this.formatRelativeTime,
    required this.minuteTick,
    required this.onTap,
  });

  final KitchenPreparationTableLine line;
  final bool selectionMode;
  final bool isSelected;
  final String Function(DateTime) formatRelativeTime;
  final ValueListenable<int> minuteTick;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final remarks = line.remarks?.trim();
    final served = line.isServed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: served
            ? Colors.green.withValues(alpha: 0.1)
            : isSelected
                ? Colors.green.withValues(alpha: 0.07)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (selectionMode && !served) ...[
                  Icon(
                    isSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 18,
                    color: isSelected
                        ? Colors.green.shade600
                        : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                ] else if (served) ...[
                  Icon(Icons.check, size: 15, color: Colors.green.shade600),
                  const SizedBox(width: 4),
                ],
                _buildQtyBadge(served: served),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              line.tableLabel,
                              style: MyFont.semiBold(
                                12,
                                color: served
                                    ? Colors.green.shade700
                                    : const Color(0xFF212121),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          ValueListenableBuilder<int>(
                            valueListenable: minuteTick,
                            builder: (context, _, __) => Text(
                              _formatTimeLabel(
                                formatRelativeTime(line.orderTime),
                              ),
                              style: MyFont.regular(
                                11,
                                color: served
                                    ? Colors.green.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (remarks != null && remarks.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '* $remarks',
                          style: MyFont.regular(
                            11,
                            color: served
                                ? Colors.green.shade400
                                : Colors.red.shade400,
                          ).copyWith(fontStyle: FontStyle.italic),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
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

  Widget _buildQtyBadge({required bool served}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: served
            ? Colors.green.withValues(alpha: 0.12)
            : _orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '×${line.qty}',
        style: MyFont.bold(
          11,
          color: served ? Colors.green.shade700 : _orange,
        ),
      ),
    );
  }
}
