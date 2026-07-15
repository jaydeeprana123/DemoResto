import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/core/utils/tax_calculator.dart';
import 'package:demo/features/ordering/services/food_bill_pdf_service.dart';
import 'package:demo/features/ordering/widgets/billing_progress_dialog.dart';
import 'package:demo/features/ordering/widgets/table_billing_mode_dialog.dart';
import 'package:demo/features/ordering/widgets/tax_summary_rows.dart';
import 'package:demo/features/ordering/widgets/whatsapp_share_phone_dialog.dart';
import 'package:demo/features/settings/services/tax_settings_service.dart';
import 'package:demo/features/tables/repositories/tables_repository.dart';
import 'package:demo/features/transactions/repositories/transactions_repository.dart';
import 'package:demo/features/zomato/services/imagekit_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

const _dialogNavy = Color(0xFF1A3A5C);
const _dialogBorder = Color(0xFFE3E8EF);
const _dialogMuted = Color(0xFF64748B);
const _dialogSuccess = Color(0xFF2E7D52);

/// Result of a successful unified billing flow.
class BillingFlowResult {
  const BillingFlowResult({
    required this.receiptData,
    required this.receiptAction,
    this.whatsappPhone,
    this.customerName,
    this.customerMobile,
  });

  final FoodBillPdfData receiptData;
  final BillReceiptAction receiptAction;
  final String? whatsappPhone;
  final String? customerName;
  final String? customerMobile;
}

Future<BillingFlowResult?> showUnifiedBillingDialog(
  BuildContext context, {
  required String tableName,
  required List<Map<String, dynamic>> fallbackItems,
  required Future<void> Function(TableBillingSubmission submission) onSubmit,
  bool hidePaidOption = false,
}) async {
  if (!context.mounted || fallbackItems.isEmpty) return null;

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
              CircularProgressIndicator(color: primary_color),
              SizedBox(height: 16),
              Text(
                'Loading order…',
                style: TextStyle(fontFamily: fontMulishSemiBold),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  var items = fallbackItems.map((e) => Map<String, dynamic>.from(e)).toList();
  try {
    final fresh = await Get.find<TablesRepository>().fetchTableOrderFresh(
      tableName,
    );
    if (fresh != null && fresh.items.isNotEmpty) {
      items = fresh.items;
    }
  } catch (_) {}

  final taxSettings = await TaxSettingsService.load();

  if (context.mounted) {
    Navigator.of(context).pop();
  }
  if (!context.mounted || items.isEmpty) return null;

  final result = await showDialog<BillingFlowResult>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _UnifiedBillingDialog(
      tableName: tableName,
      items: items,
      cgstPercent: taxSettings.cgstPercentage,
      sgstPercent: taxSettings.sgstPercentage,
      hidePaidOption: hidePaidOption,
      onSubmit: onSubmit,
    ),
  );

  return result;
}

class _UnifiedBillingDialog extends StatefulWidget {
  const _UnifiedBillingDialog({
    required this.tableName,
    required this.items,
    required this.cgstPercent,
    required this.sgstPercent,
    required this.hidePaidOption,
    required this.onSubmit,
  });

  final String tableName;
  final List<Map<String, dynamic>> items;
  final double cgstPercent;
  final double sgstPercent;
  final bool hidePaidOption;
  final Future<void> Function(TableBillingSubmission submission) onSubmit;

  @override
  State<_UnifiedBillingDialog> createState() => _UnifiedBillingDialogState();
}

class _UnifiedBillingDialogState extends State<_UnifiedBillingDialog> {
  final cashController = TextEditingController();
  final onlineController = TextEditingController();
  final totalController = TextEditingController();
  final discountAmountController = TextEditingController(text: '0');
  final discountPercentController = TextEditingController(text: '0');
  final mobileController = TextEditingController();
  final customerNameController = TextEditingController();

  late List<Map<String, dynamic>> _items;

