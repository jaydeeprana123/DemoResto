import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:demo/services/sarvam_stt_service.dart';
import 'package:demo/services/restaurant_agent_service.dart';
import 'package:demo/services/ai_order_service.dart'; // Contains OrderResult
import 'package:demo/models/agent_response.dart';
import 'package:demo/Screens/Menu/repositories/restaurant_menu_repository.dart';

/// RestaurantMenuController
/// 
/// Part of the GetX Repository Pattern.
/// Manages reactive states for the menu catalog, voice assistant ordering,
/// local category filters, search operations, and handles delegates for quantity changes.
class RestaurantMenuController extends GetxController {
  final RestaurantMenuRepository _repository = RestaurantMenuRepository();

  // ── Services ──────────────────────────────────────────────────────────────
  final SarvamSttService _sttService = SarvamSttService();
  final RestaurantAgentService _agentService = RestaurantAgentService();

  // ── Text Field Controllers ────────────────────────────────────────────────
  final TextEditingController tableNameController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  // ── Reactive Presentation States ──────────────────────────────────────────
  final RxMap<String, List<Map<String, dynamic>>> menuData = <String, List<Map<String, dynamic>>>{}.obs;
  final RxString tableName = ''.obs;
  final RxBool showSearch = false.obs;
  final RxString searchQuery = ''.obs;
  final RxBool isNameEdit = false.obs;

  // Category selection filters
  final RxSet<String> selectedCategories = <String>{}.obs;
  final RxBool showAllCategories = true.obs;

  // Voice STT UI states
  final RxBool isRecording = false.obs;
  final RxBool isTranscribing = false.obs;
  final RxBool isProcessing = false.obs;
  final RxString recognizedText = ''.obs;
  final RxInt recordingSeconds = 0.obs;
  final RxDouble currentAmplitude = 0.0.obs;
  final RxString overallRemarks = ''.obs;

  // ── Internal Helpers ──────────────────────────────────────────────────────
  Timer? _recordingTimer;
  Timer? _amplitudeTimer;

  @override
  void onClose() {
    tableNameController.dispose();
    searchController.dispose();
    _recordingTimer?.cancel();
    _amplitudeTimer?.cancel();
    super.onClose();
  }

  // ── State Initialization ──────────────────────────────────────────────────

  /// Groups the raw menu catalog items by category and pre-fills from initial table selection.
  void initializeMenuData({
    required List<Map<String, dynamic>> menuList,
    required List<Map<String, dynamic>> initialItems,
    required String initialTableName,
  }) {
    tableName.value = initialTableName;
    tableNameController.text = initialTableName;

    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var item in menuList) {
      final category = item['category'] as String;
      grouped[category] ??= [];
      grouped[category]!.add({...item, 'qty': 0});
    }

    // Pre-fill quantities from initialItems if any
    for (var category in grouped.keys) {
      for (var item in grouped[category]!) {
        final existingItem = initialItems.firstWhere(
          (e) => e['name'] == item['name'],
          orElse: () => {},
        );
        if (existingItem.isNotEmpty) {
          item['qty'] = existingItem['qty'] ?? 0;
        }
      }
    }

