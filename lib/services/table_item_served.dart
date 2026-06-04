import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../Styles/my_font.dart';

/// Item-level served tracking for kitchen swipe and dashboard display.
class TableItemServed {
  static bool isServed(Map<String, dynamic> item) => item['isServed'] == true;

  static bool allServed(Iterable<Map<String, dynamic>> items) {
    final list = items.toList();
    if (list.isEmpty) return false;
    return list.every(isServed);
  }

  static bool allServedInGroups(List<List<Map<String, dynamic>>> groups) {
    return allServed(groups.expand((g) => g));
  }

  static Future<void> markItemServed({
    required String docId,
    required int groupIndex,
    required int itemIndexInGroup,
  }) async {
    await markItemsServedByCoords([
      (docId: docId, groupIndex: groupIndex, itemIndexInGroup: itemIndexInGroup),
    ]);
  }

  /// Batch mark multiple items served. Returns true if at least one item updated.
  static Future<bool> markItemsServed(Iterable<dynamic> keys) async {
    final coords = keys
        .map(
          (k) => (
            docId: k.docId as String,
            groupIndex: k.groupIndex as int,
            itemIndexInGroup: k.itemIndexInGroup as int,
          ),
        )
        .toList();
    return markItemsServedByCoords(coords);
  }

  static Future<bool> markItemsServedByCoords(
    List<({String docId, int groupIndex, int itemIndexInGroup})> coords,
  ) async {
    if (coords.isEmpty) return false;

    final byDoc = <String, List<({int groupIndex, int itemIndexInGroup})>>{};
    for (final c in coords) {
      byDoc.putIfAbsent(c.docId, () => []).add((
        groupIndex: c.groupIndex,
        itemIndexInGroup: c.itemIndexInGroup,
      ));
    }

    var anyUpdated = false;
    for (final entry in byDoc.entries) {
      if (await _markItemsInDoc(entry.key, entry.value)) {
        anyUpdated = true;
      }
    }
    return anyUpdated;
  }

  static int _readGroupIndex(Map<String, dynamic> item) {
    final raw = item['groupIndex'];
    if (raw is num) return raw.toInt();
    return 0;
  }

