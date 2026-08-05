import 'package:smartKitchen/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WhatsAppSharePhoneDialog {
  WhatsAppSharePhoneDialog._();

  /// Returns WhatsApp-ready digits including country code (e.g. 919876543210).
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _WhatsAppSharePhoneDialog(),
    );
  }

  static const defaultCountryCode = '91';

  /// Returns WhatsApp-ready digits including country code (e.g. 919876543210).
  static String normalizePhone(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    while (digits.startsWith('0') && digits.length > 1) {
      digits = digits.substring(1);
    }
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }
    if (digits.length == 10) {
      digits = '$defaultCountryCode$digits';
    }
    return digits;
  }

  static String? validatePhone(String input) {
    final raw = input.trim().replaceAll(RegExp(r'\D'), '');
    if (raw.isEmpty) {
      return 'Enter a valid 10-digit mobile number';
    }
    if (raw.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(raw)) {
      return null;
    }
    if (raw.length == 12 &&
        raw.startsWith('91') &&
        RegExp(r'^91[6-9]\d{9}$').hasMatch(raw)) {
      return null;
    }
    return 'Enter 10-digit mobile only (e.g. 9876543210)';
  }

  static String formatForDisplay(String input) {
    final digits = normalizePhone(input.trim());
    if (digits.isEmpty) return '';
    return '+$digits';
  }
}

class _WhatsAppSharePhoneDialog extends StatefulWidget {
  const _WhatsAppSharePhoneDialog();

  @override
  State<_WhatsAppSharePhoneDialog> createState() =>
      _WhatsAppSharePhoneDialogState();
}

class _WhatsAppSharePhoneDialogState extends State<_WhatsAppSharePhoneDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  String _preview = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updatePreview);
  }

  @override
  void dispose() {
    _controller.removeListener(_updatePreview);
    _controller.dispose();
    super.dispose();
  }

  void _updatePreview() {
    final next = WhatsAppSharePhoneDialog.formatForDisplay(_controller.text);
    if (next == _preview) return;
    setState(() => _preview = next);
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(
        WhatsAppSharePhoneDialog.normalizePhone(_controller.text.trim()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Send bill on WhatsApp',
        style: TextStyle(
          fontFamily: fontMulishSemiBold,
          fontSize: 18,
          color: Color(0xFF1A3A5C),
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the customer\'s 10-digit mobile. The bill PDF is uploaded and a download link is sent on WhatsApp.',
              style: TextStyle(
                fontFamily: fontMulishRegular,
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Mobile number',
                hintText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              validator: (value) =>
                  WhatsAppSharePhoneDialog.validatePhone(value ?? ''),
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_preview.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'WhatsApp will open for $_preview',
                style: TextStyle(
                  fontFamily: fontMulishSemiBold,
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(fontFamily: fontMulishSemiBold),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: const Text(
            'Send',
            style: TextStyle(fontFamily: fontMulishSemiBold),
          ),
        ),
      ],
    );
  }
}