    menuData.assignAll(grouped);
    _loadSelectedCategories();
  }

  // ── Category Preferences loading/saving ───────────────────────────────────

  Future<void> _loadSelectedCategories() async {
    final List<String> storedList = await _repository.loadSelectedCategories();
    selectedCategories.assignAll(storedList);
    if (selectedCategories.isNotEmpty) {
      showAllCategories.value = false;
    }
  }

  Future<void> saveSelectedCategories() async {
    await _repository.saveSelectedCategories(selectedCategories.toList());
  }

  // ── Quantity Adjustments ─────────────────────────────────────────────────

  /// Increments quantity for a specific menu item.
  void incrementQty(String category, int index) {
    menuData[category]![index]['qty']++;
    menuData.refresh();
  }

  /// Decrements quantity for a specific menu item.
  void decrementQty(String category, int index) {
    if (menuData[category]![index]['qty'] > 0) {
      menuData[category]![index]['qty']--;
      menuData.refresh();
    }
  }

  /// Adds items directly (e.g., in Search list).
  void addItemDirectly(Map<String, dynamic> item) {
    item['qty'] = (item['qty'] ?? 0) + 1;
    menuData.refresh();
  }

  /// Removes items directly (e.g., in Search list).
  void removeItemDirectly(Map<String, dynamic> item) {
    if ((item['qty'] ?? 0) > 0) {
      item['qty']--;
      menuData.refresh();
    }
  }

  // ── Voice STT & AI Operations ────────────────────────────────────────────

  Future<bool> hasMicrophonePermission() async {
    return await _sttService.hasPermission();
  }

  /// Resets voice properties and begins active voice recording.
  Future<bool> startVoiceRecording() async {
    recognizedText.value = '';
    isRecording.value = false;
    isTranscribing.value = false;
    isProcessing.value = false;
    recordingSeconds.value = 0;
    currentAmplitude.value = 0.0;
    _recordingTimer?.cancel();
    _amplitudeTimer?.cancel();

    if (kIsWeb) return false;

    final started = await _sttService.startRecording();
    if (started) {
      isRecording.value = true;
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        recordingSeconds.value++;
      });
      _startAmplitudePolling();
    }
    return started;
  }

  /// Stops voice recording and fetches text transcription from Sarvam AI.
  Future<String?> stopVoiceRecording() async {
    _recordingTimer?.cancel();
    _amplitudeTimer?.cancel();

    isRecording.value = false;
    isTranscribing.value = true;

    final transcript = await _sttService.stopAndTranscribe();
    isTranscribing.value = false;

    if (transcript == null || transcript.trim().isEmpty) {
      return null;
    }

    recognizedText.value = transcript;
    isProcessing.value = true;
    return transcript;
  }

  /// Aborts active audio recordings.
  Future<void> cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    _amplitudeTimer?.cancel();
    await _sttService.cancelRecording();
    isRecording.value = false;
    isTranscribing.value = false;
    isProcessing.value = false;
  }

  void _startAmplitudePolling() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      if (!isRecording.value) return;
      final amp = await _sttService.getAmplitude();
      // Normalize from dBFS (-160..0) to 0..1
      final normalized = ((amp + 50) / 50).clamp(0.0, 1.0);
      currentAmplitude.value = normalized;
    });
  }

  /// Processes text input via AI Order Agent.
  Future<AgentResponse> processInputAgent(String text) async {
    // Collect all menu items for the agent
    final List<Map<String, dynamic>> allItems = [];
    menuData.forEach((_, items) => allItems.addAll(items));

    try {
      final response = await _agentService.handleInput(
        userText: text,
        menuItems: allItems,
      );
      isProcessing.value = false;
      return response;
    } catch (e) {
      isProcessing.value = false;
      return AgentResponse.retry('Order processing failed. Please try again.');
    }
  }

  /// Applies a confirmed list of AI Order results.
  void applyOrderResults(List<OrderResult> results) {
    for (final r in results) {
      final itemName = r.item['name'];
      for (final category in menuData.keys) {
        for (int i = 0; i < menuData[category]!.length; i++) {
          if (menuData[category]![i]['name'] == itemName) {
            menuData[category]![i]['qty'] += r.quantity;
            if (r.remarks.isNotEmpty) {
              menuData[category]![i]['remarks'] = r.remarks;
            }
          }
        }
      }
    }
    menuData.refresh();
  }

  /// Gathers all currently selected items in the cart.
  List<Map<String, dynamic>> getSelectedItems() {
    final List<Map<String, dynamic>> selectedItems = [];
    menuData.forEach((_, items) {
      for (var item in items) {
        if (item['qty'] > 0) {
          selectedItems.add(item);
        }
      }
    });
    return selectedItems;
  }
}
