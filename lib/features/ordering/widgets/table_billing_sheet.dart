import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/core/utils/tax_calculator.dart';
import 'package:demo/features/ordering/services/food_bill_pdf_service.dart';
import 'package:demo/features/ordering/widgets/billing_progress_dialog.dart';
import 'package:demo/features/ordering/widgets/editable_total_row.dart';
import 'package:demo/features/ordering/widgets/table_billing_mode_dialog.dart';
import 'package:demo/features/ordering/widgets/tax_summary_rows.dart';
import 'package:demo/features/settings/services/tax_settings_service.dart';
import 'package:demo/features/transactions/repositories/transactions_repository.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
  final int total;
  final int cashAmount;
  final int onlineAmount;
}

class TableBillingSheet extends StatefulWidget {
  const TableBillingSheet({
    required this.tableName,
    required this.items,
    required this.mode,
    required this.receiptAction,
    required this.onSubmit,
    super.key,
  });

  final String tableName;
  final List<Map<String, dynamic>> items;
  final TableBillingMode mode;
  final BillReceiptAction receiptAction;
  final Future<void> Function(TableBillingSubmission submission) onSubmit;

  static double orderTotal(List<Map<String, dynamic>> items) {
    return items.fold<double>(
      0,
      (sum, item) =>
          sum +
          ((item['qty'] as num?)?.toInt() ?? 0) *
              ((item['price'] as num?)?.toDouble() ?? 0),
    );
  }

  /// Shows billing mode dialog then summary sheet. Returns true when billing completes.
  static Future<bool> runBillingFlow(
    BuildContext context, {
    required String tableName,
    required List<Map<String, dynamic>> items,
    required Future<void> Function(TableBillingSubmission submission) onSubmit,
  }) async {
    if (items.isEmpty) return false;

    final dialogResult = await showTableBillingModeDialog(
      context,
      total: orderTotal(items),
      tableName: tableName,
    );
    if (dialogResult == null || !context.mounted) return false;

    var billingCompleted = false;
    await show(
      context,
      tableName: tableName,
      items: items,
      mode: dialogResult.mode,
      receiptAction: dialogResult.receiptAction,
      onSubmit: (submission) async {
        await onSubmit(submission);
        billingCompleted = true;
      },
    );
    return billingCompleted;
  }

