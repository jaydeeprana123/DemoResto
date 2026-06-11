import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class SharedZomatoImage {
  const SharedZomatoImage({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;
}

class ZomatoShareIntentService extends GetxService {
  final pendingImage = Rxn<SharedZomatoImage>();
  StreamSubscription<List<SharedMediaFile>>? _mediaSubscription;
  var _started = false;

  Future<ZomatoShareIntentService> init() async {
    if (_started || kIsWeb) return this;
    _started = true;

    _mediaSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen(
      _onSharedMedia,
      onError: (Object error) {
        debugPrint('[ZomatoShareIntent] stream error: $error');
      },
    );

    final initial = await ReceiveSharingIntent.instance.getInitialMedia();
    await _onSharedMedia(initial);
    return this;
  }

  Future<void> _onSharedMedia(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    final image = files.firstWhere(
      (file) => file.type == SharedMediaType.image,
      orElse: () => files.first,
    );
    if (image.type != SharedMediaType.image) return;

    final bytes = await _readBytes(image.path);
    if (bytes == null || bytes.isEmpty) return;

    pendingImage.value = SharedZomatoImage(
      bytes: bytes,
      fileName: _fileNameFromPath(image.path),
    );
  }

  SharedZomatoImage? consumePending() {
    final value = pendingImage.value;
    pendingImage.value = null;
    return value;
  }

  Future<void> resetIntent() async {
    if (kIsWeb) return;
    await ReceiveSharingIntent.instance.reset();
  }

  Future<Uint8List?> _readBytes(String rawPath) async {
    if (kIsWeb) return null;
    try {
      var path = rawPath;
      if (path.startsWith('file://')) {
        path = Uri.parse(path).toFilePath(windows: Platform.isWindows);
      }
      final file = File(path);
      if (!await file.exists()) return null;
      return file.readAsBytes();
    } catch (error) {
      debugPrint('[ZomatoShareIntent] read failed: $error');
      return null;
    }
  }

  String _fileNameFromPath(String rawPath) {
    final path = rawPath.startsWith('file://')
        ? Uri.parse(rawPath).path
        : rawPath;
    final segments = path.split(RegExp(r'[\\/]+'));
    final name = segments.isNotEmpty ? segments.last : '';
    if (name.isNotEmpty) return name;
    return 'zomato_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  @override
  void onClose() {
    _mediaSubscription?.cancel();
    super.onClose();
  }
}
