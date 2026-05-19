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
  // Deepgram Configuration
  static const String _deepgramApiKey =
      'dbf90eaa050406496ad89b19e6ea7fb8a2741985';
  static const String _deepgramUrl =
      'https://api.deepgram.com/v1/listen?smart_format=true&model=nova-2';

  // Gemini Configuration (Fallback)
  static const String _geminiApiKey = 'AIzaSyBz_YVM6SrTCL-HFA3FG6SkHZ3T5h6VgBc';
  static const String _geminiUrl =
      'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey';

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

  // ── Transcribe via Deepgram / Gemini ──────────────────────────────────────

  /// Transcribes the audio file at [filePath] using Deepgram (primary) or Gemini API (fallback).
  ///
  /// Returns the transcribed text, or `null` if both fail.
  Future<String?> transcribe(String filePath, {String? prompt}) async {
    if (kIsWeb) return null; // File I/O not available on web
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('[STTService] File not found: $filePath');
      return null;
    }

    final fileSize = await file.length();
    if (fileSize < 1000) {
      // Too small — likely less than 0.1s of audio
      debugPrint(
        '[STTService] Audio file too small ($fileSize bytes), skipping',
      );
      return null;
    }

    // Try Deepgram first if API key is provided
    if (_deepgramApiKey.isNotEmpty) {
      debugPrint(
        '[STTService] Transcribing ${fileSize ~/ 1024}KB audio file via Deepgram...',
      );
      try {
        final bytes = await file.readAsBytes();

        var uriString = _deepgramUrl;
        if (prompt != null && prompt.isNotEmpty) {
          final items = prompt
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty);
          for (final item in items) {
            uriString += '&keywords=${Uri.encodeComponent(item)}';
          }
        }

        final response = await http
            .post(
              Uri.parse(uriString),
              headers: {
                'Authorization': 'Token $_deepgramApiKey',
                'Content-Type': 'audio/wav',
              },
              body: bytes,
            )
            .timeout(const Duration(seconds: 30));

        debugPrint(
          '[STTService] Deepgram response status: ${response.statusCode}',
        );
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final transcript =
              json['results']?['channels']?[0]?['alternatives']?[0]?['transcript']
                  as String? ??
              '';
          debugPrint('[STTService] ✅ Deepgram Transcript: "$transcript"');
          if (transcript.trim().isNotEmpty) {
            _cleanupFile(path: filePath);
            return transcript.trim();
          }
        } else {
          debugPrint(
            '[STTService] ❌ Deepgram API error ${response.statusCode}: ${response.body}',
          );
        }
      } catch (e) {
        debugPrint(
          '[STTService] Deepgram transcription failed: $e. Falling back to Gemini...',
        );
      }
    }

    // Gemini fallback:
    debugPrint(
      '[STTService] Transcribing ${fileSize ~/ 1024}KB audio file via Gemini fallback...',
    );
    try {
      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);

      final geminiPrompt = prompt != null && prompt.isNotEmpty
          ? 'Transcribe the audio file exactly as spoken (verbatim), in the language it was spoken (Hindi, Gujarati, English, or code-mixed Hinglish/Gujlish). Do not translate it. Only return the transcribed text. Do not add any notes, markdown, or explanation. Hint for menu items/spelling context: $prompt'
          : 'Transcribe the audio file exactly as spoken (verbatim), in the language it was spoken (Hindi, Gujarati, English, or code-mixed Hinglish/Gujlish). Do not translate it. Only return the transcribed text. Do not add any notes, markdown, or explanation.';

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'inlineData': {'mimeType': 'audio/wav', 'data': base64Audio},
              },
              {'text': geminiPrompt},
            ],
          },
        ],
        'generationConfig': {'temperature': 0.0, 'maxOutputTokens': 1024},
      });

      final response = await http
          .post(
            Uri.parse(_geminiUrl),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(
        '[STTService] Gemini fallback response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final transcript =
            (json['candidates'] as List?)
                    ?.firstOrNull?['content']?['parts']
                    ?.firstOrNull?['text']
                as String? ??
            '';
        debugPrint('[STTService] ✅ Gemini Transcript: "$transcript"');
        if (transcript.trim().isNotEmpty) {
          return transcript.trim();
        }
      } else {
        debugPrint(
          '[STTService] ❌ Gemini API error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[STTService] Gemini fallback transcription failed: $e');
    } finally {
      _cleanupFile(path: filePath);
    }
    return null;
  }

  // ── Convenience: Record → Transcribe ──────────────────────────────────────

  /// Stops recording and immediately transcribes the result.
  /// Returns the transcript text or `null`.
  Future<String?> stopAndTranscribe({String? prompt}) async {
    final path = await stopRecording();
    if (path == null) return null;
    return transcribe(path, prompt: prompt);
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
