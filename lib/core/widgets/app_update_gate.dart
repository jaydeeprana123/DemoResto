import 'package:smartKitchen/core/services/app_update_service.dart';
import 'package:smartKitchen/core/widgets/app_update_dialog.dart';
import 'package:flutter/material.dart';

/// Runs a version check on startup and blocks the app when a force update
/// is required. Optional updates show a dismissible dialog over the app.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  bool _checking = true;
  AppUpdateInfo? _updateInfo;
  bool _optionalDismissed = false;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    _runVersionCheck();
  }

  Future<void> _runVersionCheck() async {
    final updateInfo = await AppUpdateService.checkForUpdate();
    if (!mounted) return;

    setState(() {
      _checking = false;
      _updateInfo = updateInfo;
    });

    if (updateInfo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showUpdateDialogIfNeeded();
      });
    }
  }

  Future<void> _showUpdateDialogIfNeeded() async {
    if (!mounted || _dialogVisible) return;

    final updateInfo = _updateInfo;
    if (updateInfo == null) return;
    if (!updateInfo.isForceUpdate && _optionalDismissed) return;

    _dialogVisible = true;
    await showAppUpdateDialog(context, updateInfo: updateInfo);

    if (!mounted) return;
    setState(() {
      _dialogVisible = false;
      if (!updateInfo.isForceUpdate) {
        _optionalDismissed = true;
      }
    });

    if (updateInfo.isForceUpdate && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showUpdateDialogIfNeeded();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final updateInfo = _updateInfo;
    final isForceUpdate =
        updateInfo != null && updateInfo.isForceUpdate;

    if (isForceUpdate) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          body: Center(
            child: _dialogVisible
                ? const SizedBox.shrink()
                : const CircularProgressIndicator(),
          ),
        ),
      );
    }

    return widget.child;
  }
}
