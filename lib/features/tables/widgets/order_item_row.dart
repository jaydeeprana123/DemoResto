import 'package:flutter/material.dart';

import 'package:demo/Styles/my_font.dart';
import 'package:demo/features/tables/repositories/table_item_served.dart';

/// Per-screen controller for tap-to-select on one order card at a time.
/// Uses per-document listenables so only the active card rebuilds on tap.
class TableItemSelectionController {
  String? _activeDocId;
  final Set<TableItemKey> _selected = {};
  final Map<String, ChangeNotifier> _docListenables = {};

  Listenable listenableFor(String docId) {
    return _docListenables.putIfAbsent(docId, ChangeNotifier.new);
  }

  void _notifyDoc(String? docId) {
    if (docId == null) return;
    _docListenables[docId]?.notifyListeners();
  }

  bool isSelectionModeFor(String docId) => _activeDocId == docId;

  bool isSelected(TableItemKey key) => _selected.contains(key);

  Set<TableItemKey> selectedFor(String docId) =>
      _selected.where((k) => k.docId == docId).toSet();

  void startSelection(TableItemKey key) {
    final prev = _activeDocId;
    if (prev != null && prev != key.docId) {
      _selected.clear();
    }
    _activeDocId = key.docId;
    _selected
      ..clear()
      ..add(key);
    if (prev != key.docId) _notifyDoc(prev);
    _notifyDoc(key.docId);
  }

  void toggle(TableItemKey key) {
    if (_activeDocId != key.docId) return;
    if (_selected.contains(key)) {
      _selected.remove(key);
    } else {
      _selected.add(key);
    }
    _notifyDoc(key.docId);
  }

  void cancel() {
    final prev = _activeDocId;
    _activeDocId = null;
    _selected.clear();
    _notifyDoc(prev);
  }

  Future<bool> submitSelected() async {
    if (_selected.isEmpty) return false;
    final keys = _selected.toList();
    final updated = await TableItemServed.markItemsServed(keys);
    if (updated) {
      cancel();
    }
    return updated;
  }

  Future<bool> submitSelectedUnserved() async {
    if (_selected.isEmpty) return false;
    final keys = _selected.toList();
    final updated = await TableItemServed.markItemsUnserved(keys);
    if (updated) {
      cancel();
    }
    return updated;
  }

  Future<bool> deleteSelected() async {
    if (_selected.isEmpty) return false;
    final keys = _selected.toList();
    final updated = await TableItemServed.removeItems(keys);
    if (updated) {
      cancel();
    }
    return updated;
  }
}

enum TableItemSelectionAction { serve, markPending }

enum OrderItemRowStyle { kitchen, dashboard }

class OrderItemRow extends StatelessWidget {
  const OrderItemRow({
    super.key,
    required this.item,
    required this.docId,
    required this.groupIndex,
    required this.itemIndexInGroup,
    required this.selectionController,
    required this.selectionMode,
    required this.isSelected,
    this.style = OrderItemRowStyle.kitchen,
    this.selectionForServedItems = false,
  });

  final Map<String, dynamic> item;
  final String docId;
  final int groupIndex;
  final int itemIndexInGroup;
  final TableItemSelectionController selectionController;
  final bool selectionMode;
  final bool isSelected;
  final OrderItemRowStyle style;
  final bool selectionForServedItems;

  TableItemKey get _key => TableItemKey(
    docId: docId,
    groupIndex: groupIndex,
    itemIndexInGroup: itemIndexInGroup,
  );

