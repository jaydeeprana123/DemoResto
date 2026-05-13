import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:demo/services/sarvam_stt_service.dart';
import 'package:demo/services/ai_order_service.dart';
import 'package:demo/services/restaurant_agent_service.dart';
import 'package:demo/models/agent_response.dart';

/// GetX Controller for managing Menu state, Search, Category filters, and Voice Orders.
class MenuController extends GetxController {
  // Arguments passed from View
  final List<Map<String, dynamic>> initialMenuList;
  final List<Map<String, dynamic>> initialItems;
  final String initialTableName;

  MenuController({
    required this.initialMenuList,
    required this.initialItems,
    required this.initialTableName,
  });

  // State
  var menuData = <String, List<Map<String, dynamic>>>{}.obs;
  late TextEditingController tableNameController;
  late TextEditingController searchController;

  var showSearch = false.obs;
  var searchQuery = ''.obs;
  var isNameEdit = false.obs;

  var selectedCategories = <String>{}.obs;
  var showAllCategories = true.obs;

  // Voice AI State
  final SarvamSttService sttService = SarvamSttService();
  final RestaurantAgentService agentService = RestaurantAgentService();

  var isRecording = false.obs;
  var isTranscribing = false.obs;
  var isProcessing = false.obs;
  var recognizedText = ''.obs;
  var recordingSeconds = 0.obs;
  var currentAmplitude = 0.0.obs;
  var overallRemarks = ''.obs;

  Timer? recordingTimer;
  Timer? amplitudeTimer;

  void Function(List<OrderResult> items, String title, bool isSuggestion, String transcript, double confidence)? showVoiceDialog;

  @override
  void onInit() {
    super.onInit();
    tableNameController = TextEditingController(text: initialTableName);
    searchController = TextEditingController();

    // Group menuList by category and initialize qty = 0
    Map<String, List<Map<String, dynamic>>> tempMenu = {};
    for (var item in initialMenuList) {
      final category = item['category'] as String;
      tempMenu[category] ??= [];
      tempMenu[category]!.add({...item, 'qty': 0});
    }

    // Pre-fill quantities from initialItems if any
    for (var category in tempMenu.keys) {
      for (var item in tempMenu[category]!) {
        final existingItem = initialItems.firstWhere(
          (e) => e['name'] == item['name'],
          orElse: () => <String, dynamic>{},
        );
        if (existingItem.isNotEmpty) {
          item['qty'] = existingItem['qty'];
          if (existingItem.containsKey('remarks')) {
            item['remarks'] = existingItem['remarks'];
          }
        }
      }
    }
    menuData.value = tempMenu;

    loadSelectedCategories();
  }

  @override
  void onClose() {
    tableNameController.dispose();
    searchController.dispose();
    recordingTimer?.cancel();
    amplitudeTimer?.cancel();
    super.onClose();
  }

  /// Increments the quantity of a specific item in the menu
  void incrementQty(String category, int index) {
    final items = menuData[category]!;
    items[index]['lastQty'] = items[index]['qty'];
    items[index]['qty']++;
    menuData.refresh();
  }

  /// Decrements the quantity of a specific item in the menu
  void decrementQty(String category, int index) {
    final items = menuData[category]!;
    if (items[index]['qty'] > 0) {
      items[index]['lastQty'] = items[index]['qty'];
      items[index]['qty']--;
      menuData.refresh();
    }
  }

  /// Updates the remark for a specific item
  void updateRemark(String category, int index, String remark) {
    final items = menuData[category]!;
    items[index]['remarks'] = remark;
    menuData.refresh();
  }

  /// Calculates the total number of items selected
  int get totalItems {
    int total = 0;
    menuData.forEach((category, items) {
      for (var item in items) total += item['qty'] as int;
    });
    return total;
  }

  /// Calculates the total price of the selected items
  double get totalPrice {
    double total = 0.0;
    menuData.forEach((category, items) {
      for (var item in items) {
        total += (item['qty'] as int) * (item['price']);
      }
    });
    return total;
  }

