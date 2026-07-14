/// No-op PWA install helpers on non-web platforms.
class PwaInstallService {
  PwaInstallService._();

  static final PwaInstallService instance = PwaInstallService._();

  static bool get isSupported => false;

  bool get isStandalone => false;

  bool get canInstall => false;

  bool get needsIosManualInstall => false;

  bool get shouldPromptInstall => false;

  void init({void Function()? onInstallAvailable}) {}

  Future<String?> promptInstall() async => null;

  void dispose() {}
}
