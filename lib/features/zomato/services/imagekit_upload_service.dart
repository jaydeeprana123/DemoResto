import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:demo/core/network/ssl_error_utils.dart';
import 'package:demo/features/zomato/services/imagekit_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ImageKitUploadService {
  ImageKitUploadService._();

  static const _uploadUrl = 'https://upload.imagekit.io/api/v1/files/upload';
  static const _filesApiUrl = 'https://api.imagekit.io/v1/files';

  static Future<ImageKitUploadResult> uploadScreenshot({
    required Uint8List bytes,
    required String fileName,
    String folder = '/zomato-orders',
  }) async {
    return uploadFile(
      bytes: bytes,
      fileName: fileName,
      folder: folder,
    );
  }

  static Future<ImageKitUploadResult> uploadBillPdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    return uploadFile(
      bytes: bytes,
      fileName: fileName,
      folder: '/bill-receipts',
    );
  }

  static Future<ImageKitUploadResult> uploadFile({
    required Uint8List bytes,
    required String fileName,
    String folder = '/uploads',
  }) async {
    var config = await ImageKitSettings.load();
    if (!config.isValid) {
      throw _notConfiguredError(config);
    }

    return _uploadWithAuthRetry(
      config: config,
      bytes: bytes,
      fileName: fileName,
      folder: folder,
    );
  }

  /// If saved keys fail auth, retry once with built-in defaults.
  static Future<ImageKitUploadResult> _uploadWithAuthRetry({
    required ImageKitConfig config,
    required Uint8List bytes,
    required String fileName,
    required String folder,
  }) async {
    try {
      return await _uploadDirect(
        config: config,
        bytes: bytes,
        fileName: fileName,
        folder: folder,
      );
    } catch (e) {
      if (!_isAuthError(e)) rethrow;
      ImageKitSettings.clearCache();
      final defaults = await ImageKitSettings.resetToDefaults();
      return _uploadDirect(
        config: defaults,
        bytes: bytes,
        fileName: fileName,
        folder: folder,
      );
    }
  }

  static bool _isAuthError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('cannot be authenticated') ||
        message.contains('(403)') ||
        message.contains('missing authorization') ||
        message.contains('invalid signature');
  }

  static Future<ImageKitUploadResult> _uploadDirect({
    required ImageKitConfig config,
    required Uint8List bytes,
    required String fileName,
    required String folder,
  }) async {
    if (kIsWeb) {
      return _uploadClientSide(
        config: config,
        bytes: bytes,
        fileName: fileName,
        folder: folder,
      );
    }

    return _uploadServerSide(
      config: config,
      bytes: bytes,
      fileName: fileName,
      folder: folder,
    );
  }

  /// Browser uploads must use token/signature auth — Basic Auth is blocked by CORS.
  static Future<ImageKitUploadResult> _uploadClientSide({
    required ImageKitConfig config,
    required Uint8List bytes,
    required String fileName,
    required String folder,
  }) async {
    final safeName = _safeFileName(fileName);
    final token = _generateUploadToken();
    final expire =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 2400;
    final signature = _signUpload(token, expire, config.privateKey);

    final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
    request.fields['fileName'] = safeName;
    request.fields['folder'] = _normalizeFolder(folder);
    request.fields['useUniqueFileName'] = 'true';
    request.fields['publicKey'] = config.publicKey;
    request.fields['token'] = token;
    request.fields['expire'] = expire.toString();
    request.fields['signature'] = signature;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: safeName,
        contentType: _mediaTypeForFileName(safeName),
      ),
    );

    return _sendUploadRequest(request);
  }

  /// Native/desktop upload using private key Basic Auth.
  static Future<ImageKitUploadResult> _uploadServerSide({
    required ImageKitConfig config,
    required Uint8List bytes,
    required String fileName,
    required String folder,
  }) async {
    final safeName = _safeFileName(fileName);
    final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
    request.headers['Authorization'] = 'Basic ${base64Encode(
      utf8.encode('${config.privateKey}:'),
    )}';
    request.fields['fileName'] = safeName;
    request.fields['folder'] = _normalizeFolder(folder);
    request.fields['useUniqueFileName'] = 'true';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: safeName,
        contentType: _mediaTypeForFileName(safeName),
      ),
    );

    return _sendUploadRequest(request);
  }

  static Future<ImageKitUploadResult> _sendUploadRequest(
    http.MultipartRequest request,
  ) async {
    try {
      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_parseUploadError(response.statusCode, body));
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final url = decoded['url']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('ImageKit upload did not return a URL.');
      }
      return ImageKitUploadResult(
        url: url,
        fileId: decoded['fileId']?.toString() ?? '',
        filePath: decoded['filePath']?.toString() ?? '',
      );
    } catch (e) {
      if (SslErrorUtils.isCertificateVerifyFailed(e)) {
        throw Exception(SslErrorUtils.userMessage(e));
      }
      rethrow;
    }
  }

  /// Deletes a Zomato screenshot from ImageKit when the order is served/completed.
  /// Failures are ignored so Firestore cleanup can still proceed.
  static Future<void> deleteScreenshot({
    String? fileId,
    String? screenshotUrl,
  }) async {
    final config = await ImageKitSettings.load();
    if (!config.isValid) return;

    try {
      final resolvedId = await _resolveFileId(
        config: config,
        fileId: fileId,
        screenshotUrl: screenshotUrl,
      );
      if (resolvedId == null || resolvedId.isEmpty) return;

      final response = await http.delete(
        Uri.parse('$_filesApiUrl/$resolvedId'),
        headers: _basicAuthHeaders(config.privateKey),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) return;
      if (response.statusCode == 404) return;
    } catch (_) {
      // Best-effort cleanup — do not block order removal.
    }
  }

  static Future<String?> _resolveFileId({
    required ImageKitConfig config,
    String? fileId,
    String? screenshotUrl,
  }) async {
    final trimmedId = fileId?.trim();
    if (trimmedId != null && trimmedId.isNotEmpty) return trimmedId;

    final filePath = _filePathFromScreenshotUrl(
      config.urlEndpoint,
      screenshotUrl,
    );
    if (filePath == null) return null;

    final slash = filePath.lastIndexOf('/');
    if (slash <= 0) return null;
    final folder = filePath.substring(0, slash);
    final name = filePath.substring(slash + 1);

    final uri = Uri.parse(_filesApiUrl).replace(
      queryParameters: {
        'path': folder,
        'name': name,
        'limit': '1',
      },
    );
    final response = await http.get(uri, headers: _basicAuthHeaders(config.privateKey));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final decoded = jsonDecode(response.body);
    final files = decoded is List
        ? decoded
        : decoded is Map && decoded['files'] is List
            ? decoded['files'] as List
            : null;
    if (files == null || files.isEmpty) return null;

    final first = files.first;
    if (first is! Map) return null;
    return first['fileId']?.toString();
  }

  static String? _filePathFromScreenshotUrl(
    String urlEndpoint,
    String? screenshotUrl,
  ) {
    final url = screenshotUrl?.trim();
    if (url == null || url.isEmpty) return null;

    final endpoint = urlEndpoint.replaceAll(RegExp(r'/+$'), '');
    if (url.startsWith(endpoint)) {
      final suffix = url.substring(endpoint.length);
      if (suffix.isEmpty) return null;
      return suffix.startsWith('/') ? suffix : '/$suffix';
    }

    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.length < 2) return null;
    return '/${uri.pathSegments.sublist(1).join('/')}';
  }

  static Map<String, String> _basicAuthHeaders(String privateKey) => {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$privateKey:'))}',
      };

  static String _generateUploadToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _signUpload(String token, int expire, String privateKey) {
    final hmac = Hmac(sha1, utf8.encode(privateKey));
    return hmac.convert(utf8.encode('$token$expire')).toString();
  }

  static String _normalizeFolder(String folder) {
    var value = folder.trim();
    if (value.isEmpty) return '/zomato-orders';
    if (!value.startsWith('/')) value = '/$value';
    return value.replaceAll(RegExp(r'/+'), '/');
  }

  static String _safeFileName(String fileName) {
    final trimmed = fileName.trim();
    if (trimmed.isEmpty) {
      return 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
    }
    if (trimmed.contains('.')) return trimmed;
    return '$trimmed.jpg';
  }

  static MediaType _mediaTypeForFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return MediaType('application', 'pdf');
    }
    return MediaType('image', _imageSubtype(fileName));
  }

  static String _parseUploadError(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final message = decoded['message']?.toString();
        final help = decoded['help']?.toString();
        if (message != null && message.isNotEmpty) {
          if (statusCode == 403 ||
              message.toLowerCase().contains('cannot be authenticated')) {
            return 'ImageKit authentication failed. Open Settings → Zomato / ImageKit '
                'and tap "Use default keys", or copy the full private key '
                '(eye icon in ImageKit dashboard).';
          }
          if (help != null && help.isNotEmpty) {
            return 'ImageKit upload failed ($statusCode): $message $help';
          }
          return 'ImageKit upload failed ($statusCode): $message';
        }
      }
    } catch (_) {}
    if (statusCode == 403) {
      return 'ImageKit authentication failed. Check your private key in Settings.';
    }
    if (kIsWeb && statusCode == 0) {
      return 'ImageKit upload blocked by browser. Check your internet connection '
          'or try again from the Windows app.';
    }
    return 'ImageKit upload failed ($statusCode): $body';
  }

  static Exception _notConfiguredError(ImageKitConfig config) {
    final missing = config.missingFields.join(', ');
    return Exception(
      'ImageKit is not configured ($missing). '
      'Open Settings → Zomato / ImageKit, enter all three fields, and tap Save.',
    );
  }

  static String _imageSubtype(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpeg';
  }
}

class ImageKitUploadResult {
  const ImageKitUploadResult({
    required this.url,
    required this.fileId,
    required this.filePath,
  });

  final String url;
  final String fileId;
  final String filePath;
}