  double discountAmount = 0;
  double extraAmount = 0;
  bool _isEditingTotal = false;
  bool _totalOverridden = false;
  bool _syncingDiscountFields = false;
  String paymentMode = 'Cash';
  BillReceiptAction receiptAction = BillReceiptAction.withoutPrint;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _items = widget.items.map((e) => Map<String, dynamic>.from(e)).toList();
    customerNameController.text = widget.tableName;
    totalController.text = _computedTotal.toString();
    _updatePaymentAmounts();
  }

  @override
  void dispose() {
    cashController.dispose();
    onlineController.dispose();
    totalController.dispose();
    discountAmountController.dispose();
    discountPercentController.dispose();
    mobileController.dispose();
    customerNameController.dispose();
    super.dispose();
  }

  double get _subtotal => TablesRepository.orderItemsSubtotal(_items);

  TaxBreakdown get _taxBreakdown => TaxCalculator.calculate(
    _subtotal,
    cgstPercent: widget.cgstPercent,
    sgstPercent: widget.sgstPercent,
  );

  int get _taxableTotal => (_subtotal + _taxBreakdown.totalTax).round();

  int get _computedTotal =>
      (_subtotal + _taxBreakdown.totalTax - discountAmount + extraAmount)
          .round();

  int get total {
    if (_totalOverridden) {
      return int.tryParse(totalController.text.trim()) ?? _computedTotal;
    }
    return _computedTotal;
  }

  double get _discountPercent {
    final taxable = _taxableTotal;
    if (taxable <= 0 || discountAmount <= 0) return 0;
    return (discountAmount / taxable) * 100;
  }

  String _formatPercent(double pct) {
    if ((pct - pct.roundToDouble()).abs() < 0.0001) {
      return pct.round().toString();
    }
    return pct.toStringAsFixed(2);
  }

  void _syncDiscountControllersFromState({bool syncTotal = true}) {
    if (_syncingDiscountFields) return;
    _syncingDiscountFields = true;
    _setControllerText(
      discountAmountController,
      discountAmount.round().toString(),
    );
    _setControllerText(
      discountPercentController,
      _formatPercent(_discountPercent),
    );
    if (syncTotal && !_isEditingTotal) {
      _setControllerText(totalController, total.toString());
    }
    _syncingDiscountFields = false;
  }

  void _applyDiscountAmount(String value) {
    if (_syncingDiscountFields) return;
    final parsed = double.tryParse(value.trim());
    if (parsed == null && value.trim().isNotEmpty) return;

    final taxable = _taxableTotal.toDouble();
    final amount = (parsed ?? 0).clamp(0, taxable).toDouble();

    setState(() {
      _totalOverridden = false;
      discountAmount = amount;
      extraAmount = 0;
      _syncingDiscountFields = true;
      if (parsed != null && parsed != amount) {
        _setControllerText(discountAmountController, amount.round().toString());
      }
      _setControllerText(
        discountPercentController,
        _formatPercent(_discountPercent),
      );
      _setControllerText(totalController, _computedTotal.toString());
      _syncingDiscountFields = false;
      _updatePaymentAmounts();
    });
  }

  void _applyDiscountPercent(String value) {
    if (_syncingDiscountFields) return;
    final parsed = double.tryParse(value.trim());
    if (parsed == null && value.trim().isNotEmpty) return;

    final pct = (parsed ?? 0).clamp(0, 100).toDouble();
    final taxable = _taxableTotal;

    setState(() {
      _totalOverridden = false;
      discountAmount = taxable * pct / 100;
      extraAmount = 0;
      _syncingDiscountFields = true;
      if (parsed != null && parsed != pct) {
        _setControllerText(discountPercentController, _formatPercent(pct));
      }
      _setControllerText(
        discountAmountController,
        discountAmount.round().toString(),
      );
      _setControllerText(totalController, _computedTotal.toString());
      _syncingDiscountFields = false;
      _updatePaymentAmounts();
    });
  }

  void _recalculateFromFinalAmount({bool commit = false}) {
    final edited = int.tryParse(totalController.text.trim());
    if (edited == null || edited < 0) return;

    setState(() {
      _totalOverridden = true;
      if (commit) {
        _isEditingTotal = false;
        totalController.text = edited.toString();
      }
      final taxable = _taxableTotal;
      if (edited < taxable) {
        discountAmount = (taxable - edited).toDouble();
        extraAmount = 0;
      } else if (edited > taxable) {
        discountAmount = 0;
        extraAmount = (edited - taxable).toDouble();
      } else {
        discountAmount = 0;
        extraAmount = 0;
      }
      _syncDiscountControllersFromState(syncTotal: commit);
      _updatePaymentAmounts();
    });
  }

  void _applyManualTotal() => _recalculateFromFinalAmount(commit: true);

  /// Sets a controller's text while keeping the caret at the end, so typing
  /// in the split-payment fields appends instead of selecting/replacing.
  void _setControllerText(TextEditingController controller, String text) {
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _updatePaymentAmounts() {
    if (paymentMode == 'Cash') {
      cashController.text = total.toString();
      onlineController.text = '0';
    } else if (paymentMode == 'Online') {
      cashController.text = '0';
      onlineController.text = total.toString();
    } else {
      var cash = int.tryParse(cashController.text) ?? total;
      if (cash > total) cash = total;
      cashController.text = cash.toString();
      onlineController.text = (total - cash).toString();
    }
  }

  Future<void> _confirm(TableBillingMode mode) async {
    if (_submitting) return;

    String? whatsappPhone;
    final requiresWhatsApp =
        receiptAction == BillReceiptAction.shareWhatsApp ||
        receiptAction == BillReceiptAction.printAndShareWhatsApp;
    if (requiresWhatsApp) {
      final phoneError = WhatsAppSharePhoneDialog.validatePhone(
        mobileController.text,
      );
      if (phoneError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(phoneError)));
        return;
      }
      if (!await ImageKitSettings.isConfigured()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ImageKit is not configured. Open Settings → Zomato / ImageKit.',
            ),
          ),
        );
        return;
      }
      whatsappPhone = WhatsAppSharePhoneDialog.normalizePhone(
        mobileController.text,
      );
    }

    setState(() => _submitting = true);
    BillingProgressDialog.show(context);
    FoodBillPdfData? receiptData;

    try {
      final cash = int.tryParse(cashController.text) ?? 0;
      final online = int.tryParse(onlineController.text) ?? 0;
      final taxes = _taxBreakdown;
      final taxAmount = taxes.totalTax;
      final confirmedItems = _items
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final result = await Get.find<TransactionsRepository>().createTransaction(
        items: confirmedItems,
        tableName: widget.tableName,
        subtotal: _subtotal.round(),
        tax: taxAmount,
        cgstPercentage: widget.cgstPercent,
        sgstPercentage: widget.sgstPercent,
        cgstAmount: taxes.cgstAmount,
        sgstAmount: taxes.sgstAmount,
        discount: discountAmount.round(),
        extra: extraAmount.round(),
        total: total,
        cashAmount: cash,
        onlineAmount: online,
      );

      if (result == null) {
        throw Exception('Transaction not saved.');
      }

      final submission = TableBillingSubmission(
        items: confirmedItems,
        mode: mode,
        documentId: result.documentId,
        billId: result.billId,
        subtotal: _subtotal.round(),
        tax: taxAmount,
        cgstPercentage: widget.cgstPercent,
        sgstPercentage: widget.sgstPercent,
        cgstAmount: taxes.cgstAmount,
        sgstAmount: taxes.sgstAmount,
        discount: discountAmount.round(),
        extra: extraAmount.round(),
        total: total,
        cashAmount: cash,
        onlineAmount: online,
      );

      await widget.onSubmit(submission);

      receiptData = FoodBillPdfData(
        tableName: widget.tableName,
        customerName: customerNameController.text.trim(),
        items: confirmedItems,
        subtotal: _subtotal.round(),
        tax: taxAmount,
        cgstPercentage: widget.cgstPercent,
        sgstPercentage: widget.sgstPercent,
        cgstAmount: taxes.cgstAmount,
        sgstAmount: taxes.sgstAmount,
        discount: discountAmount.round(),
        extra: extraAmount.round(),
        total: total,
        cashAmount: cash,
        onlineAmount: online,
        invoiceNumber: result.billId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Billing failed: $e')));
      }
      return;
    } finally {
      if (mounted) {
        BillingProgressDialog.hide(context);
        setState(() => _submitting = false);
      }
    }

    if (!mounted) return;

    Navigator.pop(
      context,
      BillingFlowResult(
        receiptData: receiptData!,
        receiptAction: receiptAction,
        whatsappPhone: whatsappPhone,
        customerName: customerNameController.text,
        customerMobile: mobileController.text,
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: fontMulishSemiBold,
          fontSize: 13,
          color: _dialogNavy,
        ),
      ),
    );
  }

  Widget _summaryLine(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: fontMulishRegular,
              fontSize: 13,
              color: _dialogMuted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: fontMulishSemiBold,
              fontSize: 13,
              color: valueColor ?? text_color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectBox({
    required bool selected,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: selected
                  ? primary_color.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? primary_color : _dialogBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? primary_color : _dialogMuted,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: fontMulishSemiBold,
                      fontSize: 12,
                      color: selected ? primary_color : _dialogMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 14, fontFamily: fontMulishRegular),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _dialogBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _dialogBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primary_color),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: _submitting ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.45),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: fontMulishSemiBold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _headerTotalChip() {
    if (_isEditingTotal) {
      return SizedBox(
        width: 88,
        child: TextField(
          controller: totalController,
          keyboardType: TextInputType.number,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: fontMulishBold,
            fontSize: 16,
            color: primary_color,
          ),
          decoration: InputDecoration(
            isDense: true,
            prefixText: '₹',
            filled: true,
            fillColor: primary_color.withValues(alpha: 0.12),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: primary_color.withValues(alpha: 0.35),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: primary_color.withValues(alpha: 0.35),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: primary_color),
            ),
          ),
          onChanged: (_) => _recalculateFromFinalAmount(),
          onSubmitted: (_) => _applyManualTotal(),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primary_color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary_color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '₹$total',
        style: const TextStyle(
          fontFamily: fontMulishBold,
          fontSize: 16,
          color: primary_color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taxes = _taxBreakdown;
    final itemsHeight = (_items.length * 34.0 + 8).clamp(72.0, 170.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      backgroundColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Billing Summary',
                          style: TextStyle(
                            fontFamily: fontMulishBold,
                            fontSize: 17,
                            color: _dialogNavy,
                          ),
                        ),
                        if (widget.tableName.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            widget.tableName,
                            style: const TextStyle(
                              fontFamily: fontMulishSemiBold,
                              fontSize: 14,
                              color: _dialogMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _headerTotalChip(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        icon: Icon(
                          _isEditingTotal
                              ? Icons.check_rounded
                              : Icons.edit_rounded,
                          size: 20,
                        ),
                        color: primary_color,
                        tooltip: _isEditingTotal ? 'Apply total' : 'Edit total',
                        onPressed: _isEditingTotal
                            ? _applyManualTotal
                            : () {
                                totalController.text = total.toString();
                                setState(() => _isEditingTotal = true);
                              },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: _dialogMuted,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _dialogBorder),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: itemsHeight,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(color: _dialogBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 10, color: _dialogBorder),
                        itemBuilder: (_, index) {
                          final item = _items[index];
                          final qty = (item['qty'] as num?)?.toInt() ?? 0;
                          final name = item['name']?.toString() ?? '-';
                          final price =
                              (item['price'] as num?)?.toDouble() ?? 0;
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontFamily: fontMulishSemiBold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                '×$qty',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _dialogMuted,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₹${(qty * price).toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontFamily: fontMulishBold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    _summaryLine(
                      'Subtotal',
                      '₹${_subtotal.toStringAsFixed(0)}',
                    ),
                    if (taxes.hasTax) ...[
                      const SizedBox(height: 4),
                      TaxSummaryRows(breakdown: taxes),
                    ],
                    if (extraAmount > 0) ...[
                      const SizedBox(height: 4),
                      _summaryLine(
                        'Extra',
                        '+₹${extraAmount.round()}',
                        valueColor: primary_color,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _label('Discount Amount'),
                              TextField(
                                controller: discountAmountController,
                                decoration: _inputDecoration(""),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: _applyDiscountAmount,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _label('Discount Percentage (%)'),
                              TextField(
                                controller: discountPercentController,
                                decoration: _inputDecoration(''),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
                                onChanged: _applyDiscountPercent,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: _dialogBorder),
                    _label('Customer Name'),
                    TextField(
                      controller: customerNameController,
                      decoration: _inputDecoration('Customer name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    _label('Mobile Number'),
                    TextField(
                      controller: mobileController,
                      decoration: _inputDecoration(
                        receiptAction == BillReceiptAction.shareWhatsApp ||
                                receiptAction ==
                                    BillReceiptAction.printAndShareWhatsApp
                            ? '10-digit mobile (required for WhatsApp)'
                            : '10-digit mobile (optional)',
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 12,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const Divider(height: 24, color: _dialogBorder),
                    _label('Payment Mode'),
                    Row(
                      children: [
                        _selectBox(
                          selected: paymentMode == 'Cash',
                          label: 'Cash',
                          icon: Icons.payments_outlined,
                          onTap: () => setState(() {
                            paymentMode = 'Cash';
                            _updatePaymentAmounts();
                          }),
                        ),
                        const SizedBox(width: 8),
                        _selectBox(
                          selected: paymentMode == 'Online',
                          label: 'Online',
                          icon: Icons.account_balance_wallet_outlined,
                          onTap: () => setState(() {
                            paymentMode = 'Online';
                            _updatePaymentAmounts();
                          }),
                        ),
                        const SizedBox(width: 8),
                        _selectBox(
                          selected: paymentMode == 'Both',
                          label: 'Both',
                          icon: Icons.sync_alt_rounded,
                          onTap: () => setState(() {
                            paymentMode = 'Both';
                            _updatePaymentAmounts();
                          }),
                        ),
                      ],
                    ),
                    if (paymentMode == 'Both') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: cashController,
                              decoration: _inputDecoration('Cash ₹'),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                var cash = int.tryParse(value.trim()) ?? 0;
                                // Only rewrite the field being typed in when we
                                // must clamp it; otherwise leave the caret be.
                                if (cash > total) {
                                  cash = total;
                                  _setControllerText(
                                    cashController,
                                    cash.toString(),
                                  );
                                }
                                _setControllerText(
                                  onlineController,
                                  (total - cash).toString(),
                                );
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: onlineController,
                              decoration: _inputDecoration('Online ₹'),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                var online = int.tryParse(value.trim()) ?? 0;
                                if (online > total) {
                                  online = total;
                                  _setControllerText(
                                    onlineController,
                                    online.toString(),
                                  );
                                }
                                _setControllerText(
                                  cashController,
                                  (total - online).toString(),
                                );
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    _label('Bill Delivery'),
                    Row(
                      children: [
                        _selectBox(
                          selected:
                              receiptAction == BillReceiptAction.withoutPrint,
                          label: 'No Print',
                          icon: Icons.block_outlined,
                          onTap: () => setState(
                            () =>
                                receiptAction = BillReceiptAction.withoutPrint,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _selectBox(
                          selected: receiptAction == BillReceiptAction.print,
                          label: 'Print',
                          icon: Icons.print_outlined,
                          onTap: () => setState(
                            () => receiptAction = BillReceiptAction.print,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _selectBox(
                          selected:
                              receiptAction == BillReceiptAction.shareWhatsApp,
                          label: 'WhatsApp',
                          icon: Icons.chat_outlined,
                          onTap: () => setState(
                            () =>
                                receiptAction = BillReceiptAction.shareWhatsApp,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _selectBox(
                          selected:
                              receiptAction ==
                              BillReceiptAction.printAndShareWhatsApp,
                          label: 'WhatsApp & Print',
                          icon: Icons.print_rounded,
                          onTap: () => setState(
                            () => receiptAction =
                                BillReceiptAction.printAndShareWhatsApp,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
              child: Row(
                children: [
                  if (!widget.hidePaidOption) ...[
                    Expanded(
                      child: _primaryButton(
                        label: 'Confirm & Paid',
                        color: _dialogSuccess,
                        onTap: () => _confirm(TableBillingMode.paid),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: _primaryButton(
                      label: 'Save Without Serving',
                      color: primary_color,
                      onTap: () =>
                          _confirm(TableBillingMode.paidWithoutServing),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
