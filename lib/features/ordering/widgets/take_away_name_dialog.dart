import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:smartKitchen/Styles/my_font.dart';

class TakeAwayOrderDetails {
  const TakeAwayOrderDetails({
    required this.name,
    this.isFutureOrder = false,
    this.scheduledAt,
  });

  final String name;
  final bool isFutureOrder;
  final DateTime? scheduledAt;
}

class TakeAwayNameDialog {
  TakeAwayNameDialog._();

  static Future<TakeAwayOrderDetails?> show(
    BuildContext context, {
    required String suggestedName,
    Set<String> existingNames = const {},
    String? currentName,
  }) {
    final blocked = {...existingNames};
    if (currentName != null && currentName.isNotEmpty) {
      blocked.remove(currentName);
    }

    return showDialog<TakeAwayOrderDetails>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => _TakeAwayOrderNameDialog(
        suggestedName: suggestedName,
        existingNames: blocked,
      ),
    );
  }
}

class _TakeAwayOrderNameDialog extends StatefulWidget {
  const _TakeAwayOrderNameDialog({
    required this.suggestedName,
    required this.existingNames,
  });

  final String suggestedName;
  final Set<String> existingNames;

  @override
  State<_TakeAwayOrderNameDialog> createState() =>
      _TakeAwayOrderNameDialogState();
}

class _TakeAwayOrderNameDialogState extends State<_TakeAwayOrderNameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  bool _isFutureOrder = false;
  late DateTime _scheduledAt;
  String? _scheduleError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.suggestedName);
    final now = DateTime.now();
    _scheduledAt = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _selectAllText();
    });
  }

  void _selectAllText() {
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _scheduleError = null;
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_isFutureOrder) {
      if (!_scheduledAt.isAfter(DateTime.now())) {
        setState(() {
          _scheduleError = 'Please select a future date and time';
        });
        return;
      }
    }

    Navigator.of(context, rootNavigator: true).pop(
      TakeAwayOrderDetails(
        name: _controller.text.trim(),
        isFutureOrder: _isFutureOrder,
        scheduledAt: _isFutureOrder ? _scheduledAt : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheduleLabel = DateFormat(
      'EEE, d MMM • hh:mm a',
    ).format(_scheduledAt);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Take Away Order',
        style: TextStyle(
          fontFamily: fontMulishBold,
          fontSize: 18,
          color: Color(0xFF1A3A5C),
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter order name (customer name, phone, etc.)',
              style: TextStyle(
                fontFamily: fontMulishRegular,
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onTap: _selectAllText,
              style: const TextStyle(
                fontFamily: fontMulishSemiBold,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. Take Away 1 or Rahul',
                filled: true,
                fillColor: const Color(0xFFF5F6FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return 'Please enter a name';
                if (widget.existingNames.contains(name)) {
                  return 'This name is already in use';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Future Order',
                style: TextStyle(
                  fontFamily: fontMulishSemiBold,
                  fontSize: 14,
                  color: Color(0xFF1A3A5C),
                ),
              ),
              subtitle: Text(
                'Delay kitchen until closer to pickup time',
                style: TextStyle(
                  fontFamily: fontMulishRegular,
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              value: _isFutureOrder,
              activeColor: const Color(0xFFf57c35),
              onChanged: (value) {
                setState(() {
                  _isFutureOrder = value;
                  _scheduleError = null;
                });
              },
            ),
            if (_isFutureOrder) ...[
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.event, size: 18),
                label: Text(
                  scheduleLabel,
                  style: const TextStyle(fontFamily: fontMulishSemiBold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A3A5C),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (_scheduleError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _scheduleError!,
                  style: TextStyle(
                    fontFamily: fontMulishRegular,
                    fontSize: 12,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(fontFamily: fontMulishSemiBold),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFf57c35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _submit,
          child: const Text(
            'Continue',
            style: TextStyle(fontFamily: fontMulishBold),
          ),
        ),
      ],
    );
  }
}
