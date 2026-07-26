class ZomatoImageKitCleanupJob {
  const ZomatoImageKitCleanupJob({
    required this.id,
    this.fileId,
    this.screenshotUrl,
    required this.createdAtMs,
    this.attempts = 0,
  });

  final String id;
  final String? fileId;
  final String? screenshotUrl;
  final int createdAtMs;
  final int attempts;

  bool get hasScreenshotTarget {
    final id = fileId?.trim();
    final url = screenshotUrl?.trim();
    return (id != null && id.isNotEmpty) || (url != null && url.isNotEmpty);
  }

  ZomatoImageKitCleanupJob copyWith({int? attempts}) {
    return ZomatoImageKitCleanupJob(
      id: id,
      fileId: fileId,
      screenshotUrl: screenshotUrl,
      createdAtMs: createdAtMs,
      attempts: attempts ?? this.attempts,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (fileId != null) 'fileId': fileId,
        if (screenshotUrl != null) 'screenshotUrl': screenshotUrl,
        'createdAtMs': createdAtMs,
        'attempts': attempts,
      };

  factory ZomatoImageKitCleanupJob.fromJson(Map<String, dynamic> json) {
    return ZomatoImageKitCleanupJob(
      id: json['id']?.toString() ?? '',
      fileId: json['fileId']?.toString(),
      screenshotUrl: json['screenshotUrl']?.toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    );
  }
}

class ZomatoScreenshotInfo {
  const ZomatoScreenshotInfo({
    required this.docId,
    this.fileId,
    this.screenshotUrl,
  });

  final String docId;
  final String? fileId;
  final String? screenshotUrl;
}

class ZomatoOrderServeInfo {
  const ZomatoOrderServeInfo({
    required this.docId,
    required this.name,
    this.fileId,
    this.screenshotUrl,
  });

  final String docId;
  final String name;
  final String? fileId;
  final String? screenshotUrl;
}