  @override
  Widget build(BuildContext context) {
    final served = TableItemServed.isServed(item);
    final qty = item['qty'] ?? 1;
    final qtyInt = qty is int ? qty : int.tryParse('$qty') ?? 1;
    final name = item['name']?.toString() ?? '';
    final remarks = item['remarks']?.toString() ?? '';

    final row = TableItemServed.buildItemLine(
      qty: qtyInt,
      name: name,
      served: served,
      remarks: remarks.isEmpty ? null : remarks,
      qtyBadge: _qtyBadge(qtyInt, served: served),
      nameStyle: _nameStyle(served: served),
      remarksStyle: _remarksStyle(served: served),
      showSelectionIndicator:
          selectionMode && (!served || selectionForServedItems),
      selectionSelected: isSelected,
    );

    Widget content = Padding(
      padding: EdgeInsets.only(
        bottom: style == OrderItemRowStyle.kitchen ? 8 : 0,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _rowBackground(
            served: served,
            selectionMode: selectionMode,
            selected: isSelected,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: row,
        ),
      ),
    );

    if (served && !selectionForServedItems) return content;

    if (selectionMode) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => selectionController.toggle(_key),
        child: content,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => selectionController.startSelection(_key),
      child: content,
    );
  }

  Color? _rowBackground({
    required bool served,
    required bool selectionMode,
    required bool selected,
  }) {
    if (selectionMode && selected) {
      return Colors.green.withValues(alpha: 0.08);
    }
    if (served) return Colors.green.withValues(alpha: 0.1);
    return null;
  }

  Widget _qtyBadge(int qty, {required bool served}) {
    if (style == OrderItemRowStyle.dashboard) {
      return Container(
        margin: const EdgeInsets.only(right: 5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: served
              ? Colors.green.withValues(alpha: 0.12)
              : const Color(0xFFf57c35).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '×$qty',
          style: TextStyle(
            fontSize: 12,
            color: served ? Colors.green.shade700 : const Color(0xFFf57c35),
            fontFamily: fontMulishBold,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: served
            ? Colors.green.withValues(alpha: 0.12)
            : const Color(0xFFf57c35).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: served
              ? Colors.green.withValues(alpha: 0.35)
              : const Color(0xFFf57c35).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        '${qty}x',
        style: TextStyle(
          color: served ? Colors.green.shade700 : const Color(0xFFf57c35),
          fontFamily: fontMulishBold,
          fontSize: 13,
        ),
      ),
    );
  }

  TextStyle _nameStyle({required bool served}) {
    if (style == OrderItemRowStyle.dashboard) {
      return TextStyle(
        fontSize: 13,
        fontFamily: fontMulishSemiBold,
        color: served ? Colors.green.shade700 : const Color(0xFF212121),
      );
    }
    return TextStyle(
      fontSize: 14,
      color: served ? Colors.green.shade700 : Colors.black87,
      fontFamily: fontMulishSemiBold,
      height: 1.2,
    );
  }

  TextStyle _remarksStyle({required bool served}) {
    return TextStyle(
      color: served ? Colors.green.shade400 : Colors.red.shade400,
      fontFamily: fontMulishSemiBold,
    );
  }
}

class TableItemSelectionActionBar extends StatefulWidget {
  const TableItemSelectionActionBar({
    super.key,
    required this.docId,
    required this.controller,
    this.action = TableItemSelectionAction.serve,
    this.showDeleteButton = true,
  });

  final String docId;
  final TableItemSelectionController controller;
  final TableItemSelectionAction action;
  final bool showDeleteButton;

  @override
  State<TableItemSelectionActionBar> createState() =>
      _TableItemSelectionActionBarState();
}

class _TableItemSelectionActionBarState
    extends State<TableItemSelectionActionBar> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller.listenableFor(widget.docId),
      builder: (context, _) {
        if (!widget.controller.isSelectionModeFor(widget.docId)) {
          return const SizedBox.shrink();
        }

        final count = widget.controller.selectedFor(widget.docId).length;
        final isPending = widget.action == TableItemSelectionAction.markPending;

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              if (widget.showDeleteButton)
                _actionIcon(
                  icon: Icons.delete_outline,
                  tooltip: count > 0 ? 'Delete ($count)' : 'Delete',
                  color: Colors.red.shade700,
                  onPressed: count == 0 || _submitting
                      ? null
                      : () => _confirmDeleteSelected(count),
                ),
              const Spacer(),
              _actionIcon(
                icon: Icons.close,
                tooltip: 'Cancel',
                color: Colors.grey.shade700,
                onPressed: _submitting ? null : widget.controller.cancel,
              ),
              const SizedBox(width: 12),
              _actionIcon(
                icon: isPending
                    ? Icons.pending_actions
                    : Icons.check_circle_outline,
                tooltip: isPending
                    ? (count > 0
                        ? 'Pending to serve ($count)'
                        : 'Pending to serve')
                    : (count > 0 ? 'Serve ($count)' : 'Serve'),
                color: isPending
                    ? const Color(0xFFf57c35)
                    : Colors.green.shade600,
                onPressed: count == 0 || _submitting
                    ? null
                    : () async {
                        setState(() => _submitting = true);
                        try {
                          final updated = isPending
                              ? await widget.controller.submitSelectedUnserved()
                              : await widget.controller.submitSelected();
                          if (!updated && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isPending
                                      ? 'Could not mark items as pending. '
                                          'Please try again.'
                                      : 'Could not mark items as served. '
                                          'Please try again.',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to update: ${e.toString()}',
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _submitting = false);
                        }
                      },
                showSpinner: _submitting,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteSelected(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete selected items?',
          style: TextStyle(
            fontFamily: fontMulishBold,
            fontSize: 17,
            color: Color(0xFF1A3A5C),
          ),
        ),
        content: Text(
          count == 1
              ? 'Are you sure you want to delete the selected item?'
              : 'Are you sure you want to delete $count selected items?',
          style: TextStyle(
            fontFamily: fontMulishRegular,
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final updated = await widget.controller.deleteSelected();
      if (!updated && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete items. Please try again.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
