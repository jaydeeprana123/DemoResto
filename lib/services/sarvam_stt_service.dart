import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'dart:convert';

// ─────────────────────────────────────────────────────────────────────────────
// SarvamSttService
//
// Records audio via the `record` package (WAV, 16 kHz, mono) and sends it to
// Sarvam AI's saaras:v3 speech-to-text REST API for transcription.
//
// Designed for Indian multilingual speech: Hindi, Gujarati, English,
// code-mixed, and 19 other Indian languages — auto-detected.
// ─────────────────────────────────────────────────────────────────────────────

class SarvamSttService {
  static final SarvamSttService _instance = SarvamSttService._internal();
  factory SarvamSttService() => _instance;
  SarvamSttService._internal();

  // ── Configuration ─────────────────────────────────────────────────────────
  // TODO: Replace with your actual Sarvam AI API key from dashboard.sarvam.ai
  static const String _apiKey = 'sk_jm9xxf0p_09FKG715K2n9hXMGKjmIlAIS';
  static const String _apiUrl = 'https://api.sarvam.ai/speech-to-text';
  static const String _model = 'saaras:v3';
  static const String _mode = 'translate'; // translate → always outputs English text

  // ── State ─────────────────────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentPath;

  bool get isRecording => _isRecording;

  // ── Record ────────────────────────────────────────────────────────────────

  /// Check and request microphone permission.
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Start recording audio to a temporary WAV file.
  /// Returns `true` if recording started successfully.
  Future<bool> startRecording() async {
    // path_provider / record are not supported on web
    if (kIsWeb) {
      debugPrint('[SarvamSTT] Voice recording not supported on web platform.');
      return false;
    }
    if (_isRecording) return true;

    try {
      final hasPerms = await _recorder.hasPermission();
      if (!hasPerms) {
        debugPrint('[SarvamSTT] Microphone permission denied');
        return false;
      }

      // Temp directory for the WAV file
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentPath = '${dir.path}/sarvam_recording_$timestamp.wav';

      // Record WAV at 16kHz mono — optimal for Sarvam AI
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
        ),
        path: _currentPath!,
      );

      _isRecording = true;
      debugPrint('[SarvamSTT] Recording started → $_currentPath');
      return true;
    } catch (e) {
      debugPrint('[SarvamSTT] Failed to start recording: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Get current audio amplitude (for visual feedback).
  /// Returns amplitude in dBFS (typically -160 to 0).
  Future<double> getAmplitude() async {
    if (!_isRecording) return -160.0;
    try {
      final amp = await _recorder.getAmplitude();
      return amp.current;
    } catch (_) {
      return -160.0;
    }
  }

  /// Stop recording and return the file path (or null on failure).
  Future<String?> stopRecording() async {
    if (!_isRecording) return _currentPath;

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      debugPrint('[SarvamSTT] Recording stopped → $path');
      return path ?? _currentPath;
    } catch (e) {
      debugPrint('[SarvamSTT] Failed to stop recording: $e');
      _isRecording = false;
      return _currentPath;
    }
  }

  /// Cancel recording and delete the temp file.
  Future<void> cancelRecording() async {
    try {
      await _recorder.cancel();
    } catch (_) {}
    _isRecording = false;
    _cleanupFile();
  }

  // ── Transcribe via Sarvam AI ──────────────────────────────────────────────

  /// Transcribes the audio file at [filePath] using Sarvam AI's REST API.
  ///
  /// Returns the transcribed text, or `null` if the API call fails.
  Future<String?> transcribe(String filePath) async {
    if (kIsWeb) return null; // File I/O not available on web
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('[SarvamSTT] File not found: $filePath');
      return null;
    }

    final fileSize = await file.length();
    if (fileSize < 1000) {
      // Too small — likely less than 0.1s of audio
      debugPrint(
        '[SarvamSTT] Audio file too small ($fileSize bytes), skipping',
      );
      return null;
    }

    debugPrint('[SarvamSTT] Transcribing ${fileSize ~/ 1024}KB audio file...');

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_apiUrl));

      // Auth header
      request.headers['api-subscription-key'] = _apiKey;

      // Form fields
      request.fields['model'] = _model;
      request.fields['language_code'] = 'unknown'; // auto-detect language
      request.fields['mode'] = _mode;

      // Audio file
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      // Send request
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('[SarvamSTT] Response status: ${response.statusCode}');
      debugPrint('[SarvamSTT] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final transcript = json['transcript'] as String? ?? '';
        debugPrint('[SarvamSTT] ✅ Transcript: "$transcript"');
        return transcript.trim().isEmpty ? null : transcript.trim();
      } else {
        debugPrint(
          '[SarvamSTT] ❌ API error ${response.statusCode}: ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('[SarvamSTT] Transcription failed: $e');
      return null;
    } finally {
      // Clean up the temp WAV file
      _cleanupFile(path: filePath);
    }
  }

  // ── Convenience: Record → Transcribe ──────────────────────────────────────

  /// Stops recording and immediately transcribes the result.
  /// Returns the transcript text or `null`.
  Future<String?> stopAndTranscribe() async {
    final path = await stopRecording();
    if (path == null) return null;
    return transcribe(path);
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  void _cleanupFile({String? path}) {
    final filePath = path ?? _currentPath;
    if (filePath == null) return;
    try {
      final f = File(filePath);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    if (path == null || path == _currentPath) _currentPath = null;
  }

  /// Call when the service is no longer needed.
  void dispose() {
    _recorder.dispose();
  }
}
