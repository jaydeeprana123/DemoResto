import 'dart:io';

import 'package:demo/services/menu_transcript_aligner.dart';
import 'package:demo/services/transcript_normalizer.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'dart:convert';

// ─────────────────────────────────────────────────────────────────────────────
// SarvamSttService
//
// Records audio via the `record` package (WAV, 16 kHz, mono) and sends it to
// Sarvam AI saaras:v3 speech-to-text REST API.
//
// Uses `translit` mode (roman script) — better for mixed Hindi/Gujarati/English
// while keeping menu names phonetically close (NOT `translate`, which rewrites
// dish names like "Alfaham Tukda Rice" into generic English).
// ─────────────────────────────────────────────────────────────────────────────

class SarvamSttService {
  static final SarvamSttService _instance = SarvamSttService._internal();
  factory SarvamSttService() => _instance;
  SarvamSttService._internal();

  static const String _sarvamApiKey =
      'sk_jm9xxf0p_09FKG715K2n9hXMGKjmIlAIS';
  static const String _sarvamUrl = 'https://api.sarvam.ai/speech-to-text';

  // Optional fallback if Sarvam is unavailable
  static const String _deepgramApiKey =
      'dbf90eaa050406496ad89b19e6ea7fb8a2741985';
  static const String _deepgramUrl =
      'https://api.deepgram.com/v1/listen?smart_format=true&model=nova-2';

  static const String _geminiApiKey = 'AIzaSyBz_YVM6SrTCL-HFA3FG6SkHZ3T5h6VgBc';
  static const String _geminiUrl =
      'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey';

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentPath;

  bool get isRecording => _isRecording;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<bool> startRecording() async {
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

      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentPath = '${dir.path}/sarvam_recording_$timestamp.wav';

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

  Future<double> getAmplitude() async {
    if (!_isRecording) return -160.0;
    try {
      final amp = await _recorder.getAmplitude();
      return amp.current;
    } catch (_) {
      return -160.0;
    }
  }

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

  Future<void> cancelRecording() async {
    try {
      await _recorder.cancel();
    } catch (_) {}
    _isRecording = false;
    _cleanupFile();
  }

  /// Transcribes audio using Sarvam AI (primary), Deepgram, then Gemini fallback.
  ///
  /// [menuNames] — when provided, fuzzy-aligns spoken dish names to exact menu
  /// spellings so downstream parsing matches Firebase items reliably.
  Future<String?> transcribe(
    String filePath, {
    List<String>? menuNames,
  }) async {
    if (kIsWeb) return null;

    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('[SarvamSTT] File not found: $filePath');
      return null;
    }

    final fileSize = await file.length();
    if (fileSize < 1000) {
      debugPrint('[SarvamSTT] Audio too small ($fileSize bytes), skipping');
      return null;
    }

    String? transcript;

    transcript = await _transcribeSarvam(filePath, fileSize);
    transcript ??= await _transcribeDeepgram(filePath, fileSize, menuNames);
    transcript ??= await _transcribeGemini(filePath, fileSize, menuNames);

    _cleanupFile(path: filePath);

    if (transcript == null || transcript.trim().isEmpty) return null;

    var result = TranscriptNormalizer.normalize(transcript.trim());
    debugPrint('[SarvamSTT] Normalized transcript: "$result"');

    if (menuNames != null && menuNames.isNotEmpty) {
      result = MenuTranscriptAligner.align(result, menuNames);
      debugPrint('[SarvamSTT] Menu-aligned transcript: "$result"');
    }

    return result;
  }

  /// Sarvam saaras:v3 — translit keeps dish names phonetic, not translated.
  Future<String?> _transcribeSarvam(String filePath, int fileSize) async {
    if (_sarvamApiKey.isEmpty) return null;

    debugPrint(
      '[SarvamSTT] Transcribing ${fileSize ~/ 1024}KB via Sarvam AI (translit)…',
    );

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_sarvamUrl));
      request.headers['api-subscription-key'] = _sarvamApiKey;
      request.fields['model'] = 'saaras:v3';
      // translit: roman script — preserves "alfaham tukda rice" instead of translating
      request.fields['mode'] = 'translit';
      request.fields['language_code'] = 'unknown';
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamed = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamed);

      debugPrint('[SarvamSTT] Sarvam response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final transcript = (json['transcript'] as String? ?? '').trim();
        debugPrint('[SarvamSTT] ✅ Sarvam transcript: "$transcript"');
        if (transcript.isNotEmpty) return transcript;
      } else {
        debugPrint(
          '[SarvamSTT] ❌ Sarvam error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[SarvamSTT] Sarvam transcription failed: $e');
    }
    return null;
  }

  Future<String?> _transcribeDeepgram(
    String filePath,
    int fileSize,
    List<String>? menuNames,
  ) async {
    if (_deepgramApiKey.isEmpty) return null;

    debugPrint(
      '[SarvamSTT] Fallback: Deepgram ${fileSize ~/ 1024}KB…',
    );

    try {
      final bytes = await File(filePath).readAsBytes();
      var uriString = _deepgramUrl;
      if (menuNames != null) {
        for (final item in menuNames.where((e) => e.trim().isNotEmpty)) {
          uriString += '&keywords=${Uri.encodeComponent(item.trim())}';
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

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final transcript =
            json['results']?['channels']?[0]?['alternatives']?[0]?['transcript']
                as String? ??
            '';
        if (transcript.trim().isNotEmpty) {
          debugPrint('[SarvamSTT] ✅ Deepgram transcript: "$transcript"');
          return transcript.trim();
        }
      }
    } catch (e) {
      debugPrint('[SarvamSTT] Deepgram fallback failed: $e');
    }
    return null;
  }

  Future<String?> _transcribeGemini(
    String filePath,
    int fileSize,
    List<String>? menuNames,
  ) async {
    debugPrint('[SarvamSTT] Fallback: Gemini ${fileSize ~/ 1024}KB…');

    try {
      final bytes = await File(filePath).readAsBytes();
      final base64Audio = base64Encode(bytes);

      final menuHint = menuNames != null && menuNames.isNotEmpty
          ? menuNames.take(80).join(', ')
          : '';

      final geminiPrompt = menuHint.isNotEmpty
          ? 'Transcribe the audio exactly as spoken. Use Roman/English letters. '
              'Do NOT translate dish names — keep them phonetically as spoken '
              '(e.g. "Alfaham Tukda Rice", "Char Bag Rice", "Crispy Makhni Popcorn"). '
              'Menu items for spelling reference: $menuHint. '
              'Return only the transcript, no explanation.'
          : 'Transcribe the audio exactly as spoken in Roman script. '
              'Return only the transcript.';

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

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final transcript =
            (json['candidates'] as List?)
                    ?.firstOrNull?['content']?['parts']
                    ?.firstOrNull?['text']
                as String? ??
            '';
        if (transcript.trim().isNotEmpty) {
          debugPrint('[SarvamSTT] ✅ Gemini transcript: "$transcript"');
          return transcript.trim();
        }
      }
    } catch (e) {
      debugPrint('[SarvamSTT] Gemini fallback failed: $e');
    }
    return null;
  }

  Future<String?> stopAndTranscribe({List<String>? menuNames}) async {
    final path = await stopRecording();
    if (path == null) return null;
    return transcribe(path, menuNames: menuNames);
  }

  void _cleanupFile({String? path}) {
    final filePath = path ?? _currentPath;
    if (filePath == null) return;
    try {
      final f = File(filePath);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    if (path == null || path == _currentPath) _currentPath = null;
  }

  void dispose() {
    _recorder.dispose();
  }
}