  static Future<bool> _markItemsInDoc(
    String docId,
    List<({int groupIndex, int itemIndexInGroup})> targets,
  ) async {
    final docRef = FirebaseFirestore.instance.collection('tables').doc(docId);
    final snap = await docRef.get();
    if (!snap.exists) return false;

    final rawItems = snap.data()?['items'] as List<dynamic>? ?? [];
    if (rawItems.isEmpty) return false;

    final items = rawItems
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final groupIndices = <int, List<int>>{};
    for (var i = 0; i < items.length; i++) {
      final gi = _readGroupIndex(items[i]);
      groupIndices.putIfAbsent(gi, () => []).add(i);
    }

    var changed = false;
    for (final target in targets) {
      final indices = groupIndices[target.groupIndex];
      if (indices == null) continue;
      if (target.itemIndexInGroup < 0 ||
          target.itemIndexInGroup >= indices.length) {
        continue;
      }
      final targetIndex = indices[target.itemIndexInGroup];
      if (isServed(items[targetIndex])) continue;

      items[targetIndex]['isServed'] = true;
      items[targetIndex]['servedAt'] = Timestamp.now();
      changed = true;
    }

    if (!changed) return false;

    await docRef.update({
      'items': items,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  /// Compact row: ✓ 2x Item Name (served) or □/✓ during selection mode.
  static Widget buildItemLine({
    required int qty,
    required String name,
    required bool served,
    String? remarks,
    required Widget qtyBadge,
    required TextStyle nameStyle,
    TextStyle? remarksStyle,
    bool showSelectionIndicator = false,
    bool selectionSelected = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showSelectionIndicator)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              selectionSelected ? Icons.check : Icons.crop_square,
              size: 18,
              color: selectionSelected
                  ? Colors.green.shade600
                  : Colors.grey.shade500,
            ),
          )
        else if (served) ...[
          Icon(Icons.check, size: 16, color: Colors.green.shade600),
          const SizedBox(width: 4),
        ],
        qtyBadge,
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: nameStyle.copyWith(
                  color: served ? Colors.green.shade700 : nameStyle.color,
                ),
              ),
              if (remarks != null && remarks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '* $remarks',
                    style: (remarksStyle ?? nameStyle).copyWith(
                      fontSize: 12,
                      color: served
                          ? Colors.green.shade400
                          : remarksStyle?.color,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Swipe item left to reveal a Served action button (iOS-style).
class ServeSwipeItem extends StatefulWidget {
  const ServeSwipeItem({
    super.key,
    required this.itemKey,
    required this.child,
    required this.onServe,
  });

  final Key itemKey;
  final Widget child;
  final Future<void> Function() onServe;

  @override
  State<ServeSwipeItem> createState() => _ServeSwipeItemState();
}

class _ServeSwipeItemState extends State<ServeSwipeItem> {
  double _dragOffset = 0;
  bool _busy = false;
  static const _actionWidth = 84.0;
  static const _dragSlop = 6.0;

  Offset? _pointerStart;
  bool _horizontalDrag = false;
  ScrollHoldController? _scrollHold;

  @override
  void dispose() {
    _releaseScrollHold();
    super.dispose();
  }

  Future<void> _triggerServe() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onServe();
    } finally {
      if (mounted) {
        setState(() {
          _dragOffset = 0;
          _busy = false;
        });
      }
    }
  }

  void _snapOpen(bool open) {
    setState(() => _dragOffset = open ? -_actionWidth : 0);
  }

  void _releaseScrollHold() {
    _scrollHold?.cancel();
    _scrollHold = null;
  }

  void _holdScroll() {
    if (_scrollHold != null) return;
    final position = Scrollable.maybeOf(context)?.position;
    if (position != null) {
      _scrollHold = position.hold(() {});
    }
  }

  void _resetPointerTracking() {
    _releaseScrollHold();
    _pointerStart = null;
    _horizontalDrag = false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_busy) return;
    _pointerStart = event.position;
    _horizontalDrag = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_busy || _pointerStart == null) return;

    final totalDelta = event.position - _pointerStart!;

    if (!_horizontalDrag) {
      if (totalDelta.dx.abs() < _dragSlop && totalDelta.dy.abs() < _dragSlop) {
        return;
      }
      if (totalDelta.dx.abs() <= totalDelta.dy.abs()) {
        _resetPointerTracking();
        return;
      }
      _horizontalDrag = true;
      _holdScroll();
    }

    setState(() {
      _dragOffset = (_dragOffset + event.delta.dx).clamp(-_actionWidth, 0.0);
    });
  }

  void _onPointerEnd() {
    if (_busy) {
      _resetPointerTracking();
      return;
    }

    if (_horizontalDrag) {
      _snapOpen(-_dragOffset >= _actionWidth / 2);
    }

    _resetPointerTracking();
  }

  void _onForegroundTap() {
    if (_busy || _horizontalDrag) return;
    if (_dragOffset != 0) _snapOpen(false);
  }

  @override
  Widget build(BuildContext context) {
    final cursor = kIsWeb && _dragOffset == 0
        ? SystemMouseCursors.grab
        : MouseCursor.defer;

    return SelectionContainer.disabled(
      child: ClipRRect(
        key: widget.itemKey,
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              top: 0,
              right: 0,
              bottom: 8,
              width: _actionWidth,
              child: ColoredBox(color: Colors.green.shade600),
            ),
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: (_) => _onPointerEnd(),
              onPointerCancel: (_) => _onPointerEnd(),
              child: MouseRegion(
                cursor: cursor,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _onForegroundTap,
                  child: Transform.translate(
                    offset: Offset(_dragOffset, 0),
                    child: Material(
                      color: Colors.white,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              bottom: 8,
              width: _actionWidth,
              child: IgnorePointer(
                ignoring: _dragOffset == 0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _busy ? null : _triggerServe,
                    mouseCursor: SystemMouseCursors.click,
                    child: Center(
                      child: Text(
                        'Served',
                        style: TextStyle(
                          fontFamily: fontMulishBold,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
