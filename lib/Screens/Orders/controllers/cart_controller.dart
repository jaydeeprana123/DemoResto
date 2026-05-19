import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:demo/services/sarvam_stt_service.dart';
import 'package:demo/services/ai_order_service.dart'; // Holds OrderResult
import 'package:demo/Screens/Orders/repositories/cart_repository.dart';

/// CartController
/// 
/// Part of the GetX Repository Pattern.
/// Orchestrates reactive state management for the checkout cart. Coordinates discount logic,
/// cash/online payment ratios, STT voice additions, and acts as the gatekeeper for transaction persistence.
class CartController extends GetxController {
  final CartRepository _repository = CartRepository();
  final SarvamSttService sttService = SarvamSttService();

  // ── Text Controllers ──────────────────────────────────────────────────────
  final TextEditingController tableNameController = TextEditingController();
  final TextEditingController overallRemarksController = TextEditingController();
  
  final TextEditingController discountPercentController = TextEditingController();
  final TextEditingController discountAmountController = TextEditingController();
  
  final TextEditingController cashController = TextEditingController();
  final TextEditingController onlineController = TextEditingController();

  // ── Reactive Properties ───────────────────────────────────────────────────
  final RxList<Map<String, dynamic>> cartItems = <Map<String, dynamic>>[].obs;
  
  // Parallel lists for item-specific remarks
  final List<TextEditingController> remarkControllers = [];
  final RxList<bool> remarkExpanded = <bool>[].obs;

  final RxDouble discountPercent = 0.0.obs;
  final RxDouble discountAmount = 0.0.obs;
  
  final RxBool isBilling = false.obs;
  final RxString paymentMode = 'Cash'.obs; // 'Cash', 'Online', 'Both'

  @override
  void onClose() {
    tableNameController.dispose();
    overallRemarksController.dispose();
    for (final c in remarkControllers) {
      c.dispose();
    }
    discountPercentController.dispose();
    discountAmountController.dispose();
    cashController.dispose();
    onlineController.dispose();
    super.onClose();
  }

  // ── Cart Initialization ───────────────────────────────────────────────────

  /// Feeds the initial list of selected items, table config, and remarks.
  void initializeCart({
    required List<Map<String, dynamic>> initialItems,
    required String initialTableName,
    String? initialOverallRemarks,
  }) {
    tableNameController.text = initialTableName;
    overallRemarksController.text = initialOverallRemarks ?? '';

    cartItems.assignAll(
      initialItems.map((item) => Map<String, dynamic>.from(item)).toList(),
    );

    // Clear and build remark handlers in sync
    for (final c in remarkControllers) {
      c.dispose();
    }
    remarkControllers.clear();

    remarkControllers.addAll(
      cartItems.map((item) => TextEditingController(text: (item['remarks'] ?? '').toString())),
    );

    remarkExpanded.assignAll(
      cartItems.map((item) => (item['remarks'] ?? '').toString().isNotEmpty).toList(),
    );

    updatePaymentAmounts();
  }

  // ── Reactive Calculated Getters ───────────────────────────────────────────

  double get subtotal => cartItems.fold(
        0.0,
        (sum, item) => sum + (item['qty'] as int) * (item['price'] as num),
      );

  int get tax => (subtotal * 0.085).round();

  int get total => ((subtotal + tax - discountAmount.value).round()).clamp(0, 99999999);

  // ── Stepper Actions ───────────────────────────────────────────────────────

  void incrementQty(int index) {
    cartItems[index]['qty']++;
    cartItems.refresh();
    updateDiscountFromPercent();
    updatePaymentAmounts();
  }

  void decrementQty(int index) {
    if (cartItems[index]['qty'] > 1) {
      cartItems[index]['qty']--;
      cartItems.refresh();
    } else {
      cartItems.removeAt(index);
      remarkControllers[index].dispose();
      remarkControllers.removeAt(index);
      remarkExpanded.removeAt(index);
    }
    updateDiscountFromPercent();
    updatePaymentAmounts();
  }

  // ── Discount Recalculation ────────────────────────────────────────────────

  void updateDiscountFromPercent() {
    if (discountPercent.value > 0) {
      discountAmount.value = (subtotal * discountPercent.value) / 100;
      discountAmountController.text = discountAmount.value.toStringAsFixed(0);
    }
    updatePaymentAmounts();
  }

