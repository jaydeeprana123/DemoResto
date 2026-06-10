import 'dart:typed_data';

import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';

class ZomatoScreenshotViewer extends StatelessWidget {
  const ZomatoScreenshotViewer({
    super.key,
    this.imageUrl,
    this.imageBytes,
    this.title,
  });

  final String? imageUrl;
  final Uint8List? imageBytes;
  final String? title;

  static Future<void> show(
    BuildContext context, {
    String? imageUrl,
    Uint8List? imageBytes,
    String? title,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ZomatoScreenshotViewer(
        imageUrl: imageUrl,
        imageBytes: imageBytes,
        title: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          maxWidth: 720,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title ?? 'Zomato Order Screenshot',
                      style: MyFont.bold(16, color: const Color(0xFF1A3A5C)),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: _buildImage(),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (imageBytes != null) {
      return Image.memory(imageBytes!, fit: BoxFit.contain);
    }
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (_, __, ___) => const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Could not load screenshot.'),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text('No screenshot available.'),
    );
  }
}
