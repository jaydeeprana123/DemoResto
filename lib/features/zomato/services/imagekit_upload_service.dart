import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:demo/features/zomato/services/imagekit_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ImageKitUploadService {
  ImageKitUploadService._();

  static const _uploadUrl = 'https://upload.imagekit.io/api/v1/files/upload';

  static Future<String> uploadScreenshot({
    required Uint8List bytes,
    required String fileName,
    String folder = '/zomato-orders',
  }) async {
    if (kIsWeb) {
      return _uploadViaCloudFunction(
        bytes: bytes,
        fileName: fileName,
        folder: folder,
      );
    }

    final config = await ImageKitSettings.load();
    if (!config.isValid) {
      throw _notConfiguredError(config);
    }

    return _uploadDirect(
      config: config,
      bytes: bytes,
      fileName: fileName,
      folder: folder,
    );
  }

  static Future<String> _uploadViaCloudFunction({
    required Uint8List bytes,
    required String fileName,
    required String folder,
  }) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('uploadZomatoScreenshot');
      final result = await callable.call({
        'fileName': fileName,
        'fileBase64': base64Encode(bytes),
        'folder': folder,
      });
      final data = result.data;
      if (data is! Map) {
        throw Exception('ImageKit upload returned an unexpected response.');
      }
      final url = data['url']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('ImageKit upload did not return a URL.');
      }
      return url;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        throw Exception(e.message ?? 'ImageKit is not configured.');
      }
      throw Exception('ImageKit upload failed: ${e.message ?? e.code}');
    }
  }

  static Future<String> _uploadDirect({
    required ImageKitConfig config,
    required Uint8List bytes,
    required String fileName,
    required String folder,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
    request.headers['Authorization'] = 'Basic ${base64Encode(
      utf8.encode('${config.privateKey}:'),
    )}';
    request.fields['fileName'] = fileName;
    request.fields['folder'] = folder;
    request.fields['publicKey'] = config.publicKey;
    request.fields['useUniqueFileName'] = 'true';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: MediaType('image', _imageSubtype(fileName)),
      ),
    );

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'ImageKit upload failed (${response.statusCode}): $body',
      );
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final url = decoded['url']?.toString();
    if (url == null || url.isEmpty) {
      throw Exception('ImageKit upload did not return a URL.');
    }
    return url;
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
