import 'package:smartKitchen/Styles/my_font.dart';
import 'package:smartKitchen/features/kitchen/services/kitchen_preparation_view_index.dart';
import 'package:smartKitchen/features/kitchen/services/kitchen_cross_table_pending_index.dart';
import 'package:smartKitchen/features/kitchen/services/kitchen_order_tts_service.dart';
import 'package:smartKitchen/features/kitchen/services/kitchen_settings.dart';
import 'package:smartKitchen/features/kitchen/widgets/kitchen_theme.dart';
import 'package:smartKitchen/features/tables/repositories/table_item_served.dart';
import 'package:smartKitchen/features/tables/services/serve_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

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
    this.blinkingItemKeys = const {},
    this.blinkColor = const Color(0xFFE8F5E9),
    this.footerChildren = const [],
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
  final Set<String> blinkingItemKeys;
  final Color blinkColor;
  final List<Widget> footerChildren;

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

    if (Get.isRegistered<ServeNotificationService>()) {
      Get.find<ServeNotificationService>().suppressLocalServe(keys);
    }

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
          child: widget.layoutIsGrid ? _buildGridView() : _buildListView(),
        ),
        if (_selectionMode && !widget.servedTabActive) _buildSelectionBar(),
      ],
    );
  }

  Widget _buildItemBlock(
    KitchenPreparationItemGroup group, {
    required bool bordered,
  }) {
    final normalizedKey = KitchenCrossTablePendingIndex.normalizeItemName(
      group.itemName,
    );
    final isBlinking = widget.blinkingItemKeys.contains(normalizedKey);

    return _PreparationItemBlock(
      group: group,
      bordered: bordered,
      isBlinking: isBlinking,
      blinkColor: widget.blinkColor,
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
    if (widget.footerChildren.isEmpty) {
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

    return CustomScrollView(
      controller: widget.scrollController,
      restorationId: 'kitchen_preparation_orders_grid',
      cacheExtent: 3000,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (widget.groups.isNotEmpty)
          SliverPadding(
            padding: widget.padding,
            sliver: SliverToBoxAdapter(
              child: MasonryGridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: widget.crossAxisCount,
                mainAxisSpacing: widget.mainAxisSpacing,
                crossAxisSpacing: widget.crossAxisSpacing,
                itemCount: widget.groups.length,
                itemBuilder: (context, index) =>
                    _buildItemBlock(widget.groups[index], bordered: true),
              ),
            ),
          ),
        SliverPadding(
          padding: widget.padding,
          sliver: SliverToBoxAdapter(
            child: MasonryGridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: widget.crossAxisCount,
              mainAxisSpacing: widget.mainAxisSpacing,
              crossAxisSpacing: widget.crossAxisSpacing,
              itemCount: widget.footerChildren.length,
              itemBuilder: (context, index) => widget.footerChildren[index],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListView() {
    if (widget.footerChildren.isEmpty) {
      return ListView.separated(
        controller: widget.scrollController,
        restorationId: 'kitchen_preparation_orders_list',
        cacheExtent: 3000,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: widget.groups.length,
        separatorBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1, color: KitchenTheme.surfaceBorder),
        ),
        itemBuilder: (context, index) =>
            _buildItemBlock(widget.groups[index], bordered: false),
      );
    }

    final children = <Widget>[];
    for (var i = 0; i < widget.groups.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: KitchenTheme.surfaceBorder),
          ),
        );
      }
      children.add(_buildItemBlock(widget.groups[i], bordered: false));
    }
    if (widget.footerChildren.isNotEmpty && widget.groups.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1, color: KitchenTheme.surfaceBorder),
        ),
      );
    }
    for (var i = 0; i < widget.footerChildren.length; i++) {
      if (i > 0) {
        children.add(const SizedBox(height: 12));
      }
      children.add(widget.footerChildren[i]);
    }

    return ListView(
      controller: widget.scrollController,
      restorationId: 'kitchen_preparation_orders_list',
      cacheExtent: 3000,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: widget.padding,
      children: children,
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: KitchenTheme.surfaceElevated,
        border: Border(top: BorderSide(color: KitchenTheme.surfaceBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            '${_selectedLineKeys.length} selected',
            style: MyFont.semiBold(13, color: KitchenTheme.textOnDark),
          ),
          const Spacer(),
          _actionIcon(
            icon: Icons.close,
            tooltip: 'Cancel',
            color: KitchenTheme.accentMuted,
            onPressed: _submitting ? null : _cancelSelection,
          ),
          const SizedBox(width: 12),
          _actionIcon(
            icon: Icons.check_circle_outline,
            tooltip: _selectedLineKeys.isEmpty
                ? 'Serve'
                : 'Serve (${_selectedLineKeys.length})',
            color: KitchenTheme.kdsGreen,
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
        color: color.withValues(alpha: 0.14),
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
    required this.isBlinking,
    required this.blinkColor,
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
  final bool isBlinking;
  final Color blinkColor;
  final bool selectionMode;
  final Set<String> selectedLineKeys;
  final String Function(KitchenPreparationTableLine line) lineKey;
  final String Function(DateTime) formatRelativeTime;
  final ValueListenable<int> minuteTick;
  final ValueChanged<KitchenPreparationTableLine> onLineTap;
  final bool submitting;

  Widget _buildItemHeader() {
    final headerColor = KitchenTheme.headerForOrderKey(
      group.itemName,
      isZomato: false,
    );
    final titleColor = KitchenTheme.headerTitleColor(headerColor);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              group.itemName,
              style: MyFont.semiBold(15, color: titleColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: KitchenSettings.voiceAnnouncementEnabled,
            builder: (context, voiceEnabled, _) {
              if (!voiceEnabled || group.itemName.trim().isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Tooltip(
                  message: 'Speak order',
                  child: InkWell(
                    onTap: () {
                      KitchenOrderTtsService.instance.speakQtyAndName(
                        qty: group.totalQty,
                        name: group.itemName,
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Icon(
                        Icons.volume_up,
                        size: 20,
                        color: titleColor,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              '${group.totalQty}',
              style: MyFont.bold(12, color: const Color(0xFF1A1A1A)),
            ),
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

    final headerColor = KitchenTheme.headerForOrderKey(
      group.itemName,
      isZomato: false,
    );

    if (!bordered) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isBlinking ? blinkColor : KitchenTheme.cardBody,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isBlinking
                ? headerColor.withValues(alpha: 0.55)
                : Colors.grey.shade200.withValues(alpha: 0.85),
          ),
          boxShadow: KitchenTheme.cardShadows(
            accentColor: headerColor,
            emphasize: isBlinking,
          ),
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isBlinking ? blinkColor : KitchenTheme.cardBody,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isBlinking
              ? headerColor.withValues(alpha: 0.55)
              : Colors.grey.shade200.withValues(alpha: 0.85),
        ),
        boxShadow: KitchenTheme.cardShadows(
          accentColor: headerColor,
          emphasize: isBlinking,
        ),
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
            ? KitchenTheme.kdsGreen.withValues(alpha: 0.1)
            : isSelected
            ? KitchenTheme.kdsBlue.withValues(alpha: 0.1)
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
                        ? KitchenTheme.kdsBlue
                        : KitchenTheme.accentMuted,
                  ),
                  const SizedBox(width: 6),
                ] else if (served) ...[
                  Icon(Icons.check, size: 15, color: KitchenTheme.kdsGreen),
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
                                13,
                                color: served
                                    ? KitchenTheme.servedGreen
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
                                12,
                                color: served
                                    ? KitchenTheme.kdsGreen.withValues(
                                        alpha: 0.7,
                                      )
                                    : KitchenTheme.accentMuted,
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
                                ? KitchenTheme.kdsGreen.withValues(alpha: 0.7)
                                : KitchenTheme.delayedText,
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
            ? KitchenTheme.kdsGreen.withValues(alpha: 0.12)
            : KitchenTheme.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '×${line.qty}',
        style: MyFont.bold(
          12,
          color: served ? KitchenTheme.servedGreen : KitchenTheme.orange,
        ),
      ),
    );
  }
}
