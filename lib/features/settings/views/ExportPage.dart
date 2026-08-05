import 'package:smartKitchen/core/utils/platform_utils.dart';
import 'package:smartKitchen/features/settings/repositories/export_repository.dart';
import 'package:smartKitchen/features/settings/services/export_excel_service.dart';
import 'package:smartKitchen/features/settings/utils/export_date_range.dart';
import 'package:smartKitchen/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ExportPage extends StatefulWidget {
  final bool isAdmin;

  const ExportPage({super.key, required this.isAdmin});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  static const _navy = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);

  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  bool _exportingTransactions = false;
  bool _exportingExpenses = false;

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
    super.dispose();
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

    // Automatically follow up with a time picker so the user can export by an
    // exact date and time range.
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (!mounted) return;

    // If the time picker is dismissed, fall back to the day's boundary time.
    final time =
        pickedTime ??
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
            0,
            0,
            0,
          );
          _fromController.text = _dateTimeFormat.format(_fromDate!);
        }
        _toDate = selected;
        _toController.text = _dateTimeFormat.format(selected);
      }
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

  String _exportSuccessMessage(String savedPath) {
    if (isDesktopPlatform) {
      return 'Excel saved to:\n$savedPath\n\nUse the share window to send the file. '
          'If an app only shares text, attach the saved file manually.';
    }
    return 'Excel file saved and ready to share.';
  }

  Future<void> _exportTransactions() async {
    final range = _buildRange();
    if (range == null) return;

    setState(() => _exportingTransactions = true);
    try {
      final savedPath = await Get.find<ExportRepository>().exportTransactions(
        range,
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
      if (mounted) setState(() => _exportingTransactions = false);
    }
  }

  Future<void> _exportExpenses() async {
    final range = _buildRange();
    if (range == null) return;

    setState(() => _exportingExpenses = true);
    try {
      final savedPath = await Get.find<ExportRepository>().exportExpenses(range);
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
      if (mounted) setState(() => _exportingExpenses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _exportingTransactions || _exportingExpenses;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Export to Excel',
          style: TextStyle(
            fontSize: 16,
            fontFamily: fontMulishBold,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date range',
                    style: TextStyle(
                      fontFamily: fontMulishBold,
                      fontSize: 15,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose the period to include in your Excel file.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontFamily: fontMulishRegular,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _fromController,
                          readOnly: true,
                          decoration: _dateDecoration('From Date & Time'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: fontMulishSemiBold,
                          ),
                          onTap:
                              busy ? null : () => _pickDate(isFrom: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _toController,
                          readOnly: true,
                          decoration: _dateDecoration('To Date & Time'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: fontMulishSemiBold,
                          ),
                          onTap:
                              busy ? null : () => _pickDate(isFrom: false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.isAdmin) ...[
            _ExportButton(
              icon: Icons.receipt_long_rounded,
              label: 'Export Transactions',
              subtitle: 'Sales, items, payments',
              loading: _exportingTransactions,
              enabled: !busy,
              onPressed: _exportTransactions,
            ),
            const SizedBox(height: 12),
          ],
          _ExportButton(
            icon: Icons.payments_outlined,
            label: 'Export Expenses',
            subtitle: 'Business expense records',
            loading: _exportingExpenses,
            enabled: !busy,
            onPressed: _exportExpenses,
          ),
          const SizedBox(height: 16),
          Text(
            widget.isAdmin
                ? (isDesktopPlatform
                      ? 'On desktop, choose where to save the file, then use the share '
                          'window to email or send it.'
                      : 'After export, use the share sheet to save to Files, Google Drive, '
                          'email, or WhatsApp.')
                : 'Expense export uses the date range above.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontFamily: fontMulishRegular,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dateDecoration(String label) {
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
}

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;

  const _ExportButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.loading,
    required this.enabled,
    required this.onPressed,
  });

  static const _navy = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: enabled && !loading ? onPressed : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: _orange.withOpacity(0.12),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _orange,
                  ),
                )
              : Icon(icon, color: _orange),
        ),
        title: Text(
          loading ? 'Exporting…' : label,
          style: const TextStyle(
            fontFamily: fontMulishSemiBold,
            fontSize: 15,
            color: _navy,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Icon(
          Icons.file_download_outlined,
          color: enabled && !loading ? _navy : Colors.grey.shade400,
        ),
      ),
    );
  }
}
