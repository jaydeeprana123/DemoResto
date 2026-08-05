import 'package:smartKitchen/Styles/my_font.dart';
import 'package:smartKitchen/core/pwa/pwa_install_service.dart';
import 'package:smartKitchen/core/pwa/services/pwa_install_prompt_settings.dart';
import 'package:flutter/material.dart';

/// Shows a web install dialog when the browser reports the app is installable.
class PwaInstallHost extends StatefulWidget {
  const PwaInstallHost({super.key, required this.child});

  final Widget child;

  @override
  State<PwaInstallHost> createState() => _PwaInstallHostState();
}

class _PwaInstallHostState extends State<PwaInstallHost> {
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    if (!PwaInstallService.isSupported) return;

    PwaInstallService.instance.init(onInstallAvailable: _maybeShowInstallDialog);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowInstallDialog();
    });
  }

  @override
  void dispose() {
    if (PwaInstallService.isSupported) {
      PwaInstallService.instance.dispose();
    }
    super.dispose();
  }

  Future<void> _maybeShowInstallDialog() async {
    if (!mounted || _dialogVisible) return;

    final service = PwaInstallService.instance;
    if (!service.shouldPromptInstall) return;
    if (await PwaInstallPromptSettings.wasDismissed()) return;
    if (!mounted) return;

    final isIosManual = service.needsIosManualInstall;
    _dialogVisible = true;
    var installing = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> install() async {
              if (isIosManual) {
                await PwaInstallPromptSettings.markDismissed();
                if (context.mounted) Navigator.of(context).pop();
                return;
              }

              setDialogState(() => installing = true);
              try {
                final outcome =
                    await PwaInstallService.instance.promptInstall();
                if (!context.mounted) return;

                if (outcome == 'accepted') {
                  Navigator.of(context).pop();
                  return;
                }

                if (outcome == 'dismissed') {
                  await PwaInstallPromptSettings.markDismissed();
                }
                Navigator.of(context).pop();
              } finally {
                if (context.mounted) {
                  setDialogState(() => installing = false);
                }
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                isIosManual ? 'Add to Home Screen' : 'Install Smart Kitchen',
                style: const TextStyle(
                  fontFamily: fontMulishSemiBold,
                  fontSize: 18,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isIosManual
                        ? 'iPhone and iPad do not support one-tap install in Safari. '
                            'Add Smart Kitchen to your Home Screen to open it like a native app.'
                        : 'Install this app on your device for quick access. '
                            'It opens in its own window without browser controls, '
                            'just like a native app.',
                    style: const TextStyle(
                      fontFamily: fontMulishRegular,
                      fontSize: 15,
                    ),
                  ),
                  if (isIosManual) ...[
                    const SizedBox(height: 16),
                    _iosInstallStep(
                      icon: Icons.ios_share_rounded,
                      text: 'Tap the Share button in Safari',
                    ),
                    const SizedBox(height: 8),
                    _iosInstallStep(
                      icon: Icons.add_box_outlined,
                      text: 'Choose "Add to Home Screen"',
                    ),
                    const SizedBox(height: 8),
                    _iosInstallStep(
                      icon: Icons.check_circle_outline,
                      text: 'Tap Add, then open Smart Kitchen from your Home Screen',
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: installing
                      ? null
                      : () async {
                          await PwaInstallPromptSettings.markDismissed();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                  child: const Text(
                    'Not now',
                    style: TextStyle(fontFamily: fontMulishSemiBold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: installing ? null : install,
                  icon: isIosManual
                      ? const Icon(Icons.home_filled, size: 18)
                      : installing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    isIosManual
                        ? 'Got it'
                        : installing
                        ? 'Installing...'
                        : 'Install',
                    style: const TextStyle(fontFamily: fontMulishSemiBold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (mounted) {
      setState(() => _dialogVisible = false);
    }
  }

  Widget _iosInstallStep({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1A3A5C)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: fontMulishRegular,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
