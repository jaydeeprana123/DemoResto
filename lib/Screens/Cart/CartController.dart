import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:demo/models/agent_response.dart';
import 'package:demo/services/ai_order_service.dart';
import 'package:demo/services/sarvam_stt_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CartController extends GetxController {
  final List<Map<String, dynamic>> initialCartItems;
  final String initialTableName;
  final List<Map<String, dynamic>> fullMenu;
  final String? initialRemarks;

  CartController({
    required this.initialCartItems,
    required this.initialTableName,
    required this.fullMenu,
    this.initialRemarks,
  });

  // Observables
  var cartItems = <Map<String, dynamic>>[].obs;
  
  late TextEditingController tableNameController;
  late TextEditingController overallRemarksController;
  
  var remarkControllers = <TextEditingController>[].obs;
  var remarkExpanded = <bool>[].obs;

  final discountPercentController = TextEditingController();
  final discountAmountController = TextEditingController();
  final cashController = TextEditingController();
  final onlineController = TextEditingController();

  var discountPercent = 0.0.obs;
  var discountAmount = 0.0.obs;
  var isBilling = false.obs;
  var paymentMode = 'Cash'.obs;

  final SarvamSttService sttService = SarvamSttService();
  final AiOrderService aiService = AiOrderService();

  // Callbacks for UI interaction
  void Function(List<OrderResult> newItems)? showExtractedItemsDialog;
  void Function()? showLoadingDialog;
  void Function()? hideLoadingDialog;
  void Function(BuildContext)? showVoiceBottomSheet;

  @override
  void onInit() {
    super.onInit();
    tableNameController = TextEditingController(text: initialTableName);
    overallRemarksController = TextEditingController(text: initialRemarks ?? '');
    
    for (var item in initialCartItems) {
      cartItems.add(Map<String, dynamic>.from(item));
      remarkControllers.add(TextEditingController(text: (item['remarks'] ?? '').toString()));
      remarkExpanded.add((item['remarks'] ?? '').toString().isNotEmpty);
    }
    
    updatePaymentAmounts();
  }

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

  /// Calculates the subtotal of all items in the cart
  double get subtotal => cartItems.fold(
    0.0,
    (sum, item) => sum + (item['qty'] as int) * (item['price']),
  );

  /// Calculates the total cost including tax and subtracting discount
  int get total => ((subtotal + (subtotal * 0.085) - discountAmount.value).round());

  /// Calculates the tax amount
  double get tax => subtotal * 0.085;

  /// Increments the quantity of an item in the cart
  void incrementQty(int index) {
    cartItems[index]['lastQty'] = cartItems[index]['qty'];
    cartItems[index]['qty']++;
    cartItems.refresh();
    updateDiscountFromPercent();
  }

  /// Decrements the quantity of an item or removes it if quantity reaches 0
  void decrementQty(int index) {
    if (cartItems[index]['qty'] > 1) {
      cartItems[index]['lastQty'] = cartItems[index]['qty'];
      cartItems[index]['qty']--;
    } else {
      cartItems.removeAt(index);
      remarkControllers[index].dispose();
      remarkControllers.removeAt(index);
      remarkExpanded.removeAt(index);
    }
    cartItems.refresh();
    updateDiscountFromPercent();
  }

  /// Syncs the list of identified items into the cart matching by name
  void syncItemsFromExtraction(List<OrderResult> newItems) {
    for (int i = cartItems.length - 1; i >= 0; i--) {
      final cartItemName = cartItems[i]['name'].toString().toLowerCase();
      
      final match = newItems.firstWhereOrNull(
        (ni) => ni.item['name'].toString().toLowerCase() == cartItemName
      );
      
      if (match != null) {
        cartItems[i]['qty'] = match.quantity;
        cartItems[i]['remarks'] = match.remarks;
        remarkControllers[i].text = match.remarks;
        remarkExpanded[i] = match.remarks.isNotEmpty;
      } else {
        cartItems.removeAt(i);
        remarkControllers[i].dispose();
        remarkControllers.removeAt(i);
        remarkExpanded.removeAt(i);
      }
    }

    for (var ni in newItems) {
      final niNameLower = ni.item['name'].toString().toLowerCase();
      final alreadyHandled = cartItems.any(
        (ci) => ci['name'].toString().toLowerCase() == niNameLower
      );
      if (!alreadyHandled) {
        final newItem = Map<String, dynamic>.from(ni.item);
        newItem['qty'] = ni.quantity;
        newItem['remarks'] = ni.remarks;
        cartItems.add(newItem);
        remarkControllers.add(TextEditingController(text: ni.remarks));
        remarkExpanded.add(ni.remarks.isNotEmpty);
      }
    }
    
    cartItems.refresh();
    updatePaymentAmounts();
  }

  /// Extracts structured items from the natural language remarks using AI
  Future<void> extractItemsFromRemarks() async {
    final text = overallRemarksController.text.trim();
    if (text.isEmpty) {
      Get.snackbar('Empty Remarks', 'Please enter some text in remarks first.');
      return;
    }

    if (fullMenu.isEmpty) {
      Get.snackbar(
        'Menu Not Loaded',
        'The full menu is not available. Please go back and try again.',
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    showLoadingDialog?.call();

    try {
      final results = await aiService.parseOrder(text, fullMenu);
      hideLoadingDialog?.call();

      if (results.isEmpty) {
        Get.snackbar(
          'No Items Found',
          'Could not match any menu items from these remarks. Try saying the item name more clearly.',
          duration: const Duration(seconds: 4),
        );
        return;
      }

      showExtractedItemsDialog?.call(results);
    } catch (e) {
      hideLoadingDialog?.call();
      Get.snackbar('Error', 'AI extraction failed: $e');
    }
  }

  /// Updates discount amount based on given percentage
  void updateDiscountFromPercent() {
    if (discountPercent.value > 0) {
      discountAmount.value = (subtotal * discountPercent.value) / 100;
      discountAmountController.text = discountAmount.value.toStringAsFixed(0);
    }
    updatePaymentAmounts();
  }

  /// Updates percentage based on given discount amount
  void updateDiscountFromAmount() {
    if (discountAmount.value > 0 && subtotal > 0) {
      discountPercent.value = (discountAmount.value / subtotal) * 100;
      discountPercentController.text = discountPercent.value.toStringAsFixed(2);
    }
    updatePaymentAmounts();
  }

  /// Adjusts the cash and online breakdown based on the total cart value
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

  /// Toggles visibility of item remarks field
  void toggleRemarkExpanded(int index, bool expand) {
    remarkExpanded[index] = expand;
  }

  /// Updates text of item remarks
  void updateRemark(int index, String text) {
    cartItems[index]['remarks'] = text;
  }

  /// Changes the payment mode and recalculates amounts
  void setPaymentMode(String mode) {
    paymentMode.value = mode;
    updatePaymentAmounts();
  }

  /// Handles completion of voice recording from bottom sheet
  void onVoiceRecordingComplete(String recognizedText) {
    if (recognizedText.isNotEmpty) {
      if (overallRemarksController.text.isNotEmpty) {
        overallRemarksController.text += '\n';
      }
      overallRemarksController.text += recognizedText;
      extractItemsFromRemarks();
    }
  }

  /// Saves the transaction details to Firestore and updates statistics
  Future<void> addTransactionToFirestore({
    required List<Map<String, dynamic>> items,
    required String tableName,
    required int subtotal,
    required int tax,
    required int discount,
    required int total,
    required int cashAmount,
    required int onlineAmount,
  }) async {
    try {
      final now = DateTime.now();
      final dateKey = DateFormat("yyyy-MM-dd").format(now);

      final batch = FirebaseFirestore.instance.batch();

      // 1. Add transaction record
      final txRef = FirebaseFirestore.instance.collection("transactions").doc();
      batch.set(txRef, {
        "table": tableName,
        "items": items
            .map(
              (e) => {
                "name": e["name"],
                "qty": e["qty"],
                "price": (e["price"]).round(),
                "total": ((e["qty"]) * (e["price"])).round(),
              },
            )
            .toList(),
        "subtotal": subtotal,
        "tax": tax,
        "discount": discount,
        "total": total,
        "cashAmount": cashAmount,
        "onlineAmount": onlineAmount,
        "createdAt": FieldValue.serverTimestamp(),
      });

      // 2. Update daily statistics
      final dailyRef = FirebaseFirestore.instance
          .collection("daily_stats")
          .doc(dateKey);
      batch.set(dailyRef, {
        "revenue": FieldValue.increment(total),
        "totalCash": FieldValue.increment(cashAmount),
        "totalOnline": FieldValue.increment(onlineAmount),
        "transactions": FieldValue.increment(1),
        "lastUpdated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Update global summary
      final summaryRef = FirebaseFirestore.instance
          .collection("stats")
          .doc("summary");
      batch.set(summaryRef, {
        "totalRevenue": FieldValue.increment(total),
        "totalTransactions": FieldValue.increment(1),
        "lastUpdated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Commit all changes at once
      await batch.commit();
      Get.snackbar("Successful", "Transaction saved successfully!", backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Error", "Transaction not saved: " + e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
    }
  }
}
