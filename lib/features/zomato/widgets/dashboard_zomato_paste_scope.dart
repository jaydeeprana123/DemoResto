import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DashboardZomatoPasteScope extends StatelessWidget {
  const DashboardZomatoPasteScope({
    required this.enabled,
    required this.onPasteImage,
    required this.child,
    super.key,
  });

  final bool enabled;
  final Future<void> Function() onPasteImage;
  final Widget child;

  void _triggerPaste() {
    unawaited(onPasteImage());
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): _triggerPaste,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _triggerPaste,
      },
      child: Focus(
        autofocus: true,
        canRequestFocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final isPasteKey = event.logicalKey == LogicalKeyboardKey.keyV;
          final hasModifier = HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed;
          if (isPasteKey && hasModifier) {
            _triggerPaste();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: child,
      ),
    );
  }
}
