import 'package:demo/Styles/my_font.dart';
import 'package:demo/core/utils/tax_calculator.dart';
import 'package:demo/features/settings/services/tax_settings_service.dart';
import 'package:demo/features/tables/repositories/tables_repository.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum TableBillingMode {
  /// Transaction saved; table cleared (take-away deleted).
  paid,

  /// Transaction saved; table stays with PAID tag and items visible.
  paidWithoutServing,
}

enum BillReceiptAction {
  withoutPrint,
  print,
  shareWhatsApp,
  printAndShareWhatsApp,
}

class TableBillingSubmission {
  const TableBillingSubmission({
    required this.items,
    required this.mode,
    required this.documentId,
    required this.billId,
    required this.subtotal,
    required this.tax,
    required this.cgstPercentage,
    required this.sgstPercentage,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.discount,
    required this.total,
    required this.cashAmount,
    required this.onlineAmount,
    this.extra = 0,
  });

  final List<Map<String, dynamic>> items;
  final TableBillingMode mode;
  final String documentId;
  final String billId;
  final int subtotal;
  final int tax;
  final double cgstPercentage;
  final double sgstPercentage;
  final int cgstAmount;
  final int sgstAmount;
  final int discount;
  final int extra;
  final int total;
  final int cashAmount;
  final int onlineAmount;
}

class TableBillingDialogResult {
  const TableBillingDialogResult({
    required this.mode,
    required this.receiptAction,
    required this.items,
    this.discount = 0,
    this.extra = 0,
    this.finalTotal,
  });

  final TableBillingMode mode;
  final BillReceiptAction receiptAction;
  final List<Map<String, dynamic>> items;
  final int discount;
  final int extra;
  final int? finalTotal;
}

