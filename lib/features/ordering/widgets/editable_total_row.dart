import 'package:smartKitchen/Styles/my_font.dart';
import 'package:flutter/material.dart';

class EditableTotalRow extends StatelessWidget {
  const EditableTotalRow({
    super.key,
    required this.total,
    required this.isEditing,
    required this.controller,
    required this.onEditPressed,
    required this.onApplyPressed,
    this.accentColor = const Color(0xFFf57c35),
  });

  final int total;
  final bool isEditing;
  final TextEditingController controller;
  final VoidCallback onEditPressed;
  final VoidCallback onApplyPressed;
  final Color accentColor;

  static const _navy = Color(0xFF1A3A5C);
  static const _border = Color(0xFFE3E8EF);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Total',
          style: TextStyle(
            fontFamily: fontMulishBold,
            fontSize: 17,
            color: _navy,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEditing)
              SizedBox(
                width: 96,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: fontMulishBold,
                    fontSize: 17,
                    color: _navy,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: '₹',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: accentColor),
                    ),
                  ),
                  onSubmitted: (_) => onApplyPressed(),
                ),
              )
            else
              Text(
                '₹$total',
                style: const TextStyle(
                  fontFamily: fontMulishBold,
                  fontSize: 17,
                  color: _navy,
                ),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(
                isEditing ? Icons.check_rounded : Icons.edit_rounded,
                size: 20,
              ),
              color: accentColor,
              tooltip: isEditing ? 'Apply total' : 'Edit total',
              onPressed: isEditing ? onApplyPressed : onEditPressed,
            ),
          ],
        ),
      ],
    );
  }
}
