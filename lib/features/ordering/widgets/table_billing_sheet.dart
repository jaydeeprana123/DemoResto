import 'dart:async';

import 'package:smartKitchen/features/ordering/services/food_bill_pdf_service.dart';
import 'package:smartKitchen/features/ordering/widgets/table_billing_mode_dialog.dart';
import 'package:smartKitchen/features/ordering/widgets/unified_billing_dialog.dart';
import 'package:smartKitchen/features/settings/repositories/bill_customer_contacts_repository.dart';
import 'package:smartKitchen/features/shell/controllers/shell_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

export 'package:smartKitchen/features/ordering/widgets/table_billing_mode_dialog.dart'
    show BillReceiptAction, TableBillingMode, TableBillingSubmission;
export 'package:smartKitchen/features/ordering/widgets/unified_billing_dialog.dart'
    show BillingFlowResult;

class TableBillingSheet {
  TableBillingSheet._();

  static double orderTotal(List<Map<String, dynamic>> items) {
    return items.fold<double>(
      0,
      (sum, item) =>
          sum +
          ((item['qty'] as num?)?.toInt() ?? 0) *
              ((item['price'] as num?)?.toDouble() ?? 0),
    );
  }

  /// Pops all routes until the app home (dashboard shell).
  static void popToDashboard(BuildContext context) {
    if (Get.isRegistered<ShellController>()) {
      final shell = Get.find<ShellController>();
      final dashboardIndex = shell.visibleTabs.indexOf(ShellTab.dashboard);
      if (dashboardIndex >= 0) {
        shell.changeTab(dashboardIndex);
      }
    }

    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  /// Print / WhatsApp delivery after navigation — must not block UI pop.
  static void deliverReceiptInBackground(BillingFlowResult result) {
    final needsWhatsApp =
        result.receiptAction == BillReceiptAction.shareWhatsApp ||
        result.receiptAction == BillReceiptAction.printAndShareWhatsApp;
    if (needsWhatsApp && result.whatsappPhone != null) {
      unawaited(
        _saveCustomerContactSafely(
          name: result.customerName ?? '',
          mobile: result.customerMobile ?? '',
        ),
      );
    }

    unawaited(
      FoodBillPdfService.deliverReceiptByAction(
        result.receiptData,
        result.receiptAction,
        whatsappPhone: result.whatsappPhone,
      ),
    );
  }

  static Future<void> _saveCustomerContactSafely({
    required String name,
    required String mobile,
  }) async {
    try {
      await Get.find<BillCustomerContactsRepository>().upsertContact(
        name: name,
        mobile: mobile,
      );
    } catch (_) {}
  }

  /// Opens the unified billing dialog. Returns result when billing completes.
  static Future<BillingFlowResult?> runBillingFlow(
    BuildContext context, {
    required String tableName,
    required List<Map<String, dynamic>> items,
    required Future<void> Function(TableBillingSubmission submission) onSubmit,
    bool hidePaidOption = false,
    String? addedByUserName,
  }) {
    return showUnifiedBillingDialog(
      context,
      tableName: tableName,
      fallbackItems: items,
      hidePaidOption: hidePaidOption,
      addedByUserName: addedByUserName,
      onSubmit: onSubmit,
    );
  }
}
