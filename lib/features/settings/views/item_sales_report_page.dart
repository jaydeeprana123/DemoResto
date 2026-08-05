import 'package:smartKitchen/core/utils/platform_utils.dart';
import 'package:smartKitchen/features/settings/repositories/export_repository.dart';
import 'package:smartKitchen/features/settings/services/export_excel_service.dart';
import 'package:smartKitchen/features/settings/utils/export_date_range.dart';
import 'package:smartKitchen/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ItemSalesReportPage extends StatefulWidget {
  const ItemSalesReportPage({super.key});

  @override
  State<ItemSalesReportPage> createState() => _ItemSalesReportPageState();
}

class _ItemSalesReportPageState extends State<ItemSalesReportPage> {
  static const _navy = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);

  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  ItemSalesReportData? _report;
  String _searchQuery = '';
  bool _loading = false;
  bool _exporting = false;

  static final DateFormat _dateTimeFormat = DateFormat('dd-MM-yyyy hh:mm a');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    _fromController.text = _dateTimeFormat.format(_fromDate!);
    _toController.text = _dateTimeFormat.format(_toDate!);
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ItemSalesRow> get _filteredRows {
    final rows = _report?.rows ?? const [];
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows
        .where((row) => row.itemName.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final base = isFrom ? (_fromDate ?? now) : (_toDate ?? _fromDate ?? now);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: isFrom ? DateTime(2023) : (_fromDate ?? DateTime(2023)),
      lastDate: now,
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (!mounted) return;

    final time = pickedTime ??
        (isFrom
            ? const TimeOfDay(hour: 0, minute: 0)
            : const TimeOfDay(hour: 23, minute: 59));

    final selected = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      time.hour,
      time.minute,
      isFrom ? 0 : 59,
      isFrom ? 0 : 999,
    );

    setState(() {
      if (isFrom) {
        _fromDate = selected;
        _fromController.text = _dateTimeFormat.format(selected);
        if (_toDate == null) {
          _toDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          _toController.text = _dateTimeFormat.format(_toDate!);
        }
      } else {
        if (_fromDate == null) {
          _fromDate = DateTime(
            selected.year,
            selected.month,
            selected.day,
          );
          _fromController.text = _dateTimeFormat.format(_fromDate!);
        }
        _toDate = selected;
        _toController.text = _dateTimeFormat.format(selected);
      }
      _report = null;
    });
  }

  ExportDateRange? _buildRange() {
    if (_fromDate == null) {
      Get.snackbar(
        'Date required',
        'Please select a From date.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return null;
    }
    return buildExportDateRange(fromDate: _fromDate!, toDate: _toDate);
  }

  Future<void> _generateReport() async {
    final range = _buildRange();
    if (range == null) return;

    setState(() => _loading = true);
    try {
      final report = await Get.find<ExportRepository>().loadItemSales(range);
      if (!mounted) return;
      setState(() {
        _report = report;
        _searchQuery = '';
        _searchController.clear();
      });
    } on ExportException catch (e) {
      if (!mounted) return;
      setState(() => _report = null);
      Get.snackbar(
        'Report failed',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _report = null);
      Get.snackbar(
        'Report failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _exportSuccessMessage(String savedPath) {
    if (isDesktopPlatform) {
      return 'CSV saved to:\n$savedPath\n\nUse the share window to send the file.';
    }
    return 'CSV file saved and ready to share.';
  }

  Future<void> _exportExcel() async {
    final range = _buildRange();
    if (range == null) return;

    setState(() => _exporting = true);
    try {
      final savedPath = await Get.find<ExportRepository>().exportItemSales(
        range,
        report: _report,
      );
      Get.snackbar(
        'Export saved',
        _exportSuccessMessage(savedPath),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } on ExportException catch (e) {
      Get.snackbar(
        'Export failed',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Export failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  InputDecoration _dateFieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 13,
        fontFamily: fontMulishRegular,
      ),
      prefixIcon: const Icon(Icons.event_outlined, size: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _navy, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _orange, width: 1.5),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading || _exporting;
    final filtered = _filteredRows;
    final report = _report;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Item Sales Report',
          style: TextStyle(
            fontSize: 18,
            fontFamily: fontMulishBold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (report != null)
            IconButton(
              tooltip: 'Export to CSV',
              onPressed: busy ? null : _exportExcel,
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.file_download_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _fromController,
                        readOnly: true,
                        decoration: _dateFieldDecoration('From Date & Time'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: fontMulishSemiBold,
                        ),
                        onTap: busy ? null : () => _pickDate(isFrom: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _toController,
                        readOnly: true,
                        decoration: _dateFieldDecoration('To Date & Time'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: fontMulishSemiBold,
                        ),
                        onTap: busy ? null : () => _pickDate(isFrom: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: busy ? null : _generateReport,
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.assessment_outlined),
                  label: Text(
                    _loading ? 'Generating…' : 'Generate Report',
                    style: const TextStyle(
                      fontFamily: fontMulishSemiBold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (report != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date range: ${report.range.label}',
                      style: const TextStyle(
                        fontFamily: fontMulishSemiBold,
                        fontSize: 13,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${report.rows.length} items · '
                      '${report.totalQuantitySold} total qty · '
                      '${report.transactionCount} transactions',
                      style: TextStyle(
                        fontFamily: fontMulishRegular,
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search by item name…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _orange, width: 1.5),
                  ),
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: fontMulishSemiBold,
                ),
              ),
            ),
          ],
          Expanded(
            child: report == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _loading
                            ? 'Loading transactions…'
                            : 'Select a date range and tap Generate Report.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: fontMulishRegular,
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No items found'
                          : 'No items match "$_searchQuery"',
                      style: TextStyle(
                        fontFamily: fontMulishRegular,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _navy,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Item Name',
                                style: TextStyle(
                                  fontFamily: fontMulishBold,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Text(
                              'Quantity Sold',
                              style: TextStyle(
                                fontFamily: fontMulishBold,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final row = filtered[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      row.itemName,
                                      style: const TextStyle(
                                        fontFamily: fontMulishSemiBold,
                                        fontSize: 14,
                                        color: _navy,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${row.quantitySold}',
                                    style: const TextStyle(
                                      fontFamily: fontMulishBold,
                                      fontSize: 15,
                                      color: _orange,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          if (report != null)
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: busy ? null : _exportExcel,
                  style: FilledButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.file_download_outlined),
                  label: Text(
                    _exporting ? 'Exporting…' : 'Export to CSV',
                    style: const TextStyle(
                      fontFamily: fontMulishSemiBold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
