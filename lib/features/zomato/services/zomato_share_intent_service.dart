import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:demo/core/utils/platform_utils.dart';
import 'package:demo/features/zomato/widgets/import_shared_zomato_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class ZomatoShareIntentService extends GetxService {
  StreamSubscription<List<SharedMediaFile>>? _mediaSubscription;
  bool _uiReady = false;
  _PendingShare? _queuedShare;
  bool _sheetVisible = false;

  @override
  void onInit() {
    super.onInit();
    if (!_supportsShareIntents) return;
    _startListening();
  }

  @override
  void onClose() {
    _mediaSubscription?.cancel();
    super.onClose();
  }

  bool get _supportsShareIntents =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  void markUiReady() {
    _uiReady = true;
    _flushQueuedShare();
  }

  void markUiNotReady() {
    _uiReady = false;
  }

  void _startListening() {
    _mediaSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedMedia,
      onError: (_) {},
    );

    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isEmpty) return;
      _handleSharedMedia(files);
      ReceiveSharingIntent.instance.reset();
    });
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> files) async {
    final image = _firstImage(files);
    if (image == null) return;

    final bytes = await _readSharedBytes(image);
    if (bytes == null || bytes.isEmpty) return;

    final pending = _PendingShare(
      bytes: bytes,
      fileName: _fileNameFromPath(image.path),
    );

    if (!_uiReady || _sheetVisible) {
      _queuedShare = pending;
      return;
    }

    await _presentImportSheet(pending);
  }

  void _flushQueuedShare() {
    final pending = _queuedShare;
    if (pending == null || !_uiReady || _sheetVisible) return;
    _queuedShare = null;
    unawaited(_presentImportSheet(pending));
  }

  Future<void> _presentImportSheet(_PendingShare pending) async {
    final context = Get.context;
    if (context == null) {
      _queuedShare = pending;
      return;
    }

    _sheetVisible = true;
    try {
      await ImportSharedZomatoSheet.show(
        context,
        imageBytes: pending.bytes,
        fileName: pending.fileName,
      );
    } finally {
      _sheetVisible = false;
      _flushQueuedShare();
    }
  }

  SharedMediaFile? _firstImage(List<SharedMediaFile> files) {
    for (final file in files) {
      if (file.type == SharedMediaType.image) return file;
      final mime = file.mimeType?.toLowerCase() ?? '';
      if (mime.startsWith('image/')) return file;
      final ext = _extension(file.path);
      if (ext == '.jpg' ||
          ext == '.jpeg' ||
          ext == '.png' ||
          ext == '.webp' ||
          ext == '.heic') {
        return file;
      }
    }
    return null;
  }

  Future<Uint8List?> _readSharedBytes(SharedMediaFile file) async {
    try {
      if (isDesktopPlatform || kIsWeb) return null;
      final path = file.path;
      if (path.isEmpty) return null;
      return File(path).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  String? _fileNameFromPath(String path) {
    if (path.isEmpty) return null;
    final parts = path.split(RegExp(r'[/\\]'));
    final name = parts.isEmpty ? path : parts.last;
    return name.isEmpty ? null : name;
  }

  String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot <= 0 || dot >= path.length - 1) return '';
    return path.substring(dot).toLowerCase();
  }
}

class _PendingShare {
  const _PendingShare({
    required this.bytes,
    this.fileName,
  });

  final Uint8List bytes;
  final String? fileName;
}