  /// Loads the previously selected categories from local storage
  Future<void> loadSelectedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? storedList = prefs.getStringList('selectedCategories');
    if (storedList != null && storedList.isNotEmpty) {
      selectedCategories.value = storedList.toSet();
      showAllCategories.value = false;
    }
  }

  /// Saves the current category filters to local storage
  Future<void> saveSelectedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('selectedCategories', selectedCategories.toList());
  }

  /// Toggles the search bar visibility
  void toggleSearch() {
    if (showSearch.value) {
      searchQuery.value = '';
      searchController.clear();
    }
    showSearch.value = !showSearch.value;
  }

  /// Applies the parsed voice order results into the menu cart
  void applyOrderResults(List<OrderResult> results, String transcript) {
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
    if (transcript.isNotEmpty) {
      if (overallRemarks.value.isNotEmpty) {
        overallRemarks.value += '\n';
      }
      overallRemarks.value += transcript;
    }
    menuData.refresh();
  }

  /// Syncs items returned from the cart page back into the menu
  void syncItemsFromCart(List<Map<String, dynamic>> changedItems) {
    for (var category in menuData.keys) {
      for (var item in menuData[category]!) {
        final existingItem = changedItems.firstWhere(
          (e) => e['name'] == item['name'],
          orElse: () => <String, dynamic>{},
        );
        if (existingItem.isNotEmpty) {
          item['qty'] = existingItem['qty'];
          item['remarks'] = existingItem['remarks'] ?? '';
        } else {
          item['qty'] = 0;
        }
      }
    }
    menuData.refresh();
  }

  // --- Voice Order Logic ---

  void startVoiceRecording(BuildContext context) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎤 Voice ordering requires the mobile app.')),
      );
      return;
    }

    final hasPerms = await sttService.hasPermission();
    if (!hasPerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied.')),
      );
      return;
    }

    isRecording.value = true;
    recordingSeconds.value = 0;
    currentAmplitude.value = 0.0;
    recognizedText.value = '';

    final started = await sttService.startRecording();
    if (!started) {
      isRecording.value = false;
      return;
    }

    recordingTimer?.cancel();
    recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      recordingSeconds.value++;
    });

    amplitudeTimer?.cancel();
    amplitudeTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      final amp = await sttService.getAmplitude();
      currentAmplitude.value = ((amp + 50) / 50).clamp(0.0, 1.0);
    });
  }

  Future<void> stopAndTranscribe() async {
    recordingTimer?.cancel();
    amplitudeTimer?.cancel();
    
    isRecording.value = false;
    isTranscribing.value = true;

    final transcript = await sttService.stopAndTranscribe();
    
    if (transcript == null || transcript.trim().isEmpty) {
      isTranscribing.value = false;
      Get.snackbar('Error', 'Could not recognise speech. Please try again.', backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    recognizedText.value = transcript;
    isTranscribing.value = false;
    isProcessing.value = true;

    // Process with agent
    await processOrderAndClose(transcript);
    isProcessing.value = false;
  }

  void cancelRecording() {
    recordingTimer?.cancel();
    amplitudeTimer?.cancel();
    sttService.cancelRecording();
    isRecording.value = false;
    isTranscribing.value = false;
    isProcessing.value = false;
  }

  Future<void> processOrderAndClose(String text) async {
    final List<Map<String, dynamic>> allItems = [];
    menuData.forEach((_, items) => allItems.addAll(items));

    late AgentResponse response;
    try {
      response = await agentService.handleInput(userText: text, menuItems: allItems);
    } catch (e) {
      response = AgentResponse.retry('Order processing failed. Please try again.');
    }

    if (Get.isBottomSheetOpen == true) {
      Get.back(); // Close bottom sheet
    }

    switch (response.action) {
      case AgentAction.auto:
        showVoiceDialog?.call(response.items, 'Voice Order Recognised', false, text, 1.0);
        break;
      case AgentAction.suggest:
        showVoiceDialog?.call(response.suggestions, response.message, true, text, response.confidence);
        break;
      case AgentAction.retry:
        Get.snackbar('Retry', '🎤 ${response.message}', duration: const Duration(seconds: 4));
        break;
    }
  }
}
