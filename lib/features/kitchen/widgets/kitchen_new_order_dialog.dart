import 'dart:async';
import 'dart:ui';

import 'package:smartKitchen/Styles/my_font.dart';
import 'package:smartKitchen/core/utils/table_name_utils.dart';
import 'package:smartKitchen/features/kitchen/widgets/kitchen_theme.dart';
import 'package:smartKitchen/features/tables/repositories/table_item_served.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Brief popup shown when a brand-new kitchen order arrives.
class KitchenNewOrderDialog {
  KitchenNewOrderDialog._();

  static const _autoCloseDuration = Duration(seconds: 5);
  static const _routeName = 'kitchen_new_order_alert';

  static Future<void> show(
    BuildContext context, {
    required String tableName,
    required List<Map<String, dynamic>> items,
    required bool isZomato,
    required DateTime orderTime,
    String? screenshotUrl,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.popUntil(
      (route) => route.settings.name != _routeName,
    );

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      routeSettings: const RouteSettings(name: _routeName),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _KitchenNewOrderDialogBody(
          tableName: tableName,
          items: items,
          isZomato: isZomato,
          orderTime: orderTime,
          screenshotUrl: screenshotUrl,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
}

class _KitchenNewOrderDialogBody extends StatefulWidget {
  const _KitchenNewOrderDialogBody({
    required this.tableName,
    required this.items,
    required this.isZomato,
    required this.orderTime,
    this.screenshotUrl,
  });

  final String tableName;
  final List<Map<String, dynamic>> items;
  final bool isZomato;
  final DateTime orderTime;
  final String? screenshotUrl;

  @override
  State<_KitchenNewOrderDialogBody> createState() =>
      _KitchenNewOrderDialogBodyState();
}

class _KitchenNewOrderDialogBodyState extends State<_KitchenNewOrderDialogBody> {
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    _autoCloseTimer = Timer(KitchenNewOrderDialog._autoCloseDuration, () {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  void _close() {
    _autoCloseTimer?.cancel();
    Navigator.of(context).pop();
  }

  String _relativeTime(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inSeconds < 60) return 'just now';
    if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins min${mins > 1 ? 's' : ''} ago';
    }
    return DateFormat('hh:mm a').format(time);
  }

  List<Map<String, dynamic>> get _parsedItems {
    final parsed = <Map<String, dynamic>>[];
    for (final raw in widget.items) {
      final item = TableItemServed.asItemMap(raw);
      if (item == null) continue;
      final name = item['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      parsed.add(item);
    }
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.opaque,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: _buildDialogCard(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogCard(BuildContext context) {
    final headerColor = KitchenTheme.headerForOrderTable(
      widget.tableName,
      isZomato: widget.isZomato,
    );
    final titleColor = KitchenTheme.headerTitleColor(headerColor);
    final parsedItems = _parsedItems;
    final hasScreenshot = widget.screenshotUrl?.trim().isNotEmpty == true;

    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isZomato
                        ? Icons.delivery_dining_rounded
                        : isTakeAwayOrderName(widget.tableName)
                        ? Icons.shopping_bag_outlined
                        : Icons.table_restaurant_rounded,
                    color: titleColor,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Order Received',
                          style: TextStyle(
                            fontFamily: fontMulishSemiBold,
                            fontSize: 16,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.tableName,
                          style: TextStyle(
                            fontFamily: fontMulishBold,
                            fontSize: 18,
                            color: titleColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _close,
                    icon: Icon(Icons.close_rounded, color: titleColor),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _relativeTime(widget.orderTime),
                    style: TextStyle(
                      fontFamily: fontMulishRegular,
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.isZomato && parsedItems.isEmpty && hasScreenshot)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: KitchenTheme.zomatoRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: KitchenTheme.zomatoRed.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              widget.screenshotUrl!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 56,
                                height: 56,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image_not_supported),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Zomato order screenshot received',
                              style: TextStyle(
                                fontFamily: fontMulishSemiBold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (parsedItems.isEmpty)
                    const Text(
                      'Order details will appear shortly.',
                      style: TextStyle(
                        fontFamily: fontMulishRegular,
                        fontSize: 14,
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: parsedItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = parsedItems[index];
                          final name = item['name']?.toString() ?? '';
                          final qty = (item['qty'] as num?)?.toInt() ?? 1;
                          final remarks = item['remarks']?.toString().trim();
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: KitchenTheme.kdsGreen.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$qty',
                                  style: const TextStyle(
                                    fontFamily: fontMulishBold,
                                    fontSize: 13,
                                    color: KitchenTheme.kdsGreen,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontFamily: fontMulishSemiBold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (remarks != null && remarks.isNotEmpty)
                                      Text(
                                        remarks,
                                        style: TextStyle(
                                          fontFamily: fontMulishRegular,
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
