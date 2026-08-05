import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartKitchen/core/firestore/firestore_paths.dart';
import 'package:smartKitchen/core/utils/tax_calculator.dart';
import 'package:smartKitchen/features/ordering/widgets/editable_total_row.dart';
import 'package:smartKitchen/features/ordering/widgets/tax_summary_rows.dart';
import 'package:smartKitchen/features/settings/services/tax_settings_service.dart';
import 'package:dotted_line/dotted_line.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:smartKitchen/features/ordering/widgets/table_billing_mode_dialog.dart';
import 'package:smartKitchen/features/ordering/widgets/table_billing_sheet.dart';
import 'package:smartKitchen/features/shell/shell.dart';
import 'package:smartKitchen/features/ordering/views/menu_page.dart';
import 'package:smartKitchen/Styles/my_colors.dart';
import 'package:smartKitchen/Styles/my_font.dart';
import 'package:smartKitchen/Styles/my_icons.dart';

/// Cart Page
class FinalBillingView extends StatefulWidget {
  final String tableName;
  final List<Map<String, dynamic>> menuData;
  final List<Map<String, dynamic>> totalMenuList;
  final String overallRemarks;
  final Future<void> Function(
    List<Map<String, dynamic>> selectedItems,
    bool isBillPaid,
    String tableName,
    String overallRemarks, {
    bool fromBilling,
    bool fromFinalBilling,
    String? transactionId,
  }) onConfirm;

  FinalBillingView({
    required this.menuData,
    required this.totalMenuList,
    required this.onConfirm,
    required this.tableName,
    this.overallRemarks = '',
    Key? key,
  }) : super(key: key);

  @override
  _FinalBillingViewState createState() => _FinalBillingViewState();
}

