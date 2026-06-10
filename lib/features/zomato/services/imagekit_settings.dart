import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/core/services/restaurant_session.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImageKitSettings {
  ImageKitSettings._();

  static const _prefsPublicKey = 'imagekit_public_key';
  static const _prefsPrivateKey = 'imagekit_private_key';
  static const _prefsUrlEndpoint = 'imagekit_url_endpoint';

  /// Older builds accidentally used credential strings as preference keys.
  static const _legacyPrefsPublicKey = 'public_7Zs+SRSVWNRokWUgtxUq9q5iWZM=';
  static const _legacyPrefsPrivateKey = 'private_StvLpn0g1LLFtDo9OWHudimZxRU=';
  static const _legacyPrefsUrlEndpoint = 'https://ik.imagekit.io/tet01w2tu';

  static ImageKitConfig? _memoryCache;

  static RestaurantSession get _session => Get.find<RestaurantSession>();

  static String get _restaurantScope =>
      _session.profile.value?.restaurantId ?? FirestorePaths.legacyRestaurantId;

  static Future<ImageKitConfig> load() async {
    if (_memoryCache != null && _memoryCache!.isValid) {
      return _memoryCache!;
    }

    final fromPrefs = await _loadFromPrefs();
    if (fromPrefs.isValid) {
      _memoryCache = fromPrefs;
      await _saveToCloud(fromPrefs);
      return fromPrefs;
    }

    final fromRestaurant = await _loadFromRestaurantDoc();
    if (fromRestaurant.isValid) {
      _memoryCache = fromRestaurant;
      await _saveToPrefs(fromRestaurant);
      return fromRestaurant;
    }

    final fromSettingsDoc = await _loadFromSettingsDoc();
    if (fromSettingsDoc.isValid) {
      _memoryCache = fromSettingsDoc;
      await _saveToCloud(fromSettingsDoc);
      await _saveToPrefs(fromSettingsDoc);
      return fromSettingsDoc;
    }

    return const ImageKitConfig(
      publicKey: '',
      privateKey: '',
      urlEndpoint: '',
    );
  }

  static Future<void> save(ImageKitConfig config) async {
    final normalized = ImageKitConfig(
      publicKey: config.publicKey.trim(),
      privateKey: config.privateKey.trim(),
      urlEndpoint: config.urlEndpoint.trim(),
    );
    if (!normalized.isValid) {
      throw ArgumentError('ImageKit config is incomplete.');
    }

    _memoryCache = normalized;
    await _saveToCloud(normalized);
    await _saveToPrefs(normalized);
  }

  static Future<bool> isConfigured() async {
    final config = await load();
    return config.isValid;
  }

  static Future<ImageKitConfig> _loadFromRestaurantDoc() async {
    final restaurantId = _session.profile.value?.restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      return const ImageKitConfig.empty();
    }

    try {
      final snap = await FirestorePaths.restaurant(restaurantId).get();
      if (!snap.exists) return const ImageKitConfig.empty();
      return _fromRestaurantMap(snap.data() ?? {});
    } catch (_) {
      return const ImageKitConfig.empty();
    }
  }

  static Future<ImageKitConfig> _loadFromSettingsDoc() async {
    try {
      final snap = await FirestorePaths.scopedDoc('settings', 'imagekit').get();
      if (!snap.exists) return const ImageKitConfig.empty();
      return _fromMap(snap.data() ?? {});
    } catch (_) {
      return const ImageKitConfig.empty();
    }
  }

  static Future<void> _saveToCloud(ImageKitConfig config) async {
    final restaurantId = _session.profile.value?.restaurantId;
    if (restaurantId != null && restaurantId.isNotEmpty) {
      await FirestorePaths.restaurant(restaurantId).set(
        {
          'imagekitPublicKey': config.publicKey,
          'imagekitPrivateKey': config.privateKey,
          'imagekitUrlEndpoint': config.urlEndpoint,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return;
    }

    await FirestorePaths.scopedDoc('settings', 'imagekit').set(
      {
        'publicKey': config.publicKey,
        'privateKey': config.privateKey,
        'urlEndpoint': config.urlEndpoint,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<ImageKitConfig> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final scope = _restaurantScope;

    final publicKey = _readNonEmpty(prefs, _scopedKey(_prefsPublicKey, scope)) ??
        _readNonEmpty(prefs, _prefsPublicKey) ??
        _readNonEmpty(prefs, _legacyPrefsPublicKey);
    final privateKey =
        _readNonEmpty(prefs, _scopedKey(_prefsPrivateKey, scope)) ??
            _readNonEmpty(prefs, _prefsPrivateKey) ??
            _readNonEmpty(prefs, _legacyPrefsPrivateKey);
    final urlEndpoint =
        _readNonEmpty(prefs, _scopedKey(_prefsUrlEndpoint, scope)) ??
            _readNonEmpty(prefs, _prefsUrlEndpoint) ??
            _readNonEmpty(prefs, _legacyPrefsUrlEndpoint);

    return ImageKitConfig(
      publicKey: publicKey ?? '',
      privateKey: privateKey ?? '',
      urlEndpoint: urlEndpoint ?? '',
    );
  }

  static Future<void> _saveToPrefs(ImageKitConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final scope = _restaurantScope;

    await prefs.setString(_scopedKey(_prefsPublicKey, scope), config.publicKey);
    await prefs.setString(_scopedKey(_prefsPrivateKey, scope), config.privateKey);
    await prefs.setString(
      _scopedKey(_prefsUrlEndpoint, scope),
      config.urlEndpoint,
    );

    // Keep unscoped keys too so older builds / other platforms still find them.
    await prefs.setString(_prefsPublicKey, config.publicKey);
    await prefs.setString(_prefsPrivateKey, config.privateKey);
    await prefs.setString(_prefsUrlEndpoint, config.urlEndpoint);
  }

  static String _scopedKey(String base, String scope) => '${base}_$scope';

  static String? _readNonEmpty(SharedPreferences prefs, String key) {
    final value = prefs.getString(key)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static ImageKitConfig _fromRestaurantMap(Map<String, dynamic> data) {
    return ImageKitConfig(
      publicKey: data['imagekitPublicKey']?.toString().trim() ?? '',
      privateKey: data['imagekitPrivateKey']?.toString().trim() ?? '',
      urlEndpoint: data['imagekitUrlEndpoint']?.toString().trim() ?? '',
    );
  }

  static ImageKitConfig _fromMap(Map<String, dynamic> data) {
    return ImageKitConfig(
      publicKey: data['publicKey']?.toString().trim() ?? '',
      privateKey: data['privateKey']?.toString().trim() ?? '',
      urlEndpoint: data['urlEndpoint']?.toString().trim() ?? '',
    );
  }
}

class ImageKitConfig {
  const ImageKitConfig({
    required this.publicKey,
    required this.privateKey,
    required this.urlEndpoint,
  });

  const ImageKitConfig.empty()
      : publicKey = '',
        privateKey = '',
        urlEndpoint = '';

  final String publicKey;
  final String privateKey;
  final String urlEndpoint;

  bool get isValid =>
      publicKey.isNotEmpty && privateKey.isNotEmpty && urlEndpoint.isNotEmpty;

  List<String> get missingFields {
    final missing = <String>[];
    if (publicKey.isEmpty) missing.add('Public key');
    if (privateKey.isEmpty) missing.add('Private key');
    if (urlEndpoint.isEmpty) missing.add('URL endpoint');
    return missing;
  }
}