Future<TableBillingDialogResult?> showTableBillingModeDialog(
  BuildContext context, {
  required String tableName,
  required List<Map<String, dynamic>> fallbackItems,
  bool hidePaidOption = false,
}) async {
  if (!context.mounted) return null;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFf57c35)),
              SizedBox(height: 16),
              Text(
                'Loading latest order…',
                style: TextStyle(fontFamily: fontMulishSemiBold),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  List<Map<String, dynamic>> items =
      fallbackItems.map((e) => Map<String, dynamic>.from(e)).toList();
  var loadedFromServer = false;

  try {
    final fresh = await Get.find<TablesRepository>().fetchTableOrderFresh(
      tableName,
    );
    if (fresh != null && fresh.items.isNotEmpty) {
      items = fresh.items;
      loadedFromServer = true;
    }
  } catch (_) {}

  final taxSettings = await TaxSettingsService.load();
  final subtotal = TablesRepository.orderItemsSubtotal(items);
  final taxBreakdown = TaxCalculator.calculate(
    subtotal,
    cgstPercent: taxSettings.cgstPercentage,
    sgstPercent: taxSettings.sgstPercentage,
  );
  final estimatedTotal = (subtotal + taxBreakdown.totalTax).round();

  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  if (!context.mounted || items.isEmpty) return null;

  var receiptAction = BillReceiptAction.withoutPrint;
  var displayTotal = estimatedTotal;
  var discountAmount = 0.0;
  var extraAmount = 0.0;
  var isEditingTotal = false;
  final totalEditController = TextEditingController(
    text: estimatedTotal.toString(),
  );

  void applyManualTotal() {
    final edited = int.tryParse(totalEditController.text.trim());
    if (edited == null || edited < 0) return;
    if (edited < estimatedTotal) {
      displayTotal = edited;
      discountAmount = (estimatedTotal - edited).toDouble();
      extraAmount = 0;
    } else if (edited > estimatedTotal) {
      displayTotal = edited;
      discountAmount = 0;
      extraAmount = (edited - estimatedTotal).toDouble();
    } else {
      displayTotal = estimatedTotal;
      discountAmount = 0;
      extraAmount = 0;
    }
    isEditingTotal = false;
  }

  try {
    final dialogResult = await showDialog<TableBillingDialogResult>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        TableBillingDialogResult result(TableBillingMode mode) {
          return TableBillingDialogResult(
            mode: mode,
            receiptAction: receiptAction,
            items: items,
            discount: discountAmount.round(),
            extra: extraAmount.round(),
            finalTotal: displayTotal,
          );
        }

        Widget receiptRadio(BillReceiptAction value, String label) {
          return InkWell(
            onTap: () => setDialogState(() => receiptAction = value),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Radio<BillReceiptAction>(
                    value: value,
                    groupValue: receiptAction,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) {
                      if (v == null) return;
                      setDialogState(() => receiptAction = v);
                    },
                  ),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontFamily: fontMulishSemiBold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        Widget itemRow(Map<String, dynamic> item) {
          final qty = (item['qty'] as num?)?.toInt() ?? 0;
          final name = item['name']?.toString() ?? '-';
          final price = (item['price'] as num?)?.toDouble() ?? 0;
          final lineTotal = qty * price;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontFamily: fontMulishSemiBold,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '×$qty',
                style: TextStyle(
                  fontFamily: fontMulishRegular,
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '₹${lineTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontFamily: fontMulishSemiBold,
                  fontSize: 13,
                ),
              ),
            ],
          );
        }

        final itemsListHeight = (items.length * 36.0 + 16).clamp(72.0, 220.0);
        final maxDialogHeight = MediaQuery.sizeOf(ctx).height * 0.88;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: maxDialogHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Billing',
                              style: TextStyle(
                                fontFamily: fontMulishSemiBold,
                                fontSize: 18,
                                color: Color(0xFF1A3A5C),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isEditingTotal)
                                SizedBox(
                                  width: 88,
                                  child: TextField(
                                    controller: totalEditController,
                                    keyboardType: TextInputType.number,
                                    autofocus: true,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: fontMulishBold,
                                      fontSize: 16,
                                      color: Color(0xFFf57c35),
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      prefixText: '₹',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        borderSide: BorderSide(
                                          color: const Color(0xFFf57c35)
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFf57c35),
                                        ),
                                      ),
                                    ),
                                    onSubmitted: (_) => setDialogState(
                                      applyManualTotal,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFf57c35)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFf57c35)
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Text(
                                    '₹$displayTotal',
                                    style: const TextStyle(
                                      fontFamily: fontMulishBold,
                                      fontSize: 16,
                                      color: Color(0xFFf57c35),
                                    ),
                                  ),
                                ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: Icon(
                                  isEditingTotal
                                      ? Icons.check_rounded
                                      : Icons.edit_rounded,
                                  size: 18,
                                ),
                                color: const Color(0xFFf57c35),
                                tooltip: isEditingTotal
                                    ? 'Apply amount'
                                    : 'Edit final amount',
                                onPressed: () => setDialogState(() {
                                  if (isEditingTotal) {
                                    applyManualTotal();
                                  } else {
                                    totalEditController.text =
                                        displayTotal.toString();
                                    isEditingTotal = true;
                                  }
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (tableName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          tableName,
                          style: TextStyle(
                            fontFamily: fontMulishRegular,
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: itemsListHeight,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 12,
                              color: Colors.grey.shade200,
                            ),
                            itemBuilder: (_, index) => itemRow(items[index]),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subtotal',
                                style: TextStyle(
                                  fontFamily: fontMulishRegular,
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                '₹${subtotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontFamily: fontMulishBold,
                                  fontSize: 14,
                                  color: Colors.black
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (taxBreakdown.totalTax > 0) ...[
                          const SizedBox(height: 2),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Tax',
                                  style: TextStyle(
                                    fontFamily: fontMulishRegular,
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  '₹${taxBreakdown.totalTax.round()}',
                                  style: const TextStyle(
                                    fontFamily: fontMulishSemiBold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (discountAmount > 0) ...[
                          const SizedBox(height: 2),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Discount',
                                  style: TextStyle(
                                    fontFamily: fontMulishRegular,
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  '-₹${discountAmount.round()}',
                                  style: TextStyle(
                                    fontFamily: fontMulishSemiBold,
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (extraAmount > 0) ...[
                          const SizedBox(height: 2),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Extra',
                                  style: TextStyle(
                                    fontFamily: fontMulishRegular,
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  '+₹${extraAmount.round()}',
                                  style: TextStyle(
                                    fontFamily: fontMulishSemiBold,
                                    fontSize: 12,
                                    color: const Color(0xFFf57c35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Text(
                        //   'Bill delivery',
                        //   style: TextStyle(
                        //     fontFamily: fontMulishSemiBold,
                        //     fontSize: 14,
                        //     color: Colors.grey.shade800,
                        //   ),
                        // ),
                        // const SizedBox(height: 4),
                        receiptRadio(
                          BillReceiptAction.withoutPrint,
                          'Without Print',
                        ),
                        receiptRadio(BillReceiptAction.print, 'Print'),
                        receiptRadio(
                          BillReceiptAction.shareWhatsApp,
                          'Send bill link on WhatsApp',
                        ),
                        receiptRadio(
                          BillReceiptAction.printAndShareWhatsApp,
                          'WhatsApp & Print',
                        ),
                        // if (receiptAction == BillReceiptAction.shareWhatsApp)
                        //   Padding(
                        //     padding: const EdgeInsets.only(left: 36, top: 2),
                        //     child: Text(
                        //       'Uploads PDF to ImageKit and opens WhatsApp with download link.',
                        //       style: TextStyle(
                        //         fontFamily: fontMulishRegular,
                        //         fontSize: 11,
                        //         color: Colors.grey.shade600,
                        //       ),
                        //     ),
                        //   ),
                        const SizedBox(height: 12),
                        Text(
                          'Choose how to complete billing:',
                          style: TextStyle(
                            fontFamily: fontMulishRegular,
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (!hidePaidOption) ...[
                          _ModeButton(
                            icon: Icons.check_circle_outline,
                            label: 'Paid',
                            subtitle: 'Save bill, clear table (delete take-away)',
                            color: const Color(0xFF4CAF50),
                            onTap: () =>
                                Navigator.pop(ctx, result(TableBillingMode.paid)),
                          ),
                          const SizedBox(height: 8),
                        ],
                        _ModeButton(
                          icon: Icons.receipt_long_outlined,
                          label: 'Paid Without Serving',
                          subtitle: 'Save bill, keep order with PAID tag',
                          color: const Color(0xFFf57c35),
                          onTap: () => Navigator.pop(
                            ctx,
                            result(TableBillingMode.paidWithoutServing),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontFamily: fontMulishSemiBold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
    return dialogResult;
  } finally {
    totalEditController.dispose();
  }
}

Future<BillReceiptAction?> showBillReceiptOptionsDialog(
  BuildContext context, {
  String? billId,
}) {
  return showDialog<BillReceiptAction>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Bill',
        style: TextStyle(
          fontFamily: fontMulishSemiBold,
          fontSize: 18,
          color: Color(0xFF1A3A5C),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (billId != null && billId.isNotEmpty) ...[
            Text(
              'Bill ID: $billId',
              style: TextStyle(
                fontFamily: fontMulishRegular,
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Choose how to deliver the bill:',
            style: TextStyle(
              fontFamily: fontMulishRegular,
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          _ModeButton(
            icon: Icons.share_outlined,
            label: 'Send bill link',
            subtitle: 'WhatsApp with ImageKit PDF link to any mobile number',
            color: const Color(0xFF25D366),
            onTap: () => Navigator.pop(ctx, BillReceiptAction.shareWhatsApp),
          ),
          const SizedBox(height: 10),
          _ModeButton(
            icon: Icons.print_rounded,
            label: 'WhatsApp & Print',
            subtitle: 'Print the bill and send WhatsApp PDF link',
            color: const Color(0xFF128C7E),
            onTap: () =>
                Navigator.pop(ctx, BillReceiptAction.printAndShareWhatsApp),
          ),
          const SizedBox(height: 10),
          _ModeButton(
            icon: Icons.print_outlined,
            label: 'Print',
            subtitle: 'Print the bill directly',
            color: const Color(0xFF1A3A5C),
            onTap: () => Navigator.pop(ctx, BillReceiptAction.print),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'Cancel',
            style: TextStyle(fontFamily: fontMulishSemiBold),
          ),
        ),
      ],
    ),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: fontMulishBold,
                        fontSize: 15,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: fontMulishRegular,
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