  void updateDiscountFromAmount() {
    if (discountAmount.value > 0 && subtotal > 0) {
      discountPercent.value = (discountAmount.value / subtotal) * 100;
      discountPercentController.text = discountPercent.value.toStringAsFixed(2);
    }
    updatePaymentAmounts();
  }

  // ── Payment Split Recalculation ───────────────────────────────────────────

  void updatePaymentAmounts() {
    if (paymentMode.value == 'Cash') {
      cashController.text = total.toString();
      onlineController.text = "0";
    } else if (paymentMode.value == 'Online') {
      cashController.text = "0";
      onlineController.text = total.toString();
    } else if (paymentMode.value == 'Both') {
      int cash = int.tryParse(cashController.text) ?? total;
      if (cash > total) cash = total;
      cashController.text = cash.toString();
      onlineController.text = (total - cash).toString();
    }
  }

  // ── AI Extraction and Perfect Synchronisation ─────────────────────────────

  /// Synthesizes and matches item quantities exactly from custom notes/remarks.
  Future<List<OrderResult>?> extractItemsFromRemarks(List<Map<String, dynamic>> fullMenu) async {
    final text = overallRemarksController.text.trim();
    if (text.isEmpty) {
      Get.snackbar('Empty Remarks', 'Please enter some text in remarks first.');
      return null;
    }

    if (fullMenu.isEmpty) {
      Get.snackbar(
        'Menu Not Loaded',
        'The full menu is not available. Please go back and try again.',
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return null;
    }

    Get.dialog(
      const Center(child: CircularProgressIndicator(color: Color(0xFFf57c35))),
      barrierDismissible: false,
    );

    try {
      final aiService = AiOrderService();
      final results = await aiService.parseOrder(text, fullMenu);

      Get.back(); // Close loading indicator
      return results;
    } catch (e) {
      Get.back();
      Get.snackbar('Error', 'AI extraction failed: $e');
      return null;
    }
  }

  /// Synchronizes identified voice order results perfectly to the cart checklist.
  void syncCartWithExtractedItems(List<OrderResult> newItems) {
    // 1. Clear old remark controllers safely
    for (final c in remarkControllers) {
      c.dispose();
    }
    remarkControllers.clear();
    remarkExpanded.clear();

    // 2. Full Sync: Re-populate according to identified perfect items
    final List<Map<String, dynamic>> updatedCart = [];

    for (final ni in newItems) {
      final newItem = Map<String, dynamic>.from(ni.item);
      newItem['qty'] = ni.quantity;
      newItem['remarks'] = ni.remarks;
      updatedCart.add(newItem);

      remarkControllers.add(TextEditingController(text: ni.remarks));
      remarkExpanded.add(ni.remarks.isNotEmpty);
    }

    cartItems.assignAll(updatedCart);
    updatePaymentAmounts();
  }

  // ── Persistence Layer Call ────────────────────────────────────────────────

  /// Calls the repository to persist transactional checkout details.
  Future<bool> saveTransaction() async {
    final cash = int.tryParse(cashController.text) ?? 0;
    final online = int.tryParse(onlineController.text) ?? 0;

    try {
      await _repository.addTransactionToFirestore(
        items: cartItems,
        tableName: tableNameController.text,
        subtotal: subtotal.round(),
        tax: tax,
        discount: discountAmount.value.round(),
        total: total,
        cashAmount: cash,
        onlineAmount: online,
      );
      Get.snackbar("Successful", "Transaction saved successfully!",
          backgroundColor: Colors.green.shade700, colorText: Colors.white);
      return true;
    } catch (e) {
      Get.snackbar("Error", "Transaction not saved: $e",
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
      return false;
    }
  }

  /// Saves the active table's items (creating/updating/appending) directly in Firestore.
  Future<bool> saveTableOrder({
    required bool isEditMode,
    required bool isBillPaid,
  }) async {
    try {
      await _repository.updateTableOrAddGroup(
        tableName: tableNameController.text.trim(),
        items: cartItems,
        isEditMode: isEditMode,
        isBillPaid: isBillPaid,
        overallRemarks: overallRemarksController.text.trim(),
      );
      return true;
    } catch (e) {
      Get.snackbar("Error", "Failed to update table order: $e",
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
      return false;
    }
  }
}
