import 'package:demo/features/shell/controllers/shell_controller.dart';
import 'package:demo/features/tables/controllers/dashboard_tab_controller.dart';
import 'package:demo/features/zomato/services/zomato_order_import_service.dart';
import 'package:demo/features/zomato/services/zomato_share_intent_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ZomatoShareImportListener extends StatefulWidget {
  const ZomatoShareImportListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<ZomatoShareImportListener> createState() =>
      _ZomatoShareImportListenerState();
}

class _ZomatoShareImportListenerState extends State<ZomatoShareImportListener> {
  Worker? _pendingWorker;
  var _processing = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;

    final shareService = Get.find<ZomatoShareIntentService>();
    _pendingWorker = ever<SharedZomatoImage?>(
      shareService.pendingImage,
      (_) => _processPendingShare(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processPendingShare();
    });
  }

  Future<void> _processPendingShare() async {
    if (_processing || kIsWeb || !mounted) return;

    final shareService = Get.find<ZomatoShareIntentService>();
    final pending = shareService.consumePending();
    if (pending == null) return;

    _processing = true;
    try {
      Get.find<ShellController>().changeTab(0);
      if (Get.isRegistered<DashboardTabController>()) {
        Get.find<DashboardTabController>().requestTab('Zomato');
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      await ZomatoOrderImportService.createOrderFromImage(
        context: context,
        bytes: pending.bytes,
        fileName: pending.fileName,
      );
      await shareService.resetIntent();
    } finally {
      _processing = false;
    }
  }

  @override
  void dispose() {
    _pendingWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
