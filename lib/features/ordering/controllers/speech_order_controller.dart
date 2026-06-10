import 'package:demo/features/ordering/repositories/speech_order_repository.dart';
import 'package:demo/models/agent_response.dart';
import 'package:get/get.dart';

class SpeechOrderController extends GetxController {
  SpeechOrderController(this._repository);

  final SpeechOrderRepository _repository;

  final isRecording = false.obs;
  final isTranscribing = false.obs;
  final isProcessing = false.obs;
  final recognizedText = ''.obs;
  final recordingSeconds = 0.obs;
  final currentAmplitude = 0.0.obs;

  Future<bool> ensureMicrophonePermission() =>
      _repository.hasMicrophonePermission();

  Future<bool> startRecording() async {
    final started = await _repository.startRecording();
    if (started) {
      isRecording.value = true;
      recordingSeconds.value = 0;
      currentAmplitude.value = 0;
    }
    return started;
  }

  Future<void> cancelRecording() async {
    await _repository.cancelRecording();
    isRecording.value = false;
    isTranscribing.value = false;
  }

  Future<double> pollAmplitude() => _repository.currentAmplitude();

  Future<String?> stopAndTranscribe() async {
    isRecording.value = false;
    isTranscribing.value = true;
    try {
      final transcript = await _repository.stopAndTranscribe();
      recognizedText.value = transcript ?? '';
      return transcript;
    } finally {
      isTranscribing.value = false;
    }
  }

  Future<AgentResponse> processOrder({
    required String transcript,
    required List<Map<String, dynamic>> menuItems,
  }) async {
    isProcessing.value = true;
    try {
      return await _repository.processVoiceOrder(
        transcript: transcript,
        menuItems: menuItems,
      );
    } finally {
      isProcessing.value = false;
    }
  }

  void resetSession() {
    recognizedText.value = '';
    isRecording.value = false;
    isTranscribing.value = false;
    isProcessing.value = false;
    recordingSeconds.value = 0;
    currentAmplitude.value = 0;
  }
}
