import 'dart:convert';

import 'package:smartKitchen/features/zomato/models/zomato_imagekit_cleanup_job.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local retry list for ImageKit screenshot deletes after serve.
class ZomatoImageKitCleanupQueue {
  ZomatoImageKitCleanupQueue._();

  static const _prefsKey = 'zomato_imagekit_cleanup_queue';
  static const maxAttempts = 5;

  static Future<List<ZomatoImageKitCleanupJob>> listAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => ZomatoImageKitCleanupJob.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .where((job) => job.id.isNotEmpty && job.hasScreenshotTarget)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> enqueue(ZomatoImageKitCleanupJob job) async {
    if (!job.hasScreenshotTarget) return;

    final jobs = await listAll();
    final index = jobs.indexWhere((entry) => entry.id == job.id);
    if (index >= 0) {
      jobs[index] = job;
    } else {
      jobs.add(job);
    }
    await _save(jobs);
  }

  static Future<void> remove(String id) async {
    final jobs = await listAll();
    jobs.removeWhere((job) => job.id == id);
    await _save(jobs);
  }

  static Future<void> recordFailedAttempt(String id) async {
    final jobs = await listAll();
    final index = jobs.indexWhere((job) => job.id == id);
    if (index < 0) return;

    final updated = jobs[index].copyWith(attempts: jobs[index].attempts + 1);
    if (updated.attempts >= maxAttempts) {
      jobs.removeAt(index);
    } else {
      jobs[index] = updated;
    }
    await _save(jobs);
  }

  static Future<void> _save(List<ZomatoImageKitCleanupJob> jobs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(jobs.map((job) => job.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }
}
