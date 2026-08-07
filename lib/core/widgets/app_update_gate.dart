import 'package:smartKitchen/core/services/app_update_service.dart';
import 'package:smartKitchen/core/widgets/app_update_dialog.dart';
import 'package:flutter/material.dart';

/// Runs a version check on startup and blocks the app when a force update
/// is required. Optional updates show a dismissible prompt over the app.
///
/// Placed in [MaterialApp.builder] (above Navigator), so the prompt is drawn
/// as a Stack overlay — never via [showDialog].
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
  }

  void _dismissOptionalUpdate() {
    setState(() => _optionalDismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    final updateInfo = _updateInfo;
    final isForceUpdate = updateInfo?.isForceUpdate == true;
    final showPrompt = !_checking &&
        updateInfo != null &&
        (isForceUpdate || !_optionalDismissed);

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: _checking || isForceUpdate || showPrompt,
          child: widget.child,
        ),
        if (_checking)
          const ColoredBox(
            color: Colors.white,
            child: Center(child: CircularProgressIndicator()),
          ),
        if (updateInfo != null && showPrompt)
          AppUpdatePrompt(
            updateInfo: updateInfo,
            onLater: isForceUpdate ? null : _dismissOptionalUpdate,
          ),
      ],
    );
  }
}
