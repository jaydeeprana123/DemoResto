import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:demo/Screens/Billing/repositories/billing_repository.dart';

/// BillingController
/// 
/// Part of the GetX Repository Pattern.
/// This controller handles all presentation states (payment modes, discounts, subtotal, tax, total)
/// and orchestrates database updates through the [BillingRepository].
class BillingController extends GetxController {
  final BillingRepository _repository = BillingRepository();

  final String tableName;
  final List<Map<String, dynamic>> initialMenuData;

  BillingController({
    required this.tableName,
    required this.initialMenuData,
  });

  // ── Reactive Observables (.obs) ───────────────────────────────────────────
  late final RxList<Map<String, dynamic>> cartItems;
  late final RxList<int> lastQtys;
  final RxDouble discountPercent = 0.0.obs;
  final RxDouble discountAmount = 0.0.obs;
  final RxString paymentMode = 'Cash'.obs; // Cash, Online, Both
  final RxBool isLoading = false.obs;

  // ── Text Editing Controllers ───────────────────────────────────────────────
  final TextEditingController discountPercentController = TextEditingController();
  final TextEditingController discountAmountController = TextEditingController();
  final TextEditingController cashController = TextEditingController();
  final TextEditingController onlineController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    // Initialize reactive variables from parameters
    cartItems = initialMenuData
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
        .obs;

    lastQtys = cartItems
        .map<int>((e) => e['qty'] as int)
        .toList()
        .obs;

    updatePaymentAmounts();
  }

  @override
  void onClose() {
    discountPercentController.dispose();
    discountAmountController.dispose();
    cashController.dispose();
    onlineController.dispose();
    super.onClose();
  }

  // ── Calculated Getters ─────────────────────────────────────────────────────
  double get subtotal => cartItems.fold(
        0,
        (sum, item) => sum + (item['qty'] as int) * (item['price'] as num),
      );

  int get tax => (subtotal * 0.085).round();

  int get total => ((subtotal + tax - discountAmount.value).round());

  // ── Reactive Methods & Business Logic ──────────────────────────────────────

  /// Increments quantity of an item in the cart.
  void incrementQty(int index) {
    lastQtys[index] = cartItems[index]['qty']; // store old value
    cartItems[index]['qty']++;
    cartItems.refresh();
    updateDiscountFromPercent();
    updatePaymentAmounts();
  }

  /// Decrements quantity of an item in the cart. Removes item if quantity reaches 0.
  void decrementQty(int index) {
    lastQtys[index] = cartItems[index]['qty']; // store old value
    if (cartItems[index]['qty'] > 1) {
      cartItems[index]['qty']--;
      cartItems.refresh();
    } else {
      cartItems.removeAt(index);
      lastQtys.removeAt(index);
    }
    updateDiscountFromPercent();
    updatePaymentAmounts();
  }

  /// Updates discount amount value based on percentage input.
  void updateDiscountFromPercent() {
    if (discountPercent.value > 0) {
      discountAmount.value = (subtotal * discountPercent.value) / 100;
      discountAmountController.text = discountAmount.value.toStringAsFixed(0);
    } else {
      discountAmount.value = 0.0;
      discountAmountController.text = "";
    }
    updatePaymentAmounts();
  }

  /// Updates discount percentage value based on amount input.
  void updateDiscountFromAmount() {
    if (discountAmount.value > 0 && subtotal > 0) {
      discountPercent.value = (discountAmount.value / subtotal) * 100;
      discountPercentController.text = discountPercent.value.toStringAsFixed(2);
    } else {
      discountPercent.value = 0.0;
      discountPercentController.text = "";
    }
    updatePaymentAmounts();
  }

  /// Updates splitting payment amounts when payment mode is Cash, Online, or Both.
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

  // ── Database Action Delegation ─────────────────────────────────────────────

  /// Saves transaction statistics to Firestore and clears/deletes table doc on completion.
  Future<void> checkoutBill() async {
    isLoading.value = true;
    try {
      final cash = int.tryParse(cashController.text) ?? 0;
      final online = int.tryParse(onlineController.text) ?? 0;

      // 1. Commit transaction logs to database via repository
      await _repository.saveTransaction(
        items: cartItems,
        tableName: tableName,
        subtotal: subtotal.round(),
        tax: tax,
        discount: discountAmount.value.round(),
        total: total,
        cashAmount: cash,
        onlineAmount: online,
      );

      // 2. Clear or delete the table records from Firestore
      await _repository.clearOrDeleteTable(tableName);

      Get.snackbar(
        "Successful",
        "Transaction saved successfully!",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Transaction not saved: ${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // ── PDF Utility Generator ──────────────────────────────────────────────────

  /// Generates invoice receipt PDF data.
  Future<Uint8List> generateInvoicePdf({
    required int cashAmount,
    required int onlineAmount,
  }) async {
    final pdf = pw.Document();

    // Load custom Unicode font
    final fontData = await rootBundle.load("assets/fonts/NotoSans-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    // Load logo
    final ByteData logoData = await rootBundle.load('assets/images/logo.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.DefaultTextStyle(
            style: pw.TextStyle(font: ttf, fontSize: 12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Image(logoImage, width: 64, height: 64),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        "Flavor Flow",
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Invoice / Bill",
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),

                pw.Text(
                  "Table / Order: $tableName",
                  style: pw.TextStyle(
                    font: ttf,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                pw.Divider(),

                pw.Table(
                  border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text("Item"),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text("Qty"),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text("Price"),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text("Total"),
                        ),
                      ],
                    ),
                    ...cartItems.map((item) {
                      final qty = item['qty'] ?? 1;
                      final price = double.tryParse(item['price'].toString()) ?? 0;
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(item['name'] ?? ''),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('$qty'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('₹${price.toStringAsFixed(2)}'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              '₹${(price * qty).toStringAsFixed(2)}',
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),

                pw.SizedBox(height: 16),

                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Subtotal: ₹${subtotal.toStringAsFixed(2)}"),
                      pw.Text("Tax (8.5%): ₹${tax.toStringAsFixed(2)}"),
                      pw.Text("Discount: ₹${discountAmount.value.toStringAsFixed(2)}"),
                      pw.Text(
                        "Total: ₹${total.toStringAsFixed(2)}",
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text("Cash: ₹$cashAmount"),
                      pw.Text("Online: ₹$onlineAmount"),
                    ],
                  ),
                ),

                pw.Divider(),

                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    "Thank you for visiting!",
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}
