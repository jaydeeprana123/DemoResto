import 'package:flutter/material.dart';

import 'package:demo/Styles/my_font.dart';

class TakeAwayNameDialog {
  TakeAwayNameDialog._();

  static Future<String?> show(
    BuildContext context, {
    required String suggestedName,
    Set<String> existingNames = const {},
    String? currentName,
  }) {
    final blocked = {...existingNames};
    if (currentName != null && currentName.isNotEmpty) {
      blocked.remove(currentName);
    }

    return showDialog<String>(
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.suggestedName);
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

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context, rootNavigator: true)
          .pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
