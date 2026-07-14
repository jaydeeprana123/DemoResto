import 'dart:async';
import 'dart:js' as js;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Bridges the browser PWA install APIs exposed from [web/index.html].
class PwaInstallService {
  PwaInstallService._();

  static final PwaInstallService instance = PwaInstallService._();

  static bool get isSupported => true;

  void Function()? _onInstallAvailable;
  void Function(html.Event)? _availableListener;
  void Function(html.Event)? _installedListener;

  bool _callBool(String functionName) {
    try {
      return js.context.callMethod(functionName) == true;
    } catch (_) {
      return false;
    }
  }

  bool get isStandalone => _callBool('flutterPwaIsStandalone');

  bool get canInstall => _callBool('flutterPwaCanInstall');

  bool get needsIosManualInstall => _callBool('flutterPwaNeedsIosInstall');

  bool get shouldPromptInstall => !isStandalone && (canInstall || needsIosManualInstall);

  void init({void Function()? onInstallAvailable}) {
    _onInstallAvailable = onInstallAvailable;

    _availableListener ??= (_) => _onInstallAvailable?.call();
    _installedListener ??= (_) => _onInstallAvailable?.call();

    html.window.addEventListener('pwa-install-available', _availableListener!);
    html.window.addEventListener('pwa-installed', _installedListener!);

    if (shouldPromptInstall) {
      scheduleMicrotask(() => _onInstallAvailable?.call());
    }
  }

  Future<String?> promptInstall() async {
    if (!canInstall) return null;

    final completer = Completer<String?>();
    void Function(html.Event)? resultListener;

    resultListener = (html.Event event) {
      final listener = resultListener;
      if (listener != null) {
        html.window.removeEventListener('pwa-install-result', listener);
      }
      final customEvent = event as html.CustomEvent;
      if (!completer.isCompleted) {
        completer.complete(customEvent.detail?.toString());
      }
    };

    html.window.addEventListener('pwa-install-result', resultListener);
    js.context.callMethod('flutterPwaRequestInstall');

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        final listener = resultListener;
        if (listener != null) {
          html.window.removeEventListener('pwa-install-result', listener);
        }
        return null;
      },
    );
  }

  void dispose() {
    if (_availableListener != null) {
      html.window.removeEventListener(
        'pwa-install-available',
        _availableListener!,
      );
    }
    if (_installedListener != null) {
      html.window.removeEventListener('pwa-installed', _installedListener!);
    }
    _availableListener = null;
    _installedListener = null;
    _onInstallAvailable = null;
  }
}