  static Future<void> show(
    BuildContext context, {
    required String tableName,
    required List<Map<String, dynamic>> items,
    required TableBillingMode mode,
    required BillReceiptAction receiptAction,
    required Future<void> Function(TableBillingSubmission submission) onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => TableBillingSheet(
        tableName: tableName,
        items: items,
        mode: mode,
        receiptAction: receiptAction,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<TableBillingSheet> createState() => _TableBillingSheetState();
}

class _TableBillingSheetState extends State<TableBillingSheet> {
  final discountPercentController = TextEditingController();
  final discountAmountController = TextEditingController();
  final cashController = TextEditingController();
  final onlineController = TextEditingController();
  final totalController = TextEditingController();

  double discountPercent = 0;
  double discountAmount = 0;
  double _cgstPercent = 0;
  double _sgstPercent = 0;
  bool _isEditingTotal = false;
  bool _totalOverridden = false;
  String paymentMode = 'Cash';
  bool _submitting = false;

  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.items.map((e) => Map<String, dynamic>.from(e)).toList();
    _loadTaxSettings();
  }

  @override
  void dispose() {
    discountPercentController.dispose();
    discountAmountController.dispose();
    cashController.dispose();
    onlineController.dispose();
    totalController.dispose();
    super.dispose();
  }

  Future<void> _loadTaxSettings() async {
    final settings = await TaxSettingsService.load();
    if (!mounted) return;
    setState(() {
      _cgstPercent = settings.cgstPercentage;
      _sgstPercent = settings.sgstPercentage;
      _resetTotalOverride();
      _updatePaymentAmounts();
    });
  }

  double get _subtotal => _items.fold<double>(
        0,
        (sum, item) =>
            sum +
            ((item['qty'] as num?)?.toInt() ?? 0) *
                ((item['price'] as num?)?.toDouble() ?? 0),
      );

  TaxBreakdown get _taxBreakdown => TaxCalculator.calculate(
        _subtotal,
        cgstPercent: _cgstPercent,
        sgstPercent: _sgstPercent,
      );

  int get _computedTotal =>
      (_subtotal + _taxBreakdown.totalTax - discountAmount).round();

  int get total {
    if (_totalOverridden) {
      return int.tryParse(totalController.text.trim()) ?? _computedTotal;
    }
    return _computedTotal;
  }

  void _resetTotalOverride() {
    _totalOverridden = false;
    _isEditingTotal = false;
  }

  void _startEditingTotal(VoidCallback refresh) {
    totalController.text = total.toString();
    setState(() => _isEditingTotal = true);
    refresh();
  }

  void _applyManualTotal(VoidCallback refresh) {
    final edited = int.tryParse(totalController.text.trim());
    if (edited == null || edited < 0) return;
    setState(() {
      _totalOverridden = true;
      _isEditingTotal = false;
      final taxable = _subtotal + _taxBreakdown.totalTax;
      discountAmount = (taxable - edited).toDouble();
      if (discountAmount < 0) discountAmount = 0;
      discountPercent = _subtotal > 0 ? (discountAmount / _subtotal) * 100 : 0;
      discountAmountController.text = discountAmount.toStringAsFixed(0);
      discountPercentController.text = discountPercent.toStringAsFixed(2);
      totalController.text = edited.toString();
      _updatePaymentAmounts();
    });
    refresh();
  }

  void _updateDiscountFromPercent() {
    _resetTotalOverride();
    if (discountPercent > 0) {
      discountAmount = (_subtotal * discountPercent) / 100;
      discountAmountController.text = discountAmount.toStringAsFixed(0);
    }
    _updatePaymentAmounts();
  }

  void _updateDiscountFromAmount() {
    _resetTotalOverride();
    if (discountAmount > 0 && _subtotal > 0) {
      discountPercent = (discountAmount / _subtotal) * 100;
      discountPercentController.text = discountPercent.toStringAsFixed(2);
    }
    _updatePaymentAmounts();
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

  String get _modeTitle => widget.mode == TableBillingMode.paid
      ? 'Paid — Billing Summary'
      : 'Paid Without Serving — Billing Summary';

  String get _confirmLabel => widget.mode == TableBillingMode.paid
      ? 'Confirm & Paid'
      : 'Confirm & Billing';

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    BillingProgressDialog.show(context);
    FoodBillPdfData? receiptData;

    try {
      final cash = int.tryParse(cashController.text) ?? 0;
      final online = int.tryParse(onlineController.text) ?? 0;
      final taxes = _taxBreakdown;
      final taxAmount = taxes.totalTax;
      final confirmedItems =
          _items.map((e) => Map<String, dynamic>.from(e)).toList();

      final result = await Get.find<TransactionsRepository>().createTransaction(
        items: confirmedItems,
        tableName: widget.tableName,
        subtotal: _subtotal.round(),
        tax: taxAmount,
        cgstPercentage: _cgstPercent,
        sgstPercentage: _sgstPercent,
        cgstAmount: taxes.cgstAmount,
        sgstAmount: taxes.sgstAmount,
        discount: discountAmount.round(),
        total: total,
        cashAmount: cash,
        onlineAmount: online,
      );

      if (result == null) {
        throw Exception('Transaction not saved.');
      }

      final submission = TableBillingSubmission(
        items: confirmedItems,
        mode: widget.mode,
        documentId: result.documentId,
        billId: result.billId,
        subtotal: _subtotal.round(),
        tax: taxAmount,
        cgstPercentage: _cgstPercent,
        sgstPercentage: _sgstPercent,
        cgstAmount: taxes.cgstAmount,
        sgstAmount: taxes.sgstAmount,
        discount: discountAmount.round(),
        total: total,
        cashAmount: cash,
        onlineAmount: online,
      );

      await widget.onSubmit(submission);

      receiptData = FoodBillPdfData(
        tableName: widget.tableName,
        items: confirmedItems,
        subtotal: _subtotal.round(),
        tax: taxAmount,
        cgstPercentage: _cgstPercent,
        sgstPercentage: _sgstPercent,
        cgstAmount: taxes.cgstAmount,
        sgstAmount: taxes.sgstAmount,
        discount: discountAmount.round(),
        total: total,
        cashAmount: cash,
        onlineAmount: online,
        invoiceNumber: result.billId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Billing failed: $e')),
        );
      }
      return;
    } finally {
      if (mounted) {
        BillingProgressDialog.hide(context);
        setState(() => _submitting = false);
      }
    }

    if (!mounted) return;
    Navigator.pop(context);

    final receipt = receiptData;
    if (receipt != null) {
      await FoodBillPdfService.deliverReceiptByAction(
        receipt,
        widget.receiptAction,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final taxes = _taxBreakdown;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "$_modeTitle",
                              style: const TextStyle(
                                fontSize: 16,
                                fontFamily: fontMulishSemiBold,
                                color: text_color,
                              ),
                            ),
                            Text(
                              widget.tableName,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: fontMulishRegular,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _paymentModeRow(setModalState),
                          if (paymentMode == 'Both') ...[
                            const SizedBox(height: 8),
                            _splitPaymentFields(setModalState),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Subtotal',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: secondary_text_color,
                                  fontFamily: fontMulishSemiBold,
                                ),
                              ),
                              Text(
                                '₹${_subtotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: fontMulishSemiBold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TaxSummaryRows(breakdown: taxes),
                          if (taxes.hasTax) const SizedBox(height: 8),
                          _discountRow(setModalState),
                          const SizedBox(height: 12),
                          const DottedLine(
                            dashLength: 2,
                            dashGapLength: 6,
                            lineThickness: 1,
                            dashColor: Colors.black87,
                          ),
                          const SizedBox(height: 12),
                          EditableTotalRow(
                            total: total,
                            isEditing: _isEditingTotal,
                            controller: totalController,
                            onEditPressed: () =>
                                _startEditingTotal(() => setModalState(() {})),
                            onApplyPressed: () =>
                                _applyManualTotal(() => setModalState(() {})),
                            accentColor: primary_color,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _submitting ? null : _confirm,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primary_color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _confirmLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontFamily: fontMulishSemiBold,
                          ),
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
  }

  Widget _paymentModeRow(StateSetter setModalState) {
    Widget radio(String value, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: paymentMode,
            visualDensity: VisualDensity.compact,
            onChanged: (v) {
              setModalState(() {
                paymentMode = v!;
                _updatePaymentAmounts();
              });
            },
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: fontMulishSemiBold,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Expanded(
          child: Text(
            'Payment By',
            style: TextStyle(
              fontSize: 14,
              color: secondary_text_color,
              fontFamily: fontMulishSemiBold,
            ),
          ),
        ),
        radio('Cash', 'Cash'),
        radio('Online', 'Online'),
        radio('Both', 'Both'),
      ],
    );
  }

  Widget _splitPaymentFields(StateSetter setModalState) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: cashController,
            decoration: const InputDecoration(
              labelText: 'Cash ₹',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) {
              setModalState(() {
                var cash = int.tryParse(cashController.text) ?? 0;
                if (cash > total) cash = total;
                cashController.text = cash.toString();
                onlineController.text = (total - cash).toString();
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: onlineController,
            decoration: const InputDecoration(
              labelText: 'Online ₹',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) {
              setModalState(() {
                var online = int.tryParse(onlineController.text) ?? 0;
                if (online > total) online = total;
                onlineController.text = online.toString();
                cashController.text = (total - online).toString();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _discountRow(StateSetter setModalState) {
    return Row(
      children: [
        const Expanded(
          flex: 2,
          child: Text(
            'Discount',
            style: TextStyle(
              fontSize: 14,
              color: secondary_text_color,
              fontFamily: fontMulishSemiBold,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: discountPercentController,
            decoration: const InputDecoration(
              labelText: 'Disc %',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              setModalState(() {
                discountPercent = double.tryParse(value) ?? 0;
                _updateDiscountFromPercent();
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: discountAmountController,
            decoration: const InputDecoration(
              labelText: 'Discount ₹',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setModalState(() {
                discountAmount = double.tryParse(value) ?? 0;
                _updateDiscountFromAmount();
              });
            },
          ),
        ),
      ],
    );
  }
}
