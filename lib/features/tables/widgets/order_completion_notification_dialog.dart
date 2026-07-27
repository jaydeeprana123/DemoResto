import 'dart:async';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/core/utils/table_name_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Popup shown on the Admin Dashboard when staff notifies order completion.
class OrderCompletionNotificationDialog {
  OrderCompletionNotificationDialog._();

  static const _accent = Color(0xFFf57c35);
  static const _autoCloseDuration = Duration(seconds: 8);
  static const _routeName = 'order_completion_notification_alert';
  static const _bellAsset = 'sounds/complete_bell.mp3';

  static Future<void> show(
    BuildContext context, {
    required String tableName,
    required String staffName,
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
        return _OrderCompletionNotificationDialogBody(
          tableName: tableName,
          staffName: staffName,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
}

class _OrderCompletionNotificationDialogBody extends StatefulWidget {
  const _OrderCompletionNotificationDialogBody({
    required this.tableName,
    required this.staffName,
  });

  final String tableName;
  final String staffName;

  @override
  State<_OrderCompletionNotificationDialogBody> createState() =>
      _OrderCompletionNotificationDialogBodyState();
}

class _OrderCompletionNotificationDialogBodyState
    extends State<_OrderCompletionNotificationDialogBody> {
  Timer? _autoCloseTimer;
  final AudioPlayer _bellPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    unawaited(_playCompleteBell());
    _autoCloseTimer = Timer(
      OrderCompletionNotificationDialog._autoCloseDuration,
      () {
        if (!mounted) return;
        Navigator.of(context).pop();
      },
    );
  }

  Future<void> _playCompleteBell() async {
    try {
      await _bellPlayer.stop();
      await _bellPlayer.setReleaseMode(ReleaseMode.stop);
      await _bellPlayer.setPlaybackRate(1.0);
      await _bellPlayer.play(
        AssetSource(OrderCompletionNotificationDialog._bellAsset),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Order completion bell failed: $e');
      }
    }
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    unawaited(_bellPlayer.dispose());
    super.dispose();
  }

  void _close() {
    _autoCloseTimer?.cancel();
    unawaited(_bellPlayer.stop());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final staff = widget.staffName.trim().isEmpty
        ? 'Staff'
        : widget.staffName.trim();
    final isTakeAway = isTakeAwayOrderName(widget.tableName);

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
              child: Material(
                color: Colors.white,
                elevation: 12,
                shadowColor: Colors.black.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        decoration: const BoxDecoration(
                          color: OrderCompletionNotificationDialog._accent,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isTakeAway
                                  ? Icons.shopping_bag_outlined
                                  : Icons.receipt_long_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Order Completed',
                                style: TextStyle(
                                  fontFamily: fontMulishSemiBold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _close,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                              ),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.tableName} order is completed. Please generate the bill.',
                              style: const TextStyle(
                                fontFamily: fontMulishSemiBold,
                                fontSize: 15,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Notified by: $staff',
                              style: TextStyle(
                                fontFamily: fontMulishRegular,
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