class _FinalBillingViewState extends State<FinalBillingView> {
  static const _navy   = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);
  static const _bg     = Color(0xFFF5F6FA);

  late List<Map<String, dynamic>> cartItems;

  final TextEditingController discountPercentController =
      TextEditingController();
  final TextEditingController discountAmountController =
      TextEditingController();
  late List<int> lastQtys;
  final TextEditingController cashController = TextEditingController();
  final TextEditingController onlineController = TextEditingController();
  final TextEditingController totalController = TextEditingController();

  double discountPercent = 0.0;
  double discountAmount = 0.0;

  double _cgstPercent = 0;
  double _sgstPercent = 0;
  bool _isEditingTotal = false;
  bool _totalOverridden = false;

  String paymentMode = 'Cash'; // Cash, Online, Both

  @override
  void initState() {
    super.initState();
    cartItems = widget.menuData
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    lastQtys = cartItems.map<int>((e) => e['qty'] as int).toList();

    _updatePaymentAmounts();
    _loadTaxSettings();
  }

  Future<void> _loadTaxSettings() async {
    final settings = await TaxSettingsService.load();
    if (!mounted) return;
    setState(() {
      _cgstPercent = settings.cgstPercentage;
      _sgstPercent = settings.sgstPercentage;
      _resetTotalOverride();
    });
  }

  int get _computedTotal =>
      (subtotal + taxBreakdown.totalTax - discountAmount).round();

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

  void _startEditingTotal() {
    totalController.text = total.toString();
    setState(() => _isEditingTotal = true);
  }

  void _applyManualTotal() {
    final edited = int.tryParse(totalController.text.trim());
    if (edited == null || edited < 0) return;

    setState(() {
      _totalOverridden = true;
      _isEditingTotal = false;
      final taxable = subtotal + taxBreakdown.totalTax;
      discountAmount = (taxable - edited).toDouble();
      if (discountAmount < 0) discountAmount = 0;
      discountPercent =
          subtotal > 0 ? (discountAmount / subtotal) * 100 : 0;
      discountAmountController.text = discountAmount.toStringAsFixed(0);
      discountPercentController.text = discountPercent.toStringAsFixed(2);
      totalController.text = edited.toString();
      _updatePaymentAmounts();
    });
  }

  double get subtotal => cartItems.fold(
        0,
        (sum, item) => sum + (item['qty'] as int) * (item['price']),
      );

  TaxBreakdown get taxBreakdown => TaxCalculator.calculate(
        subtotal,
        cgstPercent: _cgstPercent,
        sgstPercent: _sgstPercent,
      );

  void incrementQty(int index) {
    setState(() {
      _resetTotalOverride();
      lastQtys[index] = cartItems[index]['qty']; // store old value
      cartItems[index]['qty']++;
      _updateDiscountFromPercent();
      _updatePaymentAmounts();
    });
  }

  void decrementQty(int index) {
    setState(() {
      _resetTotalOverride();
      lastQtys[index] = cartItems[index]['qty']; // store old value
      if (cartItems[index]['qty'] > 1) {
        cartItems[index]['qty']--;
      } else {
        cartItems.removeAt(index);
      }
      _updateDiscountFromPercent();
      _updatePaymentAmounts();
    });
  }

  void _updateDiscountFromPercent() {
    _resetTotalOverride();
    if (discountPercent > 0) {
      discountAmount = (subtotal * discountPercent) / 100;
      discountAmountController.text = discountAmount.toStringAsFixed(0);
    }
    _updatePaymentAmounts();
  }

  void _updateDiscountFromAmount() {
    _resetTotalOverride();
    if (discountAmount > 0 && subtotal > 0) {
      discountPercent = (discountAmount / subtotal) * 100;
      discountPercentController.text = discountPercent.toStringAsFixed(2);
    }
    _updatePaymentAmounts();
  }

  void _updatePaymentAmounts() {
    if (paymentMode == 'Cash') {
      cashController.text = total.toString();
      onlineController.text = "0";
    } else if (paymentMode == 'Online') {
      cashController.text = "0";
      onlineController.text = total.toString();
    } else if (paymentMode == 'Both') {
      int cash = int.tryParse(cashController.text) ?? total;
      if (cash > total) cash = total;
      cashController.text = cash.toString();
      onlineController.text = (total - cash).toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final taxes = taxBreakdown;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Billing - ${widget.tableName}",
          style: const TextStyle(fontSize: 16, fontFamily: fontMulishBold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MenuPage(
                    menuList: widget.totalMenuList,
                    tableName: widget.tableName,
                    tableNameEditable: false,
                    initialItems: widget.menuData,
                    showBilling: false,
                    isFromFinalBilling: true,
                    onConfirm:
                        (
                          List<Map<String, dynamic>> selectedItems,
                          bool isBillPaid,
                          String tableName,
                          String overallRemarks, {
                          bool fromBilling = false,
                          bool fromFinalBilling = false,
                          String? transactionId,
                        }) async {
                          setState(() {
                            cartItems = selectedItems
                                .map((item) => Map<String, dynamic>.from(item))
                                .toList();

                            lastQtys = cartItems
                                .map<int>((e) => e['qty'] as int)
                                .toList();

                            _updatePaymentAmounts();
                          });
                        },
                  ),
                ),
              ).then((onValue) {
                if (onValue != null) {
                  List<Map<String, dynamic>> changedItems = onValue;
                  setState(() {
                    cartItems = changedItems
                        .map((item) => Map<String, dynamic>.from(item))
                        .toList();

                    lastQtys = cartItems
                        .map<int>((e) => e['qty'] as int)
                        .toList();

                    _updatePaymentAmounts();
                  });

                  setState(() {});
                }
              });
              ;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: cartItems.isEmpty
                ? Center(
                    child: Text(
                      "No items in cart",
                      style: TextStyle(
                        fontFamily: fontMulishSemiBold,
                        color: secondary_text_color,
                        fontSize: 16,
                      ),
                    ),
                  )
                : Scrollbar(
                    thickness: 4,
                    child: ListView.builder(
                      itemCount: cartItems.length,
                      padding: const EdgeInsets.only(top: 12, bottom: 12),
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        final qty = item['qty'] as int;
                        final lastQty = lastQtys[index];
                        return InkWell(
                          onTap: () {
                            incrementQty(index);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: text_color,
                                              fontFamily: fontMulishSemiBold,
                                            ),
                                          ),

                                          SizedBox(height: 2),

                                          Row(
                                            children: [
                                              Text(
                                                "₹${item['price']}",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: text_color,
                                                  fontFamily: fontMulishSemiBold,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Text(
                                                "\u00D7$qty",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.red,
                                                  fontFamily: fontMulishBold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => decrementQty(index),
                                        ),
                                        SizedBox(
                                          // Fixed width to contain the number
                                          height: 30, // Fixed height
                                          child: ClipRect(
                                            // Extra ClipRect to ensure no overflow
                                            child: AnimatedSwitcher(
                                              duration: const Duration(
                                                milliseconds: 300,
                                              ),
                                              transitionBuilder:
                                                  (
                                                    Widget child,
                                                    Animation<double> animation,
                                                  ) {
                                                    final isIncrement =
                                                        (item['qty'] as int) >
                                                        lastQty;

                                                    return ClipRect(
                                                      child: SlideTransition(
                                                        position:
                                                            Tween<Offset>(
                                                              begin: isIncrement
                                                                  ? const Offset(
                                                                      0,
                                                                      0.5,
                                                                    ) // New from bottom
                                                                  : const Offset(
                                                                      0,
                                                                      -0.5,
                                                                    ), // New from top
                                                              end: Offset.zero,
                                                            ).animate(
                                                              CurvedAnimation(
                                                                parent:
                                                                    animation,
                                                                curve: Curves
                                                                    .easeOutCubic,
                                                              ),
                                                            ),
                                                        child: child,
                                                      ),
                                                    );
                                                  },
                                              layoutBuilder: (currentChild, previousChildren) {
                                                return Stack(
                                                  alignment: Alignment.center,
                                                  clipBehavior: Clip
                                                      .hardEdge, // ⭐ IMPORTANT: Clip overflow
                                                  children: [
                                                    if (previousChildren
                                                        .isNotEmpty)
                                                      SlideTransition(
                                                        position: AlwaysStoppedAnimation(
                                                          (item['qty'] as int) >
                                                                  lastQty
                                                              ? const Offset(
                                                                  0,
                                                                  -0.5,
                                                                ) // Exit to top
                                                              : const Offset(
                                                                  0,
                                                                  0.5,
                                                                ), // Exit to bottom
                                                        ),
                                                        child: previousChildren
                                                            .first,
                                                      ),
                                                    if (currentChild != null)
                                                      currentChild,
                                                  ],
                                                );
                                              },
                                              child: Text(
                                                "$qty",
                                                key: ValueKey<int>(qty),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.green,
                                                  fontFamily: fontMulishBold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add_circle,
                                            color: Colors.green,
                                          ),
                                          onPressed: () => incrementQty(index),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        // Payment Mode Selection
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Payment By",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: secondary_text_color,
                                  fontFamily: fontMulishSemiBold,
                                ),
                              ),
                            ),

                            Row(
                              children: [
                                Radio<String>(
                                  value: 'Cash',
                                  groupValue: paymentMode,
                                  visualDensity: VisualDensity(
                                    horizontal: -4,
                                    vertical: -4,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      paymentMode = value!;
                                      _updatePaymentAmounts();
                                    });
                                  },
                                ),
                                const Text(
                                  'Cash',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: text_color,
                                    fontFamily: fontMulishSemiBold,
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(width: 12),
                            Row(
                              children: [
                                Radio<String>(
                                  value: 'Online',
                                  groupValue: paymentMode,
                                  visualDensity: VisualDensity(
                                    horizontal: -4,
                                    vertical: -4,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      paymentMode = value!;
                                      _updatePaymentAmounts();
                                    });
                                  },
                                ),
                                const Text(
                                  'Online',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: text_color,
                                    fontFamily: fontMulishSemiBold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: 12),
                            Row(
                              children: [
                                Radio<String>(
                                  value: 'Both',
                                  groupValue: paymentMode,
                                  visualDensity: VisualDensity(
                                    horizontal: -4,
                                    vertical: -4,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      paymentMode = value!;
                                      _updatePaymentAmounts();
                                    });
                                  },
                                ),
                                const Text(
                                  'Both',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: text_color,
                                    fontFamily: fontMulishSemiBold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Cash + Online Inputs (only if Both selected)
                        if (paymentMode == 'Both')
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 12.0,
                              top: 8,
                            ),
                            child: Row(
                              children: [
                                // Cash Amount Field
                                Expanded(child: SizedBox()),

                                Expanded(
                                  child: TextField(
                                    controller: cashController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: secondary_text_color,
                                      fontFamily: fontMulishSemiBold,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: "Cash Amount",
                                      labelStyle: const TextStyle(
                                        fontSize: 13,
                                        color: secondary_text_color,
                                        fontFamily: fontMulishMedium,
                                      ),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: Colors.grey,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        int cashVal = int.tryParse(value) ?? 0;
                                        if (cashVal > total) cashVal = total;
                                        cashController.text = cashVal
                                            .toString();
                                        onlineController.text =
                                            (total - cashVal).toString();
                                        cashController.selection =
                                            TextSelection.fromPosition(
                                              TextPosition(
                                                offset:
                                                    cashController.text.length,
                                              ),
                                            );
                                      });
                                    },
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Online Amount Field
                                Expanded(
                                  child: TextField(
                                    controller: onlineController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: secondary_text_color,
                                      fontFamily: fontMulishSemiBold,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: "Online Amount",
                                      labelStyle: const TextStyle(
                                        fontSize: 13,
                                        color: secondary_text_color,
                                        fontFamily: fontMulishMedium,
                                      ),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: Colors.grey,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        int onlineVal =
                                            int.tryParse(value) ?? 0;
                                        if (onlineVal > total)
                                          onlineVal = total;
                                        onlineController.text = onlineVal
                                            .toString();
                                        cashController.text =
                                            (total - onlineVal).toString();
                                        onlineController.selection =
                                            TextSelection.fromPosition(
                                              TextPosition(
                                                offset: onlineController
                                                    .text
                                                    .length,
                                              ),
                                            );
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Subtotal",
                          style: const TextStyle(
                            fontSize: 14,
                            color: secondary_text_color,
                            fontFamily: fontMulishSemiBold,
                          ),
                        ),
                        Text(
                          "₹${subtotal.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontSize: 14,
                            color: text_color,
                            fontFamily: fontMulishSemiBold,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 8),

                    TaxSummaryRows(breakdown: taxes),

                    if (taxes.hasTax) SizedBox(height: 8),

                    SizedBox(height: 6),

                    Row(
                      children: [
                        // Discount Percentage
                        Expanded(
                          flex: 2,
                          child: Text(
                            "Discount",
                            style: const TextStyle(
                              fontSize: 14,
                              color: secondary_text_color,
                              fontFamily: fontMulishSemiBold,
                            ),
                          ),
                        ),

                        Expanded(
                          child: TextField(
                            controller: discountPercentController,
                            style: const TextStyle(
                              fontSize: 14,
                              color: secondary_text_color,
                              fontFamily: fontMulishSemiBold,
                            ),
                            decoration: InputDecoration(
                              labelText: "Disc %",
                              labelStyle: const TextStyle(
                                fontSize: 10,
                                color: secondary_text_color,
                                fontFamily: fontMulishMedium,
                              ),
                              hintText: "Enter %",
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                fontFamily: fontMulishRegular,
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade100,
                                  width: 0.25,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: primary_color,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (value) {
                              setState(() {
                                discountPercent = double.tryParse(value) ?? 0;
                                _updateDiscountFromPercent();
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        // Discount Amount
                        Expanded(
                          child: TextField(
                            controller: discountAmountController,
                            style: const TextStyle(
                              fontSize: 14,
                              color: secondary_text_color,
                              fontFamily: fontMulishSemiBold,
                            ),
                            decoration: InputDecoration(
                              labelText: "Discount ₹",
                              labelStyle: const TextStyle(
                                fontSize: 10,
                                color: secondary_text_color,
                                fontFamily: fontMulishMedium,
                              ),
                              hintText: "Enter ₹",
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                fontFamily: fontMulishRegular,
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.grey,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: primary_color,
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                discountAmount = double.tryParse(value) ?? 0;
                                _updateDiscountFromAmount();
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Payment Mode Radio
                    DottedLine(
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
                      onEditPressed: _startEditingTotal,
                      onApplyPressed: _applyManualTotal,
                      accentColor: _orange,
                    ),
                    // const SizedBox(height: 8),
                  ],
                ),
              ),

              Align(
                alignment: Alignment.bottomCenter,
                child: InkWell(
                  onTap: _generateBill,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _orange,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _orange.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 24), // balance out the icon on the right
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                icon_bill,
                                width: 22,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Generate Bill",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontFamily: fontMulishBold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                        const SizedBox(width: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);
  }

  Future<void> _generateBill() async {
    final items =
        cartItems.map((e) => Map<String, dynamic>.from(e)).toList();
    if (items.isEmpty) return;

    final result = await TableBillingSheet.runBillingFlow(
      context,
      tableName: widget.tableName,
      items: items,
      onSubmit: (submission) async {
        switch (submission.mode) {
          case TableBillingMode.paid:
            await widget.onConfirm(
              submission.items,
              false,
              widget.tableName,
              widget.overallRemarks,
              fromFinalBilling: true,
            );
          case TableBillingMode.paidWithoutServing:
            await widget.onConfirm(
              submission.items,
              false,
              widget.tableName,
              widget.overallRemarks,
              fromBilling: true,
              transactionId: submission.documentId,
            );
        }
      },
    );

    if (!mounted || result == null) return;

    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    Navigator.of(context).pop(items);
    TableBillingSheet.deliverReceiptInBackground(result);
  }
}
